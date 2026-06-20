(** Relay read-only inspection operations. *)

type method_ =
  | List_repos
  | List_repos_by_collection
  | Get_repo_status
  | List_hosts
  | Get_host_status

let method_nsid = function
  | List_repos -> "com.atproto.sync.listRepos"
  | List_repos_by_collection -> "com.atproto.sync.listReposByCollection"
  | Get_repo_status -> "com.atproto.sync.getRepoStatus"
  | List_hosts -> "com.atproto.sync.listHosts"
  | Get_host_status -> "com.atproto.sync.getHostStatus"

let list_repos_url ?collection ?cursor host =
  let method_, params =
    match collection with
    | Some collection when collection <> "" ->
        ( List_repos_by_collection,
          [ ("limit", "500"); ("collection", collection) ] )
    | _ -> (List_repos, [ ("limit", "500") ])
  in
  let params =
    match cursor with
    | None -> params
    | Some cursor -> ("cursor", cursor) :: params
  in
  Http.xrpc_url ~base_url:host ~method_:(method_nsid method_) ~params

let list_hosts_url ?cursor host =
  let params =
    match cursor with
    | None -> [ ("limit", "500") ]
    | Some cursor -> [ ("limit", "500"); ("cursor", cursor) ]
  in
  Http.xrpc_url ~base_url:host ~method_:(method_nsid List_hosts) ~params

let repo_status_url host did =
  Http.xrpc_url ~base_url:host
    ~method_:(method_nsid Get_repo_status)
    ~params:[ ("did", did) ]

let host_status_url host hostname =
  Http.xrpc_url ~base_url:host
    ~method_:(method_nsid Get_host_status)
    ~params:[ ("hostname", hostname) ]

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

let cursor_from_body body =
  match Yojson.Safe.from_string body with
  | json -> string_field "cursor" json
  | exception Yojson.Json_error _ -> None

let array_from_body ~field body =
  match Yojson.Safe.from_string body with
  | json -> (
      match json_field field json with
      | Some (`List values) -> Ok values
      | _ -> Error (Printf.sprintf "response does not contain a %s array" field)
      )
  | exception Yojson.Json_error reason -> Error ("invalid JSON: " ^ reason)

let list_all ?auth ~url ~field host =
  let open Lwt.Syntax in
  let rec loop cursor acc =
    let* response = Http.get_text ?auth (url ?cursor host) in
    if response.status < 200 || response.status >= 300 then
      Lwt.return (Error response)
    else
      match array_from_body ~field response.body with
      | Error reason -> Lwt.return (Error { Http.status = 0; body = reason })
      | Ok values ->
          let acc = List.rev_append values acc in
          let next = cursor_from_body response.body in
          if next = None || next = Some "" then Lwt.return (Ok (List.rev acc))
          else loop next acc
  in
  loop None []

let list_accounts ?auth ?collection host =
  match collection with
  | Some collection when collection <> "" -> (
      match Syntax.validate_nsid collection with
      | Invalid reason -> Lwt.return (Error { Http.status = 0; body = reason })
      | Valid ->
          list_all ?auth
            ~url:(fun ?cursor host -> list_repos_url ~collection ?cursor host)
            ~field:"repos" host)
  | _ ->
      list_all ?auth
        ~url:(fun ?cursor host -> list_repos_url ?cursor host)
        ~field:"repos" host

let list_hosts ?auth host =
  list_all ?auth ~url:list_hosts_url ~field:"hosts" host

let account_status ?auth ~relay ~did () =
  match Syntax.validate_did did with
  | Invalid reason -> Lwt.return (Error ("invalid DID: " ^ reason))
  | Valid ->
      let open Lwt.Syntax in
      let+ response = Http.get_text ?auth (repo_status_url relay did) in
      Ok response

let host_status ?auth ~relay ~hostname () =
  let open Lwt.Syntax in
  let+ response = Http.get_text ?auth (host_status_url relay hostname) in
  Ok response

let repo_status_text json =
  match (bool_field "active" json, string_field "status" json) with
  | Some true, _ -> "active"
  | _, Some status -> status
  | _ -> "unknown"

let host_status_text json =
  string_field "status" json |> Option.value ~default:""

let rev_text json = string_field "rev" json |> Option.value ~default:""

let hostname_text json =
  string_field "hostname" json |> Option.value ~default:""

let account_count_text json =
  match int_field "accountCount" json with
  | Some value -> string_of_int value
  | None -> ""

let seq_text json =
  match int_field "seq" json with
  | Some value -> string_of_int value
  | None -> ""
