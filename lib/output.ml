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

let error_json ?status kind message =
  let fields =
    [
      ("kind", `String (string_of_error_kind kind));
      ("message", `String message);
    ]
  in
  let fields =
    match status with None -> fields | Some status -> ("status", `Int status) :: fields
  in
  `Assoc [ ("error", `Assoc (List.rev fields)) ]

let print_error ?status ~json kind message =
  if json then Fmt.epr "%s@." (Yojson.Safe.to_string (error_json ?status kind message))
  else (
    let status_text =
      match status with None -> "" | Some status -> Printf.sprintf " (HTTP %d)" status
    in
    Fmt.epr "error: %s%s: %s@." (string_of_error_kind kind) status_text message);
  exit_code_of_error_kind kind

let usage_error ~json message = print_error ~json Usage message
let validation_error ~json message = print_error ~json Validation message
let auth_error ~json message = print_error ~json Auth message
let network_error ~json message = print_error ~json Network message
let remote_error ?status ~json message = print_error ?status ~json Remote message
let filesystem_error ~json message = print_error ~json Filesystem message
let interrupted_error ~json message = print_error ~json Interrupted message

(** Print a response body, adding a trailing newline if needed. *)
let print_body body =
  Fmt.pr "%s%!" body;
  if not (String.ends_with ~suffix:"\n" body) then Fmt.pr "@."

(** Print a response body as JSON when it parses, preserving raw text otherwise.
*)
let print_json ~compact body =
  match Yojson.Safe.from_string body with
  | json ->
      let rendered =
        if compact then Yojson.Safe.to_string json
        else Yojson.Safe.pretty_to_string json
      in
      Fmt.pr "%s@." rendered
  | exception Yojson.Json_error _ -> print_body body

let message_of_http_response (response : Http.response) =
  if response.body = "" then "empty response body" else response.body

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
    print_error ~status:response.status ~json Auth (message_of_http_response response)
  else remote_error ~status:response.status ~json (message_of_http_response response)
