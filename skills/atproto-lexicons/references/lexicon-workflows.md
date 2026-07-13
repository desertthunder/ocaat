# Lexicon workflows

Use the narrowest read that answers the question. The commands below return an
`ocaat.document.v1` result so retain the complete JSON document when the result
will support later research or a compatibility decision.

## Choose a command

| Question                                          | Command                                     | Result                                                                          |
| ------------------------------------------------- | ------------------------------------------- | ------------------------------------------------------------------------------- |
| What is the published schema for an NSID?         | `ocaat lexicon get NSID --format json`      | The validated Lexicon record in `data`, with resolution evidence in `meta`.     |
| Which primary definition does a Lexicon expose?   | `ocaat lexicon describe NSID --format json` | The Lexicon id, selected definition name, definition type, and selected schema. |
| What Lexicon definition describes an XRPC method? | `ocaat xrpc describe METHOD --format json`  | The same selected-definition result, without calling the method.                |

Use `lexicon get` when the full schema or its record URI is needed. Use either
description command when the question concerns the primary definition or its
Lexicon type. `xrpc call` and `xrpc query` are separate read-only PDS requests;
they are not XRPC-description commands and require a selected PDS, normally
provided with `--pds URL`.

## Authority resolution

For an NSID such as `com.atproto.repo.getRecord`, ocaat performs these reads:

1. Validate the NSID and remove its final name segment.
2. Reverse the remaining authority segments and query the DNS TXT name
   `_lexicon.repo.atproto.com`.
3. Require exactly one valid `did=<DID>` value from that response.
4. Fetch the DID document for that Lexicon authority DID.
5. Use the declared `AtprotoPersonalDataServer` service endpoint unless
   `lexicon get --pds URL` intentionally overrides it.
6. Read `com.atproto.repo.getRecord` for the requested NSID from the selected
   PDS.

The DNS authority, DID document, and PDS record are separate evidence sources.
An empty or conflicting DNS response, an invalid DID document, a DID document
without a PDS, and an unsuccessful PDS read are failures. Do not retry one of
these stages against an AppView or relay unless a separate workflow explicitly
identifies that source.

`--pds URL` changes only the PDS endpoint for `lexicon get`; it does not change
the DNS authority or DID used to identify the publisher. Record the override
alongside the result. Do not add an override to a description example unless
the CLI exposes an explicit override for that command path.

## Fetch and validate a Lexicon

Run:

```sh
ocaat lexicon get com.atproto.repo.getRecord --format json
```

The command expects the PDS response to contain a record with the requested
URI and a Lexicon version 1 value whose `id`, `$type`, and non-empty `defs`
object are consistent.

It rejects redirects, invalid JSON, oversized responses, and malformed definitions.
This is validation of the published network record but not a local Lexicon development
or compatibility tool.

The schema remains authoritative in `data`. Do not replace it with a prose
summary.

Use Markdown for a human-readable report, JSON for notes and comparisons, and raw output
only when the protocol payload without the document envelope is specifically required.

## Describe a definition

Run either command for a definition-focused result:

```sh
ocaat lexicon describe com.atproto.repo.getRecord --format json
ocaat xrpc describe com.atproto.repo.getRecord --format json
```

Both commands fetch the published Lexicon first. They select the `main`
definition, or the only definition when no `main` key exists. A Lexicon with
several definitions and no `main` definition fails instead of choosing one by
name or order. The description result contains:

- `data.id`: the requested Lexicon NSID;
- `data.definition`: the selected definition name;
- `data.type`: its Lexicon type, such as `query`, `procedure`, `record`, or
  `subscription`;
- `data.schema`: the selected definition object.

`xrpc describe` never invokes the described method. A `procedure` or another
non-query type may be described; that does not grant permission to call it.

## Provenance

A successful JSON result has this shape:

```json
{
  "schema": "ocaat.document.v1",
  "kind": "lexicon",
  "data": {},
  "meta": {
    "source": "pds",
    "endpoint": "https://pds.example/xrpc/com.atproto.repo.getRecord?...",
    "fetched_at": "2026-07-13T00:00:00Z",
    "did": "did:plc:example",
    "pds": "https://pds.example",
    "sources": [
      { "source": "dns", "endpoint": "dns://_lexicon.repo.atproto.com" },
      { "source": "did", "endpoint": "https://plc.directory/..." },
      { "source": "pds", "endpoint": "https://pds.example/xrpc/..." }
    ]
  }
}
```

Keep `meta.fetched_at` as the observation time. Do not replace it with a
Lexicon field such as `createdAt`. Keep the exact endpoints after checking that
they contain no credential material. The CLI redacts credentials in rendered
result data and errors, but notes and citations still need a final redaction
check.
