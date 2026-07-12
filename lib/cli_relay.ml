open Cmdliner
(** Relay read commands and their document renderers. *)

open Cmdliner.Term.Syntax

let relay_arg =
  let doc = "Use $(docv) as the relay service URL." in
  Arg.(
    value
    & opt string "https://bsky.network"
    & info [ "relay-host" ] ~docv:"URL" ~doc)

(** Fetch and render accounts indexed by a relay. *)
let account_list relay collection context =
  match Output.Preflight.require_service_url "relay URL" relay with
  | Error reason ->
      Output.validation_error ~format:context.Cli_context.format reason
  | Ok relay -> (
      match
        Lwt_main.run
          (Relay.list_accounts ?auth:context.Cli_context.auth ?collection relay)
      with
      | Error response ->
          Output.print_http_response ~kind:"records" ~source:"relay"
            ~endpoint:(Relay.list_repos_url ?collection relay)
            ~format:context.Cli_context.format response
      | Ok accounts ->
          let document =
            Document.make ~source:"relay"
              ~endpoint:(Relay.list_repos_url ?collection relay)
              ~kind:"records" (`List accounts)
          in
          Renderer.print_stdout
            (Renderer.document context.Cli_context.format document);
          0)

(** Fetch and render the relay's status for one DID. *)
let account_status relay did context =
  match Output.Preflight.require_service_url "relay URL" relay with
  | Error reason ->
      Output.validation_error ~format:context.Cli_context.format reason
  | Ok relay -> (
      match
        Lwt_main.run
          (Relay.account_status ?auth:context.Cli_context.auth ~relay ~did ())
      with
      | Error reason ->
          Output.validation_error ~format:context.Cli_context.format reason
      | Ok response ->
          Output.print_http_response ~kind:"pds" ~source:"relay"
            ~endpoint:(Relay.repo_status_url relay did)
            ~did ~format:context.Cli_context.format response)

(** Fetch and render the relay's indexed host list. *)
let host_list relay context =
  match Output.Preflight.require_service_url "relay URL" relay with
  | Error reason ->
      Output.validation_error ~format:context.Cli_context.format reason
  | Ok relay -> (
      match
        Lwt_main.run (Relay.list_hosts ?auth:context.Cli_context.auth relay)
      with
      | Error response ->
          Output.print_http_response ~kind:"records" ~source:"relay"
            ~endpoint:(Relay.list_hosts_url relay)
            ~format:context.Cli_context.format response
      | Ok hosts ->
          let document =
            Document.make ~source:"relay"
              ~endpoint:(Relay.list_hosts_url relay)
              ~kind:"records" (`List hosts)
          in
          Renderer.print_stdout
            (Renderer.document context.Cli_context.format document);
          0)

(** Fetch and render the relay's status for one upstream hostname. *)
let host_status relay hostname context =
  match Output.Preflight.require_service_url "relay URL" relay with
  | Error reason ->
      Output.validation_error ~format:context.Cli_context.format reason
  | Ok relay -> (
      match
        Lwt_main.run
          (Relay.host_status ?auth:context.Cli_context.auth ~relay ~hostname ())
      with
      | Error reason ->
          Output.validation_error ~format:context.Cli_context.format reason
      | Ok response ->
          Output.print_http_response ~kind:"pds" ~source:"relay"
            ~endpoint:(Relay.host_status_url relay hostname)
            ~format:context.Cli_context.format response)

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
