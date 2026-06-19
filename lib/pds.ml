(** PDS inspection operations. *)

(** PDS-related XRPC methods used by this module. *)
type method_ = Describe_server | List_repos | Get_repo_status

(** Convert a PDS method variant to its NSID. *)
let method_nsid = function
  | Describe_server -> "com.atproto.server.describeServer"
  | List_repos -> "com.atproto.sync.listRepos"
  | Get_repo_status -> "com.atproto.sync.getRepoStatus"

(** Build the describeServer URL for a PDS host or service URL. *)
let describe_url host =
  Http.xrpc_url ~base_url:host ~method_:(method_nsid Describe_server) ~params:[]

(** Call [com.atproto.server.describeServer] on a PDS.

    The endpoint is an unauthenticated query in normal PDS deployments, but an
    optional bearer token is accepted for consistency with the shared CLI
    context. *)
let describe ?auth host = Http.get_text ?auth (describe_url host)

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
  if String.starts_with ~prefix:"did:plc:" did then
    Some ("https://plc.directory/" ^ did)
  else if String.starts_with ~prefix:"did:web:" did then
    let host = String.sub did 8 (String.length did - 8) in
    Some ("https://" ^ host ^ "/.well-known/did.json")
  else None

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
