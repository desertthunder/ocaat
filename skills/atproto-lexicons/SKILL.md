---
name: atproto-lexicons
description: >-
  Inspect published AT Protocol Lexicons and describe XRPC methods with ocaat.
  Use when an agent needs the read-only lexicon get, lexicon describe, or xrpc
  describe workflows, authority resolution, definition selection, and
  provenance-aware schema evidence.
---

# AT Protocol Lexicons

Use this skill to inspect a published Lexicon or identify the primary
definition for an XRPC method. Keep the returned schema and its resolution
evidence together so later work can distinguish protocol facts from inference.

Read [Lexicon workflows](references/lexicon-workflows.md) before choosing a
command.

## Operating rules

- Perform public, read-only reads. Do not infer permission to create, update,
  publish, unpublish, or otherwise change Lexicon or PDS data.
- Preserve the supplied NSID or XRPC method NSID before normalizing it. Let
  ocaat validate the identifier before a request is made.
- Use the Lexicon authority and DID-selected PDS by default. Pass `--pds URL`
  to `lexicon get` only for an intentional endpoint override or a local
  fixture, and record that choice in the research notes.
- Use `--auth TOKEN` only when the selected PDS requires authentication. Never
  copy the token into notes, stdout captures, citations, or error reports.
- Prefer `--format json` when the result will be processed or cited. Keep the
  complete `ocaat.document.v1` result, not only a copied schema fragment.
- Record `meta.source`, `meta.endpoint`, `meta.fetched_at`, `meta.did`,
  `meta.pds`, and every `meta.sources` entry returned by the command.
- Treat DNS, DID, PDS, validation, and description failures as gaps. Do not
  fill a missing Lexicon with an AppView, relay, search result, or guessed
  schema.

## Read-only workflow

1. State the exact NSID and question: fetch the full schema, inspect its
   selected definition, or describe an XRPC method.
2. Choose the implemented command in
   [lexicon-workflows.md](references/lexicon-workflows.md).
3. Run it with `--format json` when the result will be reused. Save the exact
   redacted command and complete stdout separately.
4. Read the relevant `data` fields and provenance in `meta`. Keep the DNS
   authority, DID document, and PDS record evidence attached to the result.
5. Separate facts present in the returned schema from interpretations about
   compatibility, implementation, or publication.

## Implemented command surface

```sh
ocaat lexicon get NSID --format json
ocaat lexicon describe NSID --format json
ocaat xrpc describe METHOD --format json
```

`lexicon get` returns the validated published Lexicon schema. `lexicon
describe` selects its `main` definition, or the only definition when the
schema has one. `xrpc describe` uses that same Lexicon resolution and
selection path; it does not call the XRPC method or substitute a PDS response
for the Lexicon.

For the authority lookup, output fields, and failure boundaries, read
[lexicon-workflows.md](references/lexicon-workflows.md).

## Planned work

This skill does not provide local file validation, Lexicon linting, publishing,
unpublishing, compatibility analysis, or change diffing. Mark those requests
as planned or unsupported rather than presenting them as available workflows.
