type t = { kind : string; message : string; status : int option }
(** Sanitized, versioned error information for machine-readable output. *)

(** Build an error document, optionally retaining an HTTP status. *)
let make ?status ~kind ~message () = { kind; message; status }

(** Convert an error to its [ocaat.error.v1] JSON envelope. *)
let to_json error =
  let fields =
    [ ("kind", `String error.kind); ("message", `String error.message) ]
  in
  let fields =
    match error.status with
    | None -> fields
    | Some status -> ("status", `Int status) :: fields
  in
  `Assoc
    [
      ("schema", `String "ocaat.error.v1"); ("error", `Assoc (List.rev fields));
    ]
