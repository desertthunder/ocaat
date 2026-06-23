open Cmdliner
open Cmdliner.Term.Syntax

let required_pds context command =
  match Output.Preflight.require_pds context.Cli_context.pds with
  | Ok pds -> Ok pds
  | Error reason ->
      Error
        (Output.usage_error ~json:context.Cli_context.json
           (command ^ " requires --pds <url>: " ^ reason))

let required_admin_token context command =
  match Output.Preflight.require_admin_auth context.Cli_context.admin_token with
  | Ok token -> Ok token
  | Error reason ->
      Error
        (Output.auth_error ~json:context.Cli_context.json
           (command ^ " requires --admin-token <token>: " ^ reason))

let value_or_unknown = function None -> "unknown" | Some value -> value

let bool_or_unknown = function
  | None -> "unknown"
  | Some value -> string_of_bool value

let int_or_unknown = function
  | None -> "unknown"
  | Some value -> string_of_int value

let list_or_unknown = function
  | None -> "unknown"
  | Some [] -> "none"
  | Some values -> String.concat "," values

let print_status_cues = function
  | [] -> Fmt.pr "statusCues=none@."
  | cues ->
      let rendered =
        cues
        |> List.map (fun (name, value) -> name ^ "=" ^ value)
        |> String.concat " "
      in
      Fmt.pr "statusCues=%s@." rendered

(** Print a compact human PDS inspection summary. *)
let print_inspection (inspection : Pds.inspection) =
  Fmt.pr "hostname=%s@." inspection.hostname;
  Fmt.pr "serviceDid=%s@." (value_or_unknown inspection.service_did);
  Fmt.pr "health=%s@." (value_or_unknown inspection.health_state);
  Fmt.pr "accountCount=%s@." (int_or_unknown inspection.account_count);
  Fmt.pr "repoCount=%s@." (int_or_unknown inspection.repo_count);
  Fmt.pr "blobCount=%s@." (int_or_unknown inspection.blob_count);
  Fmt.pr "sequencerCursor=%s@." (int_or_unknown inspection.sequencer_cursor);
  Fmt.pr "configuredCrawlers=%s@."
    (list_or_unknown inspection.configured_crawlers);
  Fmt.pr "storageBackend=%s@." (value_or_unknown inspection.storage_backend);
  Fmt.pr "adminAuthConfigured=%s@."
    (bool_or_unknown inspection.admin_auth_configured);
  print_status_cues inspection.status_cues;
  0

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

let describe_body ?auth pds =
  let response = Lwt_main.run (Pds.describe ?auth pds) in
  if response.status >= 200 && response.status < 300 then Some response.body
  else None

let service_did_from_body body = Option.bind body Pds.service_did_from_describe

let print_public_pds_response ~endpoint ~pds context response =
  if context.Cli_context.json then
    Output.print_http_response ~json:true response
  else if response.Http.status < 200 || response.status >= 300 then
    Output.print_http_response ~json:false response
  else
    match Pds.parse_json_response endpoint response.body with
    | Error reason -> Output.remote_error ~json:false reason
    | Ok json ->
        let describe_body = describe_body ?auth:context.auth pds in
        let service_did = service_did_from_body describe_body in
        Pds.public_inspection ?service_did ?describe_body ~host:pds json
        |> print_inspection

(** Run [pds health] with the shared CLI context. *)
let health context =
  match required_pds context "pds health" with
  | Error code -> code
  | Ok pds ->
      let response = Lwt_main.run (Pds.health pds) in
      print_public_pds_response ~endpoint:"_health" ~pds context response

(** Run [pds stats] with the shared CLI context. *)
let stats context =
  match required_pds context "pds stats" with
  | Error code -> code
  | Ok pds ->
      let response = Lwt_main.run (Pds.stats pds) in
      print_public_pds_response ~endpoint:"_stats" ~pds context response

(** Run [pds admin-status] with the shared CLI context. *)
let admin_status context =
  match required_pds context "pds admin-status" with
  | Error code -> code
  | Ok pds -> (
      match required_admin_token context "pds admin-status" with
      | Error code -> code
      | Ok admin_token -> (
          let response = Lwt_main.run (Pds.admin_status ~admin_token pds) in
          if context.json then Output.print_http_response ~json:true response
          else if response.status < 200 || response.status >= 300 then
            Output.print_http_response ~json:false response
          else
            match Pds.parse_json_response "_admin/status" response.body with
            | Error reason -> Output.remote_error ~json:false reason
            | Ok json ->
                let describe_body = describe_body ?auth:context.auth pds in
                let service_did = service_did_from_body describe_body in
                Pds.admin_inspection ?service_did ?describe_body ~host:pds json
                |> print_inspection))

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

(** Print one repo row from a listRepos response. *)
let print_repo ?handle repo =
  let did = Option.value ~default:"" (Pds.string_field "did" repo) in
  let rev = Option.value ~default:"" (Pds.string_field "rev" repo) in
  let status = Pds.repo_status_text repo in
  match handle with
  | None -> Fmt.pr "%s\t%s\t%s@." did status rev
  | Some handle -> Fmt.pr "%s\t%s\t%s\t%s@." did status rev handle

(** Run [pds account list] with the shared CLI context. *)
let account_list handles host context =
  match
    Lwt_main.run (Pds.list_all_repos ?auth:context.Cli_context.auth host)
  with
  | Error response -> Output.print_http_response ~json:context.json response
  | Ok repos ->
      if context.json then (
        List.iter Output.print_json_value repos;
        0)
      else if handles then (
        List.iter
          (fun repo ->
            let handle =
              match Pds.string_field "did" repo with
              | None -> None
              | Some did -> Lwt_main.run (Pds.lookup_handle did)
            in
            print_repo ?handle repo)
          repos;
        0)
      else (
        List.iter print_repo repos;
        0)

(** Run [pds account status] with the shared CLI context. *)
let account_status did context =
  match context.Cli_context.pds with
  | None ->
      Output.usage_error ~json:context.Cli_context.json
        "pds account status requires --pds <url>"
  | Some pds -> (
      match Lwt_main.run (Pds.repo_status ?auth:context.auth ~pds ~did ()) with
      | Error reason -> Output.validation_error ~json:context.json reason
      | Ok response -> (
          if context.json then Output.print_http_response ~json:true response
          else if response.status < 200 || response.status >= 300 then
            Output.print_http_response ~json:false response
          else
            match Yojson.Safe.from_string response.body with
            | repo ->
                print_repo repo;
                0
            | exception Yojson.Json_error reason ->
                Output.remote_error ~json:context.json
                  ("getRepoStatus returned invalid JSON: " ^ reason)))

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
