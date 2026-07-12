---
title: PDS observability
status: ready
---

## Purpose

Give PDS operators a concise, read-only health and repository-status view with
the shared document contract.

## Commands

~~~text
ocaat pds describe <host>
ocaat pds health --pds <url>
ocaat pds stats --pds <url>
ocaat pds admin-status --pds <url> --admin-token <token>
ocaat pds account list <host> [--handles]
ocaat pds account status <did> --pds <url>
~~~

## Current state

These commands and their Pds parsing helpers already exist. Current unit tests
cover healthy and degraded public responses, admin auth failures, listRepos
pagination, and repo status validation. They print endpoint-specific bodies or
human summaries and need migration to the shared result document.

## Requirements

- Preserve endpoint behavior and current authentication requirements.
- Pds describe and health remain public. Admin status requires admin auth.
- Human summaries include host, service DID, health, account, repo, blob, and
  sequencer facts when the service exposes them.
- Missing optional fields remain absent rather than being reported as zero.
- Use the shared JSON document and provenance renderer without changing remote
  endpoint paths.

## Verification

~~~sh
dune runtest
dune exec -- ocaat pds describe https://tempest.desertthunder.dev --format json
dune exec -- ocaat pds health --pds https://tempest.desertthunder.dev
~~~

## Subsequent planned work

PDS administration, backup, repository transfer, and blob work are documented
separately. Their status output must reuse these PDS documents where useful.
