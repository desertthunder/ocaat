(** Replacement text used for credentials and sensitive fields. *)
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

(** Redact sensitive fields recursively in a JSON value. *)
let rec json = function
  | `Assoc fields ->
      `Assoc
        (List.map
           (fun (name, value) ->
             if sensitive_field_name name then (name, `String redacted)
             else (name, json value))
           fields)
  | `List values -> `List (List.map json values)
  | value -> value

let redact_authorization_line line =
  let trimmed = String.trim line in
  let prefix = "authorization:" in
  if
    String.length trimmed >= String.length prefix
    && lowercase_ascii (String.sub trimmed 0 (String.length prefix)) = prefix
  then "Authorization: Bearer " ^ redacted
  else
    let bearer = "bearer " in
    let lower = lowercase_ascii line in
    match String.index_opt lower 'b' with
    | Some index
      when index + String.length bearer <= String.length line
           && String.sub lower index (String.length bearer) = bearer ->
        String.sub line 0 index ^ "Bearer " ^ redacted
    | _ -> line

(** Redact authorization material in non-JSON text. *)
let text value =
  value |> String.split_on_char '\n'
  |> List.map redact_authorization_line
  |> String.concat "\n"

(** Redact a response body, parsing JSON when possible. *)
let body body =
  match Yojson.Safe.from_string body with
  | value -> Yojson.Safe.to_string (json value)
  | exception Yojson.Json_error _ -> text body
