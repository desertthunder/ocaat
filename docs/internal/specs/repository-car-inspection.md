---
title: Local repository CAR inspection
status: ready
---

## Purpose

Inspect a local AT Protocol repository CAR safely and natively in OCaml, without
network transfer or dependence on an external implementation.

## Commands

```text
ocaat repo verify <file.car>
ocaat repo inspect <file.car>
ocaat repo list <file.car>
ocaat repo mst <file.car>
```

Verify performs the full structural and repository validation. Inspect reports
commit DID, revision, root CID, block count, record count, and collection
counts. List emits sorted record paths and CIDs. Mst renders a stable structural
view; JSON output contains structured node and edge data instead of terminal
art.

## Required parser behavior

Accept only a bounded CAR v1 repository export with at least one root CID. The
first root is the primary commit; validate and preserve additional root CIDs
without assigning them repository meaning. Read length-delimited sections
defensively, reject truncated or oversized sections, validate CID framing and
digest integrity, and ensure the primary root block exists.

For repository-level inspection, decode the deterministic DRISL-CBOR commit,
validate its AT Protocol structure, load the MST, validate every referenced
block, and walk record paths in deterministic order. A structurally valid CAR
that is not a valid AT Protocol repository must fail repository inspection.

## Current state

Ocaat has CID syntax validation but no CAR, DRISL-CBOR, CID codec, commit, or MST
implementation. The checked Indigo reference enforces CAR v1 and parses the
root commit before walking an MST. The configured local Tempest checkout was not
present during the spike, so the decision relies on the current AT Protocol
specifications and Indigo's repository-v3 fixture rather than undocumented
Tempest behavior.

Current AT Protocol specifications call the normalized binary data model
DRISL-CBOR, the successor to DAG-CBOR. The implementation must use the current
normalization rules even where older code or fixtures retain DAG-CBOR naming.

## T03 compatibility decision

Use a bounded native OCaml implementation for the first repository reader. The
[Pegasus `ipld`](https://tangled.org/futur.blue/pegasus/tree/main/ipld) library
is the exact OCaml dependency candidate, but its current reader does not meet
the validation and resource-limit requirements for untrusted CAR files.

Pegasus provides pure OCaml CIDv1, CARv1, and deterministic CBOR modules, and
its adjacent `mist` package implements an AT Protocol MST. Its
[`ipld.opam`](https://tangled.org/futur.blue/pegasus/blob/main/ipld.opam)
metadata documents the current package constraints. It is active and
close to the required domain, so use it as the primary OCaml reference and
re-evaluate it before implementation. Do not add it until a released version:

- bounds CAR headers, sections, block counts, decoded bytes, and CBOR nesting;
- validates the CAR version and header shape;
- recomputes and verifies every block's CID digest;
- rejects non-canonical DRISL-CBOR, floats, duplicate map keys, and unsupported
  values;
- includes CAR tests covering malformed, truncated, invalid-CID, digest
  mismatch, oversized, duplicate, and multi-root inputs; and
- supports ocaat's compiler and Dune range without pinning OCaml exactly to
  5.2.1 and Dune to the 3.20 release line.

The current package also exposes unwrapped modules without interface files,
admits zero-length SHA-256 digests, and brings `digestif`, `multibase`, Lwt PPX,
and Yojson 3. The adjacent `mist` package adds Core Unix and a larger API
surface. Its MPL-2.0 license is compatible with use as a dependency, but copying
or modifying its source would require deliberate license compliance.

General CBOR packages such as `cbor` 0.5 are less suitable: they leave CAR,
CID, normalization, commit, and MST validation custom without enforcing the
required DRISL subset.

The native scope is deliberately narrow:

- unsigned varints needed by CAR and CID framing;
- CAR v1 with one required primary commit root, arbitrary block order, bounded
  duplicate handling, and no CAR v2 or generic IPLD traversal;
- CIDv1 with the blessed DRISL-CBOR codec and SHA-256 multihash for commit and
  MST links, while record links are preserved and admitted only under the
  repository specification's rules;
- the DRISL-CBOR value subset used by commits, MST nodes, and records, with
  normalized encoding checks and CBOR tag 42 links;
- repository-v3 commits and the current MST node schema; deprecated repository
  versions are rejected rather than retained for compatibility.

Digest computation may reuse an existing maintained cryptographic primitive if
one is already available through the approved dependency graph. Any new package
still requires separate approval.

### Spike evidence

The temporary reader used Indigo's current `atproto/repo.LoadRepoFromCAR` as the
compatibility oracle and mutated local fixture bytes in memory. No runtime
dependency or project source was added.

| Case                                                     | Result                                                                 |
| -------------------------------------------------------- | ---------------------------------------------------------------------- |
| Current repository-v3 fixture (`greenground.repo.car`)   | Accepted; commit DID, revision, and MST root decoded.                  |
| Malformed non-CAR bytes                                  | Rejected as unexpected end of input.                                   |
| Valid fixture truncated by one byte                      | Rejected as unexpected end of input.                                   |
| First block CID prefix changed to an invalid CID version | Rejected during CID decoding.                                          |
| Declared section length of 32 MiB plus one byte          | Rejected before allocation.                                            |
| Older repository-v2 fixtures                             | CAR framing accepted, then rejected as unsupported repository version. |

These cases establish the parser layers and minimum limits; they are not a
substitute for the deterministic fixture suite required by implementation.

### Required implementation limits

Keep limits in one public configuration record with conservative CLI defaults.
At minimum bound the input file size, header size, section size, block count,
total decoded bytes, CID length, CBOR nesting, map and array lengths, string and
byte-string lengths, MST depth, record count, and duplicate-CID count. Reject
non-canonical varints, indefinite-length CBOR, floats, unsupported tags and
simple values, digest mismatches, conflicting duplicate CIDs, and arithmetic
overflow.

The 32 MiB section ceiling used by the compatibility oracle is an upper-bound
fixture, not an automatically approved product default. Choose and document the
actual default alongside representative repository-size tests.

## Technical plan

- Recheck Pegasus `ipld` against the fixture suite before starting T12. Adopt a
  released version only if it satisfies the requirements above and the user
  separately approves the dependency.
- Implement only the approved CAR v1, DRISL-CBOR, CID, commit, and MST subset.
  Do not introduce a generic IPLD framework.
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

```sh
dune runtest
dune exec -- ocaat repo verify test/fixtures/repos/valid.car --format json
dune exec -- ocaat repo inspect test/fixtures/repos/valid.car
dune exec -- ocaat repo list test/fixtures/repos/valid.car --format json
dune exec -- ocaat repo mst test/fixtures/repos/valid.car
```

Add minimal valid, malformed, and limit-exceeding local fixtures. Compare valid
fixture metadata with Tempest repo-core test expectations.

The fixture suite must keep CAR-container validation distinct from repository
validation. Include a structurally valid CAR whose root is not a valid current
AT Protocol commit, and a repository-v2 commit that fails explicitly as an
unsupported application version.

## Subsequent planned work

Remote repo export, repo import, unpacking, write operations, blob transfer, and
signature verification beyond the repository structure are separate work.
