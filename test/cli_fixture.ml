open Unix

(** Deterministic response shapes supported by the local HTTP fixture server. *)
type response =
  | Json of Yojson.Safe.t
  | Binary of string
  | Malformed of string
  | Delayed of float * response
  | Remote_error of int * string
  | Redirect of int * string

type request = {
  method_ : string;
  url : string;
  headers : (string * string) list;
  body : string;
}
(** Sanitized request metadata captured by a fixture. *)

type route = string * response
(** One deterministic path and response served by a fixture. *)

type command_result = {
  status : int;
  stdout : string;
  stderr : string;
  request : request option;
  requests : request list;
}
(** Result of one CLI invocation, including the fixture's observed request. *)

type rendered_response = {
  status : int;
  content_type : string;
  body : string;
  delay : float;
}

type t = {
  port : int;
  endpoint : string;
  server_pid : int;
  request_read : file_descr;
  mutable server_reaped : bool;
  mutable request_read_complete : bool;
  mutable request : request option;
  mutable requests : request list option;
  mutable command_run : bool;
}

(** Default loopback port for a fixture that does not need a custom port. *)
let default_port = 43127

let close_noerr fd = try close fd with Unix_error (_, _, _) -> ()

let rec waitpid_retry flags pid =
  try waitpid flags pid
  with Unix_error (EINTR, _, _) -> waitpid_retry flags pid

let fail_invalid name value =
  invalid_arg (Printf.sprintf "invalid fixture %s: %s" name value)

let validate_port port =
  if port < 1 || port > 65535 then fail_invalid "port" (string_of_int port)

let validate_path path =
  if path = "" || not (String.starts_with ~prefix:"/" path) then
    fail_invalid "path" path

let rec render_response = function
  | Json json ->
      {
        status = 200;
        content_type = "application/json";
        body = Yojson.Safe.to_string json;
        delay = 0.0;
      }
  | Binary body ->
      {
        status = 200;
        content_type = "application/octet-stream";
        body;
        delay = 0.0;
      }
  | Malformed body ->
      { status = 200; content_type = "application/json"; body; delay = 0.0 }
  | Delayed (delay, response) ->
      if delay < 0.0 then fail_invalid "delay" (string_of_float delay)
      else
        let rendered = render_response response in
        { rendered with delay = rendered.delay +. delay }
  | Remote_error (status, body) ->
      if status < 400 || status > 599 then
        fail_invalid "remote error status" (string_of_int status)
      else { status; content_type = "application/json"; body; delay = 0.0 }
  | Redirect (status, body) ->
      if status < 300 || status > 399 then
        fail_invalid "redirect status" (string_of_int status)
      else { status; content_type = "text/plain"; body; delay = 0.0 }

let request_metadata ~endpoint request body =
  {
    method_ = Cohttp.Code.string_of_method (Cohttp.Request.meth request);
    url = endpoint ^ Cohttp.Request.resource request;
    headers =
      Cohttp.Header.to_list (Cohttp.Request.headers request)
      |> Ocaat__Redaction.headers;
    body = Ocaat__Redaction.body body;
  }

let response_for_routes ~routes ~request_resource =
  match List.assoc_opt request_resource routes with
  | Some response -> render_response response
  | None ->
      {
        status = 404;
        content_type = "text/plain";
        body = "fixture route not found";
        delay = 0.0;
      }

let run_server ~endpoint ~port ~routes write_fd =
  let output = out_channel_of_descr write_fd in
  let callback _connection request body =
    let open Lwt.Syntax in
    let* body = Cohttp_lwt.Body.to_string body in
    let metadata = request_metadata ~endpoint request body in
    Marshal.to_channel output metadata [];
    flush output;
    let rendered =
      response_for_routes ~routes
        ~request_resource:(Cohttp.Request.resource request)
    in
    let* () =
      if rendered.delay = 0.0 then Lwt.return_unit
      else Lwt_unix.sleep rendered.delay
    in
    let headers =
      Cohttp.Header.init_with "content-type" rendered.content_type
    in
    Cohttp_lwt_unix.Server.respond_string ~headers
      ~status:(Cohttp.Code.status_of_code rendered.status)
      ~body:rendered.body ()
  in
  let server = Cohttp_lwt_unix.Server.make ~callback () in
  try
    Lwt_main.run
      (Cohttp_lwt_unix.Server.create ~mode:(`TCP (`Port port)) server);
    close_out_noerr output
  with error ->
    prerr_endline ("fixture server failed: " ^ Printexc.to_string error);
    flush Stdlib.stderr;
    close_out_noerr output;
    exit 1

