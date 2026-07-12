open Cmdliner
(** Key inspection and generation commands using the shared renderer. *)

open Cmdliner.Term.Syntax

(** Convert generated key metadata to a local result document. *)
let generated_document (key : Key.generated) =
  Document.make ~source:"local" ~endpoint:"local" ~kind:"doctor"
    (`Assoc
       [
         ("operation", `String "generate");
         ("type", `String (Key.kind_type key.kind));
         ("secretMultibase", `String key.secret_multibase);
         ("publicDidKey", `String key.public_did_key);
       ])

(** Convert inspected key metadata to a local result document. *)
let inspected_document (key : Key.inspected) =
  let fields =
    [
      ("operation", `String "inspect");
      ("type", `String (Key.kind_type key.kind));
      ( "encoding",
        `String
          (match key.encoding with
          | `Multibase -> "multibase"
          | `Did_key -> "did-key") );
      ("multibase", `String key.multibase);
    ]
  in
  let fields =
    match key.did_key with
    | None -> fields
    | Some value -> fields @ [ ("didKey", `String value) ]
  in
  Document.make ~source:"local" ~endpoint:"local" ~kind:"doctor" (`Assoc fields)

(** Generate a key and render its local result document. *)
let generate kind _terse context =
  match Key.generate kind with
  | Error reason ->
      Output.validation_error ~format:context.Cli_context.format
        ("key generation failed: " ^ reason)
  | Ok key ->
      Renderer.print_stdout
        (Renderer.document context.Cli_context.format (generated_document key));
      0

(** Inspect a public or secret key and render its metadata. *)
let inspect value context =
  match Key.inspect value with
  | Error reason ->
      Output.validation_error ~format:context.Cli_context.format
        ("invalid key: " ^ reason)
  | Ok key ->
      Renderer.print_stdout
        (Renderer.document context.Cli_context.format (inspected_document key));
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
