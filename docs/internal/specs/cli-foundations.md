---
title: CLI foundations and result contract
status: ready
---

## Purpose

Make every new read-only command predictable for both people and programs:
stable formats, provenance, safe errors, and a shared implementation seam.

## Current state

The existing CLI context has a boolean json flag, PDS and auth options, stable
error categories, redaction, preflight helpers, artifact guards, and progress
helpers. Existing output currently prints endpoint response bodies directly.

## Command and data contract

Replace the shared boolean with an output format:

```text
--format markdown|json|jsonl|raw
--json                         alias for --format json
```

Markdown is the default. JSONL is available only on commands that can produce a
sequence, initially batch. Raw is an explicit payload passthrough and is never
the default.

Successful structured output uses this document shape:

```json
{
  "schema": "ocaat.document.v1",
  "kind": "identity|record|records|plc|lexicon|pds|car|capabilities|doctor",
  "data": {},
  "meta": {
    "source": "pds|plc|did|dns|local",
    "endpoint": "https://...",
    "fetched_at": "RFC3339 timestamp",
    "did": "optional DID",
    "pds": "optional PDS URL"
  }
}
```

Data is the protocol payload with secrets redacted. Metadata describes the
actual source, never merely the requested source. Markdown renders the same
document without omitting source, endpoint, or fetch time.

Successful output goes to stdout. Warnings, progress, and debug logs go to
stderr. Errors preserve the existing sanitized error categories and exit codes;
JSON errors use a versioned error document when a command has selected JSON.

## Technical plan

- Introduce Format, Document, Provenance, Renderer, and Error_document domain
  modules before adding feature commands.
- Migrate the existing pds, relay, syntax, key, migration, and xrpc command
  renderers without changing their behavioral meaning. Retain --json as an
  alias.
- Make --pretty=auto a display concern only; it must not change Markdown
  structure or JSON values.
- Add capabilities, doctor, and completions as self-description commands once
  the command registry can describe formats and safety class.
- Keep persistent credentials, write procedures, and destructive confirmations
  under their dedicated later specifications.

## Acceptance criteria

- Every first-release read command accepts --format and --json.
- JSON documents conform to ocaat.document.v1 and carry non-empty source and
  fetched_at metadata.
- No progress text or warning is mixed into stdout JSON or JSONL.
- A remote error identifies sanitized endpoint and status without exposing a
  token, password, or authorization header.
- Existing commands remain invocable with --json.

## Verification

```sh
dune runtest
dune exec -- ocaat pds describe https://tempest.desertthunder.dev --format json
dune exec -- ocaat syntax did check did:plc:oga6ppys7zwxlheuqmcm7dac --json
```

Add CLI-level tests for format selection, JSON aliasing, stdout versus stderr,
metadata presence, and redaction.

## Boundaries

- Always: retain stable exit code meanings and redact sensitive values.
- Ask first: add a package dependency or change the documented JSON schema.
- Never: print credentials, make a write request from a read command, or emit
  unstructured output when JSON or JSONL was requested.

## Subsequent planned work

Procedure and streaming output support belong with XRPC procedures and
firehose work. JSONL beyond batch belongs with each streaming feature.
