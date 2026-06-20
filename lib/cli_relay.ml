open Cmdliner
open Cmdliner.Term.Syntax

let relay_arg =
  let doc = "Use $(docv) as the relay service URL." in
  Arg.(
    value
    & opt string "https://bsky.network"
    & info [ "relay-host" ] ~docv:"URL" ~doc)

let print_json_line json = Fmt.pr "%s@." (Yojson.Safe.to_string json)

let print_accounts ~json accounts =
  List.iter
    (fun account ->
      if json then print_json_line account
      else
        let did =
          Relay.string_field "did" account |> Option.value ~default:""
        in
        Fmt.pr "%s\t%s\t%s@." did
          (Relay.repo_status_text account)
          (Relay.rev_text account))
    accounts

let print_hosts ~json hosts =
  List.iter
    (fun host ->
      if json then print_json_line host
      else
        Fmt.pr "%s\t%s\t%s\t%s@." (Relay.hostname_text host)
          (Relay.host_status_text host)
          (Relay.account_count_text host)
          (Relay.seq_text host))
    hosts

let account_list relay collection context =
  match
    Lwt_main.run
      (Relay.list_accounts ?auth:context.Cli_context.auth ?collection relay)
  with
  | Error response -> Output.print_http_response ~json:context.json response
  | Ok accounts ->
      print_accounts ~json:context.json accounts;
      0

let account_status relay did context =
  match
    Lwt_main.run
      (Relay.account_status ?auth:context.Cli_context.auth ~relay ~did ())
  with
  | Error reason ->
      Fmt.epr "%s@." reason;
      1
  | Ok response -> Output.print_http_response ~json:context.json response

let host_list relay context =
  match
    Lwt_main.run (Relay.list_hosts ?auth:context.Cli_context.auth relay)
  with
  | Error response -> Output.print_http_response ~json:context.json response
  | Ok hosts ->
      print_hosts ~json:context.json hosts;
      0

let host_status relay hostname context =
  match
    Lwt_main.run
      (Relay.host_status ?auth:context.Cli_context.auth ~relay ~hostname ())
  with
  | Error reason ->
      Fmt.epr "%s@." reason;
      1
  | Ok response -> Output.print_http_response ~json:context.json response

let account_list_cmd =
  let collection =
    Arg.(
      value
      & opt (some string) None
      & info [ "collection"; "c" ] ~docv:"NSID"
          ~doc:"Only list repos containing this collection.")
  in
  let term =
    Cli_context.with_context
      (let+ relay = relay_arg and+ collection = collection in
       account_list relay collection)
  in
  Cmd.v (Cmd.info "list" ~doc:"Enumerate relay accounts.") term

let account_status_cmd =
  let did =
    Arg.(
      required
      & pos 0 (some string) None
      & info [] ~docv:"DID" ~doc:"Account DID.")
  in
  let term =
    Cli_context.with_context
      (let+ relay = relay_arg and+ did = did in
       account_status relay did)
  in
  Cmd.v (Cmd.info "status" ~doc:"Describe relay status for one account.") term

let account_cmd =
  Cmd.group
    (Cmd.info "account" ~doc:"Read-only account/repo relay inspection.")
    [ account_list_cmd; account_status_cmd ]

let host_list_cmd =
  let term =
    Cli_context.with_context
      (let+ relay = relay_arg in
       host_list relay)
  in
  Cmd.v
    (Cmd.info "list" ~doc:"Enumerate upstream hosts indexed by a relay.")
    term

let host_status_cmd =
  let hostname =
    Arg.(
      required
      & pos 0 (some string) None
      & info [] ~docv:"HOSTNAME" ~doc:"Upstream host name.")
  in
  let term =
    Cli_context.with_context
      (let+ relay = relay_arg and+ hostname = hostname in
       host_status relay hostname)
  in
  Cmd.v
    (Cmd.info "status" ~doc:"Describe relay status for one upstream host.")
    term

let host_cmd =
  Cmd.group
    (Cmd.info "host" ~doc:"Read-only upstream host relay inspection.")
    [ host_list_cmd; host_status_cmd ]

let cmd =
  Cmd.group
    (Cmd.info "relay" ~doc:"Read-only relay inspection commands.")
    [ account_cmd; host_cmd ]
