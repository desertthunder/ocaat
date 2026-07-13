(** Network-published Lexicon resolution and description. *)

type failure =
  | Validation of string
  | Network of string
  | Remote of int option * string
      (** Failure categories used by Lexicon commands. *)

type query = {
  nsid : string;
  authority : string;
  did : string;
  pds : string;
  endpoint : string;
  record_uri : string;
  response : Http.response;
  document : Yojson.Safe.t;
  sources : Document.source_evidence list;
}
(** A validated Lexicon record and the sources used to resolve it. *)

type method_kind =
  | Query
  | Procedure
  | Subscription
  | Record
  | Other of string
      (** Primary Lexicon definition kinds relevant to XRPC descriptions. *)

type description = {
  query : query;
  definition_name : string;
  definition : Yojson.Safe.t;
  method_kind : method_kind;
}
(** The selected primary definition from a validated Lexicon. *)

let schema_collection = "com.atproto.lexicon.schema"
let max_response_bytes = 1024 * 1024
let timeout_seconds = 5.0
let max_dns_output_bytes = 64 * 1024

let json_field name = function
  | `Assoc fields -> List.assoc_opt name fields
  | _ -> None

let string_field name json =
  match json_field name json with
  | Some (`String value) -> Some value
  | _ -> None

let response_detail endpoint (response : Http.response) =
  let detail =
    if response.body = "" then "empty response body"
    else Redaction.body response.body
  in
  endpoint ^ ": " ^ detail

let authority_of_nsid nsid =
  match Syntax.validate_nsid nsid with
  | Syntax.Invalid reason ->
      Error (Validation ("invalid Lexicon NSID: " ^ reason))
  | Syntax.Valid -> (
      match List.rev (String.split_on_char '.' nsid) with
      | _name :: reversed_authority -> Ok (String.concat "." reversed_authority)
      | [] -> Error (Validation "invalid Lexicon NSID: empty identifier"))

let quoted_txt_value line =
  let line = String.trim line in
  let output = Buffer.create (String.length line) in
  let rec loop index quoted =
    if index = String.length line then
      if quoted then None else Some (Buffer.contents output)
    else if line.[index] = '"' then loop (index + 1) (not quoted)
    else if quoted && line.[index] = '\\' && index + 1 < String.length line then (
      Buffer.add_char output line.[index + 1];
      loop (index + 2) quoted)
    else if quoted then (
      Buffer.add_char output line.[index];
      loop (index + 1) quoted)
    else loop (index + 1) quoted
  in
  match loop 0 false with
  | Some value when value <> "" -> Some value
  | Some _ -> Some line
  | None -> None

let dns_did_from_line line =
  match quoted_txt_value line with
  | Some value when String.starts_with ~prefix:"did=" value -> (
      let did = String.sub value 4 (String.length value - 4) in
      match Syntax.validate_did did with
      | Syntax.Valid -> Some did
      | Syntax.Invalid _ -> None)
  | _ -> None

let read_dns_lines channel =
  let rec loop acc total =
    match input_line channel with
    | line ->
        let total = total + String.length line + 1 in
        if total > max_dns_output_bytes then
          Error
            (Printf.sprintf "DNS response exceeded the %d-byte limit"
               max_dns_output_bytes)
        else loop (line :: acc) total
    | exception End_of_file -> Ok (List.rev acc)
  in
  loop [] 0

let dns_txt name =
  try
    let channel =
      Unix.open_process_args_in "dig"
        [| "dig"; "+short"; "+time=3"; "+tries=1"; "TXT"; name |]
    in
    let lines_result = read_dns_lines channel in
    let status = Unix.close_process_in channel in
    match (lines_result, status) with
    | Error reason, _ -> Error reason
    | Ok _, (Unix.WEXITED status | Unix.WSIGNALED status | Unix.WSTOPPED status)
      when status <> 0 ->
        Ok []
    | Ok lines, _ -> Ok lines
  with Sys_error reason | Unix.Unix_error (_, reason, _) ->
    Error ("could not execute DNS lookup: " ^ reason)

let dns_authority authority =
  let name = "_lexicon." ^ authority in
  match dns_txt name with
  | Error reason ->
      Error
        (Network
           (Printf.sprintf "lexicon DNS authority lookup %s failed: %s" name
              reason))
  | Ok lines -> (
      let dids =
        List.filter_map dns_did_from_line lines |> List.sort_uniq String.compare
      in
      match dids with
      | [ did ] -> Ok (did, "dns://" ^ name)
      | [] ->
          Error
            (Network
               (Printf.sprintf
                  "lexicon DNS authority lookup %s returned no valid DID" name))
      | _ ->
          Error
            (Network
               (Printf.sprintf
                  "lexicon DNS authority lookup %s returned multiple DIDs" name))
      )

