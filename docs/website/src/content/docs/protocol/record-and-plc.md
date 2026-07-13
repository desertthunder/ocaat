---
title: Records and PLC
description: 
  > Read public repository records from their PDS and inspect did:plc directory evidence.
---

## Overview

Ocaat reads public records from the PDS named by an actor's DID document[^did].

It also reads the PLC directory directly for `did:plc` identities.

These commands do not use an AppView, relay, or backlink index as a fallback.

```text
ocaat record get <at-uri>
ocaat record list <handle-or-did> --collection <nsid> [--limit <n>] [--cursor <cursor>]
ocaat record list <handle-or-did> --collections
ocaat plc show <handle-or-did> [--plc-host <url>]
ocaat plc history <handle-or-did> [--plc-host <url>]
```

All commands support the shared output options described in the [manual](/reference/commands/).

## Record queries

`record get` accepts a complete AT URI. The URI must include an authority, a
collection NSID, and a record key:

```sh
ocaat record get at://did:plc:oga6ppys7zwxlheuqmcm7dac/app.bsky.actor.profile/self \
  --format json
```

Ocaat resolves the URI authority, replaces a handle with its DID, and calls
`com.atproto.repo.getRecord` on the selected PDS. The `record` document keeps
the response's `uri`, optional `cid`, and `value` fields in `data`.

`record list` has two distinct modes. Record-page mode requires
`--collection` and calls `com.atproto.repo.listRecords`:

```sh
ocaat record list did:plc:oga6ppys7zwxlheuqmcm7dac \
  --collection app.bsky.actor.profile \
  --limit 25 \
  --format json
```

The limit must be between 1 and 100; the default is 50. A supplied cursor is
validated before the request. The `records` document includes the normalized
repository DID, collection, returned records, and the next cursor when the PDS
provides one.

Collection-summary mode uses `--collections` and calls
`com.atproto.repo.describeRepo`:

```sh
ocaat record list did:plc:oga6ppys7zwxlheuqmcm7dac \
  --collections \
  --format json
```

This mode cannot be combined with `--collection`, `--limit`, or `--cursor`. It
returns the PDS's repository summary and collection names. It does not invent
records or fetch record values.

## PDS selection

Ocaat resolves the actor before making a record request. Without `--pds`, it
uses the normalized `AtprotoPersonalDataServer` service from the DID document.
An explicit `--pds` changes only the endpoint used for the record query and is
included in document provenance:

```sh
ocaat record list alice.example \
  --collection app.bsky.feed.post \
  --pds https://pds.example \
  --format json
```

If the resolved identity has no PDS service, the command stops with a
validation error and suggests an explicit PDS. Invalid handles, DIDs,
collections, limits, cursors, and AT URIs fail before any request is made.

## PLC Data

`plc show` reads current directory data from:

```text
https://plc.directory/<did>/data
```

`plc history` reads the operation log from `/log` in the directory's
chronological order. When every entry exposes `createdAt`, ocaat uses that field
to make the ordering explicit. A handle is resolved to a DID before the PLC
request. Both commands reject non-PLC DIDs rather than presenting PDS state as
PLC evidence.

Use `--plc-host` for a compatible directory or a local test service:

```sh
ocaat plc show did:plc:oga6ppys7zwxlheuqmcm7dac \
  --plc-host https://plc.directory \
  --format json
```

PLC results use `source: "plc"` and carry the directory endpoint and normalized DID in `meta`.

## Output

Successful results use the shared `ocaat.document.v1` envelope:

- `record` for `record get`;
- `records` for record pages and collection summaries;
- `plc` for current PLC data and history.

## Errors

Remote HTTP failures, invalid JSON, malformed protocol response shapes, and
network failures use the shared sanitized error document on stderr.

Credentials are redacted in errors, output, and fixture diagnostics.
The stable exit codes are documented in the [manual](/reference/commands/#exit-codes).

[^did]: https://www.w3.org/TR/did-1.1/
