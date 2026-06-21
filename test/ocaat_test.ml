let usage = 64
let validation = 65

let assert_exit expected args =
  let actual = Ocaat.main ~argv:(Array.of_list ("ocaat" :: args)) () in
  if actual <> expected then
    failwith (Printf.sprintf "expected exit %d, got %d" expected actual)

let () =
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
  assert_exit validation [ "syntax"; "did"; "check"; "plc:oga6ppys7zwxlheuqmcm7dac" ];
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
  assert_exit validation [ "syntax"; "datetime"; "check"; "2026-06-19 12:34:56" ];
  assert_exit validation
    [ "syntax"; "datetime"; "check"; "1985-04-12T23:20:50.123-00:00" ];
  assert_exit 0 [ "syntax"; "datetime"; "now" ]
