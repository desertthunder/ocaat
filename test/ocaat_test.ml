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
  assert_exit 0 [ "syntax"; "did"; "check"; "did:plc:oga6ppys7zwxlheuqmcm7dac" ];
  assert_exit 1 [ "syntax"; "did"; "check"; "plc:oga6ppys7zwxlheuqmcm7dac" ];
  assert_exit 0 [ "syntax"; "nsid"; "check"; "com.atproto.repo.getRecord" ];
  assert_exit 1 [ "syntax"; "nsid"; "check"; "repo" ];
  assert_exit 0 [ "syntax"; "at-uri"; "check"; "at://did:plc:abc/app.bsky.feed.post/3kabc" ]
