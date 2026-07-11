---
title: Relay and firehose operations
status: ready
---

## Objective

Finish relay inspection and provide carefully bounded live stream observation for
operators investigating crawl and repository events.

## Commands

~~~text
ocaat relay account list|status
ocaat relay host list|status|diff
ocaat relay host request-crawl <hostname>
ocaat relay admin account|host|domain|consumer list
ocaat relay admin account takedown [--reverse] <account>
ocaat relay admin host add|block|config
ocaat relay admin domain ban [--reverse] <domain>
ocaat firehose stream [--relay-host <url>] [--cursor <cursor>]
ocaat firehose tail [--account-events] [--collection <nsid>]
~~~

## Requirements

- Complete existing relay read commands and their document output first.
- Separate public observation from admin mutation and require explicit
  authorization and confirmation for every admin write.
- Stream parsing must handle interruption with exit code 130 and keep event
  records valid JSONL when selected.
- Define collection filtering and cursor semantics before opening a socket.

## Verification

Use protocol fixtures for account, identity, commit, malformed, and interrupted
events. Execute a local Tempest firehose smoke check after deterministic tests.

## Subsequent planned work

Signature and MST verification for stream commits builds on local CAR parsing.
