let version = "0.1.0"
let pp_lines lines = List.iter (Fmt.pr "%s@.") lines

let print_migration_plan () =
  pp_lines
    [
      "Tempest account migration plan:";
      "  1. Login to the source PDS and save the source session.";
      "  2. Request service auth for com.atproto.server.createAccount.";
      "  3. Export the source repo CAR.";
      "  4. List and download source blobs.";
      "  5. Create the inactive existing-DID account on Tempest.";
      "  6. Import the CAR into Tempest.";
      "  7. Upload missing blobs.";
      "  8. Update did:plc or did:web identity so #atproto_pds points at \
       Tempest.";
      "  9. Activate only after Tempest reports migrationReady=true.";
    ]

open Cmdliner

let version_cmd =
  let term =
    Cli_context.with_setup
      Term.(
        const (fun () ->
            Fmt.pr "%s@." version;
            0)
        $ const ())
  in
  let info = Cmd.info "version" ~doc:"Print the ocaat version." in
  Cmd.v info term

let tempest_migration_plan_cmd =
  let term =
    Cli_context.with_setup
      Term.(
        const (fun () ->
            print_migration_plan ();
            0)
        $ const ())
  in
  let info =
    Cmd.info "migration-plan"
      ~doc:"Print the Tempest account migration sequence."
  in
  Cmd.v info term

let tempest_cmd =
  let info = Cmd.info "tempest" ~doc:"Tempest PDS helper commands." in
  Cmd.group info [ tempest_migration_plan_cmd ]

let root_cmd =
  let doc = "OCaml AT Protocol CLI for operating a Tempest PDS." in
  let info = Cmd.info "ocaat" ~version ~doc in
  Cmd.group info
    [
      version_cmd;
      tempest_cmd;
      Cli_account.cmd;
      Cli_get.cmd;
      Cli_identity.cmd;
      Cli_plc.cmd;
      Cli_key.cmd;
      Cli_lexicon.cmd;
      Cli_pds.cmd;
      Cli_record.cmd;
      Cli_relay.cmd;
      Cli_syntax.cmd;
      Cli_xrpc.cmd;
    ]

let main ?argv () = Cmd.eval' ?argv root_cmd
