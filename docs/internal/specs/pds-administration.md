---
title: PDS administration
status: ready
---

## Objective

Provide explicit, authenticated Tempest PDS administration without weakening the
read-only default of the main product direction.

## Commands

~~~text
ocaat pds admin account create --handle <handle> --email <email> [--password <password>]
ocaat pds admin account list
ocaat pds admin account info <handle-or-did>
ocaat pds admin account update <handle-or-did> [--email <email>] [--handle <handle>]
ocaat pds admin account reset-password <handle-or-did>
ocaat pds admin account takedown [--reverse] <handle-or-did>
ocaat pds admin account delete --yes <handle-or-did>
ocaat pds admin blob status <handle-or-did> <cid>
ocaat pds admin blob purge [--reverse] <handle-or-did> <cid>
ocaat pds admin invite create --count <n> --uses <n>
~~~

## Requirements

- Add a dedicated Pds_admin module and thin command module.
- Require admin auth before any protected request.
- Print target PDS, target account or blob, method, and intended mutation before
  confirmation.
- Password values come from a prompt when omitted and are never echoed or
  rendered.
- Takedown, reset, purge, and delete require interactive confirmation or --yes.
- Validate account identifiers, CIDs, counts, and update inputs before requests.

## Verification

Add deterministic CLI HTTP fixtures that assert method, path, query, auth
header, request body, response status, and JSON output. Cover every destructive
preflight and confirmation path.

## Subsequent planned work

Operator browser workflows remain in Tempest. Ocaat only owns the portable CLI
surface and does not store admin credentials.
