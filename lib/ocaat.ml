let version = "0.1.0"

module Log = (val Logs.src_log (Logs.Src.create "ocaat") : Logs.LOG)

type check =
  | Valid
  | Invalid of string

let is_alpha = function
  | 'a' .. 'z' | 'A' .. 'Z' -> true
  | _ -> false

let is_digit = function
  | '0' .. '9' -> true
  | _ -> false

let is_alnum c = is_alpha c || is_digit c

let starts_with ~prefix value =
  let prefix_len = String.length prefix in
  String.length value >= prefix_len && String.sub value 0 prefix_len = prefix

let contains_char needle value =
  let rec loop index =
    index < String.length value && (value.[index] = needle || loop (index + 1))
  in
  loop 0

let split_on_char needle value =
  let rec loop start index acc =
    if index = String.length value then
      List.rev (String.sub value start (index - start) :: acc)
    else if value.[index] = needle then
      loop (index + 1) (index + 1) (String.sub value start (index - start) :: acc)
    else
      loop start (index + 1) acc
  in
  loop 0 0 []

let validate_dns_label label =
  let len = String.length label in
  if len = 0 then Invalid "empty DNS label"
  else if len > 63 then Invalid "DNS label is longer than 63 characters"
  else if label.[0] = '-' || label.[len - 1] = '-' then
    Invalid "DNS label cannot start or end with '-'"
  else
    let rec loop index =
      if index = len then Valid
      else
        let c = label.[index] in
        if is_alnum c || c = '-' then loop (index + 1)
        else Invalid "DNS label contains an invalid character"
    in
    loop 0

let validate_handle value =
  let len = String.length value in
  if len < 3 then Invalid "handle is too short"
  else if len > 253 then Invalid "handle is longer than 253 characters"
  else if not (contains_char '.' value) then Invalid "handle must contain at least one '.'"
  else
    let rec loop = function
      | [] -> Valid
      | label :: rest -> (
          match validate_dns_label label with
          | Valid -> loop rest
          | Invalid reason -> Invalid reason)
    in
    loop (split_on_char '.' value)

let validate_did value =
  if not (starts_with ~prefix:"did:" value) then Invalid "DID must start with did:"
  else
    match split_on_char ':' value with
    | [ "did"; method_; identifier ] when method_ <> "" && identifier <> "" -> Valid
    | _ -> Invalid "DID must have did:<method>:<identifier> shape"

let validate_nsid_part part =
  let len = String.length part in
  if len = 0 then Invalid "empty NSID segment"
  else if not (is_alpha part.[0]) then Invalid "NSID segments must start with a letter"
  else
    let rec loop index =
      if index = len then Valid
      else
        let c = part.[index] in
        if is_alnum c || c = '-' then loop (index + 1)
        else Invalid "NSID segment contains an invalid character"
    in
    loop 0

let validate_nsid value =
  match split_on_char '.' value with
  | _ :: _ :: _ as parts ->
      let rec loop = function
        | [] -> Valid
        | part :: rest -> (
            match validate_nsid_part part with
            | Valid -> loop rest
            | Invalid reason -> Invalid reason)
      in
      loop parts
  | _ -> Invalid "NSID must contain at least three dot-separated segments"

let validate_at_uri value =
  if not (starts_with ~prefix:"at://" value) then Invalid "AT URI must start with at://"
  else
    let path = String.sub value 5 (String.length value - 5) in
    match split_on_char '/' path with
    | authority :: [] when authority <> "" -> Valid
    | authority :: collection :: rkey :: _ when authority <> "" && collection <> "" && rkey <> "" -> (
        match validate_nsid collection with
        | Valid -> Valid
        | Invalid reason -> Invalid ("collection NSID is invalid: " ^ reason))
    | _ -> Invalid "AT URI must include an authority and optional collection/rkey path"

module Http = struct
  type response =
    { status : int
    ; body : string
    }

  let get_text url =
    let open Lwt.Syntax in
    let uri = Uri.of_string url in
    let* response, body = Cohttp_lwt_unix.Client.get uri in
    let status = Cohttp.Response.status response |> Cohttp.Code.code_of_status in
    let+ body = Cohttp_lwt.Body.to_string body in
    { status; body }
end

