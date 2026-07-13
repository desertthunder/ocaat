(** A small semantic Markdown model used by the shared result renderer. *)

type inline =
  | Text of string
  | Code of string
  | Link of { label : inline list; destination : string }

type field = { label : inline list; value : inline list }
type table = { headers : inline list list; rows : inline list list list }

type block =
  | Heading of int * inline list
  | Paragraph of inline list
  | Fields of field list
  | Table of table
  | Fence of { language : string; body : string }

type t = block list
(** A Markdown document assembled from semantic blocks. *)

let max_summary_fields = 24
let max_table_rows = 20
let max_table_columns = 8
let max_inline_bytes = 240
let max_fence_bytes = 8192

let assoc_field (name : string) (json : Yojson.Safe.t) : Yojson.Safe.t option =
  match json with `Assoc fields -> List.assoc_opt name fields | _ -> None

let string_field name json =
  match assoc_field name json with
  | Some (`String value) -> Some value
  | _ -> None

let safe_prefix value limit =
  if String.length value <= limit then value
  else
    let cut = ref limit in
    while !cut > 0 && Char.code value.[!cut - 1] land 0xC0 = 0x80 do
      decr cut
    done;
    String.sub value 0 !cut ^ "…"

let sanitized_string ?(newlines = false) value =
  let output = Buffer.create (String.length value) in
  String.iter
    (fun character ->
      let code = Char.code character in
      if character = '\n' && newlines then Buffer.add_char output character
      else if character = '\t' && newlines then Buffer.add_char output character
      else if code < 0x20 || code = 0x7F then Buffer.add_char output ' '
      else Buffer.add_char output character)
    value;
  Buffer.contents output

let fence_body value =
  let output = Buffer.create (min max_fence_bytes (String.length value)) in
  let remaining = ref max_fence_bytes in
  String.iter
    (fun character ->
      if !remaining > 0 then (
        let code = Char.code character in
        if character = '\n' || character = '\t' || (code >= 0x20 && code <> 0x7F)
        then Buffer.add_char output character
        else Buffer.add_char output ' ';
        decr remaining))
    value;
  if String.length value > max_fence_bytes then
    Buffer.add_string output "\n[… summary truncated; see Raw …]";
  Buffer.contents output

let complete_code_body value =
  let output = Buffer.create (String.length value) in
  String.iter
    (fun character ->
      let code = Char.code character in
      if character = '\n' || character = '\t' || (code >= 0x20 && code <> 0x7F)
      then Buffer.add_char output character
      else Buffer.add_char output ' ')
    value;
  Buffer.contents output

let is_url value =
  try
    match Uri.scheme (Uri.of_string value) with
    | Some scheme ->
        let scheme = String.lowercase_ascii scheme in
        (scheme = "http" || scheme = "https" || scheme = "mailto")
        && not (Cmarkit.Inline.Link.is_unsafe value)
    | None -> false
  with Invalid_argument _ -> false

let is_protocol_value value =
  let starts prefix = String.starts_with ~prefix value in
  starts "did:" || starts "at://"
  || (String.length value > 20 && (starts "bafk" || starts "Qm" || starts "z"))
  || (String.length value >= 13 && starts "3")

let is_timestamp value =
  String.length value >= 20
  && value.[4] = '-'
  && value.[7] = '-'
  && (String.contains value 'T' || String.contains value 't')

let key_suggests_code key =
  let key = String.lowercase_ascii key in
  List.exists
    (fun suffix ->
      String.equal key suffix
      || String.ends_with ~suffix:("_" ^ suffix) key
      || String.ends_with ~suffix:("." ^ suffix) key)
    [
      "did";
      "uri";
      "cid";
      "rkey";
      "collection";
      "nsid";
      "handle";
      "timestamp";
      "fetched_at";
      "source";
    ]

