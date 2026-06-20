open Cmdliner.Term.Syntax

type verbosity = Quiet | Error | Warning | Info | Debug
type color = Auto | Always | Never
type t = { json : bool; pds : string option; auth : string option }

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

let setup_log ~style_renderer ~level =
  Fmt_tty.setup_std_outputs ?style_renderer ();
  Logs.set_level level;
  Logs.set_reporter (Logs_fmt.reporter ())

let no_color_default () =
  match Sys.getenv_opt "NO_COLOR" with
  | Some value when value <> "" -> Some `None
  | _ -> None

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

let json_arg =
  let open Cmdliner in
  let doc =
    "Write machine-readable JSON output when supported by the command."
  in
  Arg.(value & flag & info [ "json" ] ~doc)

let pds_arg =
  let open Cmdliner in
  let doc = "Use $(docv) as the default PDS service URL." in
  Arg.(value & opt (some string) None & info [ "pds" ] ~docv:"URL" ~doc)

let auth_arg =
  let open Cmdliner in
  let doc = "Use $(docv) as a bearer token for authenticated requests." in
  Arg.(value & opt (some string) None & info [ "auth" ] ~docv:"TOKEN" ~doc)

let context =
  let+ style_renderer = style_renderer_arg
  and+ quiet = quiet_arg
  and+ verbose = verbose_arg
  and+ verbosity = verbosity_arg
  and+ json = json_arg
  and+ pds = pds_arg
  and+ auth = auth_arg in
  let verbosity =
    if quiet then Quiet
    else
      match verbosity with
      | Some verbosity -> verbosity
      | None -> inferred_verbosity (List.length verbose)
  in
  setup_log ~style_renderer ~level:(level_of_verbosity verbosity);
  { json; pds; auth }

let with_context term =
  let+ context = context and+ run = term in
  run context

let with_setup term =
  let+ style_renderer = style_renderer_arg
  and+ quiet = quiet_arg
  and+ verbose = verbose_arg
  and+ verbosity = verbosity_arg
  and+ _json = json_arg
  and+ _pds = pds_arg
  and+ _auth = auth_arg
  and+ result = term in
  let verbosity =
    if quiet then Quiet
    else
      match verbosity with
      | Some verbosity -> verbosity
      | None -> inferred_verbosity (List.length verbose)
  in
  setup_log ~style_renderer ~level:(level_of_verbosity verbosity);
  result
