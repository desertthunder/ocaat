(** Minimal HTTP helpers for atproto XRPC calls. *)

type response = { status : int; body : string }
(** Text response returned by the HTTP client. *)

(** Build HTTP headers for an optional bearer token. *)
let auth_headers = function
  | None -> Cohttp.Header.init ()
  | Some token -> Cohttp.Header.init_with "Authorization" ("Bearer " ^ token)

(** Normalize a host or service URL into an absolute HTTP(S) base URL.

    Bare hosts default to HTTPS.

    Any trailing slash is removed so command modules can append top-level
    atproto paths predictably. *)
let normalize_base_url value =
  let value =
    if
      String.starts_with ~prefix:"http://" value
      || String.starts_with ~prefix:"https://" value
    then value
    else "https://" ^ value
  in
  let rec strip_trailing_slash value =
    let len = String.length value in
    if len > 0 && value.[len - 1] = '/' then
      strip_trailing_slash (String.sub value 0 (len - 1))
    else value
  in
  strip_trailing_slash value

(** Build an XRPC URL at [/xrpc/<method>] with string query parameters. *)
let xrpc_url ~base_url ~method_ ~params =
  let uri = Uri.of_string (normalize_base_url base_url) in
  uri
  |> Fun.flip Uri.with_path ("/xrpc/" ^ method_)
  |> Fun.flip Uri.with_query' params
  |> Uri.to_string

(** GET a URL as UTF-8-ish text.

    The optional [auth] token is sent as HTTP bearer auth.

    Response bodies are left uninterpreted so callers can handle JSON and
    non-JSON errors. *)
let get_text ?auth url =
  let open Lwt.Syntax in
  let uri = Uri.of_string url in
  let headers = auth_headers auth in
  let* response, body = Cohttp_lwt_unix.Client.get ~headers uri in
  let status = Cohttp.Response.status response |> Cohttp.Code.code_of_status in
  let+ body = Cohttp_lwt.Body.to_string body in
  { status; body }
