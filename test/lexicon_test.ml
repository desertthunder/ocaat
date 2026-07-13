let fail message = raise (Failure message)
let assert_true label condition = if not condition then fail label
let assert_equal label expected actual = if expected <> actual then fail label
let assert_int label expected actual = if expected <> actual then fail label

let assert_contains label needle value =
  let rec loop index =
    if index + String.length needle > String.length value then false
    else if String.sub value index (String.length needle) = needle then true
    else loop (index + 1)
  in
  if not (loop 0) then fail label

let json_member name json = Yojson.Safe.Util.member name json
let json_string name json = json_member name json |> Yojson.Safe.Util.to_string
let endpoint port = Printf.sprintf "http://127.0.0.1:%d" port
let did_for_port port = "did:web:localhost%3A" ^ string_of_int port

let resource_path endpoint url =
  String.sub url (String.length endpoint)
    (String.length url - String.length endpoint)

let identity_document did pds =
  `Assoc
    [
      ("id", `String did);
      ( "service",
        `List
          [
            `Assoc
              [
                ("id", `String "#atproto_pds");
                ("type", `String "AtprotoPersonalDataServer");
                ("serviceEndpoint", `String pds);
              ];
          ] );
    ]

let schema nsid =
  `Assoc
    [
      ("$type", `String "com.atproto.lexicon.schema");
      ("lexicon", `Int 1);
      ("id", `String nsid);
      ("description", `String "A fixture query.");
      ( "defs",
        `Assoc
          [
            ( "main",
              `Assoc
                [
                  ("type", `String "query");
                  ("description", `String "Fetch fixture data.");
                ] );
          ] );
    ]

let record_response ~did ~nsid value =
  `Assoc
    [
      ("uri", `String ("at://" ^ did ^ "/com.atproto.lexicon.schema/" ^ nsid));
      ("cid", `String "bafkreifxture");
      ("value", value);
    ]

let with_routes ~port ~did ~nsid record_response command =
  let pds = endpoint port in
  let record_url = Ocaat__Lexicon.record_url ~pds ~did ~nsid in
  let fixture =
    Cli_fixture.create_routes ~port
      [
        ("/.well-known/did.json", Cli_fixture.Json (identity_document did pds));
        (resource_path pds record_url, record_response);
      ]
  in
  Fun.protect
    ~finally:(fun () -> Cli_fixture.close fixture)
    (fun () -> command fixture record_url)

let with_fake_dig did f =
  let directory =
    Filename.concat
      (Filename.get_temp_dir_name ())
      ("ocaat-lexicon-dig-" ^ string_of_int (Unix.getpid ()))
  in
  if Sys.file_exists directory then Unix.rmdir directory;
  Unix.mkdir directory 0o755;
  let executable = Filename.concat directory "dig" in
  let channel = open_out_bin executable in
  output_string channel
    "#!/bin/sh\nprintf '\"did=%s\"\\n' \"$OCAAT_TEST_DNS_DID\"\n";
  close_out channel;
  Unix.chmod executable 0o755;
  let original_path = Sys.getenv_opt "PATH" in
  let original_did = Sys.getenv_opt "OCAAT_TEST_DNS_DID" in
  let path =
    match original_path with
    | None -> directory
    | Some path -> directory ^ ":" ^ path
  in
  Unix.putenv "PATH" path;
  Unix.putenv "OCAAT_TEST_DNS_DID" did;
  Fun.protect
    ~finally:(fun () ->
      (match original_path with
      | Some value -> Unix.putenv "PATH" value
      | None -> Unix.putenv "PATH" "");
      (match original_did with
      | Some value -> Unix.putenv "OCAAT_TEST_DNS_DID" value
      | None -> Unix.putenv "OCAAT_TEST_DNS_DID" "");
      Sys.remove executable;
      Unix.rmdir directory)
    f

let run_get ~port ~did ~nsid response =
  with_routes ~port ~did ~nsid response (fun fixture _record_url ->
      Cli_fixture.run fixture [ "lexicon"; "get"; nsid; "--format"; "json" ])

let () =
  let nsid = "com.example.fixture.getData" in
  let did = "did:web:localhost%3A43180" in
  let valid_response =
    Cli_fixture.Json (record_response ~did ~nsid (schema nsid))
  in
  let success =
    with_fake_dig did (fun () -> run_get ~port:43180 ~did ~nsid valid_response)
  in
  assert_int "Lexicon get status" 0 success.status;
  assert_equal "Lexicon get stderr" "" success.stderr;
  let json = Yojson.Safe.from_string success.stdout in
  assert_equal "Lexicon kind" "lexicon" (json_string "kind" json);
  assert_equal "Lexicon id" nsid (json_string "id" (json_member "data" json));
  let meta = json_member "meta" json in
  assert_equal "Lexicon source" "pds" (json_string "source" meta);
  assert_equal "Lexicon PDS" (endpoint 43180) (json_string "pds" meta);
  let sources = Yojson.Safe.Util.to_list (json_member "sources" meta) in
  assert_equal "Lexicon source evidence count" 3 (List.length sources);
  assert_equal "DNS source evidence" "dns"
    (json_string "source" (List.nth sources 0));
  assert_equal "DID source evidence" "did"
    (json_string "source" (List.nth sources 1));
  assert_equal "PDS source evidence" "pds"
    (json_string "source" (List.nth sources 2));
  assert_int "Lexicon request count" 2 (List.length success.requests);
  assert_equal "Lexicon DID request"
    (endpoint 43180 ^ "/.well-known/did.json")
    (List.nth success.requests 0).url;

  let described_did = "did:web:localhost%3A43181" in
  let described =
    with_fake_dig described_did (fun () ->
        with_routes ~port:43181 ~did:described_did ~nsid
          (Cli_fixture.Json
             (record_response ~did:described_did ~nsid (schema nsid)))
          (fun fixture _ ->
            Cli_fixture.run fixture
              [ "xrpc"; "describe"; nsid; "--format"; "json" ]))
  in
  assert_int "XRPC describe status" 0 described.status;
  let described_json = Yojson.Safe.from_string described.stdout in
  let described_data = json_member "data" described_json in
  assert_equal "XRPC selected definition" "main"
    (json_string "definition" described_data);
  assert_equal "XRPC method kind" "query" (json_string "type" described_data);

  let invalid =
    with_fake_dig did (fun () ->
        let fixture =
          Cli_fixture.create ~port:43182 ~path:"/unused"
            (Cli_fixture.Json (`Assoc []))
        in
        Fun.protect
          ~finally:(fun () -> Cli_fixture.close fixture)
          (fun () ->
            Cli_fixture.run fixture
              [ "lexicon"; "get"; "not-an-nsid"; "--format"; "json" ]))
  in
  assert_int "Invalid NSID status" 65 invalid.status;
  assert_true "Invalid NSID made no HTTP request" (invalid.requests = []);

  let mismatch_did = did_for_port 43183 in
  let mismatch =
    with_fake_dig mismatch_did (fun () ->
        run_get ~port:43183 ~did:mismatch_did ~nsid
          (Cli_fixture.Json
             (record_response ~did:mismatch_did ~nsid
                (schema "com.example.fixture.other"))))
  in
  assert_int "Mismatched Lexicon status" 70 mismatch.status;
  assert_equal "Mismatched Lexicon stdout" "" mismatch.stdout;
  assert_contains "Mismatched Lexicon identifies PDS stage"
    "lexicon PDS record read" mismatch.stderr;
  assert_contains "Mismatched Lexicon identifies expected NSID" nsid
    mismatch.stderr;

  let redirect_did = did_for_port 43184 in
  let redirect =
    with_fake_dig redirect_did (fun () ->
        with_routes ~port:43184 ~did:redirect_did ~nsid
          (Cli_fixture.Redirect (302, "http://other.example/lexicon"))
          (fun fixture _ ->
            Cli_fixture.run fixture
              [ "lexicon"; "get"; nsid; "--format"; "json" ]))
  in
  assert_int "Redirect status" 70 redirect.status;
  assert_contains "Redirect is explicitly rejected"
    "redirect; redirects are not followed" redirect.stderr;

  let malformed_did = did_for_port 43185 in
  let malformed =
    with_fake_dig malformed_did (fun () ->
        with_routes ~port:43185 ~did:malformed_did ~nsid
          (Cli_fixture.Malformed "not-json") (fun fixture _ ->
            Cli_fixture.run fixture
              [ "lexicon"; "get"; nsid; "--format"; "json" ]))
  in
  assert_int "Malformed Lexicon status" 70 malformed.status;
  assert_true "Malformed Lexicon is rejected" (malformed.stdout = "");

  let oversized_did = did_for_port 43186 in
  let oversized =
    with_fake_dig oversized_did (fun () ->
        with_routes ~port:43186 ~did:oversized_did ~nsid
          (Cli_fixture.Malformed
             (String.make (Ocaat__Lexicon.max_response_bytes + 1) 'x'))
          (fun fixture _ ->
            Cli_fixture.run fixture
              [ "lexicon"; "get"; nsid; "--format"; "json" ]))
  in
  assert_int "Oversized Lexicon status" 69 oversized.status;
  assert_contains "Oversized Lexicon identifies PDS stage"
    "lexicon PDS record read" oversized.stderr;

  print_endline "lexicon tests passed"
