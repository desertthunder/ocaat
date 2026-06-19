open Cmdliner.Term.Syntax

let setup_log ~style_renderer ~level =
  Fmt_tty.setup_std_outputs ?style_renderer ();
  Logs.set_level level;
  Logs.set_reporter (Logs_fmt.reporter ())

let with_setup term =
  let+ style_renderer = Fmt_cli.style_renderer ()
  and+ level = Logs_cli.level ()
  and+ result = term in
  setup_log ~style_renderer ~level;
  result
