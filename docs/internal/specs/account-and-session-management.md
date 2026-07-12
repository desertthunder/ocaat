---
title: Account and session management
status: ready
---

## Purpose

Support authenticated account lifecycle work while making credential storage
opt-in, reviewable, and safe.

## Commands

```text
ocaat account login --pds <url> --identifier <handle-or-email>
ocaat account logout
ocaat account session
ocaat account refresh
ocaat account status [<handle-or-did>]
ocaat account check-auth
ocaat account service-auth --aud <did> --lxm <nsid>
ocaat account app-password list|create|revoke
ocaat account missing-blobs
ocaat account activate|deactivate|delete --yes
```

## Requirements

- Prompt for passwords without echoing them.
- Redact all session and app-password material in every output mode.
- Use OS keychain or pass integration for persistent credentials by default.
- Allow plaintext storage only behind explicit --store-plaintext with warning.
- Require target summaries and confirmation for deactivate and delete.

## Verification

Use mocked session lifecycle responses and isolated temporary credential stores.
Test missing auth, refresh behavior, redaction, confirmation, and storage
failure without contacting a PDS.

## Subsequent planned work

OAuth and DPoP support require their own security review before altering this
credential contract.
