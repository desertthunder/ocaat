let fail message = raise (Failure message)
let assert_true label condition = if not condition then fail label
let assert_equal label expected actual = if expected <> actual then fail label
let assert_int label expected actual = if expected <> actual then fail label
let json_member name json = Yojson.Safe.Util.member name json
let json_string name json = json_member name json |> Yojson.Safe.Util.to_string
let endpoint port = Printf.sprintf "http://127.0.0.1:%d" port

let resource_path endpoint url =
  String.sub url (String.length endpoint)
    (String.length url - String.length endpoint)

let identity_document did pds =
  `Assoc
    [
      ("id", `String did);
      ("alsoKnownAs", `List [ `String "at://alice.example" ]);
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

let run_routes ~port routes args =
  let fixture = Cli_fixture.create_routes ~port routes in
  Fun.protect
    ~finally:(fun () -> Cli_fixture.close fixture)
    (fun () -> Cli_fixture.run fixture args)

let () =
  let record_port = 43170 in
  let record_endpoint = endpoint record_port in
  let did = "did:web:localhost%3A43170" in
  let collection = "app.bsky.actor.profile" in
  let at_uri = "at://" ^ did ^ "/" ^ collection ^ "/self" in
  let get_url =
    Ocaat__Record.get_url ~pds:record_endpoint ~did ~collection ~rkey:"self"
  in
  let get_result =
    run_routes ~port:record_port
      [
        ( "/.well-known/did.json",
          Cli_fixture.Json (identity_document did record_endpoint) );
        ( resource_path record_endpoint get_url,
          Cli_fixture.Json
            (`Assoc
               [
                 ("uri", `String at_uri);
                 ( "cid",
                   `String
                     "bafkreifodmypic3zbjtevk7rbftxvjxgpgegt5njaxn57lamxracv2a3he"
                 );
                 ("value", `Assoc [ ("displayName", `String "Alice") ]);
               ]) );
      ]
      [ "record"; "get"; at_uri; "--format"; "json" ]
  in
  assert_int "record get status" 0 get_result.status;
  assert_equal "record get stderr" "" get_result.stderr;
  let get_json = Yojson.Safe.from_string get_result.stdout in
  assert_equal "record kind" "record" (json_string "kind" get_json);
  assert_equal "record source" "pds"
    (json_string "source" (json_member "meta" get_json));
  assert_equal "record PDS provenance" record_endpoint
    (json_string "pds" (json_member "meta" get_json));
  let get_data = json_member "data" get_json in
  assert_equal "record URI" at_uri (json_string "uri" get_data);
  assert_equal "record CID"
    "bafkreifodmypic3zbjtevk7rbftxvjxgpgegt5njaxn57lamxracv2a3he"
    (json_string "cid" get_data);
  assert_equal "record value" "Alice"
    (json_string "displayName" (json_member "value" get_data));
  assert_int "record get request count" 2 (List.length get_result.requests);

  let list_port = 43171 in
  let list_endpoint = endpoint list_port in
  let list_did = "did:web:localhost%3A43171" in
  let list_collection = "app.bsky.feed.post" in
  let list_url =
    Ocaat__Record.list_records_url ~pds:list_endpoint ~did:list_did
      ~collection:list_collection ~limit:2 ~cursor:"page-2" ()
  in
  let list_result =
    run_routes ~port:list_port
      [
        ( "/.well-known/did.json",
          Cli_fixture.Json
            (identity_document list_did "https://declared.example") );
        ( resource_path list_endpoint list_url,
          Cli_fixture.Json
            (`Assoc
               [
                 ( "records",
                   `List
                     [
                       `Assoc
                         [
                           ( "uri",
                             `String
                               ("at://" ^ list_did ^ "/" ^ list_collection
                              ^ "/3kone") );
                           ("cid", `String "bafkrei-one");
                           ("value", `Assoc [ ("text", `String "one") ]);
                         ];
                     ] );
                 ("cursor", `String "next-page");
               ]) );
      ]
      [
        "record";
        "list";
        list_did;
        "--collection";
        list_collection;
        "--limit";
        "2";
        "--cursor";
        "page-2";
        "--pds";
        list_endpoint;
        "--format";
        "json";
      ]
  in
  assert_int "record list status" 0 list_result.status;
  let list_json = Yojson.Safe.from_string list_result.stdout in
  let list_data = json_member "data" list_json in
  assert_equal "record list DID" list_did (json_string "repo" list_data);
  assert_equal "record list collection" list_collection
    (json_string "collection" list_data);
  assert_equal "record list cursor" "next-page" (json_string "cursor" list_data);
  let listed_record =
    Yojson.Safe.Util.to_list (json_member "records" list_data) |> List.hd
  in
  assert_equal "record list preserves record value" "one"
    (json_string "text" (json_member "value" listed_record));
  assert_equal "record list request URL"
    (list_endpoint ^ resource_path list_endpoint list_url)
    (List.nth list_result.requests 1).url;

  let summary_port = 43172 in
  let summary_endpoint = endpoint summary_port in
  let summary_did = "did:web:localhost%3A43172" in
  let summary_url =
    Ocaat__Record.describe_repo_url ~pds:summary_endpoint ~did:summary_did
  in
  let summary_result =
    run_routes ~port:summary_port
      [
        ( "/.well-known/did.json",
          Cli_fixture.Json (identity_document summary_did summary_endpoint) );
        ( resource_path summary_endpoint summary_url,
          Cli_fixture.Json
            (`Assoc
               [
                 ("handle", `String "alice.example");
                 ("did", `String summary_did);
                 ("didDoc", identity_document summary_did summary_endpoint);
                 ("collections", `List [ `String "app.bsky.feed.post" ]);
                 ("handleIsCorrect", `Bool true);
               ]) );
      ]
      [ "record"; "list"; summary_did; "--collections"; "--format"; "json" ]
  in
  assert_int "collection summary status" 0 summary_result.status;
  let summary_json = Yojson.Safe.from_string summary_result.stdout in
  assert_true "collection summary has collections"
    (Yojson.Safe.Util.to_list
       (json_member "collections" (json_member "data" summary_json))
    <> []);
  assert_true "collection summary does not invent records"
    (json_member "records" (json_member "data" summary_json) = `Null);

  let invalid_mode_port = 43173 in
  let invalid_mode =
    let fixture =
      Cli_fixture.create ~port:invalid_mode_port ~path:"/unused"
        (Cli_fixture.Json (`Assoc []))
    in
    Fun.protect
      ~finally:(fun () -> Cli_fixture.close fixture)
      (fun () ->
        Cli_fixture.run fixture
          [
            "record";
            "list";
            "did:web:localhost%3A43173";
            "--collections";
            "--collection";
            "app.bsky.feed.post";
            "--format";
            "json";
          ])
  in
  assert_int "mutually exclusive list modes" 65 invalid_mode.status;
  assert_true "invalid list mode made no request" (invalid_mode.requests = []);

  let plc_port = 43174 in
  let plc_endpoint = endpoint plc_port in
  let plc_did = "did:plc:fixture" in
  let plc_data_url = Ocaat__Plc.data_url ~plc_host:plc_endpoint ~did:plc_did in
  let plc_result =
    run_routes ~port:plc_port
      [
        ( resource_path plc_endpoint plc_data_url,
          Cli_fixture.Json
            (`Assoc
               [
                 ("did", `String plc_did);
                 ("verificationMethods", `Assoc []);
                 ("rotationKeys", `List []);
                 ("alsoKnownAs", `List [ `String "at://alice.example" ]);
                 ("services", `Assoc []);
               ]) );
      ]
      [ "plc"; "show"; plc_did; "--plc-host"; plc_endpoint; "--format"; "json" ]
  in
  assert_int "PLC show status" 0 plc_result.status;
  let plc_json = Yojson.Safe.from_string plc_result.stdout in
  assert_equal "PLC kind" "plc" (json_string "kind" plc_json);
  assert_equal "PLC source" "plc"
    (json_string "source" (json_member "meta" plc_json));
  assert_equal "PLC endpoint" plc_data_url
    (json_string "endpoint" (json_member "meta" plc_json));
  assert_equal "PLC DID" plc_did
    (json_string "did" (json_member "meta" plc_json));
  assert_int "PLC show request count" 1 (List.length plc_result.requests);

  let history_port = 43175 in
  let history_endpoint = endpoint history_port in
  let history_did = "did:plc:history" in
  let history_url =
    Ocaat__Plc.history_url ~plc_host:history_endpoint ~did:history_did
  in
  let history_result =
    run_routes ~port:history_port
      [
        ( resource_path history_endpoint history_url,
          Cli_fixture.Json
            (`List
               [
                 `Assoc
                   [
                     ("createdAt", `String "2026-01-02T00:00:00Z");
                     ("type", `String "later");
                   ];
                 `Assoc
                   [
                     ("createdAt", `String "2025-01-02T00:00:00Z");
                     ("type", `String "earlier");
                   ];
               ]) );
      ]
      [
        "plc";
        "history";
        history_did;
        "--plc-host";
        history_endpoint;
        "--format";
        "json";
      ]
  in
  assert_int "PLC history status" 0 history_result.status;
  let history_json = Yojson.Safe.from_string history_result.stdout in
  let history_data = json_member "data" history_json in
  let first_operation = Yojson.Safe.Util.to_list history_data |> List.hd in
  assert_equal "PLC history chronological order" "earlier"
    (json_string "type" first_operation);

  let non_plc_port = 43176 in
  let non_plc =
    let fixture =
      Cli_fixture.create ~port:non_plc_port ~path:"/unused"
        (Cli_fixture.Json (`Assoc []))
    in
    Fun.protect
      ~finally:(fun () -> Cli_fixture.close fixture)
      (fun () ->
        Cli_fixture.run fixture
          [
            "plc";
            "show";
            "did:web:example.com";
            "--plc-host";
            endpoint non_plc_port;
            "--format";
            "json";
          ])
  in
  assert_int "non-PLC validation" 65 non_plc.status;
  assert_true "non-PLC made no request" (non_plc.requests = [])
