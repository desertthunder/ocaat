---
title: Account migration hardening
status: ready
---

## Objective

Make account migration into Tempest explicit, resumable, observable, and safe
through the existing account migrate command family.

## Commands

```text
ocaat account migrate plan
ocaat account migrate login-source
ocaat account migrate source-session-status
ocaat account migrate service-auth
ocaat account migrate export-car
ocaat account migrate list-source-blobs
ocaat account migrate download-source-blobs
ocaat account migrate create-account
ocaat account migrate refresh-session
ocaat account migrate import-repo
ocaat account migrate status
ocaat account migrate missing-blobs
ocaat account migrate upload-missing-blobs
ocaat account migrate plc-recommended
ocaat account migrate plc-request-token
ocaat account migrate plc-sign
ocaat account migrate plc-submit
ocaat account migrate activate
ocaat account migrate full [--cutover]
```

## Current state

The explicit subcommand scaffold and artifact helpers exist. The intended flow
comes from Tempest migration behavior, but command outputs, resume guarantees,
mocked HTTP coverage, and cutover gates need completion.

## Requirements

- Plan lists source and target hosts, source DID, target service DID, handle,
  artifact directory, expected artifacts, and reuse status.
- Every artifact is reusable and is overwritten only with --force.
- Full runs only through non-activation work by default. --cutover explicitly
  permits PLC submission and activation.
- Status reports migrationReady, missing blobs, import state, activation state,
  sessions, and PLC operation state.
- Activate refuses until status is ready unless --force is explicit.
- Signing shows the resulting atproto_pds endpoint before artifact creation.

## Verification

Use mocked source and Tempest responses for every step, including missing auth,
wrong host, invalid identifiers, missing artifacts, and remote XRPC errors.
Execute the full dry-run sequence twice and prove that the second run reuses
artifacts without replacing them.

## Subsequent planned work

Credential persistence and generic account session commands are specified
separately. Migration retains its own artifact and cutover safety rules.
