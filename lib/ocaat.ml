let version = "0.1.0"

module Http = struct
  type response = { status : int; body : string }

  let get_text url =
    let open Lwt.Syntax in
    let uri = Uri.of_string url in
    let* response, body = Cohttp_lwt_unix.Client.get uri in
    let status =
      Cohttp.Response.status response |> Cohttp.Code.code_of_status
    in
    let+ body = Cohttp_lwt.Body.to_string body in
    { status; body }
end

let pp_lines lines = List.iter (Fmt.pr "%s@.") lines

let print_tempest_defaults () =
  pp_lines
    [
      "Tempest defaults used by the migration helper:";
      "  TEMPEST=https://tempest.desertthunder.dev";
      "  TEMPEST_SERVICE_DID=did:web:tempest.desertthunder.dev";
      "  ARTIFACT_DIR=.sandbox";
      "";
      "Future HTTP commands will read these from the environment.";
    ]

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

let tempest_defaults_cmd =
  let term =
    Cli_context.with_setup
      Term.(
        const (fun () ->
            print_tempest_defaults ();
            0)
        $ const ())
  in
  let info =
    Cmd.info "defaults" ~doc:"Print default Tempest-related environment values."
  in
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
  Cmd.group info [ tempest_defaults_cmd; tempest_migration_plan_cmd ]

let root_cmd =
  let doc = "OCaml AT Protocol CLI for operating a Tempest PDS." in
  let info = Cmd.info "ocaat" ~version ~doc in
  Cmd.group info [ version_cmd; tempest_cmd; Cli_syntax.cmd ]

let main ?argv () = Cmd.eval' ?argv root_cmd
