open Cmdliner
(** Generic read-only XRPC call commands and document renderer. *)

open Cmdliner.Term.Syntax

(** Run an XRPC call with the shared CLI context. *)
let run method_ params context =
  match context.Cli_context.pds with
  | None ->
      Output.usage_error ~format:context.Cli_context.format
        "xrpc query requires --pds <url>"
  | Some pds -> (
      match Output.Preflight.require_service_url "PDS URL" pds with
      | Error reason ->
          Output.validation_error ~format:context.Cli_context.format reason
      | Ok pds -> (
          match Xrpc.parse_params params with
          | Error reason ->
              Output.validation_error ~format:context.Cli_context.format reason
          | Ok params -> (
              match
                Lwt_main.run
                  (Xrpc.call ?auth:context.auth ~pds ~method_ ~params ())
              with
              | Error reason ->
                  Output.validation_error ~format:context.Cli_context.format
                    reason
              | Ok response -> (
                  match Xrpc.query_url ~pds ~method_ ~params with
                  | Error reason ->
                      Output.validation_error ~format:context.Cli_context.format
                        reason
                  | Ok endpoint ->
                      Output.print_http_response ~kind:"pds" ~source:"pds"
                        ~endpoint
                        ~pds:(Http.normalize_base_url pds)
                        ~format:context.Cli_context.format response))))

(** Build one Cmdliner command with the shared XRPC call behavior. *)
let command name doc =
  let method_ =
    Arg.(
      required
      & pos 0 (some string) None
      & info [] ~docv:"METHOD" ~doc:"XRPC query method NSID.")
  in
  let params =
    Arg.(
      value & opt_all string []
      & info [ "param" ] ~docv:"K=V" ~doc:"Add a URL query parameter.")
  in
  let term =
    Cli_context.with_context
      (let+ method_ = method_ and+ params = params in
       run method_ params)
  in
  let info = Cmd.info name ~doc in
  Cmd.v info term

(** Cmdliner command for [xrpc call]. *)
let call_cmd = command "call" "Run a read-only XRPC query."

(** Compatibility alias for [xrpc call]. *)
let query_cmd = command "query" "Alias for xrpc call."

(** Top-level [xrpc] command group. *)
let cmd =
  let info = Cmd.info "xrpc" ~doc:"Generic XRPC escape hatch." in
  Cmd.group info [ call_cmd; query_cmd ]
