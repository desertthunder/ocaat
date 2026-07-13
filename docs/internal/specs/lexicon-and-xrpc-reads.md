---
title: Lexicon and XRPC reads
status: complete
---

## Purpose

Let users inspect the schema behind an NSID and make deliberate read-only XRPC
queries without treating an arbitrary remote service as an implicit fallback.

## Commands

```text
ocaat lexicon get <nsid>
ocaat lexicon describe <nsid>
ocaat xrpc call <nsid> [--param <key=value>]...
ocaat xrpc describe <nsid>
ocaat xrpc query <nsid> [--param <key=value>]...
```

Xrpc query remains a compatibility alias for xrpc call. Call accepts query
methods only in the first release and requires an explicit --pds or OCAAT_PDS.
Describe resolves the Lexicon and reports the selected definition and method
kind without making a procedure call.

## Lexicon resolution contract

For a network-published Lexicon, derive the authority domain from the NSID,
read its _lexicon DNS TXT DID, resolve that DID document, discover its PDS, then
read the com.atproto.lexicon.schema record whose record key equals the NSID.
Validate that the returned document id equals the requested NSID.

The resolver rejects redirects, validates endpoint URLs, bounds response size,
uses conservative timeouts, and never overwrites trusted local sources. Bundled
or explicitly configured local sources may be added later; this release makes
the network path and its provenance explicit.

## Current state

The generic XRPC client supports GET queries and key-value parameters.
Lexicon get/describe and XRPC describe use the DNS → DID → PDS resolution path and
the shared document envelope.

## Acceptance criteria

- Lexicon get returns a validated document and each DNS, DID, and PDS source is
  traceable in provenance or diagnostics.
- A mismatched or malformed Lexicon is rejected.
- XRPC call validates its NSID and parameters before opening a connection.
- XRPC call cannot invoke procedures in this release.
- XRPC describe never uses a PDS response as a substitute for the Lexicon.

## Verification

```sh
dune runtest
dune exec -- ocaat xrpc call com.atproto.server.describeServer --pds https://tempest.desertthunder.dev --format json
dune exec -- ocaat xrpc describe com.atproto.repo.getRecord --format json
```

Executable-boundary fixtures cover DNS TXT data, DID documents, Lexicon records,
malformed JSON, redirects, response-size limits, and source mismatches.

## Subsequent planned work

XRPC procedures, binary requests and responses, custom request headers,
streaming subscriptions, local Lexicon linting, publishing, and diffing belong
to later specifications.
