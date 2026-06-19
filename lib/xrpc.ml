(** Generic XRPC query support. *)

(** Split one [k=v] query parameter argument. *)
let split_param value =
  match String.index_opt value '=' with
  | None -> Error ("parameter must have k=v shape: " ^ value)
  | Some 0 -> Error ("parameter key is empty: " ^ value)
  | Some index ->
      let key = String.sub value 0 index in
      let value =
        String.sub value (index + 1) (String.length value - index - 1)
      in
      Ok (key, value)

(** Parse repeated [--param k=v] CLI values into URI query pairs. *)
let parse_params values =
  let rec loop acc = function
    | [] -> Ok (List.rev acc)
    | value :: rest -> (
        match split_param value with
        | Ok pair -> loop (pair :: acc) rest
        | Error reason -> Error reason)
  in
  loop [] values

(** Validate an XRPC method NSID and build the GET request URL. *)
let query_url ~pds ~method_ ~params =
  match Syntax.validate_nsid method_ with
  | Invalid reason -> Error ("invalid XRPC method NSID: " ^ reason)
  | Valid -> Ok (Http.xrpc_url ~base_url:pds ~method_ ~params)

(** Execute an XRPC query against a PDS/service base URL. *)
let query ?auth ~pds ~method_ ~params () =
  let open Lwt.Syntax in
  match query_url ~pds ~method_ ~params with
  | Error reason -> Lwt.return (Error reason)
  | Ok url ->
      let+ response = Http.get_text ?auth url in
      Ok response
