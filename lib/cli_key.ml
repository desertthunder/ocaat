open Cmdliner
open Cmdliner.Term.Syntax

let inspect value =
  match Key.inspect value with
  | Error reason ->
      Fmt.epr "invalid key: %s@." reason;
      1
  | Ok key ->
      Fmt.pr "Type: %s@." (Key.kind_type key.kind);
      Fmt.pr "Encoding: %s@."
        (match key.encoding with
        | `Multibase -> "multibase"
        | `Did_key -> "DID Key");
      (match key.kind with
      | P256_public | K256_public ->
          Option.iter (Fmt.pr "As DID Key: %s@.") key.did_key;
          Fmt.pr "As Multibase: %s@." key.multibase
      | P256_private | K256_private -> (
          Fmt.pr "Secret Key (Multibase Syntax): %s@." key.multibase;
          match key.did_key with
          | Some did_key -> Fmt.pr "Public Key (DID Key Syntax): %s@." did_key
          | None -> Fmt.pr "Public Key (DID Key Syntax): unavailable@."));
      0

let inspect_cmd =
  let value =
    Arg.(
      required
      & pos 0 (some string) None
      & info [] ~docv:"KEY" ~doc:"Public or secret key to inspect.")
  in
  let term =
    Cli_context.with_setup
      (let+ value = value in
       inspect value)
  in
  Cmd.v
    (Cmd.info "inspect"
       ~doc:"Parse and output metadata about a public or secret key.")
    term

let cmd =
  Cmd.group
    (Cmd.info "key" ~doc:"Read-only cryptographic key inspection commands.")
    [ inspect_cmd ]
