---
title: Local repository CAR inspection
status: ready
---

## Purpose

Inspect a local AT Protocol repository CAR safely and natively in OCaml, without
network transfer or dependence on an external implementation.

## Commands

~~~text
ocaat repo verify <file.car>
ocaat repo inspect <file.car>
ocaat repo list <file.car>
ocaat repo mst <file.car>
~~~

Verify performs the full structural and repository validation. Inspect reports
commit DID, revision, root CID, block count, record count, and collection
counts. List emits sorted record paths and CIDs. Mst renders a stable structural
view; JSON output contains structured node and edge data instead of terminal
art.

## Required parser behavior

Accept only a bounded CAR v1 repository export with exactly one root CID. Read
length-delimited sections defensively, reject truncated or oversized sections,
validate CID framing and digest integrity, and ensure the root block exists.

For repository-level inspection, decode the deterministic DAG-CBOR commit,
validate its AT Protocol structure, load the MST, validate every referenced
block, and walk record paths in deterministic order. A structurally valid CAR
that is not a valid AT Protocol repository must fail repository inspection.

## Current state

Ocaat has CID syntax validation but no CAR, DAG-CBOR, CID codec, commit, or MST
implementation. Tempest and the checked Indigo reference both enforce CAR v1
and parse the root commit before walking an MST.

## Technical plan

- First run a bounded compatibility spike against Tempest repository fixtures.
- Prefer a maintained, pure OCaml dependency only if it covers the required
  codecs and passes the fixture suite. Adding a dependency requires approval.
- If no suitable dependency exists, implement only the bounded CAR v1,
  deterministic DAG-CBOR, CID, commit, and MST subset required here. Do not
  introduce a generic IPLD framework.
- Do not call goat, Go, or a subprocess at runtime.
- Keep parser limits explicit and test every limit to avoid memory exhaustion.

## Acceptance criteria

- Valid Tempest-compatible CAR fixtures produce stable verify, inspect, list,
  and MST documents.
- Missing roots, unsupported versions, invalid CIDs, digest mismatches,
  truncated sections, invalid commits, broken MST links, and oversized sections
  fail safely with filesystem or validation errors.
- Inspect and list never write extracted files.
- The same CAR yields deterministic JSON across runs.

## Verification

~~~sh
dune runtest
dune exec -- ocaat repo verify test/fixtures/repos/valid.car --format json
dune exec -- ocaat repo inspect test/fixtures/repos/valid.car
dune exec -- ocaat repo list test/fixtures/repos/valid.car --format json
dune exec -- ocaat repo mst test/fixtures/repos/valid.car
~~~

Add minimal valid, malformed, and limit-exceeding local fixtures. Compare valid
fixture metadata with Tempest repo-core test expectations.

## Subsequent planned work

Remote repo export, repo import, unpacking, write operations, blob transfer, and
signature verification beyond the repository structure are separate work.
