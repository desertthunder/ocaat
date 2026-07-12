---
title: Tempest backup helpers
status: ready
---

## Purpose

Expose Tempest-specific backup state without confusing it with portable AT
Protocol operations.

## Commands

~~~text
ocaat tempest backup create
ocaat tempest backup status
ocaat tempest backup verify <backup-directory>
ocaat tempest repo verify --did <did>
~~~

## Requirements

- Keep Tempest-specific endpoints in a dedicated Tempest module and command
  group.
- Require admin auth for remote backup operations.
- Make create and verify artifact paths explicit and non-overwriting by default.
- Render backup state with the common result contract and a Tempest source tag.

## Verification

Use Tempest admin fixture responses and local backup fixtures. Verify auth
preflight, path validation, damaged backup detection, and JSON redaction.

## Subsequent planned work

Portable CAR and blob tools must not assume Tempest backup endpoint semantics.
