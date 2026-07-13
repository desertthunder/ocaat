---
name: atproto-research
description: Investigate public AT Protocol identities, repositories, records, and PLC 
histories with ocaat. Use this skill when research needs evidence from resolve, get, 
record, or plc commands, collection summaries, explicit source selection, and auditable 
provenance.
---

# AT Protocol Research

Use this skill for evidence-oriented investigation of one or more public AT
Protocol resources. Start with the smallest read that answers the question,
keep the raw ocaat result with the research notes, and distinguish observed
facts from interpretation.

Read the relevant reference before choosing a workflow:

- [Discovery](references/discovery.md) maps research questions to implemented
  commands and identifies planned capabilities.
- [Provenance](references/provenance.md) defines the evidence fields to retain
  and the required research-note template.

## Operating rules

- This skill performs public, read-only reads. Do not infer permission to create,
  update, delete, publish, migrate, administer, or otherwise write data.
- Resolve a handle or DID before making claims about its repository or service.
- Use the PDS selected by the DID document by default. Pass `--pds URL` only
  when an explicit endpoint override is part of the question or a fixture
  requires it; record that override in the gaps or method notes.
- Use `--plc-host URL` only for an intentional PLC-directory override. It is
  separate from `--pds`.
- Prefer `--format json` for notes and comparisons. The default Markdown view
  is useful for reading; `--format raw` omits the document envelope and is not
  sufficient as the only research record.
- Never copy authentication tokens into notes, stdout captures, or citations.
  Redact them if they appear in surrounding command output.
- Treat a failed or incomplete read as a gap. Do not fill missing facts with
  AppView, relay, backlink, or search-index data unless a later workflow
  explicitly adds and identifies that source.

## Research loop

1. State the question and target exactly. Preserve the supplied handle, DID,
   AT URI, NSID, or PDS URL before normalization.
2. Choose the implemented discovery path in
   [discovery.md](references/discovery.md). Validate identifiers and endpoint
   overrides before requesting data.
3. Run the command with `--format json` when the result will be processed or
   quoted. Save the complete stdout document and the exact command separately.
4. Read `meta` and the relevant `data` fields. Record `source`, `endpoint`,
   `fetched_at`, resolved DID/PDS values, and any missing or conflicting facts.
5. If the question needs several reads, keep one provenance entry per result.
   Do not merge observations until their sources and fetch times are retained.
6. Write a conclusion that separates facts returned by the service from
   inferences. List unresolved questions and unsupported discovery steps as
   gaps.

## Implemented command surface

The research workflows use these read commands:

- `ocaat resolve HANDLE-OR-DID`
- `ocaat get RESOURCE`
- `ocaat record get AT-URI`
- `ocaat record list HANDLE-OR-DID --collection NSID [--limit N] [--cursor CURSOR]`
- `ocaat record list HANDLE-OR-DID --collections`
- `ocaat plc show HANDLE-OR-DID [--plc-host URL]`
- `ocaat plc history HANDLE-OR-DID [--plc-host URL]`

Use `--pds URL` on PDS-backed commands when an intentional PDS override is
needed. Use `--format markdown` for a human report, `--format json` for a
machine-readable document, and `--format raw` only when the protocol payload is
needed in addition to the saved document metadata.

For a command-by-command map and examples, read [discovery](references/discovery.md).

For the fields to carry forward, read [provenance](references/provenance.md).
