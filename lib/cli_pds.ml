open Cmdliner
open Cmdliner.Term.Syntax

(** Run [pds describe] with the shared CLI context. *)
let describe host context =
  let response =
    Lwt_main.run (Pds.describe ?auth:context.Cli_context.auth host)
  in
  Output.print_http_response ~json:context.json response

(** Cmdliner command for [pds describe]. *)
let describe_cmd =
  let host =
    Arg.(
      required
      & pos 0 (some string) None
      & info [] ~docv:"HOST" ~doc:"PDS host or service URL.")
  in
  let term =
    Cli_context.with_context
      (let+ host = host in
       describe host)
  in
  let info = Cmd.info "describe" ~doc:"Describe a PDS server." in
  Cmd.v info term

(** Top-level [pds] command group. *)
let cmd =
  let info = Cmd.info "pds" ~doc:"PDS inspection commands." in
  Cmd.group info [ describe_cmd ]
