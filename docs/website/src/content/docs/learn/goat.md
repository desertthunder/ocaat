---
title: goat cli
sources:
  - https://github.com/bluesky-social/goat
  - https://atproto.com/guides/the-at-stack
author: Bluesky Social
date: captured
captured: 2026-07-12
tags:
  - atproto
  - cli
  - goat
---

## Summary

Goat is Bluesky Social’s general-purpose Go command-line tool for querying and
operating parts of the AT Protocol network, with public reads as the normal
case and authenticated commands for account changes.

## Source Boundary

- **goat repository README:** describes the tool’s stated purpose, installation,
  authentication behavior, output examples, and representative command use.
- **AT Protocol “The AT Stack” guide:** names goat as the Go AT command-line
  tool in the broader protocol tooling ecosystem.

## Key Ideas

- **General-purpose network CLI:** goat describes itself as a curl-like AT
  Protocol tool rather than an application-specific client.
- **Read first, authenticate when needed:** the README says most commands use
  public APIs, while actions such as record creation require an account.
- **Broad operational surface:** its documented examples span `at://` reads,
  repository and blob export, PLC inspection, firehose observation, account
  migration, and PDS administration.

## What goat Does

- Resolves identities and fetches `at://` resources.
- Exports repositories and blobs, and inspects PLC history.
- Subscribes to a relay’s repository event stream, including an operation view
  that unpacks record changes.
- Supports authenticated account and PDS operations.

## How It Works

### Command Surface

The README presents built-in help as the primary interface for discovery. Its
examples show direct commands for identity lookup, record retrieval, repository
export, PLC history, syntax checks, and firehose inspection.

### Authentication and Local State

Public API calls generally do not need authentication. The README says that
account login uses an app password and warns that the current implementation
stores the app password and tokens in a cleartext file in the user’s home
directory.

### Output

The README shows JSON output for identity and record reads, and explicitly notes
that some commands produce JSON suitable for processing with tools such as
`jq`.

## Claims & Evidence

| Claim                                                               | Support                                                                                                                  | Caveat / Confidence                                           |
| ------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------ | ------------------------------------------------------------- |
| Goat is a general-purpose AT Protocol CLI.                          | The repository calls it a curl-like tool and lists URI fetching, firehose monitoring, migration, and PDS administration. | High; stated by the project README.                           |
| Goat’s surface includes both public reads and authenticated writes. | The README says most commands use public APIs and gives record creation as an authenticated example.                     | High; individual command requirements may vary.               |
| Goat can observe record-level firehose operations.                  | The README documents a firehose operation mode that unpacks records and emits one result per record operation.           | High for the documented behavior.                             |
| Goat’s local credential storage is unsafe for sensitive use.        | The README explicitly warns that app passwords and tokens are stored in cleartext.                                       | High for the documented version; storage behavior can change. |

## Important Terms

| Term         | Meaning                                                     |
| ------------ | ----------------------------------------------------------- |
| `at://` URI  | An AT Protocol URI identifying repository data.             |
| Firehose     | A repository event stream, often served by a relay.         |
| App password | An account credential intended for application use.         |
| PLC          | The identity-operation system used by `did:plc` identities. |

## Lessons To Reuse

- A broad network CLI can keep public inspection and authenticated mutation in
  distinct command paths.
- Built-in help can be the primary discovery mechanism for a large command
  surface.
- Credential-storage behavior deserves explicit, user-visible documentation.

## Questions for Review

- What makes goat a general-purpose tool rather than a Bluesky-only client?
  - Its documented surface crosses identity, repositories, PLC, streams,
    migrations, and PDS administration.
- When does the README say authentication is needed?
  - For commands that change account state, such as record creation; most
    public API reads do not require it.
- What security warning does the README give?
  - The documented version stores app passwords and tokens in cleartext locally.

## Open Questions

- Which documented commands are stable across goat releases, and which remain
  experimental?
- Does current goat offer output formats beyond the JSON examples in its README?
- Has the credential-storage warning been addressed in a later release?

## Connections

- **Related sources:** The AT Stack guide places goat among Go and TypeScript
  tooling for the protocol.
- **Useful comparison:** The repository’s README provides command-level
  behavior; the AT Stack guide provides ecosystem-level placement.

## Takeaways

- Goat is a broad AT Protocol command-line tool, not only a PDS admin client.
- Its documented public-read and authenticated-write split is central to its
  interface.
- Its cleartext credential warning is a material operational caveat.
