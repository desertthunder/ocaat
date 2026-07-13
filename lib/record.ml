(** Public repository record reads through an account's PDS. *)

type failure = Identity.failure
(** Record reads reuse the shared identity failure categories. *)

type at_uri = { authority : string; collection : string; rkey : string }
(** The actor, collection, and record key extracted from an AT URI. *)

type list_mode =
  | Collections
  | Records of { collection : string; limit : int; cursor : string option }
      (** The mutually exclusive collection-summary and record-page modes. *)

type target = { did : string; pds : string; identity : Identity.resolved }
(** A resolved actor and the PDS selected for its request. *)

type query = {
  did : string;
  pds : string;
  endpoint : string;
  response : Http.response;
}
(** One PDS query together with the provenance needed to render it. *)

let json_field name = function
  | `Assoc fields -> List.assoc_opt name fields
  | _ -> None

let parse_json endpoint body =
  match Yojson.Safe.from_string body with
  | json -> Ok json
  | exception Yojson.Json_error reason ->
      Error (endpoint ^ " returned invalid JSON: " ^ reason)

(** Parse and require a record-shaped AT URI before any network request. *)
let parse_at_uri value =
  match Syntax.validate_at_uri value with
  | Syntax.Invalid reason ->
      Error (Identity.Validation ("invalid AT URI: " ^ reason))
  | Syntax.Valid -> (
      let path = String.sub value 5 (String.length value - 5) in
      match String.split_on_char '/' path with
      | [ authority; collection; rkey ] -> Ok { authority; collection; rkey }
      | _ ->
          Error
            (Identity.Validation
               "AT URI must identify a record with collection and record key"))

let valid_cursor = function
  | None -> Ok None
  | Some cursor when String.trim cursor = "" ->
      Error (Identity.Validation "cursor must not be empty")
  | Some cursor when String.length cursor > 2048 ->
      Error (Identity.Validation "cursor is longer than 2048 characters")
  | Some cursor ->
      let invalid =
        String.exists (fun character -> Char.code character < 0x20) cursor
      in
      if invalid then
        Error (Identity.Validation "cursor contains a control character")
      else Ok (Some cursor)

let valid_limit limit =
  if limit < 1 || limit > 100 then
    Error (Identity.Validation "limit must be between 1 and 100")
  else Ok limit

let valid_collection collection =
  match Syntax.validate_nsid collection with
  | Syntax.Valid -> Ok collection
  | Syntax.Invalid reason ->
      Error (Identity.Validation ("invalid collection NSID: " ^ reason))

(** Resolve an actor and select its declared or explicitly overridden PDS. *)
let resolve_target ?pds actor =
  let open Lwt.Syntax in
  let+ result = Identity.resolve actor in
  match result with
  | Error error -> Error error
  | Ok identity -> (
      match pds with
      | Some pds -> Ok { did = identity.did; pds; identity }
      | None -> (
          match identity.pds_endpoint with
          | Some pds -> Ok { did = identity.did; pds; identity }
          | None ->
              Error
                (Identity.Validation
                   ("identity " ^ identity.did
                  ^ " does not declare an AtprotoPersonalDataServer service; "
                  ^ "pass --pds <url>"))))

(** Build a [com.atproto.repo.getRecord] endpoint. *)
let get_url ~pds ~did ~collection ~rkey =
  Http.xrpc_url ~base_url:pds ~method_:"com.atproto.repo.getRecord"
    ~params:[ ("repo", did); ("collection", collection); ("rkey", rkey) ]

(** Build a [com.atproto.repo.listRecords] endpoint. *)
let list_records_url ~pds ~did ~collection ~limit ?cursor () =
  let params =
    [
      ("repo", did); ("collection", collection); ("limit", string_of_int limit);
    ]
  in
  let params =
    match cursor with
    | None -> params
    | Some cursor -> params @ [ ("cursor", cursor) ]
  in
  Http.xrpc_url ~base_url:pds ~method_:"com.atproto.repo.listRecords" ~params

(** Build a [com.atproto.repo.describeRepo] endpoint. *)
let describe_repo_url ~pds ~did =
  Http.xrpc_url ~base_url:pds ~method_:"com.atproto.repo.describeRepo"
    ~params:[ ("repo", did) ]

(** Fetch one record after resolving its AT URI authority. *)
let get ?auth ?pds value =
  match parse_at_uri value with
  | Error error -> Lwt.return (Error error)
  | Ok at_uri -> (
      let open Lwt.Syntax in
      let* target_result = resolve_target ?pds at_uri.authority in
      match target_result with
      | Error error -> Lwt.return (Error error)
      | Ok target ->
          let endpoint =
            get_url ~pds:target.pds ~did:target.did
              ~collection:at_uri.collection ~rkey:at_uri.rkey
          in
          let+ response = Http.get_text ?auth endpoint in
          Ok { did = target.did; pds = target.pds; endpoint; response })

(** Fetch one collection page or collection summary for an actor. *)
let list ?auth ?pds ~actor ~mode () =
  let mode_result =
    match mode with
    | Collections -> Ok `Collections
    | Records { collection; limit; cursor } -> (
        match valid_collection collection with
        | Error error -> Error error
        | Ok collection -> (
            match valid_limit limit with
            | Error error -> Error error
            | Ok limit -> (
                match valid_cursor cursor with
                | Error error -> Error error
                | Ok cursor -> Ok (`Records (collection, limit, cursor)))))
  in
  match mode_result with
  | Error error -> Lwt.return (Error error)
  | Ok mode -> (
      let open Lwt.Syntax in
      let* target_result = resolve_target ?pds actor in
      match target_result with
      | Error error -> Lwt.return (Error error)
      | Ok target ->
          let endpoint =
            match mode with
            | `Collections -> describe_repo_url ~pds:target.pds ~did:target.did
            | `Records (collection, limit, cursor) ->
                list_records_url ~pds:target.pds ~did:target.did ~collection
                  ~limit ?cursor ()
          in
          let+ response = Http.get_text ?auth endpoint in
          Ok { did = target.did; pds = target.pds; endpoint; response })

(** Validate a [getRecord] response without changing its protocol fields. *)
let parse_get_response ~endpoint body =
  match parse_json endpoint body with
  | Error _ as error -> error
  | Ok (`Assoc fields as json) -> (
      match (List.assoc_opt "uri" fields, List.assoc_opt "value" fields) with
      | Some (`String uri), Some _ -> (
          match Syntax.validate_at_uri uri with
          | Syntax.Valid -> Ok json
          | Syntax.Invalid reason ->
              Error (endpoint ^ " returned an invalid record URI: " ^ reason))
      | _ -> Error (endpoint ^ " returned a record without uri and value"))
  | Ok _ -> Error (endpoint ^ " returned a record that is not a JSON object")

(** Validate and annotate a [listRecords] page with its request context. *)
let parse_list_response ~endpoint ~did ~collection body =
  match parse_json endpoint body with
  | Error _ as error -> error
  | Ok (`Assoc fields) -> (
      match List.assoc_opt "records" fields with
      | Some (`List _) -> (
          match List.assoc_opt "cursor" fields with
          | None | Some (`String _) ->
              let fields =
                List.filter
                  (fun (name, _) -> name <> "repo" && name <> "collection")
                  fields
              in
              Ok
                (`Assoc
                   (("repo", `String did)
                   :: ("collection", `String collection)
                   :: fields))
          | Some _ -> Error (endpoint ^ " returned a non-string cursor"))
      | _ -> Error (endpoint ^ " returned a page without a records array"))
  | Ok _ ->
      Error (endpoint ^ " returned a record page that is not a JSON object")

(** Validate a [describeRepo] collection summary without synthesizing records.
*)
let parse_describe_response ~endpoint body =
  match parse_json endpoint body with
  | Error _ as error -> error
  | Ok (`Assoc fields as json) -> (
      match List.assoc_opt "collections" fields with
      | Some (`List _) -> Ok json
      | _ -> Error (endpoint ^ " returned a summary without a collections array")
      )
  | Ok _ ->
      Error
        (endpoint ^ " returned a repository summary that is not a JSON object")
