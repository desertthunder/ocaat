---
title: Repository transfer
status: ready
---

## Purpose

Transfer repository CAR artifacts only through deliberate, resumable operations
after local CAR inspection is available.

## Commands

~~~text
ocaat repo export <handle-or-did> [-o <file.car>]
ocaat repo import <file.car>
ocaat repo describe <handle-or-did>
ocaat repo latest-commit <handle-or-did>
ocaat repo unpack <file.car> [-o <directory>]
~~~

## Requirements

- Export resolves the actor PDS under the source-selection contract and writes
  a deterministic default artifact path when -o is absent.
- Import requires explicit PDS and authenticated write authority.
- Existing artifacts are resumed or rejected; replacement requires --force.
- Describe and latest-commit are PDS reads with provenance.
- Unpack depends on validated local CAR parsing and must reject unsafe record
  paths before writing files.

## Verification

Use fixture CARs and mocked PDS binary responses. Test interrupted and resumed
exports, invalid CAR rejection before import, output collisions, and artifact
path traversal protection.

## Subsequent planned work

Remote exports are intentionally after the first local CAR inspection release.
Backup orchestration and blob transfer are separate features.
