open Cmdliner
(** Record read commands and document rendering. *)

open Cmdliner.Term.Syntax

let print_failure context = function
  | Identity.Validation reason ->
      Output.validation_error ~format:context.Cli_context.format reason
  | Identity.Network reason ->
      Output.network_error ~format:context.Cli_context.format reason
  | Identity.Remote (status, reason) ->
      Output.remote_error ?status ~format:context.Cli_context.format reason

let selected_pds context command =
  match context.Cli_context.pds with
  | None -> Ok None
  | Some pds -> (
      match Output.Preflight.require_service_url "PDS URL" pds with
      | Ok pds -> Ok (Some pds)
      | Error reason ->
          Error
            (Output.validation_error ~format:context.Cli_context.format
               (command ^ ": " ^ reason)))

let render ~kind query parser context =
  Output.print_parsed_response ~kind ~source:"pds" ~did:query.Record.did
    ~pds:query.pds ~endpoint:query.endpoint ~format:context.Cli_context.format
    ~parse:parser query.response

let get value context =
  match selected_pds context "record get" with
  | Error code -> code
  | Ok pds -> (
      match Lwt_main.run (Record.get ?auth:context.auth ?pds value) with
      | Error error -> print_failure context error
      | Ok query ->
          render ~kind:"record" query
            (Record.parse_get_response ~endpoint:query.endpoint)
            context)

let list actor collections collection limit cursor context =
  match selected_pds context "record list" with
  | Error code -> code
  | Ok pds -> (
      let mode_result =
        if collections then
          match (collection, limit, cursor) with
          | None, None, None -> Ok Record.Collections
          | _ ->
              Error
                (Output.validation_error ~format:context.Cli_context.format
                   ("record list collection-summary mode cannot use "
                  ^ "--collection, --limit, or --cursor"))
        else
          match collection with
          | None ->
              Error
                (Output.usage_error ~format:context.Cli_context.format
                   "record list requires --collection <nsid> or --collections")
          | Some collection ->
              Ok
                (Record.Records
                   {
                     collection;
                     limit = Option.value ~default:50 limit;
                     cursor;
                   })
      in
      match mode_result with
      | Error code -> code
      | Ok mode -> (
          match
            Lwt_main.run (Record.list ?auth:context.auth ?pds ~actor ~mode ())
          with
          | Error error -> print_failure context error
          | Ok query -> (
              match mode with
              | Record.Collections ->
                  render ~kind:"records" query
                    (Record.parse_describe_response ~endpoint:query.endpoint)
                    context
              | Record.Records { collection; _ } ->
                  render ~kind:"records" query
                    (Record.parse_list_response ~endpoint:query.endpoint
                       ~did:query.did ~collection)
                    context)))

let get_cmd =
  let value =
    Arg.(
      required
      & pos 0 (some string) None
      & info [] ~docv:"AT-URI" ~doc:"AT URI identifying one record.")
  in
  let term =
    Cli_context.with_context
      (let+ value = value in
       get value)
  in
  Cmd.v (Cmd.info "get" ~doc:"Fetch one public repository record.") term

let list_cmd =
  let actor =
    Arg.(
      required
      & pos 0 (some string) None
      & info [] ~docv:"HANDLE-OR-DID" ~doc:"Repository handle or DID.")
  in
  let collections =
    Arg.(
      value & flag
      & info [ "collections" ]
          ~doc:"Show the repository's collection summary instead of records.")
  in
  let collection =
    Arg.(
      value
      & opt (some string) None
      & info [ "collection" ] ~docv:"NSID"
          ~doc:"List records from this validated collection.")
  in
  let limit =
    Arg.(
      value
      & opt (some int) None
      & info [ "limit" ] ~docv:"N"
          ~doc:"Return between 1 and 100 records; the default is 50.")
  in
  let cursor =
    Arg.(
      value
      & opt (some string) None
      & info [ "cursor" ] ~docv:"CURSOR" ~doc:"Continue after this cursor.")
  in
  let term =
    Cli_context.with_context
      (let+ actor = actor
       and+ collections = collections
       and+ collection = collection
       and+ limit = limit
       and+ cursor = cursor in
       list actor collections collection limit cursor)
  in
  Cmd.v (Cmd.info "list" ~doc:"List public records or collections.") term

let cmd =
  let info = Cmd.info "record" ~doc:"Public repository record reads." in
  Cmd.group info [ get_cmd; list_cmd ]
