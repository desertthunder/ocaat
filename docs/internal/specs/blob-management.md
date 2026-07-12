---
title: Blob management
status: ready
---

## Purpose

Support safe inspection and transfer of repository blobs with resumable local
artifacts and explicit authenticated writes.

## Commands

~~~text
ocaat blob list <handle-or-did>
ocaat blob download <handle-or-did> <cid> [-o <path>]
ocaat blob export <handle-or-did> [-o <directory>]
ocaat blob upload <file>
ocaat blob missing
ocaat blob compute <file>
~~~

## Requirements

- List, download, and export discover the actor PDS unless an explicit override
  is present.
- Downloads and exports report requested, downloaded, skipped, failed, and
  missing counts.
- Resume behavior validates existing file identity before skipping.
- Upload and missing require the appropriate bearer auth and report CID, size,
  media type when known, and sanitized remote result.
- Local compute validates file access and reports a canonical CID.

## Verification

Add local files and mocked binary endpoints for successful transfer, partial
resume, CID mismatch, missing blob, authentication failure, and write collision.

## Subsequent planned work

Garbage collection and operator-side blob purging remain PDS administration.
