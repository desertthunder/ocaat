type provenance = {
  source : string;
  endpoint : string;
  fetched_at : string;
  did : string option;
  pds : string option;
}
(** Provenance attached to a successful result document. *)

type t = {
  kind : string;
  data : Yojson.Safe.t;
  meta : provenance;
  summary : Yojson.Safe.t option;
}
(** A versioned result document before rendering.

    [summary] is presentation-only data. It is used by Markdown formatters and
    is intentionally excluded from the JSON envelope so [data] remains the
    authoritative protocol payload. *)

(** Return the current UTC time in the document timestamp format. *)
let fetched_at () =
  let tm = Unix.gmtime (Unix.gettimeofday ()) in
  Printf.sprintf "%04d-%02d-%02dT%02d:%02d:%02dZ" (tm.tm_year + 1900)
    (tm.tm_mon + 1) tm.tm_mday tm.tm_hour tm.tm_min tm.tm_sec

(** Build a document with a fresh provenance timestamp. *)
let make ?did ?pds ?summary ~source ~endpoint ~kind data =
  {
    kind;
    data;
    meta = { source; endpoint; fetched_at = fetched_at (); did; pds };
    summary;
  }

(** Render provenance as the [meta] object used by the document contract. *)
let provenance_to_json provenance =
  let fields =
    [
      ("source", `String provenance.source);
      ("endpoint", `String provenance.endpoint);
      ("fetched_at", `String provenance.fetched_at);
    ]
  in
  let fields =
    match provenance.did with
    | None -> fields
    | Some did -> fields @ [ ("did", `String did) ]
  in
  let fields =
    match provenance.pds with
    | None -> fields
    | Some pds -> fields @ [ ("pds", `String pds) ]
  in
  `Assoc fields

(** Convert a document to its [ocaat.document.v1] JSON envelope. *)
let to_json document =
  `Assoc
    [
      ("schema", `String "ocaat.document.v1");
      ("kind", `String document.kind);
      ("data", document.data);
      ("meta", provenance_to_json document.meta);
    ]
