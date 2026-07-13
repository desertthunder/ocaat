let assert_equal label expected actual =
  if expected <> actual then
    failwith (Printf.sprintf "%s: expected %S, got %S" label expected actual)

let assert_int label expected actual =
  if expected <> actual then
    failwith (Printf.sprintf "%s: expected %d, got %d" label expected actual)

let assert_true label condition = if not condition then failwith label

let assert_contains label needle value =
  if not (String.contains value needle.[0]) then
    failwith (Printf.sprintf "%s: %S does not contain %S" label value needle)
  else
    let rec loop index =
      if index + String.length needle > String.length value then false
      else if String.sub value index (String.length needle) = needle then true
      else loop (index + 1)
    in
    if not (loop 0) then
      failwith (Printf.sprintf "%s: %S does not contain %S" label value needle)

let assert_not_contains label needle value =
  let rec loop index =
    if index + String.length needle > String.length value then false
    else if String.sub value index (String.length needle) = needle then true
    else loop (index + 1)
  in
  if needle <> "" && loop 0 then
    failwith (Printf.sprintf "%s: %S contains %S" label value needle)

let header name headers =
  headers
  |> List.find_map (fun (candidate, value) ->
      if String.lowercase_ascii candidate = String.lowercase_ascii name then
        Some value
      else None)

let request_of_result (result : Cli_fixture.command_result) =
  match result.request with
  | Some request -> request
  | None -> failwith "fixture did not observe an HTTP request"

let assert_request (result : Cli_fixture.command_result) ~method_ ~url ~body
    ~authorization =
  let request = request_of_result result in
  assert_equal "request method" method_ request.method_;
  assert_equal "request URL" url request.url;
  assert_equal "request body" body request.body;
  match header "authorization" request.headers with
  | Some value -> assert_equal "redacted authorization" authorization value
  | None -> failwith "request did not contain an authorization header"

let markdown_blocks markdown =
  match
    Cmarkit.Block.normalize
      (Cmarkit.Doc.block (Cmarkit.Doc.of_string ~strict:false markdown))
  with
  | Cmarkit.Block.Blocks (blocks, _) -> blocks
  | block -> [ block ]

let markdown_heading expected blocks =
  List.exists
    (function
      | Cmarkit.Block.Heading (heading, _) ->
          let text =
            Cmarkit.Inline.to_plain_text ~break_on_soft:false
              (Cmarkit.Block.Heading.inline heading)
            |> List.map (String.concat "")
            |> String.concat "\n"
          in
          text = expected
      | _ -> false)
    blocks

let markdown_code_blocks blocks =
  List.filter_map
    (function
      | Cmarkit.Block.Code_block (code, _) ->
          Some
            (Cmarkit.Block.Code_block.code code
            |> List.map Cmarkit.Block_line.to_string
            |> String.concat "\n")
      | _ -> None)
    blocks

let endpoint port = Printf.sprintf "http://127.0.0.1:%d" port

let xrpc_args port extra =
  [
    "xrpc";
    "query";
    "com.atproto.server.describeServer";
    "--pds";
    endpoint port;
    "--auth";
    "fixture-request-secret";
  ]
  @ extra

let with_fixture ~port response args =
  let fixture =
    Cli_fixture.create ~port ~path:"/xrpc/com.atproto.server.describeServer"
      response
  in
  Fun.protect
    ~finally:(fun () -> Cli_fixture.close fixture)
    (fun () -> Cli_fixture.run fixture (args port))

let with_pds_fixture ~port ~path response args =
  let fixture = Cli_fixture.create ~port ~path response in
  Fun.protect
    ~finally:(fun () -> Cli_fixture.close fixture)
    (fun () -> Cli_fixture.run fixture (args (endpoint port)))

let resource_path endpoint url =
  let prefix = endpoint in
  String.sub url (String.length prefix)
    (String.length url - String.length prefix)

let json_member name json = Yojson.Safe.Util.member name json
let json_string name json = json_member name json |> Yojson.Safe.Util.to_string

let read_channel channel =
  let buffer = Bytes.create 4096 in
  let output = Buffer.create 4096 in
  let rec loop () =
    match input channel buffer 0 (Bytes.length buffer) with
    | 0 -> Buffer.contents output
    | count ->
        Buffer.add_subbytes output buffer 0 count;
        loop ()
  in
  loop ()

let write_all socket body =
  let body = Bytes.of_string body in
  let rec loop offset =
    if offset < Bytes.length body then
      let written =
        Unix.write socket body offset (Bytes.length body - offset)
      in
      loop (offset + written)
  in
  loop 0

