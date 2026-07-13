---
title: PDS observability
status: complete
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

These commands and their Pds parsing helpers exist. They now render successful
reads through the shared result document and provenance contract. Markdown uses
the normalized inspection facts for the operator summary and keeps the complete
redacted document in `Raw`; JSON keeps the endpoint response in `data`.

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
