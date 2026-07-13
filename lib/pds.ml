(** PDS inspection operations. *)

(** PDS-related XRPC methods used by this module. *)
type method_ =
  | Describe_server
  | List_repos
  | Get_repo_status
  | Health
  | Stats
  | Admin_status

(** Convert a PDS method variant to its NSID. *)
let method_nsid = function
  | Describe_server -> "com.atproto.server.describeServer"
  | List_repos -> "com.atproto.sync.listRepos"
  | Get_repo_status -> "com.atproto.sync.getRepoStatus"
  | Health -> "_health"
  | Stats -> "_stats"
  | Admin_status -> "_admin/status"

(** Build a non-NSID operational XRPC URL such as [/xrpc/_health]. *)
let operational_url host method_ =
  Http.xrpc_url ~base_url:host ~method_:(method_nsid method_) ~params:[]

(** Build the describeServer URL for a PDS host or service URL. *)
let describe_url host =
  Http.xrpc_url ~base_url:host ~method_:(method_nsid Describe_server) ~params:[]

(** Call [com.atproto.server.describeServer] on a PDS.

    The endpoint is an unauthenticated query in normal PDS deployments, but an
    optional bearer token is accepted for consistency with the shared CLI
    context. *)
let describe ?auth host = Http.get_text ?auth (describe_url host)

(** Call [/xrpc/_health] on a PDS. *)
let health host = Http.get_text (operational_url host Health)

(** Call [/xrpc/_stats] on a PDS. *)
let stats host = Http.get_text (operational_url host Stats)

(** Call [/xrpc/_admin/status] on a PDS with admin bearer auth. *)
let admin_status ~admin_token host =
  Http.get_text ~auth:admin_token (operational_url host Admin_status)

(** Build a listRepos URL for a PDS host or service URL. *)
let list_repos_url ?cursor host =
  let params =
    match cursor with
    | None -> [ ("limit", "500") ]
    | Some cursor -> [ ("limit", "500"); ("cursor", cursor) ]
  in
  Http.xrpc_url ~base_url:host ~method_:(method_nsid List_repos) ~params

(** Call [com.atproto.sync.listRepos] on a PDS.

    This fetches one page. Use [list_all_repos] for CLI enumeration. *)
let list_repos_page ?auth ?cursor host =
  Http.get_text ?auth (list_repos_url ?cursor host)

(** Build a getRepoStatus URL for a PDS host or service URL and account DID. *)
let repo_status_url host did =
  Http.xrpc_url ~base_url:host
    ~method_:(method_nsid Get_repo_status)
    ~params:[ ("did", did) ]

(** Call [com.atproto.sync.getRepoStatus] on a PDS for one DID. *)
let repo_status ?auth ~pds ~did () =
  match Syntax.validate_did did with
  | Invalid reason -> Lwt.return (Error ("invalid DID: " ^ reason))
  | Valid ->
      let open Lwt.Syntax in
      let+ response = Http.get_text ?auth (repo_status_url pds did) in
      Ok response

let json_field name = function
  | `Assoc fields -> List.assoc_opt name fields
  | _ -> None

let string_field name json =
  match json_field name json with
  | Some (`String value) -> Some value
  | _ -> None

let bool_field name json =
  match json_field name json with Some (`Bool value) -> Some value | _ -> None

let int_field name json =
  match json_field name json with
  | Some (`Int value) -> Some value
  | Some (`Intlit value) -> int_of_string_opt value
  | _ -> None

let list_field name json =
  match json_field name json with
  | Some (`List values) -> Some values
  | _ -> None

let object_field name json =
  match json_field name json with
  | Some (`Assoc _ as value) -> Some value
  | _ -> None

let field_path names json =
  let rec loop json = function
    | [] -> Some json
    | name :: rest -> (
        match json_field name json with
        | None -> None
        | Some json -> loop json rest)
  in
  loop json names

let string_path names json =
  match field_path names json with
  | Some (`String value) -> Some value
  | _ -> None

