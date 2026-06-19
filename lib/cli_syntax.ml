open Cmdliner
module At_syntax = Syntax
open Cmdliner.Term.Syntax
module Log = (val Logs.src_log (Logs.Src.create "ocaat.syntax") : Logs.LOG)

let check kind value =
  Log.debug (fun m -> m "checking %s syntax for %S" kind value);
  match At_syntax.validate kind value with
  | At_syntax.Valid ->
      Fmt.pr "valid %s: %s@." kind value;
      0
  | At_syntax.Invalid reason ->
      Fmt.epr "invalid %s: %s (%s)@." kind value reason;
      1

let check_cmd kind =
  let value =
    let doc = Printf.sprintf "%s value to validate." kind in
    Arg.(required & pos 0 (some string) None & info [] ~docv:"VALUE" ~doc)
  in
  let term =
    Cli_context.with_setup
      (let+ value = value in
       check kind value)
  in
  let info =
    Cmd.info "check" ~doc:(Printf.sprintf "Validate %s syntax." kind)
  in
  Cmd.v info term

let tid_generate_cmd =
  let term =
    Cli_context.with_setup
      Term.(
        const (fun () ->
            Fmt.pr "%s@." (At_syntax.generate_tid ());
            0)
        $ const ())
  in
  let info = Cmd.info "generate" ~doc:"Generate a TID." in
  Cmd.v info term

let datetime_now_cmd =
  let term =
    Cli_context.with_setup
      Term.(
        const (fun () ->
            Fmt.pr "%s@." (At_syntax.datetime_now ());
            0)
        $ const ())
  in
  let info = Cmd.info "now" ~doc:"Print the current AT Protocol datetime." in
  Cmd.v info term

let kind_cmd kind commands =
  let info = Cmd.info kind ~doc:(Printf.sprintf "%s syntax helpers." kind) in
  Cmd.group info commands

let cmd =
  let info = Cmd.info "syntax" ~doc:"AT Protocol syntax helpers." in
  Cmd.group info
    [
      kind_cmd "handle" [ check_cmd "handle" ];
      kind_cmd "did" [ check_cmd "did" ];
      kind_cmd "nsid" [ check_cmd "nsid" ];
      kind_cmd "at-uri" [ check_cmd "at-uri" ];
      kind_cmd "rkey" [ check_cmd "rkey" ];
      kind_cmd "cid" [ check_cmd "cid" ];
      kind_cmd "tid" [ check_cmd "tid"; tid_generate_cmd ];
      kind_cmd "datetime" [ datetime_now_cmd; check_cmd "datetime" ];
    ]