let socket_connects port =
  let socket = socket PF_INET SOCK_STREAM 0 in
  Fun.protect
    ~finally:(fun () -> close_noerr socket)
    (fun () ->
      try
        connect socket (ADDR_INET (inet_addr_loopback, port));
        true
      with Unix_error (_, _, _) -> false)

let wait_for_port ~pid port =
  let rec loop attempts =
    if attempts = 0 then failwith "fixture server did not start"
    else if socket_connects port then ()
    else
      match waitpid_retry [ WNOHANG ] pid with
      | 0, _ ->
          Unix.sleepf 0.01;
          loop (attempts - 1)
      | _, _ -> failwith "fixture server exited before it was ready"
  in
  loop 500

(** Start a deterministic loopback HTTP fixture with several exact routes. *)
let create_routes ?(port = default_port) routes =
  validate_port port;
  List.iter
    (fun (path, response) ->
      validate_path path;
      ignore (render_response response))
    routes;
  let endpoint = Printf.sprintf "http://127.0.0.1:%d" port in
  let request_read, request_write = pipe () in
  match fork () with
  | 0 ->
      close request_read;
      run_server ~endpoint ~port ~routes request_write;
      exit 0
  | server_pid -> (
      close request_write;
      try
        wait_for_port ~pid:server_pid port;
        {
          port;
          endpoint;
          server_pid;
          request_read;
          server_reaped = false;
          request_read_complete = false;
          request = None;
          requests = None;
          command_run = false;
        }
      with error ->
        (try kill server_pid Sys.sigterm with Unix_error (_, _, _) -> ());
        (try ignore (waitpid_retry [] server_pid)
         with Unix_error (ECHILD, _, _) -> ());
        close_noerr request_read;
        raise error)

(** Start a deterministic loopback HTTP fixture at one exact [path]. *)
let create ?(port = default_port) ~path response =
  create_routes ~port [ (path, response) ]

(** Return the base URL used by the fixture. *)
let endpoint fixture = fixture.endpoint

let process_status = function
  | WEXITED status -> status
  | WSIGNALED signal | WSTOPPED signal -> 128 + signal

let read_process_stream open_fds fd output =
  let buffer = Bytes.create 4096 in
  try
    let count = read fd buffer 0 (Bytes.length buffer) in
    if count = 0 then (
      close_noerr fd;
      open_fds := List.filter (fun open_fd -> open_fd <> fd) !open_fds)
    else Buffer.add_subbytes output buffer 0 count
  with Unix_error ((EAGAIN | EWOULDBLOCK), _, _) -> ()

let source_root () =
  let rec search directory =
    if Sys.file_exists (Filename.concat directory "dune-project") then directory
    else
      let parent = Filename.dirname directory in
      if parent = directory then failwith "could not locate dune-project"
      else search parent
  in
  search (Sys.getcwd ())

let cli_executable () =
  let root = source_root () in
  let candidates =
    [
      Filename.concat root "_build/default/bin/main.exe";
      Filename.concat (Filename.dirname Sys.executable_name) "../bin/main.exe";
    ]
  in
  match List.find_opt Sys.file_exists candidates with
  | Some executable -> executable
  | None -> failwith "could not locate the built CLI executable"

