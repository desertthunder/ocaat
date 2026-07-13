open Cmdliner
(** PDS read commands and document/provenance rendering. *)

open Cmdliner.Term.Syntax

(** Validate the configured PDS before a command makes a request. *)
let required_pds context command =
  match context.Cli_context.pds with
  | Some pds -> (
      match Output.Preflight.require_service_url "PDS URL" pds with
      | Ok pds -> Ok pds
      | Error reason ->
          Error
            (Output.validation_error ~format:context.Cli_context.format reason))
  | None ->
      Error
        (Output.usage_error ~format:context.Cli_context.format
           (command ^ " requires --pds <url>: PDS URL is required"))

(** Validate and normalize a positional PDS host. *)
let required_host context host command =
  match Output.Preflight.require_service_url "host" host with
  | Ok pds -> Ok pds
  | Error reason ->
      Error
        (Output.validation_error ~format:context.Cli_context.format
           (command ^ " has an invalid host: " ^ reason))

let required_admin_token context command =
  match Output.Preflight.require_admin_auth context.Cli_context.admin_token with
  | Ok token -> Ok token
  | Error reason ->
      Error
        (Output.auth_error ~format:context.Cli_context.format
           (command ^ " requires --admin-token <token>: " ^ reason))

(** Run [pds describe] with the shared CLI context. *)
let describe host context =
  match required_host context host "pds describe" with
  | Error code -> code
  | Ok host ->
      let response =
        Lwt_main.run (Pds.describe ?auth:context.Cli_context.auth host)
      in
      Output.print_http_response ~kind:"pds" ~source:"pds"
        ~endpoint:(Pds.describe_url host)
        ~pds:(Http.normalize_base_url host)
        ~format:context.Cli_context.format response

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

(** Fetch the optional describe payload used to enrich human inspection. *)
let describe_body ?auth pds =
  let response = Lwt_main.run (Pds.describe ?auth pds) in
  if response.status >= 200 && response.status < 300 then Some response.body
  else None

(** Build the presentation-only summary for a structured PDS response. *)
let inspection_summary ~admin ~pds context json =
  let describe_body = describe_body ?auth:context.Cli_context.auth pds in
  let service_did = Option.bind describe_body Pds.service_did_from_describe in
  let inspection =
    if admin then
      Pds.admin_inspection ?service_did ?describe_body ~host:pds json
    else Pds.public_inspection ?service_did ?describe_body ~host:pds json
  in
  Pds.inspection_to_json inspection

(** Render an operational PDS response with its actual endpoint. *)
let print_inspection_response ~admin ~method_ ~pds context
    (response : Http.response) =
  let endpoint = Pds.operational_url pds method_ in
  let summary =
    match context.Cli_context.format with
    | Format.Markdown -> (
        match Pds.parse_json_response endpoint response.body with
        | Error _ -> None
        | Ok json -> Some (inspection_summary ~admin ~pds context json))
    | Format.Json | Format.Jsonl | Format.Raw -> None
  in
  Output.print_http_response ~kind:"pds" ~source:"pds" ?summary
    ~require_json:true ~endpoint ~pds ~format:context.Cli_context.format
    response

(** Run [pds health] with the shared CLI context. *)
let health context =
  match required_pds context "pds health" with
  | Error code -> code
  | Ok pds ->
      let response = Lwt_main.run (Pds.health pds) in
      print_inspection_response ~admin:false ~method_:Pds.Health ~pds context
        response

(** Run [pds stats] with the shared CLI context. *)
let stats context =
  match required_pds context "pds stats" with
  | Error code -> code
  | Ok pds ->
      let response = Lwt_main.run (Pds.stats pds) in
      print_inspection_response ~admin:false ~method_:Pds.Stats ~pds context
        response

(** Run [pds admin-status] with the shared CLI context. *)
let admin_status context =
  match required_pds context "pds admin-status" with
  | Error code -> code
  | Ok pds -> (
      match required_admin_token context "pds admin-status" with
      | Error code -> code
      | Ok admin_token ->
          let response = Lwt_main.run (Pds.admin_status ~admin_token pds) in
          print_inspection_response ~admin:true ~method_:Pds.Admin_status ~pds
            context response)

(** Cmdliner command for [pds health]. *)
let health_cmd =
  let term =
    Cli_context.with_context
      (let+ () = Term.const () in
       health)
  in
  let info = Cmd.info "health" ~doc:"Show PDS health status." in
  Cmd.v info term