let scalar_text = function
  | `Null -> "null"
  | `Bool value -> if value then "true" else "false"
  | `Int value -> string_of_int value
  | `Float value -> Yojson.Safe.to_string (`Float value)
  | `Intlit value -> value
  | `String value -> value
  | `List _ | `Assoc _ -> ""

let inline_value ?(key = "") = function
  | `String value ->
      let value = sanitized_string value in
      if is_url value then
        [ Link { label = [ Code value ]; destination = value } ]
      else if
        key_suggests_code key || is_protocol_value value || is_timestamp value
      then [ Code (safe_prefix value max_inline_bytes) ]
      else [ Text (safe_prefix value max_inline_bytes) ]
  | (`Null | `Bool _ | `Int _ | `Float _ | `Intlit _) as value ->
      [ Code (scalar_text value) ]
  | `Assoc fields ->
      [
        Text
          (Printf.sprintf "object with %d field%s" (List.length fields)
             (if List.length fields = 1 then "" else "s"));
      ]
  | `List values ->
      [
        Text
          (Printf.sprintf "array with %d item%s" (List.length values)
             (if List.length values = 1 then "" else "s"));
      ]

let field label value =
  { label = [ Code label ]; value = inline_value ~key:label value }

let scalar json =
  match json with
  | `String _ | `Null | `Bool _ | `Int _ | `Float _ | `Intlit _ -> true
  | `Assoc _ | `List _ -> false

let object_columns rows =
  let keys =
    List.fold_left
      (fun keys row ->
        match row with
        | `Assoc fields ->
            List.fold_left
              (fun keys (key, _) ->
                if List.mem key keys then keys else keys @ [ key ])
              keys fields
        | _ -> keys)
      [] rows
  in
  if List.length keys > max_table_columns then None
  else if
    List.for_all
      (function
        | `Assoc fields -> List.for_all (fun (_, value) -> scalar value) fields
        | _ -> false)
      rows
  then Some keys
  else None

let table_for_objects rows columns =
  let cell key row =
    match row with
    | `Assoc fields -> (
        match List.assoc_opt key fields with
        | Some value -> inline_value ~key value
        | None -> [])
    | _ -> []
  in
  {
    headers = List.map (fun key -> [ Code key ]) columns;
    rows = List.map (fun row -> List.map (fun key -> cell key row) columns) rows;
  }

let table_for_scalars values =
  {
    headers = [ [ Text "Value" ] ];
    rows = List.map (fun value -> [ inline_value value ]) values;
  }

let rec take count values =
  if count <= 0 then []
  else
    match values with
    | [] -> []
    | value :: values -> value :: take (count - 1) values

let array_summary values =
  let shown = take max_table_rows values in
  let omitted = List.length values - List.length shown in
  let omitted_block =
    if omitted <= 0 then []
    else
      [
        Paragraph
          [
            Text
              (Printf.sprintf
                 "%d additional item%s omitted from the summary; see Raw."
                 omitted
                 (if omitted = 1 then " was" else "s were"));
          ];
      ]
  in
  match object_columns shown with
  | Some columns when columns <> [] ->
      [
        Table
          {
            headers = List.map (fun key -> [ Code key ]) columns;
            rows =
              List.map
                (fun row ->
                  match row with
                  | `Assoc fields ->
                      List.map
                        (fun key ->
                          match List.assoc_opt key fields with
                          | Some value -> inline_value ~key value
                          | None -> [])
                        columns
                  | _ -> [])
                shown;
          };
      ]
      @ omitted_block
  | None when List.for_all scalar values && List.length values <= max_table_rows
    ->
      [ Table (table_for_scalars values) ] @ omitted_block
  | _ ->
      [
        Paragraph
          [
            Text
              (Printf.sprintf
                 "Array with %d item%s. See Raw for the complete value."
                 (List.length values)
                 (if List.length values = 1 then "" else "s"));
          ];
      ]

let rec object_summary ?(depth = 0) fields =
  let fields, omitted =
    let visible = take max_summary_fields fields in
    let rest =
      let rec drop count values =
        if count <= 0 then values
        else
          match values with [] -> [] | _ :: values -> drop (count - 1) values
      in
      drop max_summary_fields fields
    in
    (visible, rest)
  in
  let basic, multiline, nested =
    List.fold_left
      (fun (basic, multiline, nested) (key, value) ->
        match value with
        | `String text when String.contains text '\n' ->
            (basic, (key, text) :: multiline, nested)
        | `Assoc nested_fields when depth < 1 ->
            ( basic @ [ field key value ],
              multiline,
              (key, nested_fields) :: nested )
        | _ -> (basic @ [ field key value ], multiline, nested))
      ([], [], []) fields
  in
  let blocks = if basic = [] then [] else [ Fields basic ] in
  let blocks =
    List.fold_left
      (fun blocks (key, text) ->
        blocks
        @ [
            Heading (3, [ Code key ]);
            Fence { language = "markdown"; body = fence_body text };
          ])
      blocks (List.rev multiline)
  in
  let blocks =
    if depth >= 1 then blocks
    else
      List.fold_left
        (fun blocks (key, nested_fields) ->
          blocks
          @ [ Heading (3, [ Code key ]) ]
          @ object_summary ~depth:1 nested_fields)
        blocks (List.rev nested)
  in
  if omitted <> [] then
    blocks
    @ [
        Paragraph
          [
            Text
              (Printf.sprintf
                 "%d additional field%s omitted from the summary; see Raw."
                 (List.length omitted)
                 (if List.length omitted = 1 then " was" else "s were"));
          ];
      ]
  else blocks

let generic_summary ?(depth = 0) data =
  match data with
  | `Assoc fields when fields = [] -> [ Paragraph [ Text "Empty object." ] ]
  | `Assoc fields -> object_summary ~depth fields
  | `List values when values = [] -> [ Paragraph [ Text "Empty array." ] ]
  | `List values -> array_summary values
  | value -> [ Fields [ field "Value" value ] ]

let title_of_kind kind =
  let words =
    kind |> String.split_on_char '_'
    |> List.map (String.split_on_char '-')
    |> List.flatten
  in
  let words =
    List.map
      (fun word -> if word = "" then word else String.capitalize_ascii word)
      words
  in
  match String.concat " " words with "" -> "Result" | title -> title

let lead_of_kind = function
  | "identity" -> "Resolved identity and service evidence."
  | "record" -> "A single AT Protocol record."
  | "records" -> "A bounded collection of protocol records."
  | "plc" -> "PLC directory evidence."
  | "lexicon" -> "Lexicon schema and resolution evidence."
  | "pds" -> "PDS response and operational evidence."
  | "car" -> "Local repository CAR evidence."
  | "doctor" -> "A local validation or diagnostic result."
  | _ -> "Structured result."

let identity_summary data = generic_summary data
let record_summary data = generic_summary data
let records_summary data = generic_summary data
let plc_summary data = generic_summary data
let lexicon_summary data = generic_summary data
let car_summary data = generic_summary data
let doctor_summary data = generic_summary data

let pds_summary data =
  match data with
  | `Assoc fields ->
      let preferred =
        List.filter
          (fun (key, _) ->
            List.mem key
              [
                "status";
                "health";
                "metrics";
                "storage";
                "admin";
                "sequencer";
                "blobStore";
                "hostname";
                "serviceDid";
                "accountCount";
                "repoCount";
                "blobCount";
                "sequencerCursor";
                "configuredCrawlers";
                "storageBackend";
                "adminAuthConfigured";
                "statusCues";
              ])
          fields
      in
      if preferred = [] then generic_summary data else object_summary preferred
  | _ -> generic_summary data

let formatter_for_kind kind =
  match String.lowercase_ascii kind with
  | "identity" -> identity_summary
  | "record" -> record_summary
  | "records" -> records_summary
  | "plc" -> plc_summary
  | "lexicon" -> lexicon_summary
  | "pds" -> pds_summary
  | "car" -> car_summary
  | "doctor" -> doctor_summary
  | _ -> fun data -> generic_summary data

let provenance_fields = function
  | `Assoc fields ->
      List.map
        (fun (label, value) ->
          {
            label = [ Text (String.capitalize_ascii label) ];
            value = inline_value ~key:label value;
          })
        fields
  | _ -> []

let of_envelope ?summary (envelope : Yojson.Safe.t) : t =
  let kind = Option.value (string_field "kind" envelope) ~default:"unknown" in
  let data = Option.value (assoc_field "data" envelope) ~default:`Null in
  let meta = Option.value (assoc_field "meta" envelope) ~default:(`Assoc []) in
  let summary = Option.value summary ~default:data in
  [
    Heading (1, [ Text (title_of_kind kind) ]);
    Paragraph [ Text (lead_of_kind (String.lowercase_ascii kind)) ];
  ]
  @ formatter_for_kind kind summary
  @ [ Heading (2, [ Text "Provenance" ]); Fields (provenance_fields meta) ]
  @ [
      Heading (2, [ Text "Raw" ]);
      Fence { language = "json"; body = Yojson.Safe.pretty_to_string envelope };
    ]

let inline_ast inlines =
  let rec node = function
    | Text value -> Cmarkit.Inline.Text (value, Cmarkit.Meta.none)
    | Code value ->
        Cmarkit.Inline.Code_span
          (Cmarkit.Inline.Code_span.of_string value, Cmarkit.Meta.none)
    | Link { label; destination } ->
        let definition =
          Cmarkit.Link_definition.make
            ~dest:(Cmarkit.Layout.string destination)
            ()
        in
        Cmarkit.Inline.Link
          ( Cmarkit.Inline.Link.make (inline_ast label)
              (`Inline (definition, Cmarkit.Meta.none)),
            Cmarkit.Meta.none )
  and inline_ast values =
    match List.map node values with
    | [] -> Cmarkit.Inline.empty
    | nodes -> Cmarkit.Inline.Inlines (nodes, Cmarkit.Meta.none)
  in
  inline_ast inlines

let field_block fields =
  let items =
    List.map
      (fun { label; value } ->
        let content =
          Cmarkit.Inline.Inlines
            ( [
                inline_ast label;
                Cmarkit.Inline.Text (": ", Cmarkit.Meta.none);
                inline_ast value;
              ],
              Cmarkit.Meta.none )
        in
        ( Cmarkit.Block.List_item.make
            (Cmarkit.Block.Paragraph
               (Cmarkit.Block.Paragraph.make content, Cmarkit.Meta.none)),
          Cmarkit.Meta.none ))
      fields
  in
  Cmarkit.Block.List
    ( Cmarkit.Block.List'.make ~tight:true (`Unordered '-') items,
      Cmarkit.Meta.none )

let table_block { headers; rows } =
  let row kind cells =
    let cells = List.map (fun cell -> (inline_ast cell, ("", ""))) cells in
    (kind cells, Cmarkit.Meta.none)
  in
  let header = (row (fun cells -> `Header cells) headers, "") in
  let separator =
    ( ( `Sep (List.map (fun _ -> ((Some `Left, 3), Cmarkit.Meta.none)) headers),
        Cmarkit.Meta.none ),
      "" )
  in
  let data =
    List.map (fun cells -> (row (fun cells -> `Data cells) cells, "")) rows
  in
  Cmarkit.Block.Ext_table
    (Cmarkit.Block.Table.make (header :: separator :: data), Cmarkit.Meta.none)

let block_ast = function
  | Heading (level, inlines) ->
      Cmarkit.Block.Heading
        ( Cmarkit.Block.Heading.make ~level (inline_ast inlines),
          Cmarkit.Meta.none )
  | Paragraph inlines ->
      Cmarkit.Block.Paragraph
        (Cmarkit.Block.Paragraph.make (inline_ast inlines), Cmarkit.Meta.none)
  | Fields fields -> field_block fields
  | Table table -> table_block table
  | Fence { language; body } ->
      let code = Cmarkit.Block_line.list_of_string (complete_code_body body) in
      Cmarkit.Block.Code_block
        ( Cmarkit.Block.Code_block.make
            ~info_string:(Cmarkit.Layout.string language)
            code,
          Cmarkit.Meta.none )

let to_doc (model : t) =
  let blocks = List.map block_ast model in
  let blocks =
    match blocks with
    | [] -> []
    | first :: rest ->
        List.fold_left
          (fun blocks block ->
            blocks @ [ Cmarkit.Block.Blank_line ("", Cmarkit.Meta.none); block ])
          [ first ] rest
  in
  Cmarkit.Doc.make (Cmarkit.Block.Blocks (blocks, Cmarkit.Meta.none))

let to_string (model : t) =
  let rendered = Cmarkit_commonmark.of_doc (to_doc model) in
  if String.ends_with ~suffix:"\n" rendered then rendered else rendered ^ "\n"
