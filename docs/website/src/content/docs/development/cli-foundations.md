---
title: CLI Conventions
description: Output, provenance, errors, and safety rules shared by ocaat commands.
---

## Overview

Ocaat gives every command the same boundary for results and diagnostics.

1. A successful result goes to stdout.
2. Progress, warnings, and errors go to stderr.
3. Read commands validate their identifiers and service URLs before opening a
   network connection.

## Command conventions

Use the global options after the command name:

```sh
--format markdown|json|jsonl|raw
--json # an alias for --format json
--pds URL
--auth TOKEN
--admin-token TOKEN
```

URL, DID, handle, NSID, artifact-path, and authentication preflight checks happen before
a request.

Bare PDS hosts are accepted where a positional host is documented and normalized to HTTPS.

## Output Formats

Markdown is the default output format.

It starts with a kind-aware summary, followed by a `Provenance` section.

A final `Raw` section contains the complete redacted `ocaat.document.v1` envelope
in a JSON fence. URLs are rendered as links, protocol identifiers as code, and
untrusted record text remains fenced data. The Markdown is constructed as a
CommonMark document, so values cannot add headings, links, tables, or HTML.

JSON output uses this envelope:

```json
{
  "schema": "ocaat.document.v1",
  "kind": "pds|records|doctor|...",
  "data": {},
  "meta": {
    "source": "pds|relay|local|...",
    "endpoint": "https://...",
    "fetched_at": "2026-07-12T07:11:34Z",
    "did": "optional DID",
    "pds": "optional PDS URL"
  }
}
```

`meta.endpoint` is the endpoint actually used for the request, not the
unresolved value supplied by the user.

`fetched_at` is generated when the document is built.

Optional identity fields are omitted when they are not known.

`raw` is an explicit payload passthrough for commands that return an HTTP body;
it never becomes the default. JSONL is reserved for sequence commands. Current
commands reject `--format jsonl` until the batch interface provides that mode.

## Error handling

Errors retain their stable exit categories:

| Category    | Exit code |
| ----------- | --------: |
| usage       |        64 |
| validation  |        65 |
| auth        |        66 |
| network     |        69 |
| remote      |        70 |
| filesystem  |        74 |
| interrupted |       130 |

When JSON is selected, stderr receives an `ocaat.error.v1` document:

```json
{
  "schema": "ocaat.error.v1",
  "error": {
    "kind": "remote",
    "status": 503,
    "message": "https://pds.example/xrpc/example: ..."
  }
}
```

The message contains a sanitized endpoint and status where available. Tokens,
passwords, JWTs, authorization headers, and sensitive JSON fields are replaced
with `[REDACTED]`.

## Configuration

`OCAAT_PDS`, `OCAAT_AUTH`, and `OCAAT_ADMIN_TOKEN` provide defaults for the
corresponding global options. Explicit flags override environment values.
Credentials are passed as bearer tokens for the request and are not included in
documents, progress events, or errors.

## Compatibility

Existing commands accept `--json`. It selects the same JSON document renderer
as `--format json`; there is no second JSON output shape. Markdown and JSON
carry the same document fields and payload.

## Security

The CLI rejects service URLs containing userinfo, queries, fragments, or unsupported paths
before making a request. Raw and structured renderers share the same redaction layer.

## See also

Command [reference/manual](/reference/commands/).
