---
title: Batch JSONL reads
status: ready
---

## Purpose

Allow an agent to submit a deterministic sequence of resource reads and consume
one independently parseable result per request.

## Command and input

```text
ocaat batch [--input <requests.jsonl>]
```

Standard input is the default source. --input and standard input cannot both be
selected. Each non-empty line is one JSON object:

```json
{ "resource": "at://did:plc:example/app.bsky.feed.post/3k...", "pds": "https://optional.override" }
```

Resource is required. Pds is optional and has the same meaning as the
per-command --pds override. Unknown fields are rejected in the first release so
request mistakes are visible rather than ignored.

## Output and failure contract

Batch always writes JSONL to stdout in input order. Each input line produces
exactly one output line:

- success: an ocaat.document.v1 document with request_index in metadata;
- failure: an ocaat.error.v1 document with request_index, resource, sanitized
  error category, message, and optional HTTP status.

Records run sequentially. Batch continues after a per-record error. It exits
zero only if every request succeeded; otherwise it returns the stable exit code
for the first failed request after processing the whole input. Progress and the
final count summary go to stderr.

## Current state

No batch parser or JSONL renderer exists. Shared progress helpers already
separate human messages from stdout.

## Acceptance criteria

- Input and output ordering match exactly.
- Blank lines are ignored; malformed JSON or an invalid request shape produces
  one error line for that line.
- A failed request does not prevent later requests from running.
- No non-JSONL text is written to stdout.
- No concurrency, retries, or hidden fallback services occur in this release.

## Verification

```sh
dune runtest
printf '%s\n' '{"resource":"did:plc:oga6ppys7zwxlheuqmcm7dac"}' | dune exec -- ocaat batch
printf '%s\n' '{"resource":"did:plc:xg2vq45muivyy3xwatcehspu"}' | dune exec -- ocaat batch
```

Add fixtures covering success, invalid JSON, invalid resource, remote failure,
per-record PDS override, and a success after a failure.

## Subsequent planned work

Parallelism, retry policy, fail-fast mode, broader batch operation schemas, and
JSONL support for subscriptions require separate explicit contracts.
