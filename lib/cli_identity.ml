open Cmdliner
(** The [resolve] command for normalized AT Protocol identities. *)

open Cmdliner.Term.Syntax

let print_result result context =
  let document =
    Document.make ?did:(Some result.Identity.did)
      ?pds:result.Identity.pds_endpoint ~source:result.Identity.source
      ~endpoint:result.Identity.endpoint ~kind:"identity" (Identity.data result)
  in
  Renderer.print_stdout (Renderer.document context.Cli_context.format document);
  Output.Exit_code.ok

(** Resolve a handle or DID without contacting an AppView or PDS fallback. *)
let resolve value context =
  match Lwt_main.run (Identity.resolve value) with
  | Ok result -> print_result result context
  | Error (Identity.Validation reason) ->
      Output.validation_error ~format:context.Cli_context.format reason
  | Error (Identity.Network reason) ->
      Output.network_error ~format:context.Cli_context.format reason
  | Error (Identity.Remote (status, reason)) ->
      Output.remote_error ?status ~format:context.Cli_context.format reason

let cmd =
  let value =
    Arg.(
      required
      & pos 0 (some string) None
      & info [] ~docv:"HANDLE-OR-DID"
          ~doc:"Handle or DID to resolve into identity metadata.")
  in
  let term =
    Cli_context.with_context
      (let+ value = value in
       resolve value)
  in
  Cmd.v (Cmd.info "resolve" ~doc:"Resolve a handle or DID identity.") term
