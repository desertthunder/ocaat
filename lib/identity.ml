(** AT Protocol handle and DID resolution. *)

type failure =
  | Validation of string
  | Network of string
  | Remote of int option * string
      (** Failure categories used by the resolve command. *)

type handle_evidence = { handle : string; source : string; verified : bool }
(** Evidence describing how an identity's handle was obtained. *)

type resolved = {
  input : string;
  did : string;
  document : Yojson.Safe.t;
  handle : string option;
  handle_evidence : handle_evidence option;
  pds : Yojson.Safe.t option;
  pds_endpoint : string option;
  source : string;
  endpoint : string;
}
(** A normalized identity and the evidence discovered while resolving it. *)

type resolved_document = {
  document : Yojson.Safe.t;
  claimed_handle : string option;
  pds : Yojson.Safe.t option;
  pds_endpoint : string option;
  source : string;
  endpoint : string;
}
(** The DID-document facts shared by direct and handle resolution. *)

type input =
  | Handle of string
  | Did of string
      (** The validated input class selected before any network request. *)

let json_field name = function
  | `Assoc fields -> List.assoc_opt name fields
  | _ -> None

let string_field name json =
  match json_field name json with
  | Some (`String value) -> Some value
  | _ -> None

let list_field name json =
  match json_field name json with
  | Some (`List values) -> Some values
  | _ -> None

let starts_with ~prefix value =
  String.length value >= String.length prefix
  && String.sub value 0 (String.length prefix) = prefix

let ends_with ~suffix value =
  String.length value >= String.length suffix
  && String.sub value
       (String.length value - String.length suffix)
       (String.length suffix)
     = suffix

let hex_value = function
  | '0' .. '9' as c -> Some (Char.code c - Char.code '0')
  | 'a' .. 'f' as c -> Some (Char.code c - Char.code 'a' + 10)
  | 'A' .. 'F' as c -> Some (Char.code c - Char.code 'A' + 10)
  | _ -> None

let percent_decode value =
  let output = Buffer.create (String.length value) in
  let rec loop index =
    if index = String.length value then Ok (Buffer.contents output)
    else if value.[index] <> '%' then (
      Buffer.add_char output value.[index];
      loop (index + 1))
    else if index + 2 >= String.length value then
      Error "DID web identifier contains an incomplete percent escape"
    else
      match (hex_value value.[index + 1], hex_value value.[index + 2]) with
      | Some high, Some low ->
          Buffer.add_char output (Char.chr ((high lsl 4) lor low));
          loop (index + 3)
      | _ -> Error "DID web identifier contains an invalid percent escape"
  in
  loop 0

let valid_did did =
  match Syntax.validate_did did with
  | Syntax.Valid -> true
  | Syntax.Invalid _ -> false

let did_method did =
  match Syntax.split_on_char ':' did with
  | "did" :: method_ :: _ -> Some method_
  | _ -> None

(** Return the fetch endpoint and source for a supported DID method. *)
let did_document_url ?plc_host did =
  try
    match did_method did with
    | Some "plc" ->
        let plc_host =
          Option.value ~default:"https://plc.directory" plc_host
          |> Http.normalize_base_url
        in
        Ok (plc_host ^ "/" ^ did, "plc")
    | Some "web" -> (
        let identifier = String.sub did 8 (String.length did - 8) in
        if String.contains identifier ':' then
          Error
            "did:web path-based identifiers are not supported; use a hostname"
        else
          match percent_decode identifier with
          | Error reason -> Error reason
          | Ok host ->
              let host_lower = String.lowercase_ascii host in
              let host, scheme =
                match String.index_opt host ':' with
                | None -> (
                    if host_lower = "localhost" then (host, "http")
                    else
                      match Syntax.validate_handle host with
                      | Syntax.Valid -> (host, "https")
                      | Syntax.Invalid reason -> raise (Invalid_argument reason)
                    )
                | Some colon ->
                    let hostname = String.sub host 0 colon in
                    let port =
                      String.sub host (colon + 1)
                        (String.length host - colon - 1)
                    in
                    if String.lowercase_ascii hostname <> "localhost" then
                      raise
                        (Invalid_argument
                           "did:web ports are supported only for localhost")
                    else if
                      port = ""
                      || not
                           (String.for_all
                              (function '0' .. '9' -> true | _ -> false)
                              port)
                    then
                      raise
                        (Invalid_argument "did:web localhost port is invalid")
                    else if
                      match int_of_string_opt port with
                      | Some value -> value < 1 || value > 65535
                      | None -> true
                    then
                      raise
                        (Invalid_argument
                           "did:web localhost port is out of range")
                    else (hostname ^ ":" ^ port, "http")
              in
              Ok (scheme ^ "://" ^ host ^ "/.well-known/did.json", "did:web"))
    | Some method_ -> Error ("unsupported DID method: did:" ^ method_)
    | None -> Error "DID method could not be determined"
  with Invalid_argument reason -> Error reason

let handle_from_also_known_as json =
  let valid_handle value =
    if starts_with ~prefix:"at://" value then
      let handle = String.sub value 5 (String.length value - 5) in
      if not (String.contains handle '/') then
        match Syntax.validate_handle handle with
        | Syntax.Valid -> Some (String.lowercase_ascii handle)
        | Syntax.Invalid _ -> None
      else None
    else None
  in
  match list_field "alsoKnownAs" json with
  | Some values ->
      List.find_map
        (function `String value -> valid_handle value | _ -> None)
        values
  | None -> None

