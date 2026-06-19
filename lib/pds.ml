(** PDS inspection operations. *)

(** NSID for the PDS describeServer query. *)
let describe_method = "com.atproto.server.describeServer"

(** Build the describeServer URL for a PDS host or service URL. *)
let describe_url host =
  Http.xrpc_url ~base_url:host ~method_:describe_method ~params:[]

(** Call [com.atproto.server.describeServer] on a PDS.

    The endpoint is an unauthenticated query in normal PDS deployments, but an
    optional bearer token is accepted for consistency with the shared CLI
    context. *)
let describe ?auth host = Http.get_text ?auth (describe_url host)
