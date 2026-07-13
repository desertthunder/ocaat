---
title: Resource Resolver
description: Resolves AT Protocol handles and DIDs into identity and PDS metadata.
---

## Overview

Use the `resolve` command when you have an account handle or DID and need the
identity document that describes the account.

The command returns the normalized DID, the fetched DID document, the first valid
handle claim, and the account's `AtprotoPersonalDataServer` service when the document
declares one.

```sh
ocaat resolve did:plc:oga6ppys7zwxlheuqmcm7dac --format json
ocaat resolve alice.example --format markdown
```

Resolution is read-only.

The command never asks an AppView, relay, backlink index, or PDS to resolve an identity.

## Args

`resolve` accepts:

- handles such as `alice.example`
- `did:plc` DIDs
- hostname-level `did:web` DIDs

Path-based `did:web` identifiers and other DID methods are rejected. A DID may
be syntactically valid and still be unsupported by atproto.

`resolve` reports that distinction before it opens a connection.

Handles are normalized to lowercase before they are resolved but DIDs remain
case-sensitive and are returned exactly as they appear in the input or DID document.

## Sources

The resolver follows the two handle methods defined by AT Protocol:

1. It queries the TXT record at `_atproto.<handle>` and accepts a single `did=<DID>`
   value.
2. If DNS has no usable answer, it requests `https://<handle>/.well-known/atproto-did`
   and reads the response body as a DID.

The DNS result takes precedence when both methods produce answers and the handle
is accepted only after the resolved DID document claims the same handle in its
`alsoKnownAs` array.

For a `did:plc` DID, `resolve` fetches `https://plc.directory/<DID>`.

For a hostname-level `did:web` DID, it fetches `https://<hostname>/.well-known/did.json`.

Loopback `did:web` identifiers may encode a localhost port as `%3A`, for example
`did:web:localhost%3A43152`, which use HTTP for local fixture and development servers.

See the [AT Protocol DID specification](https://atproto.com/specs/did) and
[handle specification](https://atproto.com/specs/handle) for the protocol
rules behind these lookups.

## DID Document Checks

The fetched document must be a JSON object whose `id` exactly matches the DID
that was requested or discovered. `resolve` takes the first syntactically
valid `at://<handle>` URI in `alsoKnownAs` as the document's claimed handle.

For PDS discovery, it takes the first service whose `id` ends in
`#atproto_pds` and whose `type` is `AtprotoPersonalDataServer`. Its
`serviceEndpoint` must be an HTTP(S) service URL without credentials, a query,
fragment, or path prefix.

An invalid matching PDS service is an error. The resolver does not silently choose
another service.

The resolver does not require a PDS service to be present.

Accounts can have a valid DID document during a migration or while their hosting
service is temporarily unavailable.

## Resolved Resources

Successful JSON output uses the shared `ocaat.document.v1` envelope. The
identity payload has this shape; the `document` and `pds` values retain the
protocol JSON returned by the source:

```json
{
  "schema": "ocaat.document.v1",
  "kind": "identity",
  "data": {
    "input": "alice.example",
    "did": "did:plc:...",
    "handle": "alice.example",
    "handleEvidence": {
      "handle": "alice.example",
      "source": "dns",
      "verified": true,
      "did": "did:plc:..."
    },
    "document": {},
    "pds": {
      "id": "#atproto_pds",
      "type": "AtprotoPersonalDataServer",
      "serviceEndpoint": "https://pds.example"
    }
  },
  "meta": {
    "source": "plc",
    "endpoint": "https://plc.directory/did:plc:...",
    "fetched_at": "2026-07-12T00:00:00Z",
    "did": "did:plc:...",
    "pds": "https://pds.example"
  }
}
```

When the input is a DID, a handle in the DID document is marked with
`source: "did-document"` and `verified: false`. The command has not performed
the reverse handle lookup in that case. The `meta.pds` value is the normalized
endpoint that later PDS-backed commands can select.

Markdown includes the same payload in its `Raw` section and adds a compact
summary and provenance section. JSON and Markdown redact credentials and other
sensitive fields through the shared output layer.

## PDS selection

Identity resolution discovers a PDS; it does not make a PDS request. Later
commands use the service endpoint from the resolved DID document for actor
reads. An explicit `--pds` applies only to a command that actually makes a PDS
request and remains visible as the request endpoint in its provenance.

## Errors

The command validates the input and DID method before network access. It then
reports distinct failure categories:

- validation errors for malformed identifiers, unsupported DID methods, DID
  document mismatches, and invalid PDS bindings;
- network errors when the resolver cannot reach a source;
- remote errors for non-success HTTP responses and malformed source bodies.

With `--format json`, errors are written to stderr as `ocaat.error.v1`
documents. Successful results go to stdout; diagnostics never share that
stream.

## Reference

- [AT Protocol DID specification](https://atproto.com/specs/did)
- [AT Protocol handle specification](https://atproto.com/specs/handle)
- [CLI Conventions](/development/cli-foundations/)