let bool_path names json =
  match field_path names json with
  | Some (`Bool value) -> Some value
  | _ -> None

let int_path names json =
  match field_path names json with
  | Some (`Int value) -> Some value
  | Some (`Intlit value) -> int_of_string_opt value
  | _ -> None

let hostname host =
  let uri = Uri.of_string (Http.normalize_base_url host) in
  Option.value ~default:host (Uri.host uri)

let service_did_from_describe body =
  match Yojson.Safe.from_string body with
  | json -> string_field "did" json
  | exception Yojson.Json_error _ -> None

let fetch_service_did ?auth host =
  let open Lwt.Syntax in
  let+ response = describe ?auth host in
  if response.status >= 200 && response.status < 300 then
    service_did_from_describe response.body
  else None

let parse_json_response endpoint body =
  match Yojson.Safe.from_string body with
  | json -> Ok json
  | exception Yojson.Json_error reason ->
      Error (endpoint ^ " returned invalid JSON: " ^ reason)

(* Sum a field only when at least one value was actually supplied. *)
let sum_int_field name values =
  let rec loop total = function
    | [] -> total
    | json :: rest ->
        let total =
          match int_field name json with
          | None -> total
          | Some value ->
              let total = Option.value ~default:0 total in
              Some (total + value)
        in
        loop total rest
  in
  loop None values

type inspection = {
  hostname : string;
  service_did : string option;
  health_state : string option;
  account_count : int option;
  repo_count : int option;
  blob_count : int option;
  sequencer_cursor : int option;
  configured_crawlers : string list option;
  storage_backend : string option;
  admin_auth_configured : bool option;
  status_cues : (string * string) list;
}
(** Normalized PDS facts used by the human inspection summary. *)

let status_cues_from_health json =
  match field_path [ "health"; "checks" ] json with
  | Some (`Assoc fields) ->
      List.map (fun (name, value) -> (name, Yojson.Safe.to_string value)) fields
  | _ -> (
      match object_field "storage" json with
      | Some (`Assoc fields) ->
          List.map
            (fun (name, value) -> (name, Yojson.Safe.to_string value))
            fields
      | _ -> [])

let crawlers_from_describe body =
  match Yojson.Safe.from_string body with
  | json -> (
      match list_field "availableUserDomains" json with
      | Some domains ->
          Some
            (List.filter_map
               (function `String value -> Some value | _ -> None)
               domains)
      | None -> None)
  | exception Yojson.Json_error _ -> None

let public_inspection ?service_did ?describe_body ~host json =
  let metrics = object_field "metrics" json in
  let account_count =
    match metrics with
    | Some metrics -> (
        match int_field "hostedAccountCount" metrics with
        | Some _ as count -> count
        | None -> int_field "totalAccountCount" metrics)
    | None -> None
  in
  {
    hostname = hostname host;
    service_did;
    health_state =
      (match string_path [ "health"; "status" ] json with
      | Some _ as value -> value
      | None -> string_field "status" json);
    account_count;
    repo_count = Option.bind metrics (int_field "repoCount");
    blob_count = Option.bind metrics (int_field "blobCount");
    sequencer_cursor = Option.bind metrics (int_field "sequencerCursor");
    configured_crawlers = Option.bind describe_body crawlers_from_describe;
    storage_backend =
      (match string_path [ "storage"; "adapter" ] json with
      | Some _ as value -> value
      | None -> string_path [ "storage"; "backend" ] json);
    admin_auth_configured = None;
    status_cues = status_cues_from_health json;
  }

let admin_inspection ?service_did ?describe_body ~host json =
  let accounts = list_field "accounts" json in
  {
    hostname = hostname host;
    service_did;
    health_state = string_field "status" json;
    account_count =
      (match int_path [ "blobStore"; "accountCount" ] json with
      | Some _ as count -> count
      | None -> Option.map List.length accounts);
    repo_count = Option.bind accounts (sum_int_field "repoCount");
    blob_count =
      (match int_path [ "blobStore"; "blobCount" ] json with
      | Some _ as count -> count
      | None -> Option.bind accounts (sum_int_field "blobCount"));
    sequencer_cursor = int_path [ "sequencer"; "currentSeq" ] json;
    configured_crawlers = Option.bind describe_body crawlers_from_describe;
    storage_backend = string_path [ "blobStore"; "adapter" ] json;
    admin_auth_configured = bool_path [ "admin"; "tokenConfigured" ] json;
    status_cues = status_cues_from_health json;
  }

let optional_field name to_json value fields =
  match value with
  | None -> fields
  | Some value -> fields @ [ (name, to_json value) ]

