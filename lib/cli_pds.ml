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
  | None -> Output.usage_error ~json:context.Cli_context.json "pds account status requires --pds <url>"
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
  Cmd.group info [ describe_cmd; account_cmd ]
