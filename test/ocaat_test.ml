let usage = 64
let validation = 65
let auth = 66

let assert_equal expected actual =
  if actual <> expected then
    failwith (Printf.sprintf "expected %S, got %S" expected actual)

let assert_int_option expected actual =
  if actual <> expected then failwith "unexpected optional integer value"

let assert_bool_option expected actual =
  if actual <> expected then failwith "unexpected optional boolean value"

let assert_contains needle value =
  if not (String.contains value needle.[0]) then
    failwith (Printf.sprintf "expected %S to contain %S" value needle)
  else
    let rec loop index =
      if index + String.length needle > String.length value then false
      else if String.sub value index (String.length needle) = needle then true
      else loop (index + 1)
    in
    if not (loop 0) then
      failwith (Printf.sprintf "expected %S to contain %S" value needle)

let assert_not_contains needle value =
  match String.index_opt value needle.[0] with
  | None -> ()
  | Some _ ->
      let rec loop index =
        if index + String.length needle > String.length value then false
        else if String.sub value index (String.length needle) = needle then true
        else loop (index + 1)
      in
      if loop 0 then
        failwith (Printf.sprintf "did not expect %S to contain %S" value needle)

let read_pipe fd =
  let channel = Unix.in_channel_of_descr fd in
  Fun.protect
    ~finally:(fun () -> close_in_noerr channel)
    (fun () ->
      let buffer = Bytes.create 4096 in
      let output = Buffer.create 4096 in
      let rec loop () =
        match input channel buffer 0 (Bytes.length buffer) with
        | 0 -> ()
        | count ->
            Buffer.add_subbytes output buffer 0 count;
            loop ()
      in
      loop ();
      Buffer.contents output)

let capture_output f =
  let old_stdout = Unix.dup Unix.stdout in
  let old_stderr = Unix.dup Unix.stderr in
  let stdout_read, stdout_write = Unix.pipe () in
  let stderr_read, stderr_write = Unix.pipe () in
  Unix.dup2 stdout_write Unix.stdout;
  Unix.dup2 stderr_write Unix.stderr;
  Unix.close stdout_write;
  Unix.close stderr_write;
  let restore () =
    flush_all ();
    Unix.dup2 old_stdout Unix.stdout;
    Unix.dup2 old_stderr Unix.stderr;
    Unix.close old_stdout;
    Unix.close old_stderr
  in
  match f () with
  | result ->
      restore ();
      let stdout = read_pipe stdout_read in
      let stderr = read_pipe stderr_read in
      (result, stdout, stderr)
  | exception error ->
      restore ();
      ignore (read_pipe stdout_read);
      ignore (read_pipe stderr_read);
      raise error

let assert_exit expected args =
  let actual = Ocaat.main ~argv:(Array.of_list ("ocaat" :: args)) () in
  if actual <> expected then
    failwith (Printf.sprintf "expected exit %d, got %d" expected actual)

