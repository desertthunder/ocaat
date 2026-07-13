(** Minimal HTTP helpers for atproto XRPC calls. *)

type response = { status : int; body : string }
(** Text response returned by the HTTP client. *)

type bytes_response = { status : int; headers : Cohttp.Header.t; body : string }
(** Binary/text response with headers, used for CAR and blob transfer. *)

(** Build HTTP headers for an optional bearer token. *)
let auth_headers = function
  | None -> Cohttp.Header.init ()
  | Some token -> Cohttp.Header.init_with "Authorization" ("Bearer " ^ token)

let add_content_type headers = function
  | None -> headers
  | Some content_type -> Cohttp.Header.add headers "Content-Type" content_type

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
let network_error exn = { status = 0; body = Printexc.to_string exn }

let bytes_network_error exn =
  { status = 0; headers = Cohttp.Header.init (); body = Printexc.to_string exn }

let get_text ?auth url =
  let open Lwt.Syntax in
  Lwt.catch
    (fun () ->
      let uri = Uri.of_string url in
      let headers = auth_headers auth in
      let* response, body = Cohttp_lwt_unix.Client.get ~headers uri in
      let status =
        Cohttp.Response.status response |> Cohttp.Code.code_of_status
      in
      let+ body = Cohttp_lwt.Body.to_string body in
      { status; body })
    (fun exn -> Lwt.return (network_error exn))

exception Response_too_large

let bounded_body ~max_bytes body =
  let stream = Cohttp_lwt.Body.to_stream body in
  let buffer = Buffer.create (min max_bytes 4096) in
  let rec read total =
    let open Lwt.Syntax in
    let* chunk = Lwt_stream.get stream in
    match chunk with
    | None -> Lwt.return (Buffer.contents buffer)
    | Some chunk ->
        let total = total + String.length chunk in
        if total > max_bytes then Lwt.fail Response_too_large
        else (
          Buffer.add_string buffer chunk;
          read total)
  in
  read 0

(** GET text with an explicit body-size and wall-clock bound.

    This is used for untrusted discovery responses. An oversized or timed-out
    response is represented as a network response with status [0], preserving
    the existing error-rendering seam without exposing an unbounded body. *)
let get_text_limited ?auth ~max_bytes ~timeout_seconds url =
  if max_bytes < 1 then invalid_arg "HTTP response size limit must be positive";
  if timeout_seconds <= 0.0 then
    invalid_arg "HTTP timeout must be greater than zero";
  let open Lwt.Syntax in
  let request () =
    let uri = Uri.of_string url in
    let headers = auth_headers auth in
    let* response, body = Cohttp_lwt_unix.Client.get ~headers uri in
    let status =
      Cohttp.Response.status response |> Cohttp.Code.code_of_status
    in
    let content_length_exceeds_limit =
      match
        Cohttp.Header.get (Cohttp.Response.headers response) "content-length"
      with
      | Some value -> (
          match int_of_string_opt value with
          | Some length -> length > max_bytes
          | None -> false)
      | None -> false
    in
    if content_length_exceeds_limit then Lwt.fail Response_too_large
    else
      let+ body = bounded_body ~max_bytes body in
      { status; body }
  in
  Lwt.catch
    (fun () -> Lwt_unix.with_timeout timeout_seconds request)
    (function
      | Response_too_large ->
          Lwt.return
            {
              status = 0;
              body =
                Printf.sprintf "response exceeded the %d-byte limit" max_bytes;
            }
      | Lwt_unix.Timeout ->
          Lwt.return
            {
              status = 0;
              body =
                Printf.sprintf "request timed out after %.1f seconds"
                  timeout_seconds;
            }
      | exn -> Lwt.return (network_error exn))

(** GET a URL and keep response headers with the body. *)
let get_bytes ?auth url =
  let open Lwt.Syntax in
  Lwt.catch
    (fun () ->
      let uri = Uri.of_string url in
      let headers = auth_headers auth in
      let* response, body = Cohttp_lwt_unix.Client.get ~headers uri in
      let status =
        Cohttp.Response.status response |> Cohttp.Code.code_of_status
      in
      let headers = Cohttp.Response.headers response in
      let+ body = Cohttp_lwt.Body.to_string body in
      { status; headers; body })
    (fun exn -> Lwt.return (bytes_network_error exn))

(** POST a text body and return the response as text. *)
let post_text ?auth ?content_type ~body url =
  let open Lwt.Syntax in
  Lwt.catch
    (fun () ->
      let uri = Uri.of_string url in
      let headers =
        auth_headers auth |> Fun.flip add_content_type content_type
      in
      let body = Cohttp_lwt.Body.of_string body in
      let* response, body = Cohttp_lwt_unix.Client.post ~headers ~body uri in
      let status =
        Cohttp.Response.status response |> Cohttp.Code.code_of_status
      in
      let+ body = Cohttp_lwt.Body.to_string body in
      { status; body })
    (fun exn -> Lwt.return (network_error exn))

(** POST a JSON object body. *)
let post_json ?auth ~json url =
  post_text ?auth ~content_type:"application/json"
    ~body:(Yojson.Safe.to_string json)
    url

(** POST a binary body and return the response as text. *)
let post_bytes ?auth ?content_type ~body url =
  post_text ?auth ?content_type ~body url
