---
title: Getting Started
description: Configure ocaat and run a first read-only PDS check.
---

## Installation

Build the CLI from the repository with Dune:

```sh
dune build
```

The executable is available through `dune exec ./bin/main.exe -- ...`.

## Configuration

Set a default PDS and optional bearer credentials with environment variables:

```sh
export OCAAT_PDS=https://tempest.desertthunder.dev
export OCAAT_AUTH=...
export OCAAT_ADMIN_TOKEN=...
```

Explicit `--pds`, `--auth`, and `--admin-token` options override these values.

The CLI treats credentials as sensitive and redacts them (best-effort) from output.

## Using ocaat

Start with a read-only service description:

```sh
dune exec ./bin/main.exe -- \
  pds describe https://tempest.desertthunder.dev --format json
```

The same command accepts the bare host form `tempest.desertthunder.dev`, which defaults to HTTPS.

### PDS selection

Use `--pds URL` for commands whose endpoint is selected globally. Positional
host arguments, such as `pds describe HOST`, identify the service directly.

Ocaat validates the URL before making a request.

### Authentication

Use `--auth TOKEN` for authenticated protocol requests and `--admin-token TOKEN`
for PDS admin endpoints.

Missing required authentication fails before the network request with exit code 66.

### Output

Markdown is the default output format. You can select JSON with `--format json` or `--json`:

```sh
dune exec ./bin/main.exe -- \
  syntax did check did:plc:oga6ppys7zwxlheuqmcm7dac --json
```

Successful documents go to stdout. Progress, warnings, and errors go to stderr.

JSON results use `ocaat.document.v1` and include the actual endpoint,
source, and RFC3339 `fetched_at` timestamp.

JSON errors use `ocaat.error.v1` and preserve stable exit categories.

### Local artifacts

Migration commands use `.sandbox` as a temp directory[^1] by default and accept
`--artifact-dir DIR`. Artifact paths are checked before writes; existing artifacts
require `--force` to replace them.

[^1]: this is an [owais](https://desertthunder.dev)-ism
