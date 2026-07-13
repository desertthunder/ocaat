open Cmdliner
(** PLC directory read commands and document rendering. *)

open Cmdliner.Term.Syntax

let print_failure context = function
  | Identity.Validation reason ->
      Output.validation_error ~format:context.Cli_context.format reason
  | Identity.Network reason ->
      Output.network_error ~format:context.Cli_context.format reason
  | Identity.Remote (status, reason) ->
      Output.remote_error ?status ~format:context.Cli_context.format reason

let plc_host_arg =
  Arg.(
    value
    & opt string Plc.default_host
    & info [ "plc-host" ] ~docv:"URL"
        ~doc:"PLC directory service URL; defaults to https://plc.directory.")

let selected_host context host command =
  match Output.Preflight.require_service_url "PLC URL" host with
  | Ok host -> Ok host
  | Error reason ->
      Error
        (Output.validation_error ~format:context.Cli_context.format
           (command ^ ": " ^ reason))

let show actor host context =
  match selected_host context host "plc show" with
  | Error code -> code
  | Ok host -> (
      match Lwt_main.run (Plc.show ~plc_host:host actor) with
      | Error error -> print_failure context error
      | Ok query ->
          Output.print_parsed_response ~kind:"plc" ~source:"plc" ~did:query.did
            ~endpoint:query.endpoint ~format:context.Cli_context.format
            ~parse:(Plc.parse_data_response ~endpoint:query.endpoint)
            query.response)

let history actor host context =
  match selected_host context host "plc history" with
  | Error code -> code
  | Ok host -> (
      match Lwt_main.run (Plc.history ~plc_host:host actor) with
      | Error error -> print_failure context error
      | Ok query ->
          Output.print_parsed_response ~kind:"plc" ~source:"plc" ~did:query.did
            ~endpoint:query.endpoint ~format:context.Cli_context.format
            ~parse:(Plc.parse_history_response ~endpoint:query.endpoint)
            query.response)

let actor_arg =
  Arg.(
    required
    & pos 0 (some string) None
    & info [] ~docv:"HANDLE-OR-DID" ~doc:"Handle or DID to inspect.")

let show_cmd =
  let term =
    Cli_context.with_context
      (let+ actor = actor_arg and+ host = plc_host_arg in
       show actor host)
  in
  Cmd.v (Cmd.info "show" ~doc:"Show current PLC directory data.") term

let history_cmd =
  let term =
    Cli_context.with_context
      (let+ actor = actor_arg and+ host = plc_host_arg in
       history actor host)
  in
  Cmd.v (Cmd.info "history" ~doc:"Show a DID's chronological PLC history.") term

let cmd =
  let info = Cmd.info "plc" ~doc:"Direct PLC identity-directory reads." in
  Cmd.group info [ show_cmd; history_cmd ]
