---
title: Lexicons and XRPC
description: Resolve published Lexicons and inspect read-only XRPC methods.
---

## Overview

Lexicons describe records and XRPC methods.

`ocaat` resolves a published Lexicon from its NSID and returns the original schema with the
resolution trail that produced it.

## XRPC queries

Use `xrpc call|query` for an explicitly selected PDS. The first release permits only
known query methods and encodes repeated `--param K=V` values as URL query
parameters.

```sh
ocaat xrpc call com.atproto.server.describeServer \
  --pds https://tempest.desertthunder.dev --format json
```

Procedures are rejected before a request is opened.

## Lexicon discovery

For an NSID, `ocaat` removes the final name segment and reverses the authority
segments. It reads `_lexicon.<authority>` as a DNS TXT record, resolves the
returned DID document, selects its declared PDS, and fetches the
`com.atproto.lexicon.schema` record whose key is the requested NSID.

```sh
ocaat lexicon get com.atproto.repo.getRecord --format json
ocaat lexicon describe com.atproto.repo.getRecord --format json
ocaat xrpc describe com.atproto.repo.getRecord --format json
```

The returned schema must be Lexicon version 1, carry the requested `id`, use
the expected record URI and `$type`, and contain typed definitions.

Redirects, invalid JSON, oversized responses, and missing or conflicting DNS
authority records fail the command.

## Supported methods

`lexicon describe` and `xrpc describe` select the `main` definition, or the
only definition when a Lexicon contains one. The result reports its Lexicon
type, such as `query`, `procedure`, `record`, or `subscription`.

## Output

Results use the `ocaat.document.v1` envelope. The schema remains in `data`;
`meta.sources` records the DNS name, DID document endpoint, and PDS record
endpoint used during resolution. The top-level provenance points to the PDS
record that supplied the schema.

## Errors

Errors identify the resolution stage, such as DNS authority lookup, DID
resolution, or PDS record read. Remote response bodies and credentials are
redacted before rendering.

## Reference

See the [manual](/reference/commands) for the full CLI surface and
the [Lexicon specification](https://atproto.com/specs/lexicon) for underlying
publication rules.