let setup_log ~style_renderer ~level =
  Fmt_tty.setup_std_outputs ?style_renderer ();
  Logs.set_level level;
  Logs.set_reporter (Logs_fmt.reporter ())

let pp_lines lines =
  List.iter (Fmt.pr "%s@.") lines

let print_tempest_defaults () =
  pp_lines
    [ "Tempest defaults used by the migration helper:"
    ; "  TEMPEST=https://tempest.desertthunder.dev"
    ; "  TEMPEST_SERVICE_DID=did:web:tempest.desertthunder.dev"
    ; "  ARTIFACT_DIR=.sandbox"
    ; ""
    ; "Future HTTP commands will read these from the environment."
    ]

let print_migration_plan () =
  pp_lines
    [ "Tempest account migration plan:"
    ; "  1. Login to the source PDS and save the source session."
    ; "  2. Request service auth for com.atproto.server.createAccount."
    ; "  3. Export the source repo CAR."
    ; "  4. List and download source blobs."
    ; "  5. Create the inactive existing-DID account on Tempest."
    ; "  6. Import the CAR into Tempest."
    ; "  7. Upload missing blobs."
    ; "  8. Update did:plc or did:web identity so #atproto_pds points at Tempest."
    ; "  9. Activate only after Tempest reports migrationReady=true."
    ]

let check_syntax kind value =
  Log.debug (fun m -> m "checking %s syntax for %S" kind value);
  let result =
    match kind with
    | "handle" -> validate_handle value
    | "did" -> validate_did value
    | "nsid" -> validate_nsid value
    | "at-uri" -> validate_at_uri value
    | _ -> Invalid ("unknown syntax kind: " ^ kind)
  in
  match result with
  | Valid ->
      Fmt.pr "valid %s: %s@." kind value;
      0
  | Invalid reason ->
      Fmt.epr "invalid %s: %s (%s)@." kind value reason;
      1

open Cmdliner
open Cmdliner.Term.Syntax

let with_setup term =
  let+ style_renderer = Fmt_cli.style_renderer ()
  and+ level = Logs_cli.level () 
  and+ result = term in
  setup_log ~style_renderer ~level;
  result

let version_cmd =
  let term = with_setup Term.(const (fun () -> Fmt.pr "%s@." version; 0) $ const ()) in
  let info = Cmd.info "version" ~doc:"Print the ocaat version." in
  Cmd.v info term

let tempest_defaults_cmd =
  let term = with_setup Term.(const (fun () -> print_tempest_defaults (); 0) $ const ()) in
  let info = Cmd.info "defaults" ~doc:"Print default Tempest-related environment values." in
  Cmd.v info term

let tempest_migration_plan_cmd =
  let term = with_setup Term.(const (fun () -> print_migration_plan (); 0) $ const ()) in
  let info = Cmd.info "migration-plan" ~doc:"Print the Tempest account migration sequence." in
  Cmd.v info term

let tempest_cmd =
  let info = Cmd.info "tempest" ~doc:"Tempest PDS helper commands." in
  Cmd.group info [ tempest_defaults_cmd; tempest_migration_plan_cmd ]

let syntax_check_cmd kind =
  let value =
    let doc = Printf.sprintf "%s value to validate." kind in
    Arg.(required & pos 0 (some string) None & info [] ~docv:"VALUE" ~doc)
  in
  let term =
    with_setup
      (let+ value = value in
       check_syntax kind value)
  in
  let info = Cmd.info "check" ~doc:(Printf.sprintf "Validate %s syntax." kind) in
  Cmd.v info term

let syntax_kind_cmd kind =
  let info = Cmd.info kind ~doc:(Printf.sprintf "%s syntax helpers." kind) in
  Cmd.group info [ syntax_check_cmd kind ]

let syntax_cmd =
  let info = Cmd.info "syntax" ~doc:"AT Protocol syntax helpers." in
  Cmd.group info
    [ syntax_kind_cmd "handle"
    ; syntax_kind_cmd "did"
    ; syntax_kind_cmd "nsid"
    ; syntax_kind_cmd "at-uri"
    ]

let root_cmd =
  let doc = "OCaml AT Protocol CLI for operating a Tempest PDS." in
  let info = Cmd.info "ocaat" ~version ~doc in
  Cmd.group info [ version_cmd; tempest_cmd; syntax_cmd ]

let main ?argv () = Cmd.eval' ?argv root_cmd
