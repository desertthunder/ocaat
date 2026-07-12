(** Tempest account migration flow.

    It is intentionally step-oriented such that each command reads/writes
    explicit artifacts, and commands fail before network access when required
    secrets or artifacts are missing. *)

type error = string

type settings = {
  artifact_dir : string;
  old_pds : string;
  old_login_pds : string;
  old_auth_pds : string;
  tempest : string;
  tempest_service_did : string;
  did : string;
  handle : string;
  email : string option;
  old_password : string option;
  tempest_password : string option;
  old_session_path : string;
  service_auth_path : string;
  car_path : string;
  source_blobs_path : string;
  create_account_path : string;
  import_repo_path : string;
  status_path : string;
  missing_blobs_path : string;
  plc_recommended_path : string;
  plc_token_path : string;
  plc_signed_path : string;
  plc_submit_path : string;
  activate_path : string;
}

(** XRPC methods used by the migration flow. *)
type xrpc_method =
  | Server_create_account
  | Server_create_session
  | Server_get_service_auth
  | Server_get_session
  | Server_refresh_session
  | Server_check_account_status
  | Server_activate_account
  | Sync_get_repo
  | Sync_list_blobs
  | Sync_get_blob
  | Repo_import_repo
  | Repo_list_missing_blobs
  | Repo_upload_blob
  | Identity_get_recommended_did_credentials
  | Identity_request_plc_operation_signature
  | Identity_sign_plc_operation
  | Identity_submit_plc_operation

(** Convert a migration XRPC method variant to its atproto NSID. *)
let xrpc_method_nsid = function
  | Server_create_account -> "com.atproto.server.createAccount"
  | Server_create_session -> "com.atproto.server.createSession"
  | Server_get_service_auth -> "com.atproto.server.getServiceAuth"
  | Server_get_session -> "com.atproto.server.getSession"
  | Server_refresh_session -> "com.atproto.server.refreshSession"
  | Server_check_account_status -> "com.atproto.server.checkAccountStatus"
  | Server_activate_account -> "com.atproto.server.activateAccount"
  | Sync_get_repo -> "com.atproto.sync.getRepo"
  | Sync_list_blobs -> "com.atproto.sync.listBlobs"
  | Sync_get_blob -> "com.atproto.sync.getBlob"
  | Repo_import_repo -> "com.atproto.repo.importRepo"
  | Repo_list_missing_blobs -> "com.atproto.repo.listMissingBlobs"
  | Repo_upload_blob -> "com.atproto.repo.uploadBlob"
  | Identity_get_recommended_did_credentials ->
      "com.atproto.identity.getRecommendedDidCredentials"
  | Identity_request_plc_operation_signature ->
      "com.atproto.identity.requestPlcOperationSignature"
  | Identity_sign_plc_operation -> "com.atproto.identity.signPlcOperation"
  | Identity_submit_plc_operation -> "com.atproto.identity.submitPlcOperation"

let xrpc_url ~base_url method_ =
  Http.xrpc_url ~base_url ~method_:(xrpc_method_nsid method_)

type step =
  | Login_source
  | Service_auth
  | Source_session_status
  | Export_car
  | List_source_blobs
  | Download_source_blobs
  | Create_account
  | Refresh_session
  | Import_repo
  | Status
  | Missing_blobs
  | Upload_missing_blobs
  | Plc_recommended
  | Plc_request_token
  | Plc_sign
  | Plc_submit
  | Activate
  | Full

(** Convert a migration step variant to the CLI subcommand name. *)
let step_name = function
  | Login_source -> "login-source"
  | Service_auth -> "service-auth"
  | Source_session_status -> "source-session-status"
  | Export_car -> "export-car"
  | List_source_blobs -> "list-source-blobs"
  | Download_source_blobs -> "download-source-blobs"
  | Create_account -> "create-account"
  | Refresh_session -> "refresh-session"
  | Import_repo -> "import-repo"
  | Status -> "status"
  | Missing_blobs -> "missing-blobs"
  | Upload_missing_blobs -> "upload-missing-blobs"
  | Plc_recommended -> "plc-recommended"
  | Plc_request_token -> "plc-request-token"
  | Plc_sign -> "plc-sign"
  | Plc_submit -> "plc-submit"
  | Activate -> "activate"
  | Full -> "full"