let pds_service_id value =
  value = "#atproto_pds" || ends_with ~suffix:"#atproto_pds" value

let extract_pds _expected_did json =
  let rec find = function
    | [] -> Ok None
    | (`Assoc _ as service) :: rest -> (
        match (string_field "id" service, string_field "type" service) with
        | Some id, Some "AtprotoPersonalDataServer" when pds_service_id id -> (
            let endpoint = string_field "serviceEndpoint" service in
            match endpoint with
            | None ->
                Error "DID document PDS service is missing serviceEndpoint"
            | Some endpoint -> (
                match Syntax.validate_service_url endpoint with
                | Syntax.Invalid reason ->
                    Error ("invalid DID document PDS service: " ^ reason)
                | Syntax.Valid ->
                    Ok (Some (service, Http.normalize_base_url endpoint))))
        | _ -> find rest)
    | _ :: rest -> find rest
  in
  match list_field "service" json with
  | None -> Ok None
  | Some services -> find services

let response_detail endpoint (response : Http.response) =
  let detail =
    if response.body = "" then "empty response body"
    else Redaction.body response.body
  in
  endpoint ^ ": " ^ detail

let parse_did_document ~did ~endpoint (response : Http.response) =
  if response.Http.status = 0 then
    Error (Network (response_detail endpoint response))
  else if response.status < 200 || response.status >= 300 then
    Error (Remote (Some response.status, response_detail endpoint response))
  else
    match Yojson.Safe.from_string response.body with
    | exception Yojson.Json_error reason ->
        Error (Remote (None, endpoint ^ " returned invalid JSON: " ^ reason))
    | json -> (
        match string_field "id" json with
        | Some actual when actual = did -> (
            match extract_pds did json with
            | Error reason -> Error (Validation reason)
            | Ok pds ->
                Ok
                  {
                    document = json;
                    claimed_handle = handle_from_also_known_as json;
                    pds = Option.map fst pds;
                    pds_endpoint = Option.map snd pds;
                    source =
                      (if starts_with ~prefix:"did:plc:" did then "plc"
                       else "did:web");
                    endpoint;
                  })
        | Some actual ->
            Error
              (Remote
                 ( None,
                   Printf.sprintf "%s returned DID document for %s, expected %s"
                     endpoint actual did ))
        | None ->
            Error
              (Remote (None, endpoint ^ " returned a DID document without id")))

let resolve_did ?plc_host did =
  match did_document_url ?plc_host did with
  | Error reason -> Lwt.return (Error (Validation reason))
  | Ok (endpoint, source) -> (
      let open Lwt.Syntax in
      let+ response = Http.get_text endpoint in
      match parse_did_document ~did ~endpoint response with
      | Error error -> Error error
      | Ok document -> Ok { document with source })

type dns_result = No_answer | Answer of string | Conflict of string

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
  | Some value when starts_with ~prefix:"did=" value ->
      let did = String.sub value 4 (String.length value - 4) in
      if valid_did did then Some did else None
  | _ -> None

let dns_txt handle =
  try
    let channel =
      Unix.open_process_args_in "dig"
        [|
          "dig"; "+short"; "+time=3"; "+tries=1"; "TXT"; "_atproto." ^ handle;
        |]
    in
    let rec read_lines acc =
      match input_line channel with
      | line -> read_lines (line :: acc)
      | exception End_of_file -> List.rev acc
    in
    let lines = read_lines [] in
    let status = Unix.close_process_in channel in
    match status with
    | Unix.WEXITED 0 -> (
        let dids =
          List.filter_map dns_did_from_line lines
          |> List.sort_uniq String.compare
        in
        match dids with
        | [] -> No_answer
        | [ did ] -> Answer did
        | _ -> Conflict "DNS handle resolution returned multiple DIDs")
    | _ -> No_answer
  with Sys_error _ | Unix.Unix_error _ -> No_answer

let handle_well_known_url handle =
  let scheme =
    if ends_with ~suffix:".localhost" handle then "http" else "https"
  in
  scheme ^ "://" ^ handle ^ "/.well-known/atproto-did"

let parse_handle_response ~handle endpoint (response : Http.response) =
  if response.Http.status = 0 then
    Error (Network (response_detail endpoint response))
  else if response.status < 200 || response.status >= 300 then
    Error (Remote (Some response.status, response_detail endpoint response))
  else
    let did = String.trim response.body in
    if did = "" || not (valid_did did) then
      Error
        (Remote
           (None, endpoint ^ " returned an invalid DID for handle " ^ handle))
    else Ok did

let resolve_handle handle =
  match dns_txt handle with
  | Answer did -> Lwt.return (Ok (did, "dns"))
  | Conflict reason -> Lwt.return (Error (Network reason))
  | No_answer -> (
      let endpoint = handle_well_known_url handle in
      let open Lwt.Syntax in
      let+ response = Http.get_text endpoint in
      match parse_handle_response ~handle endpoint response with
      | Error error -> Error error
      | Ok did -> Ok (did, "https"))

let parse_input value =
  if starts_with ~prefix:"did:" value then
    match Syntax.validate_did value with
    | Syntax.Valid -> Ok (Did value)
    | Syntax.Invalid reason -> Error (Validation ("invalid DID: " ^ reason))
  else
    match Syntax.validate_handle value with
    | Syntax.Valid -> Ok (Handle (String.lowercase_ascii value))
    | Syntax.Invalid reason ->
        Error (Validation ("invalid handle or DID: " ^ reason))

(** Resolve a handle or DID with bidirectional handle verification. *)
let resolve ?plc_host value =
  match parse_input value with
  | Error error -> Lwt.return (Error error)
  | Ok (Did did) -> (
      let open Lwt.Syntax in
      let+ result = resolve_did ?plc_host did in
      match result with
      | Error error -> Error error
      | Ok resolved ->
          Ok
            {
              input = value;
              did;
              document = resolved.document;
              handle = resolved.claimed_handle;
              handle_evidence =
                Option.map
                  (fun handle ->
                    { handle; source = "did-document"; verified = false })
                  resolved.claimed_handle;
              pds = resolved.pds;
              pds_endpoint = resolved.pds_endpoint;
              source = resolved.source;
              endpoint = resolved.endpoint;
            })
  | Ok (Handle handle) -> (
      let open Lwt.Syntax in
      let* did_result = resolve_handle handle in
      match did_result with
      | Error error -> Lwt.return (Error error)
      | Ok (did, handle_source) -> (
          let+ document_result = resolve_did ?plc_host did in
          match document_result with
          | Error error -> Error error
          | Ok resolved ->
              if resolved.claimed_handle <> Some handle then
                Error
                  (Validation
                     (Printf.sprintf
                        "handle %s is not claimed by DID document %s" handle did))
              else
                Ok
                  {
                    input = value;
                    did;
                    document = resolved.document;
                    handle = Some handle;
                    handle_evidence =
                      Some { handle; source = handle_source; verified = true };
                    pds = resolved.pds;
                    pds_endpoint = resolved.pds_endpoint;
                    source = resolved.source;
                    endpoint = resolved.endpoint;
                  }))

let optional_field name make value fields =
  match value with
  | None -> fields
  | Some value -> fields @ [ (name, make value) ]

(** Serialize a resolved identity for the shared document envelope. *)
let data (resolved : resolved) =
  let fields =
    [
      ("input", `String resolved.input);
      ("did", `String resolved.did);
      ("document", resolved.document);
    ]
    |> optional_field "handle" (fun value -> `String value) resolved.handle
    |> optional_field "handleEvidence"
         (fun (evidence : handle_evidence) ->
           `Assoc
             [
               ("handle", `String evidence.handle);
               ("source", `String evidence.source);
               ("verified", `Bool evidence.verified);
               ("did", `String resolved.did);
             ])
         resolved.handle_evidence
    |> optional_field "pds" Fun.id resolved.pds
  in
  `Assoc fields
