open Cmdliner
(** The top-level [get] dispatcher for recognizable AT Protocol resources. *)

open Cmdliner.Term.Syntax

let print_identity result context = Cli_identity.print_result result context

let print_record query context =
  Cli_record.render ~kind:"record" query
    (Record.parse_get_response ~endpoint:query.Record.endpoint)
    context

let print_lexicon query context =
  Cli_lexicon.render query query.Lexicon.document context

let print_failure context = function
  | Resource.Validation reason ->
      Output.validation_error ~format:context.Cli_context.format reason
  | Resource.Identity_failure failure ->
      Cli_record.print_failure context failure
  | Resource.Lexicon_failure failure ->
      Cli_lexicon.print_failure context failure

let get value context =
  match
    Lwt_main.run
      (Resource.get ?auth:context.Cli_context.auth ?pds:context.Cli_context.pds
         value)
  with
  | Error failure -> print_failure context failure
  | Ok (Resource.Identity_result result) -> print_identity result context
  | Ok (Resource.Record_result query) -> print_record query context
  | Ok (Resource.Lexicon_result query) -> print_lexicon query context
  | Ok (Resource.Pds_result { pds; endpoint; response }) ->
      Output.print_http_response ~kind:"pds" ~source:"pds" ~endpoint ~pds
        ~format:context.Cli_context.format response

let cmd =
  let value =
    Arg.(
      required
      & pos 0 (some string) None
      & info [] ~docv:"RESOURCE"
          ~doc:"Handle, DID, AT URI, supported web URL, NSID, or PDS URL.")
  in
  let term =
    Cli_context.with_context
      (let+ value = value in
       get value)
  in
  Cmd.v
    (Cmd.info "get" ~doc:"Fetch one recognizable AT Protocol resource.")
    term