let env name default =
  match Sys.getenv_opt name with
  | Some "" | None -> default
  | Some value -> Some value

let env_or name default = Option.value ~default (env name None)

let required_env name =
  match env name None with
  | Some value -> Ok value
  | None -> Error (name ^ " is required for migration commands")

let join_path dir file =
  if Filename.is_relative file then Filename.concat dir file else file

(** Build migration settings from environment variables and an artifact dir.

    Account identity and PDS targets are required environment variables. *)
let settings ?artifact_dir () =
  let ( let* ) = Result.bind in
  let artifact_dir =
    Option.value ~default:(env_or "ARTIFACT_DIR" ".sandbox") artifact_dir
  in
  let* old_pds = required_env "OLD_PDS" in
  let old_pds = Http.normalize_base_url old_pds in
  let old_auth_pds =
    env "OLD_AUTH_PDS" None
    |> Option.value ~default:old_pds
    |> Http.normalize_base_url
  in
  let old_login_pds =
    env "OLD_LOGIN_PDS" None
    |> Option.value ~default:old_auth_pds
    |> Http.normalize_base_url
  in
  let* tempest = required_env "TEMPEST" in
  let tempest = Http.normalize_base_url tempest in
  let* tempest_service_did = required_env "TEMPEST_SERVICE_DID" in
  let* did = required_env "DID" in
  let* handle = required_env "HANDLE" in
  let path name file = env_or name (join_path artifact_dir file) in
  Ok
    {
      artifact_dir;
      old_pds;
      old_auth_pds;
      old_login_pds;
      tempest;
      tempest_service_did;
      did;
      handle;
      email = env "EMAIL" None;
      old_password = env "OLD_PASSWORD" None;
      tempest_password = env "TEMPEST_PASSWORD" None;
      old_session_path = path "OLD_SESSION_JSON" "old_session.json";
      service_auth_path =
        path "SERVICE_AUTH_JSON" "service_auth_create_account.json";
      car_path = path "REPO_CAR" "tempestpds.repo.car";
      source_blobs_path = path "SOURCE_BLOBS_JSON" "source_blobs.json";
      create_account_path =
        path "TEMPEST_CREATE_ACCOUNT_JSON" "tempest_create_account.json";
      import_repo_path =
        path "TEMPEST_IMPORT_REPO_JSON" "tempest_import_repo.json";
      status_path = path "TEMPEST_STATUS_JSON" "tempest_account_status.json";
      missing_blobs_path =
        path "TEMPEST_MISSING_BLOBS_JSON" "tempest_missing_blobs.json";
      plc_recommended_path = path "PLC_RECOMMENDED_JSON" "plc_recommended.json";
      plc_token_path = path "PLC_TOKEN_JSON" "plc_token.json";
      plc_signed_path =
        path "PLC_SIGNED_OPERATION_JSON" "plc_signed_operation.json";
      plc_submit_path = path "PLC_SUBMIT_JSON" "plc_submit.json";
      activate_path =
        path "TEMPEST_ACTIVATE_JSON" "tempest_activate_account.json";
    }

let ensure_artifact_dir settings =
  if not (Sys.file_exists settings.artifact_dir) then
    Unix.mkdir settings.artifact_dir 0o755

let require name = function
  | Some value when value <> "" -> Ok value
  | _ -> Error (name ^ " is required for this command")

let read_file path =
  try
    let channel = open_in_bin path in
    Fun.protect
      ~finally:(fun () -> close_in_noerr channel)
      (fun () -> really_input_string channel (in_channel_length channel))
    |> Result.ok
  with Sys_error reason -> Error reason

let write_file ~force path body = Output.Artifact.write_file ~force path body

