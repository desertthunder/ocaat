(** Output formats supported by the CLI. *)
type t = Markdown | Json | Jsonl | Raw

(** Cmdliner names and their corresponding formats. *)
let all =
  [ ("markdown", Markdown); ("json", Json); ("jsonl", Jsonl); ("raw", Raw) ]

(** Whether a format is intended for machine consumption. *)
let is_machine = function Json | Jsonl -> true | Markdown | Raw -> false

(** Whether a format emits JSON syntax. *)
let is_json = function Json | Jsonl -> true | Markdown | Raw -> false

(** Return the stable command-line spelling of a format. *)
let to_string = function
  | Markdown -> "markdown"
  | Json -> "json"
  | Jsonl -> "jsonl"
  | Raw -> "raw"
