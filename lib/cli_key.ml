open Cmdliner
open Cmdliner.Term.Syntax

let print_generated ~terse key =
  if terse then Fmt.pr "%s@." key.Key.secret_multibase
  else (
    Fmt.pr "Key Type: %s@." (Key.kind_type key.kind);
    Fmt.pr
      "Secret Key (Multibase Syntax): save this securely (eg, add to password \
       manager)@.";
    Fmt.pr "\t%s@." key.secret_multibase;
    Fmt.pr
      "Public Key (DID Key Syntax): share or publish this (eg, in DID \
       document)@.";
    Fmt.pr "\t%s@." key.public_did_key)

let generate kind terse context =
  match Key.generate kind with
  | Error reason ->
      Output.validation_error ~json:context.Cli_context.json
        ("key generation failed: " ^ reason)
  | Ok key ->
      print_generated ~terse key;
      0

let inspect value context =
  match Key.inspect value with
  | Error reason ->
      Output.validation_error ~json:context.Cli_context.json
        ("invalid key: " ^ reason)
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
    Cli_context.with_context
      (let+ value = value in
       inspect value)
  in
  Cmd.v
    (Cmd.info "inspect"
       ~doc:"Parse and output metadata about a public or secret key.")
    term

let generate_cmd =
  let key_type =
    let types =
      [
        ("P-256", Key.P256_private);
        ("p256", Key.P256_private);
        ("ES256", Key.P256_private);
        ("secp256r1", Key.P256_private);
        ("K-256", Key.K256_private);
        ("k256", Key.K256_private);
        ("ES256K", Key.K256_private);
        ("secp256k1", Key.K256_private);
      ]
    in
    Arg.(
      value
      & opt (enum types) Key.P256_private
      & info [ "type"; "t" ] ~docv:"TYPE"
          ~doc:"Curve type to generate. Defaults to P-256.")
  in
  let terse =
    Arg.(
      value & flag
      & info [ "terse" ] ~doc:"Print only the secret key multibase value.")
  in
  let term =
    Cli_context.with_context
      (let+ key_type = key_type and+ terse = terse in
       generate key_type terse)
  in
  Cmd.v (Cmd.info "generate" ~doc:"Create a new secret key.") term

let cmd =
  Cmd.group
    (Cmd.info "key" ~doc:"Cryptographic key inspection and generation commands.")
    [ generate_cmd; inspect_cmd ]
