let fail message = raise (Failure message)
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

let with_fake_dig did f =
  let directory =
    Filename.concat
      (Filename.get_temp_dir_name ())
      ("ocaat-resource-dig-" ^ string_of_int (Unix.getpid ()))
  in
  Unix.mkdir directory 0o755;
  let executable = Filename.concat directory "dig" in
  let channel = open_out_bin executable in
  output_string channel
    (Printf.sprintf "#!/bin/sh\nprintf '%%s\\n' '\"did=%s\"'\n" did);
  close_out channel;
  Unix.chmod executable 0o755;
  let original_path = Sys.getenv_opt "PATH" in
  let path =
    match original_path with
    | None -> directory
    | Some path -> directory ^ ":" ^ path
  in
  Unix.putenv "PATH" path;
  Fun.protect
    ~finally:(fun () ->
      (match original_path with
      | Some value -> Unix.putenv "PATH" value
      | None -> Unix.putenv "PATH" "");
      Sys.remove executable;
      Unix.rmdir directory)
    f

let () =
  let expect_branch label expected value =
    match Ocaat__Resource.classify value with
    | Ok actual when actual = expected -> ()
    | Ok _ -> fail (label ^ " selected the wrong branch")
    | Error _ -> fail (label ^ " was rejected")
  in
  expect_branch "handle" (Ocaat__Resource.Identity "alice.example")
    "Alice.Example";
  expect_branch "multi-label handle"
    (Ocaat__Resource.Identity "alice.bsky.social") "Alice.Bsky.Social";
  expect_branch "DID" (Ocaat__Resource.Identity "did:plc:fixture")
    "did:plc:fixture";
  expect_branch "AT URI"
    (Ocaat__Resource.Record "at://did:plc:fixture/app.bsky.feed.post/3kabc")
    "at://did:plc:fixture/app.bsky.feed.post/3kabc";
  expect_branch "web URL"
    (Ocaat__Resource.Record "at://alice.example/app.bsky.feed.post/3kabc")
    "https://bsky.app/profile/alice.example/post/3kabc";
  expect_branch "DID web URL"
    (Ocaat__Resource.Record
       "at://did:web:localhost%3A43191/app.bsky.feed.post/3kabc")
    "https://bsky.app/profile/did:web:localhost%3A43191/post/3kabc";
  expect_branch "NSID" (Ocaat__Resource.Lexicon "com.example.fixture.getData")
    "com.example.fixture.getData";
  expect_branch "PDS URL" (Ocaat__Resource.Pds "https://pds.example")
    "https://pds.example/";
  (match Ocaat__Resource.classify "https://example.com/not-atproto" with
  | Error (Ocaat__Resource.Validation _) -> ()
  | _ -> fail "unsupported web URL was accepted");

  let port = 43190 in
  let pds = endpoint port in
  let describe_url = Ocaat__Pds.describe_url pds in
  let fixture =
    Cli_fixture.create_routes ~port
      [
        ( resource_path pds describe_url,
          Cli_fixture.Json
            (`Assoc
               [
                 ("did", `String "did:web:pds.example");
                 ("availableUserDomains", `List []);
               ]) );
      ]
  in
  Fun.protect
    ~finally:(fun () -> Cli_fixture.close fixture)
    (fun () ->
      let result = Cli_fixture.run fixture [ "get"; pds; "--format"; "json" ] in
      assert_int "PDS get status" 0 result.status;
      assert_equal "PDS get stderr" "" result.stderr;
      let json = Yojson.Safe.from_string result.stdout in
      assert_equal "PDS get kind" "pds" (json_string "kind" json);
      assert_equal "PDS get endpoint" describe_url
        (json_string "endpoint" (json_member "meta" json));
      assert_int "PDS get request count" 1 (List.length result.requests));

  let failed_port = 43192 in
  let failed_pds = endpoint failed_port in
  let failed_describe_url = Ocaat__Pds.describe_url failed_pds in
  let failed_fixture =
    Cli_fixture.create ~port:failed_port
      ~path:(resource_path failed_pds failed_describe_url)
      (Cli_fixture.Remote_error (503, "fixture unavailable"))
  in
  Fun.protect
    ~finally:(fun () -> Cli_fixture.close failed_fixture)
    (fun () ->
      let result =
        Cli_fixture.run failed_fixture [ "get"; failed_pds; "--format"; "json" ]
      in
      assert_int "failed PDS get status" 70 result.status;
      assert_int "failed PDS has no fallback request" 1
        (List.length result.requests));

  let port = 43191 in
  let pds = endpoint port in
  let did = "did:web:localhost%3A43191" in
  let at_uri = "at://" ^ did ^ "/app.bsky.feed.post/3kabc" in
  let record_url =
    Ocaat__Record.get_url ~pds ~did ~collection:"app.bsky.feed.post"
      ~rkey:"3kabc"
  in
  let fixture =
    Cli_fixture.create_routes ~port
      [
        ( "/.well-known/did.json",
          Cli_fixture.Json (identity_document did "https://declared.example") );
        ( resource_path pds record_url,
          Cli_fixture.Json
            (`Assoc
               [
                 ("uri", `String at_uri);
                 ("cid", `String "bafkrei-resource");
                 ("value", `Assoc [ ("text", `String "fixture") ]);
               ]) );
      ]
  in
  Fun.protect
    ~finally:(fun () -> Cli_fixture.close fixture)
    (fun () ->
      with_fake_dig did (fun () ->
          let result =
            Cli_fixture.run fixture
              [
                "get";
                "https://bsky.app/profile/alice.example/post/3kabc";
                "--format";
                "json";
                "--pds";
                pds;
              ]
          in
          if result.status <> 0 then
            fail
              ("web get status "
              ^ string_of_int result.status
              ^ ": " ^ result.stderr);
          let json = Yojson.Safe.from_string result.stdout in
          assert_equal "web get kind" "record" (json_string "kind" json);
          assert_equal "web get normalized URI" at_uri
            (json_string "uri" (json_member "data" json));
          assert_equal "web get PDS override" pds
            (json_string "pds" (json_member "meta" json));
          assert_int "web get request count" 2 (List.length result.requests)));

  print_endline "resource tests passed"
