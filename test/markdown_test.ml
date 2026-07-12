let fail message = raise (Failure message)
let assert_true label condition = if not condition then fail label
let assert_equal label expected actual = if expected <> actual then fail label

let contains needle value =
  let rec loop index =
    if index + String.length needle > String.length value then false
    else if String.sub value index (String.length needle) = needle then true
    else loop (index + 1)
  in
  needle = "" || loop 0

let assert_contains label needle value =
  if not (contains needle value) then fail label

let blocks markdown =
  match
    Cmarkit.Block.normalize
      (Cmarkit.Doc.block (Cmarkit.Doc.of_string ~strict:false markdown))
  with
  | Cmarkit.Block.Blocks (blocks, _) -> blocks
  | block -> [ block ]

let heading_text = function
  | Cmarkit.Block.Heading (heading, _) ->
      Some
        (Cmarkit.Inline.to_plain_text ~break_on_soft:false
           (Cmarkit.Block.Heading.inline heading)
        |> List.map (String.concat "")
        |> String.concat "\n")
  | _ -> None

let has_heading expected blocks =
  List.exists (fun block -> heading_text block = Some expected) blocks

let code_blocks blocks =
  List.filter_map
    (function
      | Cmarkit.Block.Code_block (code, _) ->
          Some
            (Cmarkit.Block.Code_block.code code
            |> List.map Cmarkit.Block_line.to_string
            |> String.concat "\n")
      | _ -> None)
    blocks

let has_table blocks =
  List.exists (function Cmarkit.Block.Ext_table _ -> true | _ -> false) blocks

let render kind data =
  let document =
    Ocaat__Document.make ~source:"fixture" ~endpoint:"https://pds.example" ~kind
      data
  in
  Ocaat__Renderer.document Ocaat__Format.Markdown document

let sample_data =
  `Assoc
    [
      ("id", `String "did:plc:example");
      ("name", `String "A *value* with | pipes and <html>");
      ("url", `String "https://example.test/a_(b)");
      ("authorization", `String "secret-value");
    ]

let () =
  let kinds =
    [
      "identity"; "record"; "records"; "plc"; "lexicon"; "pds"; "car"; "doctor";
    ]
  in
  List.iter
    (fun kind ->
      let markdown = render kind sample_data in
      let parsed = blocks markdown in
      assert_true (kind ^ " heading")
        (has_heading (String.capitalize_ascii kind) parsed);
      assert_true
        (kind ^ " provenance heading")
        (has_heading "Provenance" parsed);
      assert_true (kind ^ " raw heading") (has_heading "Raw" parsed);
      assert_true (kind ^ " raw envelope")
        (List.exists
           (fun code ->
             assert_contains (kind ^ " schema") "ocaat.document.v1" code;
             assert_contains (kind ^ " redaction") "[REDACTED]" code;
             not (contains "secret-value" code))
           (code_blocks parsed)))
    kinds;

  let records =
    `List
      [
        `Assoc [ ("id", `Int 1); ("name", `String "one") ];
        `Assoc [ ("id", `Int 2); ("name", `String "two") ];
      ]
  in
  let records_markdown = render "records" records in
  assert_true records_markdown (has_table (blocks records_markdown));

  let hostile =
    `Assoc
      [
        ( "description",
          `String "line one\n# forged heading\n```\n| forged | table |" );
        ("html", `String "<script>alert(1)</script>");
        ("pipe", `String "| not a table | and `not code`|");
      ]
  in
  let hostile_markdown = render "unknown_kind" hostile in
  let hostile_blocks = blocks hostile_markdown in
  assert_true "hostile content is not a heading"
    (not (has_heading "forged heading" hostile_blocks));
  assert_true "hostile content is fenced as data"
    (List.exists
       (fun code ->
         assert_contains "hostile fence content" "forged heading" code;
         true)
       (code_blocks hostile_blocks));
  assert_true "unknown shape has raw envelope"
    (List.exists
       (fun code -> contains "unknown_kind" code)
       (code_blocks hostile_blocks));

  let document =
    Ocaat__Document.make ~source:"fixture" ~endpoint:"local" ~kind:"doctor"
      (`Assoc [ ("ok", `Bool true); ("token", `String "secret") ])
  in
  let envelope = Ocaat__Redaction.json (Ocaat__Document.to_json document) in
  assert_equal "JSON renderer remains unchanged"
    (Yojson.Safe.pretty_to_string envelope ^ "\n")
    (Ocaat__Renderer.document Ocaat__Format.Json document);
  assert_equal "JSONL renderer remains unchanged"
    (Yojson.Safe.to_string envelope ^ "\n")
    (Ocaat__Renderer.document Ocaat__Format.Jsonl document);
  assert_equal "raw renderer remains unchanged"
    (Yojson.Safe.to_string (Yojson.Safe.Util.member "data" envelope) ^ "\n")
    (Ocaat__Renderer.document Ocaat__Format.Raw document)