let prefixed_failure stage = function
  | Identity.Validation reason -> Validation (stage ^ ": " ^ reason)
  | Identity.Network reason -> Network (stage ^ ": " ^ reason)
  | Identity.Remote (status, reason) -> Remote (status, stage ^ ": " ^ reason)

let resolve_did did =
  match Identity.did_document_url did with
  | Error reason ->
      Lwt.return (Error (Validation ("lexicon DID resolution: " ^ reason)))
  | Ok (endpoint, _) -> (
      let open Lwt.Syntax in
      let+ response =
        Http.get_text_limited ~max_bytes:max_response_bytes ~timeout_seconds
          endpoint
      in
      match Identity.parse_did_document ~did ~endpoint response with
      | Ok resolved -> Ok (endpoint, resolved)
      | Error error -> Error (prefixed_failure "lexicon DID resolution" error))

let record_url ~pds ~did ~nsid =
  Http.xrpc_url ~base_url:pds ~method_:"com.atproto.repo.getRecord"
    ~params:[ ("repo", did); ("collection", schema_collection); ("rkey", nsid) ]

let expected_record_uri ~did ~nsid =
  "at://" ^ did ^ "/" ^ schema_collection ^ "/" ^ nsid

let validate_definition name definition =
  match (name, definition, string_field "type" definition) with
  | "", _, _ -> Error "Lexicon definition name is empty"
  | _, `Assoc _, Some _ -> Ok ()
  | _, _, _ -> Error ("Lexicon definition " ^ name ^ " is missing a type")

let validate_schema ~endpoint ~nsid value =
  match value with
  | `Assoc fields -> (
      match (List.assoc_opt "lexicon" fields, List.assoc_opt "id" fields) with
      | Some (`Int 1), Some (`String id) when id = nsid -> (
          let type_result =
            match List.assoc_opt "$type" fields with
            | Some (`String value) when value = schema_collection -> Ok ()
            | Some _ ->
                Error
                  (endpoint ^ " returned a Lexicon record with the wrong $type")
            | None ->
                Error (endpoint ^ " returned a Lexicon record without $type")
          in
          match type_result with
          | Error reason -> Error reason
          | Ok () -> (
              match List.assoc_opt "defs" fields with
              | Some (`Assoc definitions) when definitions <> [] -> (
                  let rec validate = function
                    | [] -> Ok ()
                    | (name, definition) :: rest -> (
                        match validate_definition name definition with
                        | Error reason ->
                            Error (endpoint ^ " returned " ^ reason)
                        | Ok () -> validate rest)
                  in
                  match validate definitions with
                  | Error reason -> Error reason
                  | Ok () -> Ok value)
              | Some (`Assoc _) ->
                  Error (endpoint ^ " returned a Lexicon with no definitions")
              | _ ->
                  Error (endpoint ^ " returned a Lexicon without a defs object")
              ))
      | Some _, Some (`String _) ->
          Error (endpoint ^ " returned Lexicon version other than 1")
      | Some _, _ -> Error (endpoint ^ " returned a Lexicon with an invalid id")
      | None, _ ->
          Error (endpoint ^ " returned a Lexicon without lexicon version"))
  | _ -> Error (endpoint ^ " returned a Lexicon that is not a JSON object")

let parse_record_response ~endpoint ~did ~nsid body =
  match Yojson.Safe.from_string body with
  | exception Yojson.Json_error reason ->
      Error (endpoint ^ " returned invalid JSON: " ^ reason)
  | `Assoc fields -> (
      match (List.assoc_opt "uri" fields, List.assoc_opt "value" fields) with
      | Some (`String uri), Some value -> (
          let expected_uri = expected_record_uri ~did ~nsid in
          if uri <> expected_uri then
            Error
              (Printf.sprintf "%s returned record URI %s, expected %s" endpoint
                 uri expected_uri)
          else
            match validate_schema ~endpoint ~nsid value with
            | Error reason -> Error reason
            | Ok document -> Ok (uri, document))
      | _ -> Error (endpoint ^ " returned a record without uri and value"))
  | _ -> Error (endpoint ^ " returned a record that is not a JSON object")

let source_evidence ?did ?pds ~source ~endpoint () : Document.source_evidence =
  { source; endpoint; did; pds }

