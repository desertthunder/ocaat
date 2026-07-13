(** Serialize JSON for a human-readable or compact output channel. *)
let json_string ?(pretty = false) json =
  if pretty then Yojson.Safe.pretty_to_string json
  else Yojson.Safe.to_string json

(** Render a result document as Markdown without dropping its metadata. *)
let markdown document =
  let envelope = Redaction.json (Document.to_json document) in
  let summary = Option.map Redaction.json document.Document.summary in
  Markdown.to_string (Markdown.of_envelope ?summary envelope)

(** Render a result document in the selected format. *)
let document format document =
  let json = Redaction.json (Document.to_json document) in
  match format with
  | Format.Markdown -> markdown document
  | Format.Json -> json_string ~pretty:true json ^ "\n"
  | Format.Jsonl -> json_string json ^ "\n"
  | Format.Raw -> json_string (Redaction.json document.Document.data) ^ "\n"

(** Render an explicit raw payload while applying credential redaction. *)
let raw body =
  Redaction.body body ^ if String.ends_with ~suffix:"\n" body then "" else "\n"

(** Render an error for stderr in the selected format. *)
let error format error =
  let json = Redaction.json (Error_document.to_json error) in
  match format with
  | Format.Json | Format.Jsonl -> json_string json ^ "\n"
  | Format.Markdown | Format.Raw ->
      let status_text =
        match error.Error_document.status with
        | None -> ""
        | Some status -> Printf.sprintf " (HTTP %d)" status
      in
      Printf.sprintf "error: %s%s: %s\n" error.kind status_text error.message

(** Write a primary result to stdout and flush it. *)
let print_stdout value =
  output_string stdout value;
  flush stdout

(** Write a diagnostic or progress message to stderr and flush it. *)
let print_stderr value =
  output_string stderr value;
  flush stderr