(** Cmdliner command for [pds stats]. *)
let stats_cmd =
  let term =
    Cli_context.with_context
      (let+ () = Term.const () in
       stats)
  in
  let info = Cmd.info "stats" ~doc:"Show public PDS stats." in
  Cmd.v info term

(** Cmdliner command for [pds admin-status]. *)
let admin_status_cmd =
  let term =
    Cli_context.with_context
      (let+ () = Term.const () in
       admin_status)
  in
  let info = Cmd.info "admin-status" ~doc:"Show admin PDS status." in
  Cmd.v info term

(** Run [pds account list] with the shared CLI context, enumerating PDS
    repositories and rendering them as a records document. *)
let account_list handles host context =
  match required_host context host "pds account list" with
  | Error code -> code
  | Ok host -> (
      match
        Lwt_main.run (Pds.list_all_repos ?auth:context.Cli_context.auth host)
      with
      | Error response ->
          Output.print_http_response ~kind:"records" ~source:"pds"
            ~endpoint:(Pds.list_repos_url host)
            ~pds:(Http.normalize_base_url host)
            ~format:context.Cli_context.format response
      | Ok repos ->
          let repos =
            if handles && context.Cli_context.format = Format.Markdown then
              List.map
                (fun repo ->
                  match Pds.string_field "did" repo with
                  | None -> repo
                  | Some did -> (
                      match Lwt_main.run (Pds.lookup_handle did) with
                      | None -> repo
                      | Some handle -> (
                          match repo with
                          | `Assoc fields ->
                              `Assoc (fields @ [ ("handle", `String handle) ])
                          | _ -> repo)))
                repos
            else repos
          in
          let data = `List repos in
          let endpoint = Pds.list_repos_url host in
          let document =
            Document.make ~source:"pds" ~endpoint
              ~pds:(Http.normalize_base_url host)
              ~kind:"records" data
          in
          Renderer.print_stdout
            (Renderer.document context.Cli_context.format document);
          0)

(** Run [pds account status] with the shared CLI context, fetching and rendering
    repository status for one account DID. *)
let account_status did context =
  match context.Cli_context.pds with
  | None ->
      Output.usage_error ~format:context.Cli_context.format
        "pds account status requires --pds <url>"
  | Some pds -> (
      match Output.Preflight.require_service_url "PDS URL" pds with
      | Error reason ->
          Output.validation_error ~format:context.Cli_context.format reason
      | Ok pds -> (
          match
            Lwt_main.run (Pds.repo_status ?auth:context.auth ~pds ~did ())
          with
          | Error reason ->
              Output.validation_error ~format:context.Cli_context.format reason
          | Ok response ->
              Output.print_http_response ~kind:"pds" ~source:"pds"
                ~require_json:true
                ~endpoint:(Pds.repo_status_url pds did)
                ~pds ~did ~format:context.Cli_context.format response))

(** Cmdliner command for [pds account list]. *)
let account_list_cmd =
  let handles =
    Arg.(
      value & flag
      & info [ "handles" ] ~doc:"Resolve account handles when possible.")
  in
  let host =
    Arg.(
      required
      & pos 0 (some string) None
      & info [] ~docv:"HOST" ~doc:"PDS host or service URL.")
  in
  let term =
    Cli_context.with_context
      (let+ handles = handles and+ host = host in
       account_list handles host)
  in
  let info = Cmd.info "list" ~doc:"List repos hosted by a PDS." in
  Cmd.v info term

(** Cmdliner command for [pds account status]. *)
let account_status_cmd =
  let did =
    Arg.(
      required
      & pos 0 (some string) None
      & info [] ~docv:"DID" ~doc:"Account DID.")
  in
  let term =
    Cli_context.with_context
      (let+ did = did in
       account_status did)
  in
  let info =
    Cmd.info "status" ~doc:"Show repo hosting status for one account."
  in
  Cmd.v info term

(** Cmdliner command group for [pds account]. *)
let account_cmd =
  let info = Cmd.info "account" ~doc:"PDS account/repo inspection commands." in
  Cmd.group info [ account_list_cmd; account_status_cmd ]

(** Top-level [pds] command group. *)
let cmd =
  let info = Cmd.info "pds" ~doc:"PDS inspection commands." in
  Cmd.group info
    [ describe_cmd; health_cmd; stats_cmd; admin_status_cmd; account_cmd ]
