# Provenance and research notes

Every successful ocaat read is a document with this envelope:

```json
{
  "schema": "ocaat.document.v1",
  "kind": "record",
  "data": {},
  "meta": {
    "source": "pds",
    "endpoint": "https://pds.example/xrpc/com.atproto.repo.getRecord?...",
    "fetched_at": "2026-01-02T03:04:05Z",
    "did": "did:plc:example",
    "pds": "https://pds.example"
  }
}
```

The payload in `data` is the protocol result. `meta` describes where and when
ocaat obtained it. Do not replace `data` with a hand-written summary or treat a
Markdown rendering as the authoritative payload.

## Fields to retain

- `schema`: keep `ocaat.document.v1` so the envelope can be recognized later.
- `kind`: identify the result class, such as `identity`, `record`, `records`,
  or `plc`.
- `meta.source`: name the answering source, such as `pds`, `plc`, `did:web`,
  or `dns` where the command exposes it.
- `meta.endpoint`: retain the exact request endpoint returned by ocaat. Query
  parameters can identify the repository, collection, and record key.
- `meta.fetched_at`: use this as the observation time. Do not replace it with
  the record's `createdAt` or an operation's `createdAt`.
- `meta.did` and `meta.pds`: retain them when present. A PDS override appears
  here and must be called out as a method choice.
- `meta.sources`: retain each additional source entry when present. Each entry
  contains `source`, `endpoint`, and optional `did` and `pds`.
- Relevant `data` fields: preserve CIDs, record URIs, cursors, DID documents,
  collection arrays, PLC operations, and handle evidence exactly as returned.

For `resolve`, handle evidence is in `data.handleEvidence`, including its
`source`, `verified` flag, handle, and DID. The top-level `meta.endpoint` is the
DID-document endpoint; retain the handle evidence separately when a handle was
the input.

## Research-note template

Use one entry per command result:

```markdown
### Observation: <short question>

- Target as supplied: `<handle, DID, AT URI, NSID, or URL>`
- Command: `<exact redacted command>`
- Result kind: `<kind>`
- Source: `<meta.source>`
- Endpoint: `<meta.endpoint>`
- Fetched at: `<meta.fetched_at>`
- DID: `<meta.did or data.did or not returned>`
- PDS: `<meta.pds or not returned>`
- Endpoint override: `<none or explain --pds/--plc-host>`
- Evidence: <facts directly present in data>
- Gaps: <missing, conflicting, paginated, failed, or planned evidence>
```

For a multi-step investigation, keep separate observations for identity
resolution, collection summary, each record page, each record read, and each
PLC read. A final conclusion may link them, but it must not erase their
individual endpoints or fetch times.

## Failure and absence

Keep sanitized error output with the observation when a command fails. Record
the target, attempted command, endpoint if it was constructed, and the failure
category. Distinguish these cases:

- no PDS declared by a DID document;
- a PDS request that returned an error;
- a successful empty collection or record page;
- a collection or backlink question that has no implemented discovery command.

Do not report an empty result as proof that no data exists outside the queried
service or page. Do not retry a PDS failure against an AppView, relay, or
backlink index without an explicitly identified, separately supported workflow.

## Redaction

The CLI redacts credentials in rendered errors and result bodies. Keep that
property in research artifacts: remove bearer tokens, admin tokens, cookies,
authorization headers, and credential-bearing URLs before sharing notes. Store
the exact endpoint only after checking that it contains no secret material.
