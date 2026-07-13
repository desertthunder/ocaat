# Discovery workflows

Use the narrowest implemented read that can answer the research question. Each
command returns an `ocaat.document.v1` result; keep its complete JSON document
with the research notes. The command examples assume the installed executable
is named `ocaat`.

## Target selection

| Question or input | Command | What it establishes |
| --- | --- | --- |
| Which DID and PDS belong to a handle or DID? | `ocaat resolve HANDLE-OR-DID --format json` | The normalized DID, DID document, declared PDS, and handle evidence when available. |
| What does one recognizable resource return? | `ocaat get RESOURCE --format json` | A single dispatch to an identity, record, Lexicon, or PDS read based on validated input. |
| What is one repository record? | `ocaat record get AT-URI --format json` | The validated record payload, CID, resolved repository DID, and answering PDS. |
| Which collections are currently listed by a repository? | `ocaat record list HANDLE-OR-DID --collections --format json` | The PDS `describeRepo` collection summary without synthesizing records. |
| Which records are on one known collection? | `ocaat record list HANDLE-OR-DID --collection NSID --format json` | One validated `listRecords` page, including an optional continuation cursor. |
| What is the current PLC operation? | `ocaat plc show HANDLE-OR-DID --format json` | Current PLC directory data for a `did:plc` identity. |
| How did a `did:plc` identity change? | `ocaat plc history HANDLE-OR-DID --format json` | The PLC operation log, ordered chronologically when timestamps are present. |

PDS-backed commands select the PDS declared by the resolved DID document. Add
`--pds URL` only for a deliberate endpoint override or a local fixture, and
record that choice. PLC commands use `https://plc.directory` by default; use
`--plc-host URL` only when the directory override is intentional. These two
overrides answer different questions.

## Identity and service workflow

1. Run `resolve` for a supplied handle or DID.
2. Confirm that the returned `data.did` is the identity under investigation.
3. Inspect `data.document` and the optional `data.pds`. For a handle, retain
   `data.handleEvidence` because it records whether the handle came from DNS or
   the HTTPS well-known method and whether the DID document verified it.
4. Use the PDS endpoint in `meta.pds` for a subsequent record or collection
   read unless the question explicitly calls for `--pds`.
5. Record the identity result's `meta.source`, `meta.endpoint`, and
   `meta.fetched_at` even when a later PDS read is the main evidence.

`resolve` follows the supported handle and DID resolution paths. It does not
silently fall back to an AppView, relay, or backlink index.

## Resource workflow

Use `get` when the input is already a recognizable handle, DID, AT URI,
supported Bluesky web URL, NSID, or PDS URL. It performs validation and chooses
one read branch. Use the more specific `record` or `plc` command when the
research question needs its options or a clearly named endpoint.

For an exact record, prefer an AT URI and run:

```sh
ocaat record get at://did:plc:example/app.bsky.feed.post/3kexample --format json
```

For a supported Bluesky URL, `get` records the normalized AT URI in `data`.
Unsupported web pages are not scraped.

## Collection and record workflow

Start with the current repository summary when the collection is unknown:

```sh
ocaat record list alice.example --collections --format json
```

Then choose a collection from the returned `data.collections` and request a
bounded page:

```sh
ocaat record list alice.example \
  --collection app.bsky.feed.post --limit 50 --format json
```

Use the returned `data.cursor` as `--cursor` for the next page and preserve one
provenance entry per page. A collection summary reports what the repository
advertises through `describeRepo`; it does not prove that a collection has
records and does not synthesize record values.

General collection discovery across repositories, indexes, or AppViews is
planned. Backlink queries and backlink indexes are planned. Do not describe
either capability as available, and do not substitute a relay or AppView when
the PDS read is empty or fails.

## PLC history workflow

Use PLC commands only for a `did:plc` identity. A handle is resolved first and
must resolve to a PLC DID:

```sh
ocaat plc show did:plc:example --format json
ocaat plc history did:plc:example --format json
```

If the input resolves to `did:web`, stop with a gap; do not invent a PLC
history. Compare PLC operations with the DID document and PDS reads only after
retaining each result's source and fetch time.

## Gaps to report

Report a gap when any of these applies:

- resolution fails, returns no PDS, or finds conflicting handle evidence;
- a record or collection request fails, is paginated beyond the captured page,
  or uses an explicit endpoint override;
- the target is not a `did:plc` identity for a PLC question;
- the question asks for collection discovery, backlinks, AppView data, relay
  data, caching, or writes, which this release does not implement.

Name the command, target, endpoint when known, and the reason. Keep gaps next
to the evidence they qualify.
