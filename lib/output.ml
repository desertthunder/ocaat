(** Output helpers shared by CLI command modules. *)

(** Stable process exit categories used by command modules. *)
module Exit_code = struct
  let ok = 0
  let usage = 64
  let validation = 65
  let auth = 66
  let network = 69
  let remote = 70
  let filesystem = 74
  let interrupted = 130
end

(** Error categories mapped to the stable exit codes above. *)
type error_kind =
  | Usage
  | Validation
  | Auth
  | Network
  | Remote
  | Filesystem
  | Interrupted

let string_of_error_kind = function
  | Usage -> "usage"
  | Validation -> "validation"
  | Auth -> "auth"
  | Network -> "network"
  | Remote -> "remote"
  | Filesystem -> "filesystem"
  | Interrupted -> "interrupted"

let exit_code_of_error_kind = function
  | Usage -> Exit_code.usage
  | Validation -> Exit_code.validation
  | Auth -> Exit_code.auth
  | Network -> Exit_code.network
  | Remote -> Exit_code.remote
  | Filesystem -> Exit_code.filesystem
  | Interrupted -> Exit_code.interrupted

type format = Format.t
(** Alias used by shared output functions. *)

(** Shared redaction aliases retained for command and test modules. *)
let redacted = Redaction.redacted

(** Redact a JSON value before rendering it. *)
let redact_json = Redaction.json

(** Redact text before placing it in a diagnostic. *)
let redact_text = Redaction.text

(** Redact a response body before displaying or reporting it. *)
let redact_body = Redaction.body

(** Sanitize and print an error, returning its stable process exit code. *)
let print_error ?status ~format kind message =
  let message = redact_text message in
  let error =
    Error_document.make ?status ~kind:(string_of_error_kind kind) ~message ()
  in
  Renderer.print_stderr (Renderer.error format error);
  exit_code_of_error_kind kind

let usage_error ~format message = print_error ~format Usage message
let validation_error ~format message = print_error ~format Validation message
let auth_error ~format message = print_error ~format Auth message
let network_error ~format message = print_error ~format Network message

let remote_error ?status ~format message =
  print_error ?status ~format Remote message

let filesystem_error ~format message = print_error ~format Filesystem message
let interrupted_error ~format message = print_error ~format Interrupted message

let message_of_http_response ~endpoint (response : Http.response) =
  let detail =
    if response.body = "" then "empty response body"
    else redact_body response.body
  in
  endpoint ^ ": " ^ detail

(** Print an HTTP response and return a process exit code.

    Successful responses are written to stdout. Unsuccessful responses use the
    standard CLI error envelope. The selected format controls whether the
    response is rendered as a document, raw payload, or sanitized error. *)
