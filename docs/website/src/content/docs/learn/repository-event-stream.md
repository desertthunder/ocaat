---
title: Repository Event Stream
sources:
  - https://atproto.com/specs/sync
author: AT Protocol
date: captured
captured: 2026-07-12
tags:
  - atproto
  - firehose
  - relay
  - synchronization
---

## Summary

The AT Protocol repository event stream is a WebSocket-based, CBOR-encoded
firehose of repository, identity, and account-hosting updates that can be
served by a PDS or aggregated by relays.

## Source Boundary

- **AT Protocol Sync specification:** defines repository exports, repository
  event streams, event semantics, verification properties, and synchronization
  guidance.

## Key Ideas

- **Multiple stream producers:** a PDS emits events for its hosted accounts;
  relays aggregate multiple upstream streams, and some operate at network-wide
  scope.
- **Verifiable repository updates:** commit and sync data contains signatures
  that can be verified without another PDS request, while identity and account
  information needs independent checking.
- **Resumable but not self-healing:** sequence cursors support resumption, but
  consumers must handle gaps, stale identity data, and synchronization work.

## What the Repository Event Stream Does

- Publishes repository commits and sync events, identity updates, and account
  hosting-status changes.
- Uses WebSockets with CBOR message encoding and sequence-based cursors.
- Lets relays expose a single combined stream from multiple PDSes.

## How It Works

### Stream Topology

PDS hosts expose updates for their own accounts. A relay subscribes to multiple
upstream firehoses and aggregates them; a relay that covers all PDSes produces a
full-network firehose.

### Event Semantics

The specification identifies `#commit` and `#sync` repository events,
`#identity` updates for DID documents and handles, and `#account` events for
hosting status. Events carry a sequence number, DID or repository identifier,
and a received-time estimate.

### Verification and Recovery

Repository data in the firehose is self-certifying and can be verified from the
stream data. Identity and account status are not self-certifying, so consumers
need DID/handle resolution or a check against the PDS. The specification advises
processing events sequentially for each account even when different accounts are
processed concurrently.

## Claims & Evidence

| Claim                                                                       | Support                                                                                               | Caveat / Confidence                                         |
| --------------------------------------------------------------------------- | ----------------------------------------------------------------------------------------------------- | ----------------------------------------------------------- |
| PDSes and relays can expose compatible `subscribeRepos` streams.            | The Sync specification says multiple services use the same endpoint with compatible semantics.        | High; protocol specification.                               |
| Relays aggregate upstream firehoses.                                        | The specification defines relays as services that subscribe to multiple PDS streams and combine them. | High.                                                       |
| Commit data is verifiable without fetching from the PDS.                    | The specification says synchronized repository data is self-certifying and signed.                    | High; identity and account events are explicitly different. |
| Identity events are best-effort signals, not authoritative state snapshots. | The specification says they may be absent, redundant, or modified by intermediaries.                  | High.                                                       |

## Important Terms

| Term                    | Meaning                                                                |
| ----------------------- | ---------------------------------------------------------------------- |
| Repository event stream | The AT Protocol firehose of repository, identity, and account updates. |
| Relay                   | A service that aggregates multiple upstream event streams.             |
| Cursor                  | A sequence position used to resume stream consumption.                 |
| `#commit`               | An event carrying a new repository commit, usually with a CAR diff.    |
| Self-certifying         | Independently verifiable through the stream’s signed repository data.  |

## Lessons To Reuse

- Stream topology and event verification need to be documented as separate
  concerns.
- A cursor supports resumption, but does not remove the need for reconciliation
  and state recovery.
- Per-account ordering can coexist with cross-account concurrency.

## Questions for Review

- How does a relay differ from a PDS as a stream producer?
  - A PDS emits hosted-account updates; a relay combines updates from multiple
    upstream producers.
- Which event classes require independent resolution or hosting checks?
  - Identity and account events; their data is not self-certifying.
- Why preserve ordering per account?
  - Repository revisions and synchronization state must be applied in sequence
    for one repository.

## Open Questions

- How should a consumer persist cursors and recover after a long outage?
- Which verification level is appropriate for a particular downstream use case?
- How should a consumer reconcile an identity event with current DID and handle
  resolution results?

## Connections

- **Related sources:** Jetstream documentation describes a JSON-oriented stream
  derived from this repository event stream.
- **Tension:** A relay’s wider coverage and a PDS’s direct authority answer
  different operational and verification questions.

## Takeaways

- The firehose is a protocol-level synchronization stream with explicit
  verification semantics.
- Relays broaden stream coverage by aggregation; they do not replace identity
  verification.
- Correct consumers need per-account ordering, cursors, and recovery logic.