let fetch_record ~auth ~nsid ~authority ~did ~did_endpoint ~dns_endpoint ~pds =
  let endpoint = record_url ~pds ~did ~nsid in
  let open Lwt.Syntax in
  let+ response =
    Http.get_text_limited ?auth ~max_bytes:max_response_bytes ~timeout_seconds
      endpoint
  in
  if response.status = 0 then
    Error
      (Network ("lexicon PDS record read: " ^ response_detail endpoint response))
  else if response.status >= 300 && response.status < 400 then
    Error
      (Remote
         ( Some response.status,
           "lexicon PDS record read: " ^ endpoint
           ^ " returned a redirect; redirects are not followed" ))
  else if response.status < 200 || response.status >= 300 then
    Error
      (Remote
         ( Some response.status,
           "lexicon PDS record read: " ^ response_detail endpoint response ))
  else
    match parse_record_response ~endpoint ~did ~nsid response.body with
    | Error reason ->
        Error (Remote (None, "lexicon PDS record read: " ^ reason))
    | Ok (record_uri, document) ->
        let sources =
          [
            source_evidence ~source:"dns" ~endpoint:dns_endpoint ~did ();
            source_evidence ~source:"did" ~endpoint:did_endpoint ~did ~pds ();
            source_evidence ~source:"pds" ~endpoint ~did ~pds ();
          ]
        in
        Ok
          {
            nsid;
            authority;
            did;
            pds;
            endpoint;
            record_uri;
            response;
            document;
            sources;
          }

(** Resolve and validate one network-published Lexicon. *)
let validate_pds_override = function
  | None -> Ok None
  | Some value -> (
      let value =
        if
          String.starts_with ~prefix:"http://" value
          || String.starts_with ~prefix:"https://" value
        then value
        else "https://" ^ value
      in
      match Syntax.validate_service_url value with
      | Syntax.Valid -> Ok (Some (Http.normalize_base_url value))
      | Syntax.Invalid reason ->
          Error (Validation ("lexicon PDS override: " ^ reason)))

let get ?auth ?pds nsid =
  match validate_pds_override pds with
  | Error error -> Lwt.return (Error error)
  | Ok pds_override -> (
      match authority_of_nsid nsid with
      | Error error -> Lwt.return (Error error)
      | Ok authority -> (
          match dns_authority authority with
          | Error error -> Lwt.return (Error error)
          | Ok (did, dns_endpoint) -> (
              let open Lwt.Syntax in
              let* did_result = resolve_did did in
              match did_result with
              | Error error -> Lwt.return (Error error)
              | Ok (did_endpoint, resolved) -> (
                  let pds_result =
                    match pds_override with
                    | Some pds -> Ok pds
                    | None -> (
                        match resolved.Identity.pds_endpoint with
                        | Some pds -> Ok pds
                        | None ->
                            Error
                              (Validation
                                 ("lexicon PDS resolution: DID document for "
                                ^ did ^ " at " ^ did_endpoint
                                ^ " does not declare an \
                                   AtprotoPersonalDataServer")))
                  in
                  match pds_result with
                  | Error error -> Lwt.return (Error error)
                  | Ok pds ->
                      fetch_record ~auth ~nsid ~authority ~did ~did_endpoint
                        ~dns_endpoint ~pds))))

let method_kind definition =
  match string_field "type" definition with
  | Some "query" -> Query
  | Some "procedure" -> Procedure
  | Some "subscription" -> Subscription
  | Some "record" -> Record
  | Some kind -> Other kind
  | None -> Other "unknown"

let string_of_method_kind = function
  | Query -> "query"
  | Procedure -> "procedure"
  | Subscription -> "subscription"
  | Record -> "record"
  | Other kind -> kind

let select_definition document =
  match json_field "defs" document with
  | Some (`Assoc definitions) -> (
      match List.assoc_opt "main" definitions with
      | Some definition -> Ok ("main", definition)
      | None -> (
          match definitions with
          | [ (name, definition) ] -> Ok (name, definition)
          | _ ->
              Error "Lexicon has no main definition to select for description"))
  | _ -> Error "Lexicon has no definitions to select for description"

(** Resolve a Lexicon and describe its selected primary definition. *)
let describe ?auth nsid =
  let open Lwt.Syntax in
  let+ result = get ?auth nsid in
  match result with
  | Error error -> Error error
  | Ok query -> (
      match select_definition query.document with
      | Error reason -> Error (Remote (None, "lexicon description: " ^ reason))
      | Ok (definition_name, definition) ->
          Ok
            {
              query;
              definition_name;
              definition;
              method_kind = method_kind definition;
            })

let description_data description =
  `Assoc
    [
      ("id", `String description.query.nsid);
      ("definition", `String description.definition_name);
      ("type", `String (string_of_method_kind description.method_kind));
      ("schema", description.definition);
    ]
