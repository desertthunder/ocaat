open Cmdliner
open Cmdliner.Term.Syntax

let run_migrate step artifact_dir _context =
  let settings = Migration.settings ?artifact_dir () in
  match Lwt_main.run (Migration.run step settings) with
  | Error reason ->
      Fmt.epr "%s@." reason;
      1
  | Ok json ->
      Migration.log_json (Migration.step_name step) json;
      0

let artifact_dir_arg =
  Arg.(
    value
    & opt (some string) None
    & info [ "artifact-dir" ] ~docv:"DIR"
        ~doc:"Directory for migration artifacts.")

let migrate_step_cmd step =
  let name = Migration.step_name step in
  let term =
    Cli_context.with_context
      (let+ artifact_dir = artifact_dir_arg in
       run_migrate step artifact_dir)
  in
  Cmd.v (Cmd.info name ~doc:"Run one account migration step.") term

(** Cmdliner command group for Tempest-first account migration steps. *)
let migrate_cmd =
  let info = Cmd.info "migrate" ~doc:"Run Tempest account migration steps." in
  Cmd.group info
    [
      migrate_step_cmd Full;
      migrate_step_cmd Login_source;
      migrate_step_cmd Service_auth;
      migrate_step_cmd Source_session_status;
      migrate_step_cmd Export_car;
      migrate_step_cmd List_source_blobs;
      migrate_step_cmd Download_source_blobs;
      migrate_step_cmd Create_account;
      migrate_step_cmd Refresh_session;
      migrate_step_cmd Import_repo;
      migrate_step_cmd Status;
      migrate_step_cmd Missing_blobs;
      migrate_step_cmd Upload_missing_blobs;
      migrate_step_cmd Plc_recommended;
      migrate_step_cmd Plc_request_token;
      migrate_step_cmd Plc_sign;
      migrate_step_cmd Plc_submit;
      migrate_step_cmd Activate;
    ]

(** Top-level [account] command group. *)
let cmd =
  let info = Cmd.info "account" ~doc:"Account and migration commands." in
  Cmd.group info [ migrate_cmd ]
