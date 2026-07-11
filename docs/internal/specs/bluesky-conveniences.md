---
title: Bluesky conveniences
status: ready
---

## Objective

Offer a deliberately small set of Bluesky account conveniences once the generic
account, record, and credential contracts are stable.

## Commands

~~~text
ocaat bsky prefs export
ocaat bsky prefs import <file>
ocaat bsky post <text>
~~~

## Requirements

- Export is read-only and JSON-friendly.
- Import validates input before any procedure request.
- Post validates text, session, repository, and record response before
  reporting the created URI and CID.
- Do not introduce a parallel credential system; use account sessions.

## Verification

Add mocked auth, preference, malformed JSON, and successful post fixtures.
Manual live checks must use a non-production test account.

## Subsequent planned work

Broader app-specific APIs should remain generic XRPC or be justified as a new
feature specification.
