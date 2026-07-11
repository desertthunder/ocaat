---
title: Record and PLC reads
status: ready
---

## Objective

Provide the core evidence an investigator needs about a public repository record
and the identity history that authorizes its PDS.

## Commands

~~~text
ocaat record get <at-uri>
ocaat record list <handle-or-did> --collection <nsid> [--limit <n>] [--cursor <cursor>]
ocaat record list <handle-or-did> --collections
ocaat plc show <handle-or-did>
ocaat plc history <handle-or-did>
~~~

The two record-list modes are mutually exclusive. The collection-summary mode
uses describeRepo; the record mode uses listRecords and returns the next cursor
when present.

Plc show returns the current PLC operation and normalized DID context. Plc
history returns the operation log in chronological order. A non-PLC DID produces
a clear validation result rather than an invented PLC history.

## Current state

Tempest exposes com.atproto.repo.getRecord, listRecords, and describeRepo as
public queries. The project has no Record, Plc, or Identity module yet.

## Technical plan

- Depend on the normalized actor and PDS result from Resource resolution.
- Parse AT URIs into DID, collection, and record key before constructing
  com.atproto.repo.getRecord.
- Preserve protocol record fields and CID values in data; add transport facts
  only in document metadata.
- Query PLC directly for did:plc operations. Do not treat a PDS account response
  as PLC directory evidence.
- Bound limit values and validate cursors and collection NSIDs before requests.

## Acceptance criteria

- Record get works with a DID AT URI and reports resolved PDS provenance.
- Record list returns a stable page, optional cursor, and validated collection.
- Collection summary never synthesizes record values.
- PLC show and history resolve a handle to a DID before querying the PLC
  directory.
- Remote not-found, invalid JSON, and unsupported DID method failures use the
  shared sanitized error contract.

## Verification

~~~sh
dune runtest
dune exec -- ocaat record get at://did:plc:oga6ppys7zwxlheuqmcm7dac/app.bsky.actor.profile/self --format json
dune exec -- ocaat record list did:plc:oga6ppys7zwxlheuqmcm7dac --collections --format json
dune exec -- ocaat plc show did:plc:oga6ppys7zwxlheuqmcm7dac --format json
~~~

Use mocked PDS and PLC HTTP fixtures for every automatic test. The live commands
are manual compatibility checks and must not be snapshot asserted.

## Subsequent planned work

Record creation, update, deletion, PLC signing, PLC submission, bulk PLC dumps,
and migration flows remain later write-oriented work.
