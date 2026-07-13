open Cmdliner
(** Lexicon read commands and document rendering. *)

open Cmdliner.Term.Syntax

let print_failure context = function
  | Lexicon.Validation reason ->
      Output.validation_error ~format:context.Cli_context.format reason
  | Lexicon.Network reason ->
      Output.network_error ~format:context.Cli_context.format reason
  | Lexicon.Remote (status, reason) ->
      Output.remote_error ?status ~format:context.Cli_context.format reason

let render query data context =
  if context.Cli_context.format = Format.Raw then (
    Renderer.print_stdout (Renderer.raw query.Lexicon.response.body);
    Output.Exit_code.ok)
  else
    let document =
      Document.make ?did:(Some query.Lexicon.did) ?pds:(Some query.Lexicon.pds)
        ~sources:query.Lexicon.sources ~source:"pds"
        ~endpoint:query.Lexicon.endpoint ~kind:"lexicon" data
    in
    Renderer.print_stdout
      (Renderer.document context.Cli_context.format document);
    Output.Exit_code.ok

let get nsid context =
  match
    Lwt_main.run
      (Lexicon.get ?auth:context.Cli_context.auth ?pds:context.Cli_context.pds
         nsid)
  with
  | Error error -> print_failure context error
  | Ok query -> render query query.Lexicon.document context

(** Run [lexicon describe] for a validated network Lexicon. *)
let describe nsid context =
  match Lwt_main.run (Lexicon.describe ?auth:context.Cli_context.auth nsid) with
  | Error error -> print_failure context error
  | Ok description ->
      render description.Lexicon.query
        (Lexicon.description_data description)
        context

let nsid_arg =
  Arg.(
    required
    & pos 0 (some string) None
    & info [] ~docv:"NSID" ~doc:"Lexicon NSID to resolve.")

let get_cmd =
  let term =
    Cli_context.with_context
      (let+ nsid = nsid_arg in
       get nsid)
  in
  Cmd.v (Cmd.info "get" ~doc:"Fetch and validate a published Lexicon.") term

let describe_cmd =
  let term =
    Cli_context.with_context
      (let+ nsid = nsid_arg in
       describe nsid)
  in
  Cmd.v
    (Cmd.info "describe" ~doc:"Describe the selected Lexicon definition.")
    term

let cmd =
  let info = Cmd.info "lexicon" ~doc:"Published Lexicon read commands." in
  Cmd.group info [ get_cmd; describe_cmd ]
