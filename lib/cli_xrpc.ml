open Cmdliner
open Cmdliner.Term.Syntax

(** Run [xrpc query] with the shared CLI context. *)
let query method_ params context =
  match context.Cli_context.pds with
  | None ->
      Output.usage_error ~json:context.Cli_context.json
        "xrpc query requires --pds <url>"
  | Some pds -> (
      match Xrpc.parse_params params with
      | Error reason -> Output.validation_error ~json:context.json reason
      | Ok params -> (
          match
            Lwt_main.run
              (Xrpc.query ?auth:context.auth ~pds ~method_ ~params ())
          with
          | Error reason -> Output.validation_error ~json:context.json reason
          | Ok response ->
              Output.print_http_response ~json:context.json response))

(** Cmdliner command for [xrpc query]. *)
let query_cmd =
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
       query method_ params)
  in
  let info = Cmd.info "query" ~doc:"Run a generic XRPC query." in
  Cmd.v info term

(** Top-level [xrpc] command group. *)
let cmd =
  let info = Cmd.info "xrpc" ~doc:"Generic XRPC escape hatch." in
  Cmd.group info [ query_cmd ]
