(** Direct read-only access to the PLC directory. *)

(** The public PLC directory used when no host override is supplied. *)
let default_host = "https://plc.directory"

type failure = Identity.failure
(** PLC reads reuse the shared identity failure categories. *)

type query = { did : string; endpoint : string; response : Http.response }
(** One PLC request together with its normalized DID and endpoint. *)

let json_field name = function
  | `Assoc fields -> List.assoc_opt name fields
  | _ -> None

let is_plc_did did = String.starts_with ~prefix:"did:plc:" did

let endpoint ~plc_host ~did suffix =
  Http.normalize_base_url plc_host ^ "/" ^ did ^ suffix

(** Build the current PLC data endpoint for a DID. *)
let data_url ~plc_host ~did = endpoint ~plc_host ~did "/data"

(** Build the chronological PLC operation-log endpoint for a DID. *)
let history_url ~plc_host ~did = endpoint ~plc_host ~did "/log"

let resolve_did ?plc_host actor =
  match Identity.parse_input actor with
  | Error error -> Lwt.return (Error error)
  | Ok (Identity.Did did) ->
      if is_plc_did did then Lwt.return (Ok did)
      else
        Lwt.return
          (Error
             (Identity.Validation
                ("PLC commands require a did:plc identifier; got " ^ did)))
  | Ok (Identity.Handle _) -> (
      let open Lwt.Syntax in
      let+ result = Identity.resolve ?plc_host actor in
      match result with
      | Error error -> Error error
      | Ok resolved when is_plc_did resolved.did -> Ok resolved.did
      | Ok resolved ->
          Error
            (Identity.Validation
               ("PLC commands require a did:plc identifier; resolved "
              ^ resolved.did)))

(** Fetch current PLC data for a DID or handle. *)
let show ?plc_host actor =
  let plc_host = Option.value ~default:default_host plc_host in
  let open Lwt.Syntax in
  let* did_result = resolve_did ~plc_host actor in
  match did_result with
  | Error error -> Lwt.return (Error error)
  | Ok did ->
      let endpoint = data_url ~plc_host ~did in
      let+ response = Http.get_text endpoint in
      Ok { did; endpoint; response }

(** Fetch the PLC operation log for a DID or handle. *)
let history ?plc_host actor =
  let plc_host = Option.value ~default:default_host plc_host in
  let open Lwt.Syntax in
  let* did_result = resolve_did ~plc_host actor in
  match did_result with
  | Error error -> Lwt.return (Error error)
  | Ok did ->
      let endpoint = history_url ~plc_host ~did in
      let+ response = Http.get_text endpoint in
      Ok { did; endpoint; response }

let parse_json endpoint body =
  match Yojson.Safe.from_string body with
  | json -> Ok json
  | exception Yojson.Json_error reason ->
      Error (endpoint ^ " returned invalid JSON: " ^ reason)

(** Validate the current PLC response while retaining its complete object. *)
let parse_data_response ~endpoint body =
  match parse_json endpoint body with
  | Error _ as error -> error
  | Ok (`Assoc _ as json) -> Ok json
  | Ok _ -> Error (endpoint ^ " returned PLC data that is not a JSON object")

(** Parse and chronologically order a PLC operation log. *)
let parse_history_response ~endpoint body =
  match parse_json endpoint body with
  | Error _ as error -> error
  | Ok (`List operations) ->
      let rec add index acc = function
        | [] -> Ok acc
        | (`Assoc _ as operation) :: rest -> (
            match json_field "createdAt" operation with
            | Some (`String created_at) when created_at <> "" ->
                add (index + 1) ((created_at, index, operation) :: acc) rest
            | None | Some (`String "") | Some _ ->
                add (index + 1) (("", index, operation) :: acc) rest)
        | _ :: _ -> Error (endpoint ^ " returned a non-object PLC operation")
      in
      let sorted =
        match add 0 [] operations with
        | Error reason -> Error reason
        | Ok indexed ->
            let indexed = List.rev indexed in
            if List.for_all (fun (created_at, _, _) -> created_at <> "") indexed
            then
              let compare (created_a, index_a, _) (created_b, index_b, _) =
                match String.compare created_a created_b with
                | 0 -> Int.compare index_a index_b
                | comparison -> comparison
              in
              Ok
                (List.sort compare indexed
                |> List.map (fun (_, _, operation) -> operation))
            else Ok operations
      in
      Result.map (fun operations -> `List operations) sorted
  | Ok _ -> Error (endpoint ^ " returned a PLC log that is not an array")
