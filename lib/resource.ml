(** Classification and dispatch for one user-supplied AT Protocol resource. *)

type input =
  | Identity of string
  | Record of string
  | Lexicon of string
  | Pds of string
      (** A validated resource branch and its normalized request value. *)

type pds_query = { pds : string; endpoint : string; response : Http.response }
(** A PDS describe response with the normalized service endpoint. *)

type result =
  | Identity_result of Identity.resolved
  | Record_result of Record.query
  | Lexicon_result of Lexicon.query
  | Pds_result of pds_query
      (** One result produced by exactly one resource branch. *)

type failure =
  | Validation of string
  | Identity_failure of Identity.failure
  | Lexicon_failure of Lexicon.failure
      (** Failures returned by classification or a delegated read path. *)

let starts_with ~prefix value =
  String.length value >= String.length prefix
  && String.sub value 0 (String.length prefix) = prefix

let normalize_pds value =
  let value =
    if
      starts_with ~prefix:"http://" value
      || starts_with ~prefix:"https://" value
    then value
    else "https://" ^ value
  in
  match Syntax.validate_service_url value with
  | Syntax.Valid -> Ok (Http.normalize_base_url value)
  | Syntax.Invalid reason -> Error reason

let validate_actor actor =
  if starts_with ~prefix:"did:" actor then
    match Syntax.validate_did actor with
    | Syntax.Valid -> Ok actor
    | Syntax.Invalid reason -> Error ("invalid DID: " ^ reason)
  else
    match Syntax.validate_handle actor with
    | Syntax.Valid -> Ok (String.lowercase_ascii actor)
    | Syntax.Invalid reason -> Error ("invalid handle: " ^ reason)

let normalize_web_actor actor =
  match validate_actor actor with
  | Error _ as error -> error
  | Ok actor when starts_with ~prefix:"did:web:" actor ->
      let prefix = "did:web:" in
      let rest =
        String.sub actor (String.length prefix)
          (String.length actor - String.length prefix)
      in
      Ok (prefix ^ String.concat "%3A" (String.split_on_char ':' rest))
  | Ok actor -> Ok actor

let normalized_web_url value =
  try
    let uri = Uri.of_string value in
    let scheme = Option.map String.lowercase_ascii (Uri.scheme uri) in
    let host = Option.map String.lowercase_ascii (Uri.host uri) in
    if scheme <> Some "https" then Error "AT Protocol web URLs must use https"
    else if host <> Some "bsky.app" then
      Error "unsupported AT Protocol web URL host; expected bsky.app"
    else if Uri.userinfo uri <> None then
      Error "AT Protocol web URLs must not contain credentials"
    else if Uri.port uri <> None then
      Error "AT Protocol web URLs must not contain a port"
    else if Uri.verbatim_query uri <> None || Uri.fragment uri <> None then
      Error "AT Protocol web URLs must not contain a query or fragment"
    else
      match String.split_on_char '/' (Uri.path uri) with
      | [ ""; "profile"; actor ] -> (
          match normalize_web_actor actor with
          | Error reason -> Error reason
          | Ok actor -> Ok ("at://" ^ actor ^ "/app.bsky.actor.profile/self"))
      | [ ""; "profile"; actor; "post"; rkey ] -> (
          match normalize_web_actor actor with
          | Error reason -> Error reason
          | Ok actor -> (
              match Syntax.validate_rkey rkey with
              | Syntax.Valid ->
                  Ok ("at://" ^ actor ^ "/app.bsky.feed.post/" ^ rkey)
              | Syntax.Invalid reason ->
                  Error ("invalid post record key: " ^ reason)))
      | [ ""; "profile"; actor; "lists"; rkey ] -> (
          match normalize_web_actor actor with
          | Error reason -> Error reason
          | Ok actor -> (
              match Syntax.validate_rkey rkey with
              | Syntax.Valid ->
                  Ok ("at://" ^ actor ^ "/app.bsky.graph.list/" ^ rkey)
              | Syntax.Invalid reason ->
                  Error ("invalid list record key: " ^ reason)))
      | [ ""; "profile"; actor; "feed"; rkey ] -> (
          match normalize_web_actor actor with
          | Error reason -> Error reason
          | Ok actor -> (
              match Syntax.validate_rkey rkey with
              | Syntax.Valid ->
                  Ok ("at://" ^ actor ^ "/app.bsky.feed.generator/" ^ rkey)
              | Syntax.Invalid reason ->
                  Error ("invalid feed record key: " ^ reason)))
      | _ ->
          Error
            "unsupported AT Protocol web URL; expected /profile/<actor>, \
             /profile/<actor>/post/<rkey>, /profile/<actor>/lists/<rkey>, or \
             /profile/<actor>/feed/<rkey>"
  with Invalid_argument reason -> Error ("invalid URL: " ^ reason)