let string_json value = `String value
let int_json value = `Int value
let bool_json value = `Bool value
let strings_json values = `List (List.map string_json values)

let json_of_status_cues cues =
  let value text =
    match Yojson.Safe.from_string text with
    | value -> value
    | exception Yojson.Json_error _ -> `String text
  in
  `Assoc (List.map (fun (name, text) -> (name, value text)) cues)

(** Convert normalized inspection facts to the Markdown presentation value.

    Fields whose source did not expose a value are omitted instead of being
    represented by a synthetic zero or "unknown" string. *)
let inspection_to_json (inspection : inspection) =
  let fields =
    [ ("hostname", string_json inspection.hostname) ]
    |> optional_field "serviceDid" string_json inspection.service_did
    |> optional_field "health" string_json inspection.health_state
    |> optional_field "accountCount" int_json inspection.account_count
    |> optional_field "repoCount" int_json inspection.repo_count
    |> optional_field "blobCount" int_json inspection.blob_count
    |> optional_field "sequencerCursor" int_json inspection.sequencer_cursor
    |> optional_field "configuredCrawlers" strings_json
         inspection.configured_crawlers
    |> optional_field "storageBackend" string_json inspection.storage_backend
    |> optional_field "adminAuthConfigured" bool_json
         inspection.admin_auth_configured
  in
  `Assoc
    (fields @ [ ("statusCues", json_of_status_cues inspection.status_cues) ])

(** Return the display status for a listRepos/getRepoStatus JSON object. *)
let repo_status_text json =
  match (bool_field "active" json, string_field "status" json) with
  | Some true, _ -> "active"
  | _, Some status -> status
  | _ -> "unknown"

(** Extract the next pagination cursor from a listRepos response body. *)
let cursor_from_body body =
  match Yojson.Safe.from_string body with
  | json -> string_field "cursor" json
  | exception Yojson.Json_error _ -> None

(** Extract repo objects from a listRepos response body. *)
let repos_from_body body =
  match Yojson.Safe.from_string body with
  | json -> (
      match json_field "repos" json with
      | Some (`List repos) -> Ok repos
      | _ -> Error "listRepos response does not contain a repos array")
  | exception Yojson.Json_error reason ->
      Error ("listRepos returned invalid JSON: " ^ reason)

(** Fetch every listRepos page from a PDS, preserving the raw repo JSON objects.
*)
let list_all_repos ?auth host =
  let open Lwt.Syntax in
  let rec loop cursor acc =
    let* response = list_repos_page ?auth ?cursor host in
    if response.status < 200 || response.status >= 300 then
      Lwt.return (Error response)
    else
      match repos_from_body response.body with
      | Error reason -> Lwt.return (Error { Http.status = 0; body = reason })
      | Ok repos ->
          let acc = List.rev_append repos acc in
          let next = cursor_from_body response.body in
          if next = None || next = Some "" then Lwt.return (Ok (List.rev acc))
          else loop next acc
  in
  loop None []

(** Build a DID document URL for DID methods used by atproto accounts. *)
let did_document_url did =
  match Identity.did_document_url did with
  | Ok (url, _) -> Some url
  | Error _ -> None

(** Extract the first syntactically valid handle from a DID document JSON body.
*)
let handle_from_did_document body =
  match Yojson.Safe.from_string body with
  | json -> (
      match json_field "alsoKnownAs" json with
      | Some (`List values) ->
          let rec loop = function
            | [] -> None
            | `String value :: rest ->
                if String.starts_with ~prefix:"at://" value then
                  let handle = String.sub value 5 (String.length value - 5) in
                  match Syntax.validate_handle handle with
                  | Valid -> Some handle
                  | Invalid _ -> loop rest
                else loop rest
            | _ :: rest -> loop rest
          in
          loop values
      | _ -> None)
  | exception Yojson.Json_error _ -> None

(** Best-effort DID-to-handle lookup for human list output.

    Failures intentionally return [None] so account listing still succeeds if
    one DID document is unavailable or omits an [alsoKnownAs] handle. *)
let lookup_handle did =
  let open Lwt.Syntax in
  match did_document_url did with
  | None -> Lwt.return_none
  | Some url ->
      let+ response = Http.get_text url in
      if response.status >= 200 && response.status < 300 then
        handle_from_did_document response.body
      else None
