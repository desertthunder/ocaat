---
title: Local Development
description: Developing & verifying ocaat
---

## Local PDS

Assume a local [Tempest](https://tangled.org/desertthunder.dev/tempest) PDS instance is
available at `http://localhost:4000`:

```sh
ocaat pds describe http://localhost:4000
ocaat pds health --pds http://localhost:4000
ocaat pds stats --pds http://localhost:4000
ocaat pds account list http://localhost:4000 --format json
```

These commands are read-only.

<!-- TODO: pds admin status would be better -->

Use `pds admin-status` only with an explicit admin token and the intended local target.

## Public test accounts

For interoperability checks, describe the supplied public PDS hosts without
mutating an account:

```sh
ocaat pds describe https://shaggymane.us-west.host.bsky.network --format json
ocaat pds describe https://tempest.desertthunder.dev --format json
```

Avoid strict snapshots of remote payloads.

Service metadata and hosted account state can change.

## Fixtures

Automated tests use deterministic response values and local command entrypoints.

The output-structure tests in `test/ocaat_test.ml` cover JSON documents, JSON aliases,
error documents, stderr separation, and redaction without requiring a live PDS.

### Harness

The reusable HTTP fixture harness in `test/cli_fixture.ml` runs the built CLI
executable as a subprocess, captures sanitized request metadata, and covers JSON,
binary, malformed, delayed, and remote-error responses on fixed loopback ports.

Run the checks with:

```sh
dune runtest
dune build @doc
```