(** Normalize one supported Bluesky web URL to a record AT URI. *)
let normalize_web_url = normalized_web_url

(** Prefer a Lexicon interpretation for common reverse-domain namespaces when
    the same spelling also satisfies handle syntax. *)
let likely_nsid value =
  let parts = String.split_on_char '.' value in
  let first = match parts with first :: _ -> first | [] -> "" in
  let last = match List.rev parts with last :: _ -> last | [] -> "" in
  let namespace_prefixes =
    [
      "com";
      "app";
      "org";
      "net";
      "dev";
      "site";
      "io";
      "co";
      "me";
      "tv";
      "xyz";
      "info";
    ]
  in
  List.mem first namespace_prefixes
  || String.lowercase_ascii first = first
     && String.exists (function 'A' .. 'Z' -> true | _ -> false) last

(** Classify a resource without making a network request. *)
let classify value =
  if String.trim value = "" then Error (Validation "resource is empty")
  else if starts_with ~prefix:"at://" value then
    match Record.parse_at_uri value with
    | Ok _ -> Ok (Record value)
    | Error (Identity.Validation reason) -> Error (Validation reason)
    | Error _ -> Error (Validation "invalid AT URI")
  else if starts_with ~prefix:"did:" value then
    match Syntax.validate_did value with
    | Syntax.Valid -> Ok (Identity value)
    | Syntax.Invalid reason -> Error (Validation ("invalid DID: " ^ reason))
  else if
    starts_with ~prefix:"http://" value || starts_with ~prefix:"https://" value
  then
    match normalize_pds value with
    | Ok pds -> Ok (Pds pds)
    | Error pds_reason -> (
        match normalized_web_url value with
        | Ok at_uri -> Ok (Record at_uri)
        | Error web_reason ->
            Error
              (Validation
                 ("unsupported resource URL: " ^ pds_reason ^ "; " ^ web_reason))
        )
  else
    match (Syntax.validate_handle value, Syntax.validate_nsid value) with
    | Syntax.Valid, Syntax.Valid when likely_nsid value -> Ok (Lexicon value)
    | Syntax.Valid, _ -> Ok (Identity (String.lowercase_ascii value))
    | Syntax.Invalid _, Syntax.Valid -> Ok (Lexicon value)
    | Syntax.Invalid _, Syntax.Invalid reason ->
        Error
          (Validation
             ("expected a handle, DID, AT URI, NSID, PDS URL, or supported AT \
               Protocol web URL: " ^ reason))

let validate_override = function
  | None -> Ok None
  | Some value -> (
      match normalize_pds value with
      | Ok value -> Ok (Some value)
      | Error reason -> Error (Validation ("PDS URL: " ^ reason)))

(** Resolve and fetch one resource through its selected read path. *)
let get ?auth ?pds value =
  match classify value with
  | Error error -> Lwt.return (Error error)
  | Ok (Identity value) ->
      let open Lwt.Syntax in
      let+ result = Identity.resolve value in
      Result.map_error (fun error -> Identity_failure error) result
      |> Result.map (fun value -> Identity_result value)
  | Ok (Record value) -> (
      match validate_override pds with
      | Error error -> Lwt.return (Error error)
      | Ok pds ->
          let open Lwt.Syntax in
          let+ result = Record.get ?auth ?pds value in
          Result.map_error (fun error -> Identity_failure error) result
          |> Result.map (fun value -> Record_result value))
  | Ok (Lexicon value) -> (
      match validate_override pds with
      | Error error -> Lwt.return (Error error)
      | Ok pds ->
          let open Lwt.Syntax in
          let+ result = Lexicon.get ?auth ?pds value in
          Result.map_error (fun error -> Lexicon_failure error) result
          |> Result.map (fun value -> Lexicon_result value))
  | Ok (Pds pds) ->
      let endpoint = Pds.describe_url pds in
      let open Lwt.Syntax in
      let+ response = Pds.describe ?auth pds in
      Ok (Pds_result { pds; endpoint; response })
