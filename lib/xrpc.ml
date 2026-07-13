(** Generic read-only XRPC query support. *)

(** Method classification used by the first-release GET-only safety boundary. *)
type method_kind = Query | Procedure | Unknown

let known_procedure method_ =
  List.mem method_
    [
      "com.atproto.repo.applyWrites";
      "com.atproto.repo.createRecord";
      "com.atproto.repo.deleteRecord";
      "com.atproto.repo.importRepo";
      "com.atproto.repo.putRecord";
      "com.atproto.repo.uploadBlob";
      "com.atproto.server.activateAccount";
      "com.atproto.server.createAccount";
      "com.atproto.server.createAppPassword";
      "com.atproto.server.createInviteCode";
      "com.atproto.server.createInviteCodes";
      "com.atproto.server.createSession";
      "com.atproto.server.deactivateAccount";
      "com.atproto.server.deleteAccount";
      "com.atproto.server.getServiceAuth";
      "com.atproto.server.refreshSession";
      "com.atproto.server.requestAccountDelete";
      "com.atproto.server.requestEmailConfirmation";
      "com.atproto.server.requestEmailUpdate";
      "com.atproto.server.resetPassword";
      "com.atproto.server.revokeAppPassword";
      "com.atproto.server.sendEmail";
      "com.atproto.server.updateEmail";
    ]

(** Read methods covered by the first-release GET-only surface. *)
let known_query method_ =
  List.mem method_
    [
      "com.atproto.identity.resolveHandle";
      "com.atproto.repo.describeRepo";
      "com.atproto.repo.getRecord";
      "com.atproto.repo.listMissingBlobs";
      "com.atproto.repo.listRecords";
      "com.atproto.server.checkAccountStatus";
      "com.atproto.server.describeServer";
      "com.atproto.server.getSession";
      "com.atproto.sync.getBlob";
      "com.atproto.sync.getHostStatus";
      "com.atproto.sync.getRepo";
      "com.atproto.sync.getRepoStatus";
      "com.atproto.sync.listBlobs";
      "com.atproto.sync.listHosts";
      "com.atproto.sync.listRepos";
      "com.atproto.sync.listReposByCollection";
    ]

(** Classify methods known to the first-release safety guard. *)
let method_kind method_ =
  if known_procedure method_ then Procedure
  else if known_query method_ then Query
  else Unknown

(** Split one [k=v] query parameter argument. *)
let split_param value =
  match String.index_opt value '=' with
  | None -> Error "parameter must have k=v shape"
  | Some 0 -> Error "parameter key is empty"
  | Some index ->
      let key = String.sub value 0 index in
      let value =
        String.sub value (index + 1) (String.length value - index - 1)
      in
      Ok (key, value)

(** Parse repeated [--param k=v] CLI values into URI query pairs. *)
let parse_params values =
  let valid_param_key key =
    let len = String.length key in
    let is_alpha = function 'a' .. 'z' | 'A' .. 'Z' -> true | _ -> false in
    let is_param_char = function
      | 'a' .. 'z' | 'A' .. 'Z' | '0' .. '9' | '_' -> true
      | _ -> false
    in
    if len = 0 then Error "parameter key is empty"
    else if len > 64 then Error "parameter key is longer than 64 characters"
    else if not (is_alpha key.[0]) then
      Error "parameter key must start with an ASCII letter"
    else
      let rec loop index =
        if index = len then Ok ()
        else if is_param_char key.[index] then loop (index + 1)
        else Error "parameter key must contain only letters, digits, or '_'"
      in
      loop 1
  in
  let valid_param_value value =
    let rec loop index =
      if index = String.length value then Ok ()
      else
        match value.[index] with
        | '\000' | '\r' | '\n' ->
            Error "parameter value contains a forbidden control character"
        | _ -> loop (index + 1)
    in
    loop 0
  in
  let validate (key, value) =
    match valid_param_key key with
    | Error reason -> Error reason
    | Ok () -> valid_param_value value
  in
  let rec loop acc = function
    | [] -> Ok (List.rev acc)
    | value :: rest -> (
        match split_param value with
        | Ok pair -> (
            match validate pair with
            | Ok () -> loop (pair :: acc) rest
            | Error reason -> Error reason)
        | Error reason -> Error reason)
  in
  loop [] values

(** Validate already split query parameters before building a request URL. *)
let validate_params params =
  match
    parse_params (List.map (fun (key, value) -> key ^ "=" ^ value) params)
  with
  | Ok _ -> Ok params
  | Error reason -> Error reason

(** Validate an XRPC method NSID and build the GET request URL. *)
let query_url ~pds ~method_ ~params =
  match Syntax.validate_nsid method_ with
  | Invalid reason -> Error ("invalid XRPC method NSID: " ^ reason)
  | Valid -> (
      match method_kind method_ with
      | Procedure ->
          Error
            ("XRPC method " ^ method_
           ^ " is a procedure; xrpc call only supports query methods")
      | Unknown ->
          Error
            ("XRPC method " ^ method_
           ^ " has no first-release query description; refusing to call an "
           ^ "unclassified method")
      | Query -> (
          match validate_params params with
          | Error reason -> Error ("invalid XRPC parameter: " ^ reason)
          | Ok params -> Ok (Http.xrpc_url ~base_url:pds ~method_ ~params)))

(** Execute an XRPC query against a PDS/service base URL. *)
let call ?auth ~pds ~method_ ~params () =
  let open Lwt.Syntax in
  match query_url ~pds ~method_ ~params with
  | Error reason -> Lwt.return (Error reason)
  | Ok url ->
      let+ response = Http.get_text ?auth url in
      Ok response

(** Compatibility name for [call]. *)
let query ?auth ~pds ~method_ ~params () = call ?auth ~pds ~method_ ~params ()
