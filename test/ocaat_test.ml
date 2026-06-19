let assert_exit expected args =
  let actual = Ocaat.main ~argv:(Array.of_list ("ocaat" :: args)) () in
  if actual <> expected then
    failwith (Printf.sprintf "expected exit %d, got %d" expected actual)

let () =
  assert_exit 0 [ "version" ];
  assert_exit 0 [ "tempest"; "defaults" ];
  assert_exit 0 [ "tempest"; "migration-plan" ];
  assert_exit 0 [ "syntax"; "handle"; "check"; "tempest.desertthunder.dev" ];
  assert_exit 1 [ "syntax"; "handle"; "check"; "tempest" ];
  assert_exit 1 [ "syntax"; "handle"; "check"; "cn.8" ];
  assert_exit 0 [ "syntax"; "did"; "check"; "did:plc:oga6ppys7zwxlheuqmcm7dac" ];
  assert_exit 1 [ "syntax"; "did"; "check"; "plc:oga6ppys7zwxlheuqmcm7dac" ];
  assert_exit 1 [ "syntax"; "did"; "check"; "did:METHOD:val" ];
  assert_exit 0 [ "syntax"; "nsid"; "check"; "com.atproto.repo.getRecord" ];
  assert_exit 0 [ "syntax"; "nsid"; "check"; "cn.8.lex.stuff" ];
  assert_exit 1 [ "syntax"; "nsid"; "check"; "repo" ];
  assert_exit 0
    [ "syntax"; "at-uri"; "check"; "at://did:plc:abc/app.bsky.feed.post/3kabc" ];
  assert_exit 1 [ "syntax"; "at-uri"; "check"; "at://foo.com/" ];
  assert_exit 0 [ "syntax"; "rkey"; "check"; "3kabc" ];
  assert_exit 1 [ "syntax"; "rkey"; "check"; "." ];
  assert_exit 1 [ "syntax"; "rkey"; "check"; "any+space" ];
  assert_exit 0
    [
      "syntax";
      "cid";
      "check";
      "bafkreifodmypic3zbjtevk7rbftxvjxgpgegt5njaxn57lamxracv2a3he";
    ];
  assert_exit 1 [ "syntax"; "cid"; "check"; "QmNotBase32" ];
  assert_exit 0 [ "syntax"; "tid"; "check"; "3kabc234567ab" ];
  assert_exit 1 [ "syntax"; "tid"; "check"; "short" ];
  assert_exit 1 [ "syntax"; "tid"; "check"; "kjzfcijpj2z2a" ];
  assert_exit 0 [ "syntax"; "tid"; "generate" ];
  assert_exit 0 [ "syntax"; "datetime"; "check"; "2026-06-19T12:34:56Z" ];
  assert_exit 0
    [ "syntax"; "datetime"; "check"; "1985-04-12T23:20:50.123-07:00" ];
  assert_exit 1 [ "syntax"; "datetime"; "check"; "2026-06-19 12:34:56" ];
  assert_exit 1
    [ "syntax"; "datetime"; "check"; "1985-04-12T23:20:50.123-00:00" ];
  assert_exit 0 [ "syntax"; "datetime"; "now" ]