let read_json path =
  match read_file path with
  | Error reason ->
      Error ("missing or unreadable artifact " ^ path ^ ": " ^ reason)
  | Ok body -> (
      match Yojson.Safe.from_string body with
      | `Assoc _ as json -> Ok json
      | _ -> Error ("expected JSON object in " ^ path)
      | exception Yojson.Json_error reason ->
          Error ("invalid JSON artifact " ^ path ^ ": " ^ reason))

let write_json ~force path json =
  write_file ~force path (Yojson.Safe.pretty_to_string json ^ "\n")

let existing_json_artifact path =
  Result.map
    (fun json ->
      match json with
      | `Assoc fields ->
          `Assoc (("_ocaat_reused_artifact", `String path) :: fields)
      | json ->
          `Assoc [ ("_ocaat_reused_artifact", `String path); ("value", json) ])
    (read_json path)

let existing_file_artifact path =
  match read_file path with
  | Error reason -> Error reason
  | Ok body ->
      Ok
        (`Assoc
           [
             ("_ocaat_reused_artifact", `String path);
             ("bytes", `Int (String.length body));
           ])

let if_existing_json_unless_force ~force path f =
  if Sys.file_exists path && not force then
    Lwt.return (existing_json_artifact path)
  else f ()

let if_existing_file_unless_force ~force path f =
  if Sys.file_exists path && not force then
    Lwt.return (existing_file_artifact path)
  else f ()

let json_field name = function
  | `Assoc fields -> List.assoc_opt name fields
  | _ -> None

let string_field name json =
  match json_field name json with
  | Some (`String value) -> Some value
  | _ -> None

let token_from_json path field =
  match read_json path with
  | Error reason -> Error reason
  | Ok json -> (
      match string_field field json with
      | Some token when token <> "" -> Ok token
      | _ -> Error (path ^ " does not contain " ^ field))

let old_access settings =
  match env "OLD_ACCESS" None with
  | Some token -> Ok token
  | None -> token_from_json settings.old_session_path "accessJwt"

let service_auth settings =
  match env "SERVICE_AUTH" None with
  | Some token -> Ok token
  | None -> token_from_json settings.service_auth_path "token"

let tempest_access settings =
  match env "TEMPEST_ACCESS" None with
  | Some token -> Ok token
  | None -> token_from_json settings.create_account_path "accessJwt"

let tempest_refresh settings =
  match env "TEMPEST_REFRESH" None with
  | Some token -> Ok token
  | None -> token_from_json settings.create_account_path "refreshJwt"

let plc_token settings =
  match env "PLC_TOKEN" None with
  | Some token -> Ok token
  | None -> token_from_json settings.plc_token_path "token"

let json_response (response : Http.response) =
  match Yojson.Safe.from_string response.Http.body with
  | `Assoc _ as json when response.status >= 200 && response.status < 300 ->
      Ok json
  | `Assoc fields ->
      let message =
        match
          (List.assoc_opt "message" fields, List.assoc_opt "error" fields)
        with
        | Some (`String message), _ -> message
        | _, Some (`String error) -> error
        | _ -> response.body
      in
      Error (Printf.sprintf "HTTP %d: %s" response.status message)
  | _ ->
      Error (Printf.sprintf "HTTP %d returned non-object JSON" response.status)
  | exception Yojson.Json_error _ ->
      Error (Printf.sprintf "HTTP %d returned non-JSON body" response.status)

let log_json label json =
  Fmt.epr "%s: %s@." label (Yojson.Safe.to_string (Output.redact_json json))

let get_json ?auth url =
  let open Lwt.Syntax in
  let+ response = Http.get_text ?auth url in
  json_response response

let post_json ?auth ~json url =
  let open Lwt.Syntax in
  let+ response = Http.post_json ?auth ~json url in
  json_response response

(** Create a source PDS session and write [old_session.json]. *)
let login_source ~force settings =
  if_existing_json_unless_force ~force settings.old_session_path @@ fun () ->
  match require "OLD_PASSWORD" settings.old_password with
  | Error reason -> Lwt.return (Error reason)
  | Ok password -> (
      let identifier = env_or "OLD_IDENTIFIER" settings.handle in
      let payload =
        [ ("identifier", `String identifier); ("password", `String password) ]
        |> fun fields ->
        match env "OLD_AUTH_FACTOR_TOKEN" None with
        | None -> `Assoc fields
        | Some token -> `Assoc (("authFactorToken", `String token) :: fields)
      in
      let url =
        xrpc_url ~base_url:settings.old_login_pds Server_create_session
          ~params:[]
      in
      let open Lwt.Syntax in
      let+ result = post_json ~json:payload url in
      match result with
      | Error reason -> Error reason
      | Ok (`Assoc fields) ->
          let json =
            `Assoc
              (("_tempest_old_login_pds", `String settings.old_login_pds)
              :: ("_tempest_old_auth_pds", `String settings.old_auth_pds)
              :: ("_tempest_old_identifier", `String identifier)
              :: fields)
          in
          Result.map
            (fun () -> json)
            (write_json ~force settings.old_session_path json)
      | Ok _ -> Error "createSession returned non-object JSON")

(** Request service auth for creating the account on Tempest. *)
let get_service_auth ~force settings =
  if_existing_json_unless_force ~force settings.service_auth_path @@ fun () ->
  match old_access settings with
  | Error reason -> Lwt.return (Error reason)
  | Ok auth ->
      let url =
        xrpc_url ~base_url:settings.old_pds Server_get_service_auth
          ~params:
            [
              ("aud", settings.tempest_service_did);
              ("lxm", xrpc_method_nsid Server_create_account);
            ]
      in
      let open Lwt.Syntax in
      let+ result = get_json ~auth url in
      Result.bind result (fun json ->
          Result.map
            (fun () -> json)
            (write_json ~force settings.service_auth_path json))

(** Check whether the source session is accepted by the source PDS. *)
let source_session_status settings =
  match old_access settings with
  | Error reason -> Lwt.return (Error reason)
  | Ok auth ->
      let url =
        xrpc_url ~base_url:settings.old_auth_pds Server_get_session ~params:[]
      in
      get_json ~auth url

(** Export the source repository CAR to disk. *)
let export_car ~force settings =
  if_existing_file_unless_force ~force settings.car_path @@ fun () ->
  match Syntax.validate_did settings.did with
  | Invalid reason -> Lwt.return (Error ("invalid DID: " ^ reason))
  | Valid ->
      let url =
        xrpc_url ~base_url:settings.old_pds Sync_get_repo
          ~params:[ ("did", settings.did) ]
      in
      let open Lwt.Syntax in
      let+ response = Http.get_bytes url in
      if response.status < 200 || response.status >= 300 then
        Error (Printf.sprintf "HTTP %d exporting repo" response.status)
      else
        Result.map
          (fun () -> `Assoc [ ("bytes", `Int (String.length response.body)) ])
          (write_file ~force settings.car_path response.body)

(** List source blob CIDs and write [source_blobs.json]. *)
let list_source_blobs ~force settings =
  if_existing_json_unless_force ~force settings.source_blobs_path @@ fun () ->
  let url =
    xrpc_url ~base_url:settings.old_pds Sync_list_blobs
      ~params:[ ("did", settings.did) ]
  in
  let open Lwt.Syntax in
  let+ result = get_json url in
  Result.bind result (fun json ->
      Result.map
        (fun () -> json)
        (write_json ~force settings.source_blobs_path json))

let blob_path settings cid =
  Filename.concat settings.artifact_dir ("tempestpds.blob." ^ cid)

(** Download source blobs listed in [source_blobs.json]. *)
let download_source_blobs ~force ?progress settings =
  match read_json settings.source_blobs_path with
  | Error reason -> Lwt.return (Error reason)
  | Ok json -> (
      match json_field "cids" json with
      | Some (`List cids) ->
          let open Lwt.Syntax in
          let total = List.length cids in
          let rec loop downloaded skipped index = function
            | [] ->
                Lwt.return
                  (Ok
                     (`Assoc
                        [
                          ("downloaded", `Int downloaded);
                          ("skipped", `Int skipped);
                        ]))
            | `String cid :: rest -> (
                let path = blob_path settings cid in
                Option.iter
                  (fun progress ->
                    Output.Progress.event progress ~current:index ~total
                      "download-source-blobs"
                      [ ("cid", `String cid) ])
                  progress;
                if Sys.file_exists path && not force then
                  loop downloaded (skipped + 1) (index + 1) rest
                else
                  let url =
                    xrpc_url ~base_url:settings.old_pds Sync_get_blob
                      ~params:[ ("did", settings.did); ("cid", cid) ]
                  in
                  let* response = Http.get_bytes url in
                  if response.status < 200 || response.status >= 300 then
                    Lwt.return
                      (Error
                         (Printf.sprintf "HTTP %d downloading blob %s"
                            response.status cid))
                  else
                    match write_file ~force path response.body with
                    | Error reason -> Lwt.return (Error reason)
                    | Ok () -> loop (downloaded + 1) skipped (index + 1) rest)
            | _ :: _ ->
                Lwt.return (Error "source blob list contains a non-string CID")
          in
          loop 0 0 1 cids
      | _ ->
          Lwt.return
            (Error (settings.source_blobs_path ^ " does not contain cids")))

(** Create the inactive account on Tempest using prior service auth. *)
let create_account ~force settings =
  if_existing_json_unless_force ~force settings.create_account_path @@ fun () ->
  match
    ( require "EMAIL" settings.email,
      require "TEMPEST_PASSWORD" settings.tempest_password,
      service_auth settings )
  with
  | Error reason, _, _ | _, Error reason, _ | _, _, Error reason ->
      Lwt.return (Error reason)
  | Ok email, Ok password, Ok service_auth ->
      let json =
        `Assoc
          [
            ("did", `String settings.did);
            ("handle", `String settings.handle);
            ("email", `String email);
            ("password", `String password);
            ("serviceAuth", `String service_auth);
          ]
      in
      let url =
        xrpc_url ~base_url:settings.tempest Server_create_account ~params:[]
      in
      let open Lwt.Syntax in
      let+ result = post_json ~json url in
      Result.bind result (fun json ->
          Result.map
            (fun () -> json)
            (write_json ~force settings.create_account_path json))

(** Refresh the Tempest session artifact. *)
let refresh_session ~force settings =
  if_existing_json_unless_force ~force settings.create_account_path @@ fun () ->
  match tempest_refresh settings with
  | Error reason -> Lwt.return (Error reason)
  | Ok auth ->
      let url =
        xrpc_url ~base_url:settings.tempest Server_refresh_session ~params:[]
      in
      let open Lwt.Syntax in
      let+ result = post_json ~auth ~json:(`Assoc []) url in
      Result.bind result (fun json ->
          Result.map
            (fun () -> json)
            (write_json ~force settings.create_account_path json))

(** Import the exported CAR into Tempest. *)
let import_repo ~force settings =
  if_existing_json_unless_force ~force settings.import_repo_path @@ fun () ->
  match (tempest_access settings, read_file settings.car_path) with
  | Error reason, _ | _, Error reason -> Lwt.return (Error reason)
  | Ok auth, Ok body ->
      let url =
        xrpc_url ~base_url:settings.tempest Repo_import_repo ~params:[]
      in
      let open Lwt.Syntax in
      let+ response =
        Http.post_bytes ~auth ~content_type:"application/vnd.ipld.car" ~body url
      in
      Result.bind (json_response response) (fun json ->
          Result.map
            (fun () -> json)
            (write_json ~force settings.import_repo_path json))

(** Check authenticated Tempest migration/account status. *)
let check_status ~force settings =
  if_existing_json_unless_force ~force settings.status_path @@ fun () ->
  match tempest_access settings with
  | Error reason -> Lwt.return (Error reason)
  | Ok auth ->
      let url =
        xrpc_url ~base_url:settings.tempest Server_check_account_status
          ~params:[]
      in
      let open Lwt.Syntax in
      let+ result = get_json ~auth url in
      Result.bind result (fun json ->
          Result.map
            (fun () -> json)
            (write_json ~force settings.status_path json))

(** List blobs Tempest still needs after repo import. *)
let list_missing_blobs ~force settings =
  if_existing_json_unless_force ~force settings.missing_blobs_path @@ fun () ->
  match tempest_access settings with
  | Error reason -> Lwt.return (Error reason)
  | Ok auth ->
      let url =
        xrpc_url ~base_url:settings.tempest Repo_list_missing_blobs ~params:[]
      in
      let open Lwt.Syntax in
      let+ result = get_json ~auth url in
      Result.bind result (fun json ->
          Result.map
            (fun () -> json)
            (write_json ~force settings.missing_blobs_path json))

let mime_type path =
  if Filename.check_suffix path ".png" then "image/png"
  else if
    Filename.check_suffix path ".jpg" || Filename.check_suffix path ".jpeg"
  then "image/jpeg"
  else if Filename.check_suffix path ".webp" then "image/webp"
  else "application/octet-stream"

(** Upload each missing blob from local artifacts to Tempest. *)
let upload_missing_blobs ?progress settings =
  match (tempest_access settings, read_json settings.missing_blobs_path) with
  | Error reason, _ | _, Error reason -> Lwt.return (Error reason)
  | Ok auth, Ok json -> (
      match json_field "blobs" json with
      | Some (`List blobs) ->
          let open Lwt.Syntax in
          let total = List.length blobs in
          let rec loop count index = function
            | [] -> Lwt.return (Ok (`Assoc [ ("uploaded", `Int count) ]))
            | (`Assoc _ as blob) :: rest -> (
                match string_field "cid" blob with
                | None -> Lwt.return (Error "missing blob entry without cid")
                | Some cid -> (
                    Option.iter
                      (fun progress ->
                        Output.Progress.event progress ~current:index ~total
                          "upload-missing-blobs"
                          [ ("cid", `String cid) ])
                      progress;
                    let path = blob_path settings cid in
                    match read_file path with
                    | Error reason -> Lwt.return (Error reason)
                    | Ok body ->
                        let url =
                          xrpc_url ~base_url:settings.tempest Repo_upload_blob
                            ~params:[]
                        in
                        let* response =
                          Http.post_bytes ~auth ~content_type:(mime_type path)
                            ~body url
                        in
                        if response.status < 200 || response.status >= 300 then
                          Lwt.return
                            (Error
                               (Printf.sprintf "HTTP %d uploading blob %s"
                                  response.status cid))
                        else loop (count + 1) (index + 1) rest))
            | _ :: _ ->
                Lwt.return
                  (Error "missing blob list contains a non-object entry")
          in
          loop 0 1 blobs
      | _ ->
          Lwt.return
            (Error (settings.missing_blobs_path ^ " does not contain blobs")))

(** Fetch recommended PLC credentials from Tempest. *)
let plc_recommended ~force settings =
  if_existing_json_unless_force ~force settings.plc_recommended_path
  @@ fun () ->
  match tempest_access settings with
  | Error reason -> Lwt.return (Error reason)
  | Ok auth ->
      let url =
        xrpc_url ~base_url:settings.tempest
          Identity_get_recommended_did_credentials ~params:[]
      in
      let open Lwt.Syntax in
      let+ result = get_json ~auth url in
      Result.bind result (fun json ->
          Result.map
            (fun () -> json)
            (write_json ~force settings.plc_recommended_path json))

(** Request a PLC operation token/signature from the old PDS. *)
let plc_request_token ~force settings =
  if_existing_json_unless_force ~force settings.plc_token_path @@ fun () ->
  match old_access settings with
  | Error reason -> Lwt.return (Error reason)
  | Ok auth ->
      let url =
        xrpc_url ~base_url:settings.old_auth_pds
          Identity_request_plc_operation_signature ~params:[]
      in
      let json =
        match settings.old_password with
        | None -> `Assoc []
        | Some password -> `Assoc [ ("password", `String password) ]
      in
      let open Lwt.Syntax in
      let+ response = Http.post_json ~auth ~json url in
      let result =
        if
          response.status >= 200 && response.status < 300
          && String.trim response.body = ""
        then
          Ok
            (`Assoc [ ("requested", `Bool true); ("delivery", `String "email") ])
        else json_response response
      in
      Result.bind result (fun json ->
          Result.map
            (fun () -> json)
            (write_json ~force settings.plc_token_path json))

(** Ask the old PDS to sign the recommended PLC operation. *)
let plc_sign ~force settings =
  if_existing_json_unless_force ~force settings.plc_signed_path @@ fun () ->
  match
    ( old_access settings,
      read_json settings.plc_recommended_path,
      plc_token settings )
  with
  | Error reason, _, _ | _, Error reason, _ | _, _, Error reason ->
      Lwt.return (Error reason)
  | Ok auth, Ok recommended, Ok token ->
      let keep key acc =
        match json_field key recommended with
        | None -> acc
        | Some value -> (key, value) :: acc
      in
      let fields =
        [] |> keep "rotationKeys" |> keep "alsoKnownAs"
        |> keep "verificationMethods" |> keep "services"
      in
      let json = `Assoc (("token", `String token) :: fields) in
      let url =
        xrpc_url ~base_url:settings.old_auth_pds Identity_sign_plc_operation
          ~params:[]
      in
      let open Lwt.Syntax in
      let+ result = post_json ~auth ~json url in
      Result.bind result (fun json ->
          Result.map
            (fun () -> json)
            (write_json ~force settings.plc_signed_path json))

(** Submit the signed PLC operation through Tempest. *)
let plc_submit ~force settings =
  if_existing_json_unless_force ~force settings.plc_submit_path @@ fun () ->
  match (tempest_access settings, read_json settings.plc_signed_path) with
  | Error reason, _ | _, Error reason -> Lwt.return (Error reason)
  | Ok auth, Ok signed -> (
      match json_field "operation" signed with
      | None ->
          Lwt.return
            (Error (settings.plc_signed_path ^ " does not contain operation"))
      | Some operation ->
          let json = `Assoc [ ("operation", operation) ] in
          let url =
            xrpc_url ~base_url:settings.tempest Identity_submit_plc_operation
              ~params:[]
          in
          let open Lwt.Syntax in
          let+ result = post_json ~auth ~json url in
          Result.bind result (fun json ->
              Result.map
                (fun () -> json)
                (write_json ~force settings.plc_submit_path json)))

(** Activate the migrated Tempest account. *)
let activate ~force settings =
  if_existing_json_unless_force ~force settings.activate_path @@ fun () ->
  match tempest_access settings with
  | Error reason -> Lwt.return (Error reason)
  | Ok auth ->
      let url =
        xrpc_url ~base_url:settings.tempest Server_activate_account ~params:[]
      in
      let open Lwt.Syntax in
      let+ result = post_json ~auth ~json:(`Assoc []) url in
      Result.bind result (fun json ->
          Result.map
            (fun () -> json)
            (write_json ~force settings.activate_path json))

let bind_lwt result f =
  let open Lwt.Syntax in
  let* result = result in
  match result with Error _ as error -> Lwt.return error | Ok _ -> f ()

(** Run the non-activation migration sequence. *)
let full ~force ?progress settings =
  bind_lwt (login_source ~force settings) (fun () ->
      bind_lwt (get_service_auth ~force settings) (fun () ->
          bind_lwt (export_car ~force settings) (fun () ->
              bind_lwt (list_source_blobs ~force settings) (fun () ->
                  bind_lwt (download_source_blobs ~force ?progress settings)
                    (fun () ->
                      bind_lwt (create_account ~force settings) (fun () ->
                          bind_lwt (import_repo ~force settings) (fun () ->
                              bind_lwt (check_status ~force settings) (fun () ->
                                  list_missing_blobs ~force settings))))))))

(** Run one migration step. *)
let run ?(force = false) ?progress step settings =
  ensure_artifact_dir settings;
  match step with
  | Login_source -> login_source ~force settings
  | Service_auth -> get_service_auth ~force settings
  | Source_session_status -> source_session_status settings
  | Export_car -> export_car ~force settings
  | List_source_blobs -> list_source_blobs ~force settings
  | Download_source_blobs -> download_source_blobs ~force ?progress settings
  | Create_account -> create_account ~force settings
  | Refresh_session -> refresh_session ~force settings
  | Import_repo -> import_repo ~force settings
  | Status -> check_status ~force settings
  | Missing_blobs -> list_missing_blobs ~force settings
  | Upload_missing_blobs -> upload_missing_blobs ?progress settings
  | Plc_recommended -> plc_recommended ~force settings
  | Plc_request_token -> plc_request_token ~force settings
  | Plc_sign -> plc_sign ~force settings
  | Plc_submit -> plc_submit ~force settings
  | Activate -> activate ~force settings
  | Full -> full ~force ?progress settings
