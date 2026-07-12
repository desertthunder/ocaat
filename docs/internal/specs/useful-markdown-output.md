---
title: Useful Markdown output
status: ready
---

## Purpose

Make the default CLI output useful to a person while preserving the complete,
redacted result document and its provenance.

## Output contract

Markdown remains a rendering of the same `ocaat.document.v1` value used by JSON
output. It presents a kind-specific summary first, provenance second, and the
authoritative redacted document in a final `Raw` section.

````markdown
# Record

Human-readable result.

## Provenance

- Source: PDS
- Endpoint: <https://pds.example>
- DID: `did:plc:example`
- Fetched: 2026-07-12T12:00:00Z

## Raw

```json
{
  "schema": "ocaat.document.v1",
  "kind": "record",
  "data": {},
  "meta": {}
}
```
````

The raw block contains the entire envelope, not only `data`. Frontmatter is not
used: processors may hide it, YAML would introduce a second serialization, and
large nested payloads do not belong in document metadata.

Single results and bounded lists always include `Raw`. Streaming JSONL output
does not have a Markdown form. If a future command can produce a result too
large to duplicate safely, that command must define an explicit limit and direct
the user to `--format json`; omission must not happen silently.

## Rendering model

Add a private semantic Markdown module whose values represent headings,
paragraphs, field lists, links, code spans, tables, and fenced code. The shared
renderer converts `Document.t` to this model and serializes it with cmarkit.
Command modules continue to produce documents and do not assemble Markdown.

Provide a small formatter registry keyed by `Document.kind`, optionally refined
by a protocol `$type` or collection when that produces a materially better
summary. Begin with identity, record, records, PLC, lexicon, PDS, CAR, and doctor
documents. Unknown shapes use a generic structural renderer rather than gaining
one formatter per Lexicon collection.

The generic renderer uses these bounded rules:

- scalar object fields become labeled fields;
- short homogeneous arrays of scalar objects may become tables;
- long prose becomes paragraphs only when the field is defined as prose;
- complex, heterogeneous, empty, or oversized shapes use concise summaries and
  remain available in `Raw`;
- URLs become links; DIDs, AT URIs, CIDs, NSIDs, and timestamps receive readable
  formatting without changing their values.

Protocol strings are untrusted. Construct cmarkit nodes rather than interpolating
Markdown so structural characters are escaped correctly. Markdown stored in a
record is data by default and is shown in a dynamically sized `markdown` fence.
Parsing and splicing stored Markdown requires a separately documented trusted
content policy.

## Dependency decision

Use cmarkit for CommonMark AST construction and serialization, subject to user
approval before adding the package. Pin the accepted version deliberately:
cmarkit's CommonMark output may change between minor releases.

Tests must assert parsed document structure and content rather than incidental
whitespace. A small set of golden outputs remains useful for readability review.

## Acceptance criteria

- Every Markdown result leads with a useful kind-specific or generic summary.
- Provenance visibly includes every present metadata field.
- `Raw` contains the complete redacted `ocaat.document.v1` JSON envelope.
- Markdown metacharacters, HTML, control characters, backticks, pipes, links,
  multiline strings, and credentials cannot alter structure or bypass redaction.
- Unknown document kinds and data shapes render without data loss or exceptions.
- JSON, JSONL, and raw output bytes do not change as a side effect.
- Command modules remain format-agnostic and thin.

## Verification

```sh
dune runtest
dune exec -- ocaat syntax did check did:plc:oga6ppys7zwxlheuqmcm7dac --format markdown
dune exec -- ocaat pds describe https://tempest.desertthunder.dev --format markdown
```

Add CLI-level fixtures for each supported kind, unknown JSON shapes, empty and
large collections, hostile strings, redaction, and the complete `Raw` envelope.
Parse rendered Markdown with cmarkit in tests and assert the expected block and
inline structure.

## Boundaries

- Always preserve the JSON document as the authoritative output contract.
- Ask before adding cmarkit or changing `ocaat.document.v1`.
- Never treat arbitrary record text as trusted Markdown or emit credentials.
- Do not add collection-specific formatters until a real result demonstrates
  that the generic renderer is inadequate.