let post_fixture_request ~endpoint ~path =
  let socket = Unix.socket Unix.PF_INET Unix.SOCK_STREAM 0 in
  Fun.protect
    ~finally:(fun () ->
      try Unix.close socket with Unix.Unix_error (_, _, _) -> ())
    (fun () ->
      let uri = Uri.of_string endpoint in
      Unix.connect socket
        (Unix.ADDR_INET (Unix.inet_addr_loopback, Option.get (Uri.port uri)));
      let body = {|{"password":"post-body-secret","handle":"fixture.test"}|} in
      let request =
        Printf.sprintf
          "POST %s HTTP/1.1\r\n\
           Host: 127.0.0.1\r\n\
           Content-Type: application/json\r\n\
           Authorization: Bearer post-request-secret\r\n\
           Content-Length: %d\r\n\
           Connection: close\r\n\
           \r\n\
           %s"
          path (String.length body) body
      in
      write_all socket request;
      let input = Unix.in_channel_of_descr socket in
      Fun.protect
        ~finally:(fun () -> close_in_noerr input)
        (fun () -> read_channel input))

let () =
  let json_result =
    with_fixture ~port:43127
      (Cli_fixture.Json
         (`Assoc
            [
              ("ok", `Bool true);
              ("token", `String "fixture-response-secret");
              ("name", `String "fixture");
            ]))
      (fun port -> xrpc_args port [ "--format"; "json" ])
  in
  assert_int "JSON exit status" 0 json_result.status;
  assert_equal "JSON stderr" "" json_result.stderr;
  assert_contains "JSON document" "ocaat.document.v1" json_result.stdout;
  assert_contains "JSON redaction" "[REDACTED]" json_result.stdout;
  assert_not_contains "JSON response secret" "fixture-response-secret"
    json_result.stdout;
  assert_not_contains "JSON request secret" "fixture-request-secret"
    (json_result.stdout ^ json_result.stderr);
  assert_request json_result ~method_:"GET"
    ~url:(endpoint 43127 ^ "/xrpc/com.atproto.server.describeServer")
    ~body:"" ~authorization:"[REDACTED]";

  let markdown_result =
    with_fixture ~port:43133
      (Cli_fixture.Json
         (`Assoc
            [
              ("status", `String "ok");
              ("url", `String "https://example.test/a_(b)");
              ( "description",
                `String "line one\n# forged heading\n```\n| forged | table |" );
              ("html", `String "<script>alert(1)</script>");
              ("token", `String "fixture-response-secret");
            ]))
      (fun port -> xrpc_args port [ "--format"; "markdown" ])
  in
  assert_int "Markdown exit status" 0 markdown_result.status;
  assert_equal "Markdown stderr" "" markdown_result.stderr;
  assert_contains "Markdown summary" "# Pds" markdown_result.stdout;
  assert_contains "Markdown provenance" "## Provenance" markdown_result.stdout;
  assert_contains "Markdown raw" "## Raw" markdown_result.stdout;
  assert_contains "Markdown redaction" "[REDACTED]" markdown_result.stdout;
  assert_not_contains "Markdown response secret" "fixture-response-secret"
    markdown_result.stdout;
  let parsed = markdown_blocks markdown_result.stdout in
  assert_true "Markdown parsed provenance heading"
    (markdown_heading "Provenance" parsed);
  assert_true "Markdown parsed raw heading" (markdown_heading "Raw" parsed);
  assert_true "Markdown hostile text remains code data"
    (List.exists
       (fun code ->
         assert_contains "Markdown hostile fence" "forged heading" code;
         true)
       (markdown_code_blocks parsed));
  assert_true "Markdown hostile text is not a heading"
    (not (markdown_heading "forged heading" parsed));
  assert_request markdown_result ~method_:"GET"
    ~url:(endpoint 43133 ^ "/xrpc/com.atproto.server.describeServer")
    ~body:"" ~authorization:"[REDACTED]";

  let health_port = 43134 in
  let health_response =
    Cli_fixture.Json
      (`Assoc
         [
           ("status", `String "ok");
           ( "metrics",
             `Assoc
               [
                 ("hostedAccountCount", `Int 2);
                 ("repoCount", `Int 2);
                 ("blobCount", `Int 9);
                 ("sequencerCursor", `Int 42);
               ] );
         ])
  in
  let health_result =
    with_pds_fixture ~port:health_port ~path:"/xrpc/_health" health_response
      (fun pds -> [ "pds"; "health"; "--pds"; pds; "--format"; "json" ])
  in
  assert_int "PDS health exit status" 0 health_result.status;
  assert_equal "PDS health stderr" "" health_result.stderr;
  let health_json = Yojson.Safe.from_string health_result.stdout in
  assert_equal "PDS health kind" "pds" (json_string "kind" health_json);
  let health_meta = json_member "meta" health_json in
  assert_equal "PDS health source" "pds" (json_string "source" health_meta);
  assert_equal "PDS health endpoint"
    (endpoint health_port ^ "/xrpc/_health")
    (json_string "endpoint" health_meta);
  assert_equal "PDS health PDS metadata" (endpoint health_port)
    (json_string "pds" health_meta);
  assert_equal "PDS health payload" "ok"
    (json_string "status" (json_member "data" health_json));
  let health_request = request_of_result health_result in
  assert_equal "PDS health method" "GET" health_request.method_;
  assert_equal "PDS health URL"
    (endpoint health_port ^ "/xrpc/_health")
    health_request.url;
  assert_true "PDS health has no authorization"
    (header "authorization" health_request.headers = None);

  let health_markdown =
    with_pds_fixture ~port:43135 ~path:"/xrpc/_health" health_response
      (fun pds -> [ "pds"; "health"; "--pds"; pds; "--format"; "markdown" ])
  in
  assert_int "PDS health Markdown exit status" 0 health_markdown.status;
  assert_contains "PDS health Markdown hostname" "hostname"
    health_markdown.stdout;
  assert_contains "PDS health Markdown account summary" "accountCount"
    health_markdown.stdout;
  assert_contains "PDS health Markdown provenance" "## Provenance"
    health_markdown.stdout;
  assert_contains "PDS health Markdown raw" "## Raw" health_markdown.stdout;

  let admin_port = 43136 in
  let admin_response =
    Cli_fixture.Json
      (`Assoc
         [
           ("status", `String "ok");
           ("blobStore", `Assoc [ ("adapter", `String "s3") ]);
           ( "accounts",
             `List [ `Assoc [ ("repoCount", `Int 1); ("blobCount", `Int 3) ] ]
           );
         ])
  in
  let admin_result =
    with_pds_fixture ~port:admin_port ~path:"/xrpc/_admin/status" admin_response
      (fun pds ->
        [
          "pds";
          "admin-status";
          "--pds";
          pds;
          "--admin-token";
          "fixture-admin-secret";
          "--format";
          "json";
        ])
  in
  assert_int "PDS admin exit status" 0 admin_result.status;
  assert_equal "PDS admin stderr" "" admin_result.stderr;
  let admin_json = Yojson.Safe.from_string admin_result.stdout in
  assert_equal "PDS admin endpoint"
    (endpoint admin_port ^ "/xrpc/_admin/status")
    (json_string "endpoint" (json_member "meta" admin_json));
  assert_request admin_result ~method_:"GET"
    ~url:(endpoint admin_port ^ "/xrpc/_admin/status")
    ~body:"" ~authorization:"[REDACTED]";

  let list_port = 43137 in
  let list_endpoint = endpoint list_port in
  let list_url = Ocaat__Pds.list_repos_url list_endpoint in
  let list_result =
    with_pds_fixture ~port:list_port
      ~path:(resource_path list_endpoint list_url)
      (Cli_fixture.Json
         (`Assoc
            [
              ( "repos",
                `List
                  [
                    `Assoc
                      [
                        ("did", `String "did:plc:fixture");
                        ("rev", `String "3kfixture");
                        ("active", `Bool true);
                      ];
                  ] );
            ]))
      (fun pds ->
        [
          "pds";
          "account";
          "list";
          pds;
          "--auth";
          "fixture-account-secret";
          "--format";
          "json";
        ])
  in
  assert_int "PDS account list exit status" 0 list_result.status;
  let list_json = Yojson.Safe.from_string list_result.stdout in
  assert_equal "PDS account list kind" "records" (json_string "kind" list_json);
  assert_equal "PDS account list endpoint" list_url
    (json_string "endpoint" (json_member "meta" list_json));
  assert_request list_result ~method_:"GET" ~url:list_url ~body:""
    ~authorization:"[REDACTED]";

  let status_port = 43138 in
  let status_endpoint = endpoint status_port in
  let status_did = "did:plc:oga6ppys7zwxlheuqmcm7dac" in
  let status_url = Ocaat__Pds.repo_status_url status_endpoint status_did in
  let status_result =
    with_pds_fixture ~port:status_port
      ~path:(resource_path status_endpoint status_url)
      (Cli_fixture.Json (`Assoc [ ("active", `Bool true) ]))
      (fun pds ->
        [
          "pds";
          "account";
          "status";
          status_did;
          "--pds";
          pds;
          "--format";
          "json";
        ])
  in
  assert_int "PDS account status exit status" 0 status_result.status;
  let status_json = Yojson.Safe.from_string status_result.stdout in
  assert_equal "PDS account status DID" status_did
    (json_string "did" (json_member "meta" status_json));
  assert_equal "PDS account status endpoint" status_url
    (json_string "endpoint" (json_member "meta" status_json));
  assert_true "PDS account status has no authorization"
    (header "authorization" (request_of_result status_result).headers = None);

  let binary_body = "CAR\000fixture-bytes" in
  let binary_result =
    with_fixture ~port:43128 (Cli_fixture.Binary binary_body) (fun port ->
        xrpc_args port [ "--format"; "raw" ])
  in
  assert_int "binary exit status" 0 binary_result.status;
  assert_equal "binary stderr" "" binary_result.stderr;
  assert_equal "binary stdout" (binary_body ^ "\n") binary_result.stdout;
  assert_request binary_result ~method_:"GET"
    ~url:(endpoint 43128 ^ "/xrpc/com.atproto.server.describeServer")
    ~body:"" ~authorization:"[REDACTED]";

  let malformed_result =
    with_fixture ~port:43129 (Cli_fixture.Malformed "not-json") (fun port ->
        xrpc_args port [ "--format"; "json" ])
  in
  assert_int "malformed exit status" 0 malformed_result.status;
  assert_equal "malformed stderr" "" malformed_result.stderr;
  assert_contains "malformed payload" "not-json" malformed_result.stdout;
  assert_request malformed_result ~method_:"GET"
    ~url:(endpoint 43129 ^ "/xrpc/com.atproto.server.describeServer")
    ~body:"" ~authorization:"[REDACTED]";

  let delayed_result =
    with_fixture ~port:43130
      (Cli_fixture.Delayed
         (0.05, Cli_fixture.Json (`Assoc [ ("delayed", `Bool true) ])))
      (fun port -> xrpc_args port [ "--format"; "json" ])
  in
  assert_int "delayed exit status" 0 delayed_result.status;
  assert_equal "delayed stderr" "" delayed_result.stderr;
  assert_contains "delayed payload" "delayed" delayed_result.stdout;
  assert_request delayed_result ~method_:"GET"
    ~url:(endpoint 43130 ^ "/xrpc/com.atproto.server.describeServer")
    ~body:"" ~authorization:"[REDACTED]";

  let remote_result =
    with_fixture ~port:43131
      (Cli_fixture.Remote_error
         (503, {|{"error":"fixture failure","token":"remote-secret"}|}))
      (fun port -> xrpc_args port [ "--format"; "json" ])
  in
  assert_int "remote error exit status" 70 remote_result.status;
  assert_equal "remote error stdout" "" remote_result.stdout;
  assert_contains "remote error document" "ocaat.error.v1" remote_result.stderr;
  assert_contains "remote error status" "503" remote_result.stderr;
  assert_contains "remote error redaction" "[REDACTED]" remote_result.stderr;
  assert_not_contains "remote response secret" "remote-secret"
    remote_result.stderr;
  assert_request remote_result ~method_:"GET"
    ~url:(endpoint 43131 ^ "/xrpc/com.atproto.server.describeServer")
    ~body:"" ~authorization:"[REDACTED]";

  let post_port = 43132 in
  let post_fixture =
    Cli_fixture.create ~port:post_port
      ~path:"/xrpc/com.atproto.server.createSession"
      (Cli_fixture.Json (`Assoc [ ("ok", `Bool true) ]))
  in
  Fun.protect
    ~finally:(fun () -> Cli_fixture.close post_fixture)
    (fun () ->
      let response =
        post_fixture_request
          ~endpoint:(Cli_fixture.endpoint post_fixture)
          ~path:"/xrpc/com.atproto.server.createSession"
      in
      assert_contains "POST response status" "200 OK" response;
      let request =
        match Cli_fixture.stop post_fixture with
        | Some request -> request
        | None -> failwith "POST fixture did not observe an HTTP request"
      in
      assert_equal "POST method" "POST" request.method_;
      assert_equal "POST URL"
        (endpoint post_port ^ "/xrpc/com.atproto.server.createSession")
        request.url;
      assert_equal "POST body redaction"
        {|{"password":"[REDACTED]","handle":"fixture.test"}|} request.body;
      match header "authorization" request.headers with
      | Some value ->
          assert_equal "POST authorization redaction" "[REDACTED]" value
      | None -> failwith "POST did not contain an authorization header")
