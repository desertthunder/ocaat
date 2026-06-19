(** Output helpers shared by CLI command modules. *)

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

(** Print an HTTP response and return a process exit code.

    Successful responses are written to stdout.

    Unsuccessful responses are written to stderr, preserving non-JSON bodies
    because XRPC services may return generic proxy errors. *)
let print_http_response ~json response =
  if response.Http.status >= 200 && response.status < 300 then (
    print_json ~compact:json response.body;
    0)
  else (
    Fmt.epr "HTTP %d@." response.status;
    if response.body <> "" then Fmt.epr "%s@." response.body;
    1)
