---
title: Resource resolution and universal get
status: ready
---

## Purpose

Let a human or agent give ocaat one recognizable AT Protocol resource and
receive the correct read-only document without first learning service topology.

## Commands

~~~text
ocaat resolve <handle-or-did>
ocaat get <resource>
~~~

Resolve returns a normalized DID, the DID document, discovered PDS service, and
handle evidence when available.

Get dispatches by validated input:

| Input | Result kind |
| --- | --- |
| handle or DID | identity |
| AT URI | record |
| recognized AT Protocol web URL | normalized record |
| NSID | lexicon |
| PDS URL | pds |

## Source-selection contract

Handle resolution uses the AT Protocol handle-resolution algorithm rather than
an AppView fallback. DID documents are resolved using their declared method.
PDS-backed reads use the AtprotoPersonalDataServer service from the resolved DID
document. An explicit --pds overrides that PDS only for the endpoint request.

AppViews, relays, and backlink indexes are explicit later services. Ocaat must
not silently retry against one of them when a PDS request fails. Every result
reports the service that answered it.

## Current state

Syntax validation already covers handles, DIDs, AT URIs, NSIDs, and safe service
URLs. There is no identity module, DID resolver, web-URL normalizer, or command
dispatcher yet.

## Technical plan

- Add Identity with handle resolution, DID-document retrieval, service
  extraction, and normalized actor results.
- Support did:plc and did:web before accepting other DID methods. Return a
  validation error for unsupported methods rather than guessing.
- Add Resource to classify input only after syntax validation. Its dispatcher
  calls Identity, Record, Lexicon, or Pds; it does not duplicate their logic.
- Normalize only documented AT Protocol web URL shapes. Reject other web URLs
  with an actionable error instead of scraping pages.
- Cache is not required for the first release. A later cache must preserve
  fetched_at and never hide which source supplied a result.

## Acceptance criteria

- A handle resolves to a DID and a discovered PDS when its DID document has a
  valid PDS service binding.
- A DID returns its document and service information without an unrelated
  handle lookup.
- Get chooses exactly one resource branch and records the normalized input.
- --pds changes only the PDS request endpoint and remains visible in metadata.
- A failed PDS request does not contact an AppView, relay, or other fallback.

## Verification

~~~sh
dune runtest
dune exec -- ocaat resolve did:plc:oga6ppys7zwxlheuqmcm7dac --format json
dune exec -- ocaat get did:plc:oga6ppys7zwxlheuqmcm7dac --format markdown
dune exec -- ocaat get https://tempest.desertthunder.dev --format json
~~~

Use fixture DID documents and handle DNS or HTTPS responses for repeatable
tests. Add manual non-destructive checks only after fixture coverage is green.

## Subsequent planned work

Caching, alternate DID methods, AppView reads, collection discovery, and
backlinks build on this contract but do not alter its source-selection rule.
