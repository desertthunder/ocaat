---
title: Command reference
description: Current ocaat commands, options, endpoints, and exit codes.
---

## Configuration

Global options are available on commands that render results:

```text
--format markdown|json|jsonl|raw
--json
--pds URL
--auth TOKEN
--admin-token TOKEN
--color auto|always|never
--quiet | --verbose | --verbosity LEVEL
```

`OCAAT_PDS`, `OCAAT_AUTH`, and `OCAAT_ADMIN_TOKEN` provide environment
defaults. Explicit options take precedence.

## Output formats

Markdown is the default. JSON is selected with either `--format json` or the
`--json` alias. Successful structured output has the `ocaat.document.v1`
schema, a command-specific `kind`, the protocol result in `data`, and
provenance in `meta`.

```sh
ocaat pds describe https://tempest.desertthunder.dev --format json
ocaat syntax did check did:plc:oga6ppys7zwxlheuqmcm7dac --json
```

`--format raw` prints an HTTP payload directly after redaction. JSONL is
reserved for sequence commands and is rejected by the commands currently in
this reference.

## Exit codes

| Code | Meaning |
| ---: | --- |
| 0 | success |
| 64 | usage error |
| 65 | validation error |
| 66 | authentication or authorization error |
| 69 | network error |
| 70 | remote HTTP/XRPC error |
| 74 | filesystem error |
| 130 | interrupted operation |

With JSON selected, errors are versioned `ocaat.error.v1` documents on stderr.

## Version

```sh
ocaat version
```

Prints the CLI version.

## Account migration

Migration steps use the artifact directory and environment settings documented
in the account migration guide. Progress is diagnostic output on stderr; a
completed step renders its result document on stdout.

### account migrate

All migration steps accept the shared output and safety options. They preserve
the existing artifact reuse and `--force` behavior.

#### full

Runs the non-activation migration sequence through missing-blob discovery.

#### login-source

Creates and stores the source session artifact.

#### service-auth

Requests and stores service authorization for the migration procedure.

#### source-session-status

Reads the source session status.

#### export-car

Exports the source repository CAR artifact.

#### list-source-blobs

Lists source blob CIDs into an artifact.

#### download-source-blobs

Downloads source blobs listed by the source blob artifact.

#### create-account

Creates the target account artifact.

#### refresh-session

Refreshes the target session artifact.

#### import-repo

Imports the repository CAR into the target PDS and stores the response.

#### status

Reads target migration status.

#### missing-blobs

Lists target blobs that are still missing.

#### upload-missing-blobs

Uploads the missing blobs from the local artifact set.

#### plc-recommended

Fetches the recommended PLC operation.

#### plc-request-token

Requests a PLC operation token.

#### plc-sign

Signs the recommended PLC operation artifact.

#### plc-submit

Submits the signed PLC operation.

#### activate

Activates the target account as the final migration step.

## PDS management

PDS reads use XRPC endpoints under the selected service URL. A positional host
may be bare and defaults to HTTPS; `--pds` requires a service URL.

### pds describe

Calls `com.atproto.server.describeServer` for a host.

```sh
ocaat pds describe https://tempest.desertthunder.dev --format json
```

### pds health

Calls `/xrpc/_health` using `--pds URL`.

### pds stats

Calls `/xrpc/_stats` using `--pds URL`.

### pds admin-status

Calls `/xrpc/_admin/status` using `--pds URL` and `--admin-token TOKEN`.

### pds account list

Calls `com.atproto.sync.listRepos`, follows pagination, and renders a
`records` document. `--handles` adds best-effort handle evidence for Markdown
output.

### pds account status

Calls `com.atproto.sync.getRepoStatus` for the positional DID and `--pds URL`.
The DID is validated before the request.

## Identity resolution

### resolve

Resolves a handle or supported DID into a normalized identity document. Handle
resolution uses the AT Protocol DNS TXT and HTTPS well-known methods, then
checks the DID document's reverse handle claim. The result includes the
document's PDS service when one is declared.

```sh
ocaat resolve alice.example --format json
ocaat resolve did:plc:oga6ppys7zwxlheuqmcm7dac --format markdown
```

## Key management

Key commands produce local `doctor` documents with the selected format.

### key generate

Generates a P-256 key by default. Use `--type K-256` for secp256k1.

### key inspect

Parses a public or secret multibase/DID key and returns curve and encoding
metadata.

## Relay support

Relay reads use `--relay-host URL` and identify `relay` as their provenance
source.

### relay account list

Calls `com.atproto.sync.listRepos` or the collection-filtered equivalent and
returns a `records` document.

### relay account status

Calls `com.atproto.sync.getRepoStatus` for a validated DID.

### relay host list

Calls `com.atproto.sync.listHosts` and returns a `records` document.

### relay host status

Calls `com.atproto.sync.getHostStatus` for the supplied hostname.

## Tempest integration

These commands are safe helpers for Tempest-specific workflows.

### tempest migration-plan

Prints the ordered migration plan. It is a human-facing plan rather than a
network result document.

## Identifier tools

Syntax checks are local and render `doctor` documents on success. Validation
failures keep the validation exit code and write diagnostics to stderr.

### syntax handle check

Validates an AT Protocol handle.

### syntax did check

Validates a DID.

### syntax nsid check

Validates an NSID.

### syntax at-uri check

Validates an AT URI.

### syntax rkey check

Validates a record key.

### syntax cid check

Validates a CID.

### syntax tid check

Validates a TID.

### syntax tid generate

Generates a TID.

### syntax datetime now

Prints the current AT Protocol datetime.

### syntax datetime check

Validates an AT Protocol datetime.

### syntax language check

Validates an ISO-style language tag.

### syntax url check

Validates an HTTP or HTTPS service URL and rejects credentials, queries,
fragments, and non-root paths.

### syntax artifact-path check

Validates a local artifact path before filesystem work.

## XRPC queries

XRPC queries are read-only GET requests and return a `pds` document.

### xrpc query

Calls a validated method NSID against `--pds URL`. Repeated `--param K=V`
options become URL query parameters. Procedures are outside this command's
read-only scope.
