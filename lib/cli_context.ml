open Cmdliner.Term.Syntax

type verbosity = Quiet | Error | Warning | Info | Debug
type color = Auto | Always | Never

type t = {
  format : Format.t;
  pds : string option;
  auth : string option;
  admin_token : string option;
  yes : bool;
  dry_run : bool;
  force : bool;
}
(** Global settings shared by every command renderer and request path. *)

let level_of_verbosity = function
  | Quiet -> None
  | Error -> Some Logs.Error
  | Warning -> Some Logs.Warning
  | Info -> Some Logs.Info
  | Debug -> Some Logs.Debug

let inferred_verbosity verbose_count =
  if verbose_count <= 0 then Warning
  else if verbose_count = 1 then Info
  else Debug

(** Configure color and the stderr log reporter for one CLI invocation. *)
let setup_log ~style_renderer ~level =
  Fmt_tty.setup_std_outputs ?style_renderer ();
  Logs.set_level level;
  Logs.set_reporter (Logs_fmt.reporter ())

let no_color_default () =
  match Sys.getenv_opt "NO_COLOR" with
  | Some value when value <> "" -> Some `None
  | _ -> None

let env name doc = Cmdliner.Cmd.Env.info name ~doc

let style_renderer_arg =
  let open Cmdliner in
  let color =
    Arg.enum [ ("auto", Auto); ("always", Always); ("never", Never) ]
  in
  let doc =
    "Control ANSI color output. $(b,NO_COLOR) disables default color when set \
     to a non-empty value; an explicit $(b,--color) value overrides it."
  in
  let renderer = function
    | None -> no_color_default ()
    | Some Auto -> None
    | Some Always -> Some `Ansi_tty
    | Some Never -> Some `None
  in
  let+ mode =
    Arg.(value & opt (some color) None & info [ "color" ] ~docv:"WHEN" ~doc)
  in
  renderer mode

let verbosity_arg =
  let open Cmdliner in
  let verbosity =
    Arg.enum
      [
        ("quiet", Quiet);
        ("error", Error);
        ("warning", Warning);
        ("info", Info);
        ("debug", Debug);
      ]
  in
  let doc = "Set log verbosity to $(docv)." in
  Arg.(
    value & opt (some verbosity) None & info [ "verbosity" ] ~docv:"LEVEL" ~doc)

let verbose_arg =
  let open Cmdliner in
  let doc = "Increase log verbosity. Can be used more than once." in
  Arg.(value & flag_all & info [ "v"; "verbose" ] ~doc)

let quiet_arg =
  let open Cmdliner in
  let doc = "Suppress log output." in
  Arg.(value & flag & info [ "q"; "quiet" ] ~doc)

(** Global output format selector. *)
let format_arg =
  let open Cmdliner in
  let doc =
    "Output format: $(docv). Markdown is the default; JSONL is reserved for \
     sequence commands."
  in
  Arg.(
    value
    & opt (enum Format.all) Format.Markdown
    & info [ "format" ] ~docv:"FORMAT" ~doc)

(** Convenience alias for selecting [Format.Json]. *)
let json_arg =
  let open Cmdliner in
  let doc =
    "Write machine-readable JSON output when supported by the command."
  in
  Arg.(value & flag & info [ "json" ] ~doc)

let pds_arg =
  let open Cmdliner in
  let doc = "Use $(docv) as the default PDS service URL." in
  Arg.(
    value
    & opt (some string) None
    & info [ "pds" ] ~docv:"URL" ~doc
        ~env:(env "OCAAT_PDS" "Default PDS service URL."))

let auth_arg =
  let open Cmdliner in
  let doc = "Use $(docv) as a bearer token for authenticated requests." in
  Arg.(
    value
    & opt (some string) None
    & info [ "auth" ] ~docv:"TOKEN" ~doc
        ~env:(env "OCAAT_AUTH" "Default bearer token."))

let admin_token_arg =
  let open Cmdliner in
  let doc = "Use $(docv) as a bearer token for PDS admin requests." in
  Arg.(
    value
    & opt (some string) None
    & info [ "admin-token"; "admin" ] ~docv:"TOKEN" ~doc
        ~env:(env "OCAAT_ADMIN_TOKEN" "Default admin bearer token."))

let yes_arg =
  let open Cmdliner in
  let doc = "Confirm destructive operations without prompting." in
  Arg.(value & flag & info [ "yes"; "y" ] ~doc)

let dry_run_arg =
  let open Cmdliner in
  let doc = "Validate and describe an operation without making changes." in
  Arg.(value & flag & info [ "dry-run" ] ~doc)

let force_arg =
  let open Cmdliner in
  let doc =
    "Overwrite existing artifacts or bypass safety checks when supported."
  in
  Arg.(value & flag & info [ "force"; "f" ] ~doc)

(** Resolve global flags into the immutable command context. *)
let setup_and_make_context style_renderer quiet verbose verbosity format json
    pds auth admin_token yes dry_run force =
  let verbosity =
    if quiet then Quiet
    else
      match verbosity with
      | Some verbosity -> verbosity
      | None -> inferred_verbosity (List.length verbose)
  in
  setup_log ~style_renderer ~level:(level_of_verbosity verbosity);
  let format = if json then Format.Json else format in
  { format; pds; auth; admin_token; yes; dry_run; force }

(** Cmdliner term that assembles global settings and configures logging. *)
let context =
  let+ style_renderer = style_renderer_arg
  and+ quiet = quiet_arg
  and+ verbose = verbose_arg
  and+ verbosity = verbosity_arg
  and+ format = format_arg
  and+ json = json_arg
  and+ pds = pds_arg
  and+ auth = auth_arg
  and+ admin_token = admin_token_arg
  and+ yes = yes_arg
  and+ dry_run = dry_run_arg
  and+ force = force_arg in
  setup_and_make_context style_renderer quiet verbose verbosity format json pds
    auth admin_token yes dry_run force

(** Run a command with global context, rejecting unsupported JSONL output. *)
let with_context term =
  let+ context = context and+ run = term in
  if context.format = Format.Jsonl then
    Output.usage_error ~format:context.format
      "--format jsonl is reserved for sequence commands"
  else run context

(** Configure global logging for commands without a context-aware renderer. *)
let with_setup term =
  let+ _context = context and+ result = term in
  result
