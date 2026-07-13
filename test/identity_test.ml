let fail message = raise (Failure message)
let assert_true label condition = if not condition then fail label
let assert_equal label expected actual = if expected <> actual then fail label
let json_member name json = Yojson.Safe.Util.member name json
let json_string name json = json_member name json |> Yojson.Safe.Util.to_string
let json_bool name json = json_member name json |> Yojson.Safe.Util.to_bool

let fixture_document did service_endpoint =
  `Assoc
    [
      ("id", `String did);
      ("alsoKnownAs", `List [ `String "at://Alice.Example" ]);
      ( "service",
        `List
          [
            `Assoc
              [
                ("id", `String "#atproto_pds");
                ("type", `String "AtprotoPersonalDataServer");
                ("serviceEndpoint", `String service_endpoint);
              ];
          ] );
    ]

let run_fixture ~port ~did response =
  let fixture =
    Cli_fixture.create ~port ~path:"/.well-known/did.json"
      (Cli_fixture.Json response)
  in
  Fun.protect
    ~finally:(fun () -> Cli_fixture.close fixture)
    (fun () -> Cli_fixture.run fixture [ "resolve"; did; "--format"; "json" ])

let request_url (result : Cli_fixture.command_result) =
  match result.Cli_fixture.request with
  | Some request -> request.url
  | None -> fail "fixture did not observe a request"

let () =
  let did = "did:web:localhost%3A43152" in
  let success =
    run_fixture ~port:43152 ~did (fixture_document did "https://pds.example/")
  in
  assert_equal "successful resolve status" 0 success.status;
  assert_equal "successful resolve stderr" "" success.stderr;
  let json = Yojson.Safe.from_string success.stdout in
  assert_equal "identity kind" "identity" (json_string "kind" json);
  let data = json_member "data" json in
  assert_equal "normalized DID" did (json_string "did" data);
  assert_equal "normalized handle" "alice.example" (json_string "handle" data);
  assert_true "claimed handle is unverified"
    (not (json_bool "verified" (json_member "handleEvidence" data)));
  assert_equal "PDS endpoint" "https://pds.example"
    (json_string "pds" (json_member "meta" json));
  assert_equal "resolved endpoint" "http://localhost:43152/.well-known/did.json"
    (json_string "endpoint" (json_member "meta" json));
  assert_equal "fixture request URL"
    "http://127.0.0.1:43152/.well-known/did.json" (request_url success);

  let invalid_service =
    run_fixture ~port:43153 ~did:"did:web:localhost%3A43153"
      (fixture_document "did:web:localhost%3A43153" "https://pds.example/xrpc")
  in
  assert_equal "invalid service status" 65 invalid_service.status;
  assert_equal "invalid service stdout" "" invalid_service.stdout;
  assert_true "invalid service diagnostic"
    (String.length invalid_service.stderr > 0);

  let unsupported =
    let fixture =
      Cli_fixture.create ~port:43154 ~path:"/.well-known/did.json"
        (Cli_fixture.Json (`Assoc []))
    in
    Fun.protect
      ~finally:(fun () -> Cli_fixture.close fixture)
      (fun () ->
        Cli_fixture.run fixture [ "resolve"; "did:key:abc"; "--format"; "json" ])
  in
  assert_equal "unsupported DID status" 65 unsupported.status;
  assert_true "unsupported DID made no request" (unsupported.request = None);

  let mismatch =
    run_fixture ~port:43155 ~did:"did:web:localhost%3A43155"
      (fixture_document "did:web:localhost%3Awrong" "https://pds.example")
  in
  assert_equal "mismatched document status" 70 mismatch.status;
  assert_equal "mismatched document stdout" "" mismatch.stdout;

  let no_service =
    run_fixture ~port:43156 ~did:"did:web:localhost%3A43156"
      (`Assoc
         [
           ("id", `String "did:web:localhost%3A43156");
           ("alsoKnownAs", `List [ `String "at://Alice.Example" ]);
         ])
  in
  assert_equal "missing PDS service status" 0 no_service.status;
  let no_service_json = Yojson.Safe.from_string no_service.stdout in
  let no_service_data = json_member "data" no_service_json in
  assert_true "missing PDS service is omitted"
    (json_member "pds" no_service_data = `Null)