let read_process_output ~pid ~stdout_read ~stderr_read ~timeout =
  Unix.set_nonblock stdout_read;
  Unix.set_nonblock stderr_read;
  let open_fds = ref [ stdout_read; stderr_read ] in
  let stdout = Buffer.create 4096 in
  let stderr = Buffer.create 4096 in
  let deadline = Unix.gettimeofday () +. timeout in
  while !open_fds <> [] do
    let remaining = deadline -. Unix.gettimeofday () in
    if remaining <= 0.0 then (
      (try kill pid Sys.sigterm with Unix_error (_, _, _) -> ());
      ignore (waitpid_retry [] pid);
      close_noerr stdout_read;
      close_noerr stderr_read;
      failwith "CLI fixture command timed out")
    else
      let ready, _, _ = select !open_fds [] [] remaining in
      List.iter
        (fun fd ->
          if fd = stdout_read then read_process_stream open_fds fd stdout
          else read_process_stream open_fds fd stderr)
        ready
  done;
  let _, status = waitpid_retry [] pid in
  (process_status status, Buffer.contents stdout, Buffer.contents stderr)

let run_cli ?(timeout = 10.0) args =
  let executable = cli_executable () in
  let argv = Array.of_list (executable :: args) in
  let stdin = openfile "/dev/null" [ O_RDONLY ] 0 in
  let stdout_read, stdout_write = pipe () in
  let stderr_read, stderr_write = pipe () in
  Unix.putenv "NO_COLOR" "1";
  try
    let pid = create_process executable argv stdin stdout_write stderr_write in
    close_noerr stdin;
    close_noerr stdout_write;
    close_noerr stderr_write;
    Fun.protect
      ~finally:(fun () ->
        close_noerr stdout_read;
        close_noerr stderr_read)
      (fun () -> read_process_output ~pid ~stdout_read ~stderr_read ~timeout)
  with error ->
    close_noerr stdin;
    close_noerr stdout_write;
    close_noerr stderr_write;
    close_noerr stdout_read;
    close_noerr stderr_read;
    raise error

let read_requests fixture =
  if not fixture.request_read_complete then (
    fixture.request_read_complete <- true;
    let input = in_channel_of_descr fixture.request_read in
    let rec read acc =
      match Marshal.from_channel input with
      | request -> read (request :: acc)
      | exception End_of_file -> List.rev acc
    in
    let requests = read [] in
    fixture.requests <- Some requests;
    fixture.request <-
      (match requests with first :: _ -> Some first | [] -> None);
    close_in_noerr input);
  Option.value ~default:[] fixture.requests

(** Stop a fixture and return all sanitized captured requests. *)
let stop_all fixture =
  (if not fixture.server_reaped then
     let pid, _ = waitpid_retry [ WNOHANG ] fixture.server_pid in
     if pid = 0 then (
       (try kill fixture.server_pid Sys.sigterm
        with Unix_error (_, _, _) -> ());
       ignore (waitpid_retry [] fixture.server_pid))
     else fixture.server_reaped <- true);
  if not fixture.server_reaped then fixture.server_reaped <- true;
  read_requests fixture

(** Stop a fixture and return its first sanitized request, if any. *)
let stop fixture =
  match stop_all fixture with first :: _ -> Some first | [] -> None

(** Run one CLI invocation against the fixture executable boundary. *)
let run fixture args =
  if fixture.command_run then invalid_arg "a fixture can run only one command";
  fixture.command_run <- true;
  try
    let status, stdout, stderr = run_cli args in
    let requests = stop_all fixture in
    let request = match requests with first :: _ -> Some first | [] -> None in
    { status; stdout; stderr; request; requests }
  with error ->
    ignore (stop fixture);
    raise error

(** Release a fixture when a test exits before [run] completes. *)
let close fixture = ignore (stop_all fixture)