let print_http_response ?(kind = "pds") ?(source = "pds") ?did ?pds ?summary
    ?(require_json = false) ~format ~endpoint (response : Http.response) =
  if response.Http.status >= 200 && response.status < 300 then
    match format with
    | Format.Raw ->
        Renderer.print_stdout (Renderer.raw response.body);
        Exit_code.ok
    | (Format.Markdown | Format.Json | Format.Jsonl) as format -> (
        let data_result =
          match Yojson.Safe.from_string response.body with
          | json -> Ok json
          | exception Yojson.Json_error reason -> Error reason
        in
        match data_result with
        | Ok data ->
            let document =
              Document.make ?did ?pds ?summary ~source ~endpoint ~kind data
            in
            Renderer.print_stdout (Renderer.document format document);
            Exit_code.ok
        | Error reason when require_json ->
            remote_error ~format (endpoint ^ " returned invalid JSON: " ^ reason)
        | Error _ ->
            let document =
              Document.make ?did ?pds ?summary ~source ~endpoint ~kind
                (`String response.body)
            in
            Renderer.print_stdout (Renderer.document format document);
            Exit_code.ok)
  else if response.status = 0 then
    network_error ~format (message_of_http_response ~endpoint response)
  else if response.status = 401 || response.status = 403 then
    print_error ~status:response.status ~format Auth
      (message_of_http_response ~endpoint response)
  else
    remote_error ~status:response.status ~format
      (message_of_http_response ~endpoint response)

(** Parse and render a successful JSON response while preserving the shared HTTP
    error contract for unsuccessful responses. *)
let print_parsed_response ?did ?pds ?(sources = []) ?summary ~kind ~source
    ~endpoint ~format ~parse (response : Http.response) =
  if response.Http.status >= 200 && response.status < 300 then (
    match parse response.body with
    | Error reason -> remote_error ~format reason
    | Ok data ->
        if format = Format.Raw then (
          Renderer.print_stdout (Renderer.raw response.body);
          Exit_code.ok)
        else
          let document =
            Document.make ?did ?pds ~sources ?summary ~source ~endpoint ~kind
              data
          in
          Renderer.print_stdout (Renderer.document format document);
          Exit_code.ok)
  else
    print_http_response ~kind ~source ?did ?pds ?summary ~require_json:true
      ~endpoint ~format response

(** Validation helpers that run before network or filesystem work. *)
module Preflight = struct
  let require_value name = function
    | Some value when String.trim value <> "" -> Ok value
    | _ -> Error (name ^ " is required")

  let require_pds = require_value "PDS URL"
  let require_auth = require_value "auth token"
  let require_admin_auth = require_value "admin token"

  (** Validate and normalize a service URL before making a request. *)
  let require_service_url name value =
    let value =
      if
        String.starts_with ~prefix:"http://" value
        || String.starts_with ~prefix:"https://" value
      then value
      else "https://" ^ value
    in
    match Syntax.validate_service_url value with
    | Syntax.Valid -> Ok (Http.normalize_base_url value)
    | Syntax.Invalid reason -> Error (name ^ ": " ^ reason)

  let require_did_or_handle value =
    match (Syntax.validate_did value, Syntax.validate_handle value) with
    | Syntax.Valid, _ | _, Syntax.Valid -> Ok value
    | Syntax.Invalid did_reason, Syntax.Invalid handle_reason ->
        Error
          ("expected DID or handle; DID " ^ did_reason ^ "; handle "
         ^ handle_reason)

  let require_input_file path =
    if not (Sys.file_exists path) then
      Error ("input file does not exist: " ^ path)
    else if Sys.is_directory path then
      Error ("input path is a directory: " ^ path)
    else Ok path

  let require_output_path ?(force = false) path =
    match Syntax.validate_artifact_path path with
    | Syntax.Invalid reason -> Error ("invalid output path: " ^ reason)
    | Syntax.Valid ->
        if Sys.file_exists path && not force then
          Error
            ("output already exists: " ^ path ^ " (pass --force to overwrite)")
        else Ok path

  let require_artifact_state ~exists path =
    let actual = Sys.file_exists path in
    if Bool.equal actual exists then Ok path
    else if exists then Error ("required artifact is missing: " ^ path)
    else Error ("artifact already exists: " ^ path)
end

(** Confirmation helper for commands that may change state. *)
module Confirm = struct
  let prompt ?(yes = false) message =
    if yes then Ok true
    else if not (Unix.isatty Unix.stdin) then
      Error (message ^ " requires --yes in non-interactive mode")
    else (
      Fmt.epr "%s Type 'yes' to continue: %!" message;
      match read_line () with
      | "yes" -> Ok true
      | _ -> Ok false
      | exception End_of_file -> Error "confirmation input ended")
end

(** Safe artifact path and write helpers. *)
module Artifact = struct
  type state = Missing | File | Directory

  let state path =
    if not (Sys.file_exists path) then Missing
    else if Sys.is_directory path then Directory
    else File

  let ensure_parent_dir path =
    let dir = Filename.dirname path in
    if dir = "." || Sys.file_exists dir then Ok ()
    else
      try
        Unix.mkdir dir 0o755;
        Ok ()
      with Sys_error reason -> Error reason

  let can_write ?(force = false) path =
    match Preflight.require_output_path ~force path with
    | Error _ as error -> error
    | Ok _ -> ensure_parent_dir path

  let write_file ?(force = false) path body =
    match can_write ~force path with
    | Error reason -> Error reason
    | Ok () -> (
        try
          let channel = open_out_bin path in
          Fun.protect
            ~finally:(fun () -> close_out_noerr channel)
            (fun () -> output_string channel body);
          Ok ()
        with Sys_error reason -> Error reason)
end

module Progress = struct
  type t = { format : format }
  (** Progress output is always diagnostic output and therefore uses stderr. *)

  (** Create a progress renderer using the command's selected format. *)
  let make ~format = { format }

  (** Emit one human or JSON progress event. *)
  let event t ?current ?total label fields =
    let fields =
      ("event", `String label)
      ::
      (match current with
      | None -> fields
      | Some value -> ("current", `Int value) :: fields)
    in
    let fields =
      match total with
      | None -> fields
      | Some value -> ("total", `Int value) :: fields
    in
    let json = redact_json (`Assoc (List.rev fields)) in
    if Format.is_json t.format then
      Renderer.print_stderr (Yojson.Safe.to_string json ^ "\n")
    else
      match (current, total) with
      | Some current, Some total ->
          Renderer.print_stderr
            (Printf.sprintf "%s %d/%d\n" label current total)
      | Some current, None ->
          Renderer.print_stderr (Printf.sprintf "%s %d\n" label current)
      | None, _ -> Renderer.print_stderr (label ^ "\n")
end