let () =
  let redacted =
    Ocaat__Output.redact_json
      (`Assoc
         [
           ("accessJwt", `String "access-secret");
           ("refreshJwt", `String "refresh-secret");
           ("password", `String "password-secret");
           ("serviceAuth", `String "service-secret");
           ("adminToken", `String "admin-secret");
           ("ok", `String "visible");
         ])
  in
  assert_equal
    {|{"accessJwt":"[REDACTED]","refreshJwt":"[REDACTED]","password":"[REDACTED]","serviceAuth":"[REDACTED]","adminToken":"[REDACTED]","ok":"visible"}|}
    (Yojson.Safe.to_string redacted);
  let healthy_stats =
    `Assoc
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
        ( "health",
          `Assoc
            [
              ("status", `String "ok");
              ("checks", `Assoc [ ("storageWritable", `Bool true) ]);
            ] );
        ("storage", `Assoc [ ("adapter", `String "local") ]);
      ]
  in
  let healthy_inspection =
    Ocaat__Pds.public_inspection ~service_did:"did:web:pds.example"
      ~describe_body:{|{"availableUserDomains":[".example.test"]}|}
      ~host:"https://pds.example/" healthy_stats
  in
  assert_equal "pds.example" healthy_inspection.hostname;
  assert_equal "ok" (Option.get healthy_inspection.health_state);
  assert_int_option (Some 2) healthy_inspection.account_count;
  assert_int_option (Some 2) healthy_inspection.repo_count;
  assert_int_option (Some 9) healthy_inspection.blob_count;
  assert_int_option (Some 42) healthy_inspection.sequencer_cursor;
  assert_equal "local" (Option.get healthy_inspection.storage_backend);
  let degraded_stats =
    `Assoc
      [
        ("status", `String "degraded");
        ("metrics", `Assoc [ ("hostedAccountCount", `Int 1) ]);
        ( "health",
          `Assoc
            [
              ("status", `String "degraded");
              ("checks", `Assoc [ ("statsScanErrorCount", `Int 1) ]);
            ] );
      ]
  in
  let degraded_inspection =
    Ocaat__Pds.public_inspection ~host:"pds.example" degraded_stats
  in
  assert_equal "degraded" (Option.get degraded_inspection.health_state);
  assert_int_option (Some 1) degraded_inspection.account_count;
  assert (List.mem ("statsScanErrorCount", "1") degraded_inspection.status_cues);
  let admin_status =
    `Assoc
      [
        ("status", `String "ok");
        ("admin", `Assoc [ ("tokenConfigured", `Bool true) ]);
        ("sequencer", `Assoc [ ("currentSeq", `Int 77) ]);
        ("blobStore", `Assoc [ ("adapter", `String "s3") ]);
        ( "accounts",
          `List
            [
              `Assoc [ ("repoCount", `Int 1); ("blobCount", `Int 3) ];
              `Assoc [ ("repoCount", `Int 1); ("blobCount", `Int 4) ];
            ] );
      ]
  in
  let admin_inspection =
    Ocaat__Pds.admin_inspection ~host:"https://pds.example" admin_status
  in
  assert_int_option (Some 2) admin_inspection.account_count;
  assert_int_option (Some 2) admin_inspection.repo_count;
  assert_int_option (Some 7) admin_inspection.blob_count;
  assert_int_option (Some 77) admin_inspection.sequencer_cursor;
  assert_equal "s3" (Option.get admin_inspection.storage_backend);
  assert_bool_option (Some true) admin_inspection.admin_auth_configured;
  let admin_without_metrics =
    `Assoc [ ("status", `String "ok"); ("blobStore", `Assoc []) ]
  in
  let missing_admin_inspection =
    Ocaat__Pds.admin_inspection ~host:"https://pds.example"
      admin_without_metrics
  in
  assert_int_option None missing_admin_inspection.account_count;
  assert_int_option None missing_admin_inspection.repo_count;
  assert_int_option None missing_admin_inspection.blob_count;
  let missing_summary =
    Ocaat__Pds.inspection_to_json missing_admin_inspection
  in
  assert (Ocaat__Pds.json_field "accountCount" missing_summary = None);
  assert (Ocaat__Pds.json_field "repoCount" missing_summary = None);
  assert (Ocaat__Pds.json_field "blobCount" missing_summary = None);
  assert (Result.is_error (Ocaat__Pds.parse_json_response "_stats" "not-json"));
  let artifact_path =
    "/tmp/ocaat-artifact-helper-test-" ^ string_of_int (Unix.getpid ())
  in
  assert (Ocaat__Output.Artifact.write_file artifact_path "one" = Ok ());
  assert (
    Result.is_error (Ocaat__Output.Artifact.write_file artifact_path "two"));
  assert (
    Ocaat__Output.Artifact.write_file ~force:true artifact_path "two" = Ok ());
  assert_equal "two"
    (let channel = open_in_bin artifact_path in
     Fun.protect
       ~finally:(fun () -> close_in_noerr channel)
       (fun () -> really_input_string channel (in_channel_length channel)));
  assert_exit 0 [ "version" ];
  assert_exit 0
    [
      "version";
      "--color=never";
      "--json";
      "--pds";
      "https://pds.example";
      "--auth";
      "token";
      "--admin";
      "admin-token";
      "--yes";
      "--dry-run";
      "--force";
    ];
  assert_exit 0 [ "version"; "-q" ];
  assert_exit 0 [ "version"; "-vv" ];
  assert_exit 0 [ "version"; "--verbosity=debug" ];
  Unix.putenv "NO_COLOR" "1";
  assert_exit 0 [ "version" ];
  assert_exit 0 [ "version"; "--color=always" ];
  Unix.putenv "NO_COLOR" "";
  assert_exit 0 [ "tempest"; "migration-plan" ];
  assert_exit validation
    [
      "account";
      "migrate";
      "login-source";
      "--artifact-dir";
      "/tmp/ocaat-test-no-network";
    ];
  assert_exit validation
    [
      "account";
      "migrate";
      "service-auth";
      "--artifact-dir";
      "/tmp/ocaat-test-no-network";
    ];
  assert_exit usage [ "xrpc"; "query"; "com.atproto.server.describeServer" ];
  assert_exit validation
    [ "xrpc"; "query"; "not-an-nsid"; "--pds"; "https://pds.example" ];
  assert_exit validation
    [ "pds"; "account"; "status"; "not-a-did"; "--pds"; "https://pds.example" ];
  assert_exit usage [ "pds"; "account"; "status"; "did:plc:abc" ];
  assert_exit usage [ "pds"; "health" ];
  assert_exit usage [ "pds"; "stats" ];
  assert_exit usage [ "pds"; "admin-status" ];
  assert_exit auth [ "pds"; "admin-status"; "--pds"; "https://pds.example" ];
  assert_exit validation [ "relay"; "account"; "status"; "not-a-did" ];
  assert_exit 0
    [ "key"; "inspect"; "z42tvqQS5sVhaV1jLZ5P6ZKEPEbSpYavNVmT88YDYV3MEZ8D" ];
  assert_exit 0
    [ "key"; "inspect"; "z3vLWgA9nXoPzxsJJafDY9BPrZd3EDWjvcCtYfrFxZ7xbMVi" ];
  assert_exit 0 [ "key"; "generate"; "--terse" ];
  assert_exit 0 [ "key"; "generate"; "--type"; "K-256"; "--terse" ];
  assert_exit validation [ "key"; "inspect"; "not-a-key" ];
  assert_exit 0 [ "syntax"; "handle"; "check"; "tempest.desertthunder.dev" ];
  assert_exit validation [ "syntax"; "handle"; "check"; "tempest" ];
  assert_exit validation [ "syntax"; "handle"; "check"; "cn.8" ];
  assert_exit 0 [ "syntax"; "did"; "check"; "did:plc:oga6ppys7zwxlheuqmcm7dac" ];
  assert_exit validation
    [ "syntax"; "did"; "check"; "plc:oga6ppys7zwxlheuqmcm7dac" ];
  assert_exit validation [ "syntax"; "did"; "check"; "did:METHOD:val" ];
  assert_exit 0 [ "syntax"; "nsid"; "check"; "com.atproto.repo.getRecord" ];
  assert_exit 0 [ "syntax"; "nsid"; "check"; "cn.8.lex.stuff" ];
  assert_exit validation [ "syntax"; "nsid"; "check"; "repo" ];
  assert_exit 0
    [ "syntax"; "at-uri"; "check"; "at://did:plc:abc/app.bsky.feed.post/3kabc" ];
  assert_exit validation [ "syntax"; "at-uri"; "check"; "at://foo.com/" ];
  assert_exit 0 [ "syntax"; "rkey"; "check"; "3kabc" ];
  assert_exit validation [ "syntax"; "rkey"; "check"; "." ];
  assert_exit validation [ "syntax"; "rkey"; "check"; "any+space" ];
  assert_exit 0
    [
      "syntax";
      "cid";
      "check";
      "bafkreifodmypic3zbjtevk7rbftxvjxgpgegt5njaxn57lamxracv2a3he";
    ];
  assert_exit validation [ "syntax"; "cid"; "check"; "QmNotBase32" ];
  assert_exit 0 [ "syntax"; "tid"; "check"; "3kabc234567ab" ];
  assert_exit validation [ "syntax"; "tid"; "check"; "short" ];
  assert_exit validation [ "syntax"; "tid"; "check"; "kjzfcijpj2z2a" ];
  assert_exit 0 [ "syntax"; "tid"; "generate" ];
  assert_exit 0 [ "syntax"; "datetime"; "check"; "2026-06-19T12:34:56Z" ];
  assert_exit 0
    [ "syntax"; "datetime"; "check"; "1985-04-12T23:20:50.123-07:00" ];
  assert_exit validation
    [ "syntax"; "datetime"; "check"; "2026-06-19 12:34:56" ];
  assert_exit validation
    [ "syntax"; "datetime"; "check"; "1985-04-12T23:20:50.123-00:00" ];
  assert_exit 0 [ "syntax"; "datetime"; "now" ];
  assert_exit 0 [ "syntax"; "language"; "check"; "en" ];
  assert_exit 0 [ "syntax"; "language"; "check"; "zh-Hant-TW" ];
  assert_exit 0 [ "syntax"; "language"; "check"; "x-tempest" ];
  assert_exit validation [ "syntax"; "language"; "check"; "e" ];
  assert_exit validation [ "syntax"; "language"; "check"; "en--US" ];
  assert_exit validation [ "syntax"; "language"; "check"; "en_US" ];
  assert_exit 0 [ "syntax"; "url"; "check"; "https://pds.example" ];
  assert_exit 0 [ "syntax"; "url"; "check"; "http://localhost:4000/" ];
  assert_exit validation [ "syntax"; "url"; "check"; "pds.example" ];
  assert_exit validation [ "syntax"; "url"; "check"; "ftp://pds.example" ];
  assert_exit validation
    [ "syntax"; "url"; "check"; "https://token@pds.example" ];
  assert_exit validation
    [ "syntax"; "url"; "check"; "https://pds.example/xrpc" ];
  assert_exit validation
    [ "syntax"; "url"; "check"; "https://pds.example?debug=1" ];
  assert_exit 0 [ "syntax"; "artifact-path"; "check"; ".sandbox/repo.car" ];
  assert_exit 0 [ "syntax"; "artifact-path"; "check"; "/tmp/ocaat/repo.car" ];
  assert_exit validation [ "syntax"; "artifact-path"; "check"; "" ];
  assert_exit validation [ "syntax"; "artifact-path"; "check"; "bad\000path" ];

  let did = "did:plc:oga6ppys7zwxlheuqmcm7dac" in
  let json_result, json_stdout, json_stderr =
    capture_output (fun () ->
        Ocaat.main
          ~argv:[| "ocaat"; "syntax"; "did"; "check"; did; "--format"; "json" |]
          ())
  in
  assert_equal "" json_stderr;
  assert_equal "0" (string_of_int json_result);
  let json = Yojson.Safe.from_string json_stdout in
  assert_equal "ocaat.document.v1"
    (Yojson.Safe.Util.member "schema" json |> Yojson.Safe.Util.to_string);
  assert_equal "doctor"
    (Yojson.Safe.Util.member "kind" json |> Yojson.Safe.Util.to_string);
  assert_equal "local"
    (Yojson.Safe.Util.member "source" (Yojson.Safe.Util.member "meta" json)
    |> Yojson.Safe.Util.to_string);
  assert_contains "fetched_at" json_stdout;

  let alias_result, alias_stdout, alias_stderr =
    capture_output (fun () ->
        Ocaat.main
          ~argv:[| "ocaat"; "syntax"; "did"; "check"; did; "--json" |]
          ())
  in
  assert_equal "" alias_stderr;
  assert_equal "0" (string_of_int alias_result);
  assert_equal "ocaat.document.v1"
    (Yojson.Safe.Util.member "schema" (Yojson.Safe.from_string alias_stdout)
    |> Yojson.Safe.Util.to_string);

  let invalid_result, invalid_stdout, invalid_stderr =
    capture_output (fun () ->
        Ocaat.main
          ~argv:[| "ocaat"; "syntax"; "did"; "check"; "not-a-did"; "--json" |]
          ())
  in
  assert_equal "65" (string_of_int invalid_result);
  assert_equal "" invalid_stdout;
  assert_equal "ocaat.error.v1"
    (Yojson.Safe.Util.member "schema" (Yojson.Safe.from_string invalid_stderr)
    |> Yojson.Safe.Util.to_string);

  let response =
    { Ocaat__Http.status = 200; body = {|{"ok":true,"password":"secret"}|} }
  in
  let _, response_stdout, response_stderr =
    capture_output (fun () ->
        Ocaat__Output.print_http_response ~format:Ocaat__Format.Json
          ~endpoint:"https://fixture.test/xrpc/example" response)
  in
  assert_equal "" response_stderr;
  assert_contains "ocaat.document.v1" response_stdout;
  assert_contains "[REDACTED]" response_stdout;
  assert_not_contains "secret" response_stdout;

  let error_response =
    { Ocaat__Http.status = 401; body = {|{"message":"bad","token":"secret"}|} }
  in
  let error_result, error_stdout, error_stderr =
    capture_output (fun () ->
        Ocaat__Output.print_http_response ~format:Ocaat__Format.Json
          ~endpoint:"https://fixture.test/xrpc/private" error_response)
  in
  assert_equal "66" (string_of_int error_result);
  assert_equal "" error_stdout;
  assert_contains "ocaat.error.v1" error_stderr;
  assert_contains "401" error_stderr;
  assert_contains "[REDACTED]" error_stderr;
  assert_not_contains "secret" error_stderr;

  let jsonl_result, jsonl_stdout, jsonl_stderr =
    capture_output (fun () ->
        Ocaat.main
          ~argv:
            [| "ocaat"; "syntax"; "did"; "check"; did; "--format"; "jsonl" |]
          ())
  in
  assert_equal "64" (string_of_int jsonl_result);
  assert_equal "" jsonl_stdout;
  assert_contains "jsonl" jsonl_stderr
