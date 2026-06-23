(** Output helpers shared by CLI command modules. *)

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

let redacted = "[REDACTED]"
let lowercase_ascii value = String.lowercase_ascii value

let contains ~needle value =
  let needle = lowercase_ascii needle in
  let value = lowercase_ascii value in
  let needle_len = String.length needle in
  let value_len = String.length value in
  let rec loop index =
    index + needle_len <= value_len
    && (String.sub value index needle_len = needle || loop (index + 1))
  in
  needle_len = 0 || loop 0

let sensitive_field_name name =
  let name = lowercase_ascii name in
  List.exists
    (fun needle -> contains ~needle name)
    [
      "accessjwt";
      "refreshjwt";
      "password";
      "apptoken";
      "app_password";
      "apppassword";
      "serviceauth";
      "service_auth";
      "admintoken";
      "admin_token";
      "authorization";
      "token";
    ]

let rec redact_json = function
  | `Assoc fields ->
      `Assoc
        (List.map
           (fun (name, value) ->
             if sensitive_field_name name then (name, `String redacted)
             else (name, redact_json value))
           fields)
  | `List values -> `List (List.map redact_json values)
  | value -> value

let redact_text value =
  let redact_authorization line =
    let prefix = "authorization:" in
    if
      String.length line >= String.length prefix
      && lowercase_ascii (String.sub line 0 (String.length prefix)) = prefix
    then "Authorization: Bearer " ^ redacted
    else line
  in
  value |> String.split_on_char '\n'
  |> List.map redact_authorization
  |> String.concat "\n"

let redact_body body =
  match Yojson.Safe.from_string body with
  | json -> Yojson.Safe.to_string (redact_json json)
  | exception Yojson.Json_error _ -> redact_text body

let error_json ?status kind message =
  let fields =
    [
      ("kind", `String (string_of_error_kind kind));
      ("message", `String (redact_text message));
    ]
  in
  let fields =
    match status with
    | None -> fields
    | Some status -> ("status", `Int status) :: fields
  in
  `Assoc [ ("error", `Assoc (List.rev fields)) ]

let print_error ?status ~json kind message =
  let message = redact_text message in
  (if json then
     Fmt.epr "%s@." (Yojson.Safe.to_string (error_json ?status kind message))
   else
     let status_text =
       match status with
       | None -> ""
       | Some status -> Printf.sprintf " (HTTP %d)" status
     in
     Fmt.epr "error: %s%s: %s@." (string_of_error_kind kind) status_text message);
  exit_code_of_error_kind kind

let usage_error ~json message = print_error ~json Usage message
let validation_error ~json message = print_error ~json Validation message
let auth_error ~json message = print_error ~json Auth message
let network_error ~json message = print_error ~json Network message

let remote_error ?status ~json message =
  print_error ?status ~json Remote message

let filesystem_error ~json message = print_error ~json Filesystem message
let interrupted_error ~json message = print_error ~json Interrupted message

(** Print a response body, adding a trailing newline if needed. *)
let print_body body =
  let body = redact_body body in
  Fmt.pr "%s%!" body;
  if not (String.ends_with ~suffix:"\n" body) then Fmt.pr "@."

(** Print a response body as JSON when it parses, preserving raw text otherwise.
*)
let print_json ~compact body =
  match Yojson.Safe.from_string body with
  | json ->
      let json = redact_json json in
      let rendered =
        if compact then Yojson.Safe.to_string json
        else Yojson.Safe.pretty_to_string json
      in
      Fmt.pr "%s@." rendered
  | exception Yojson.Json_error _ -> print_body body

let print_json_value ?(compact = true) json =
  let json = redact_json json in
  let rendered =
    if compact then Yojson.Safe.to_string json
    else Yojson.Safe.pretty_to_string json
  in
  Fmt.pr "%s@." rendered

let message_of_http_response (response : Http.response) =
  if response.body = "" then "empty response body"
  else redact_body response.body

(** Print an HTTP response and return a process exit code.

    Successful responses are written to stdout.

    Unsuccessful responses use the standard CLI error envelope. *)
let print_http_response ~json (response : Http.response) =
  if response.Http.status >= 200 && response.status < 300 then (
    print_json ~compact:json response.body;
    Exit_code.ok)
  else if response.status = 0 then
    network_error ~json (message_of_http_response response)
  else if response.status = 401 || response.status = 403 then
    print_error ~status:response.status ~json Auth
      (message_of_http_response response)
  else
    remote_error ~status:response.status ~json
      (message_of_http_response response)

module Preflight = struct
  let require_value name = function
    | Some value when String.trim value <> "" -> Ok value
    | _ -> Error (name ^ " is required")

  let require_pds = require_value "PDS URL"
  let require_auth = require_value "auth token"
  let require_admin_auth = require_value "admin token"

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
  type t = { json : bool }

  let make ~json = { json }

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
    if t.json then Fmt.pr "%s@." (Yojson.Safe.to_string json)
    else
      match (current, total) with
      | Some current, Some total -> Fmt.epr "%s %d/%d@." label current total
      | Some current, None -> Fmt.epr "%s %d@." label current
      | None, _ -> Fmt.epr "%s@." label
end
