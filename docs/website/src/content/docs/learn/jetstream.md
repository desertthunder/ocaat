---
title: Jetstream
sources:
  - https://docs.bsky.app/blog/jetstream
  - https://github.com/bluesky-social/jetstream
author: Bluesky Social
date: 2024-10-16
captured: 2026-07-12
tags:
  - atproto
  - jetstream
  - streaming
---

## Summary

Jetstream is an AT Protocol streaming service designed to make full-network
event consumption simpler and cheaper than consuming the binary repository
firehose directly, with important verification and stability tradeoffs.

## Source Boundary

- **“Introducing Jetstream” (2024):** explains the original service as a JSON
  fan-out layer over the firehose, its intended use cases, and its tradeoffs.
- **Current Jetstream repository README:** describes the current repository as
  a full-network archive and streaming service and warns that its on-disk format
  is not yet stable before a 1.0 release.

The two sources may describe different stages or generations of Jetstream. This
note preserves both rather than treating their operational details as identical.

## Key Ideas

- **Simpler event representation:** the 2024 announcement presents Jetstream as
  JSON instead of the firehose’s CBOR and CAR-based payloads.
- **Targeted subscriptions:** the announcement identifies collection and DID
  filtering as a way to avoid processing unrelated full-network traffic.
- **Different trust model:** Jetstream events omit signatures and Merkle-tree
  nodes, so they are not self-authenticating in the way firehose repository data
  can be.

## What Jetstream Does

- Consumes data from an AT Protocol firehose and fans it out to subscribers.
- Provides event categories for repository commits, identity changes, and
  account-status changes in the original service documentation.
- Offers a lower-complexity option for filtered event consumption.

## How It Works

### Event Transformation

The 2024 announcement describes a Jetstream server consuming firehose events,
then serving JSON to many subscribers. It identifies filtering by collection
(NSID) and repository (DID) as part of that service.

### Verification Boundary

The announcement says Jetstream drops cryptographic signatures and Merkle-tree
nodes from events. A consumer therefore relies on the Jetstream operator unless
it independently verifies data through another path.

### Operational Status

The current repository calls itself a full-network archive and streaming service
and includes a pre-1.0 compatibility warning for on-disk data. The 2024 article
also says that Jetstream is not formally part of the AT Protocol and was not
promised as a stable, critical API. These statements should be rechecked before
depending on a specific deployment or storage format.

## Claims & Evidence

| Claim                                                     | Support                                                                                               | Caveat / Confidence                                               |
| --------------------------------------------------------- | ----------------------------------------------------------------------------------------------------- | ----------------------------------------------------------------- |
| Jetstream provides JSON events derived from the firehose. | The 2024 announcement describes it as a firehose-consuming fan-out service with simple JSON encoding. | High for the original service.                                    |
| Jetstream supports filtering by collection and DID.       | The announcement names both filtering modes as core advantages.                                       | High for the described service; check the current API before use. |
| Jetstream data is not self-authenticating.                | The announcement says events omit signatures and Merkle-tree nodes.                                   | High; consumers need to understand the resulting trust boundary.  |
| Current Jetstream storage is not yet stable.              | The current repository warns of backward-incompatible on-disk-format changes before 1.0.              | High for the repository state captured here; time-sensitive.      |

## Important Terms

| Term                | Meaning                                                                                       |
| ------------------- | --------------------------------------------------------------------------------------------- |
| Firehose            | The AT Protocol repository event stream from which Jetstream consumes.                        |
| NSID                | A namespaced identifier; Jetstream’s original documentation uses it for collection filtering. |
| Self-authenticating | Data that carries enough cryptographic structure for independent verification.                |
| Fan-out             | One upstream stream being distributed to many downstream subscribers.                         |

## Lessons To Reuse

- A simpler data format can shift complexity into a different trust boundary.
- A streaming API needs filtering, cursor, and deployment details documented
  together with its encoding.
- Sources from different project generations should not be merged without
  identifying the version boundary.

## Questions for Review

- Why can Jetstream be easier to use than the repository firehose?
  - It presents JSON and can filter by collection or DID instead of requiring
    every consumer to decode full binary stream data.
- What trust property is lost in the original Jetstream representation?
  - The signatures and Merkle-tree nodes needed for self-authentication are not
    included.
- Why should an operator distinguish the two sources in this note?
  - The 2024 announcement and current repository describe different operational
    states, especially around stability and storage.

## Open Questions

- Which parts of the original JSON subscription API remain supported by the
  current repository?
- What is the current production deployment and stability policy for Jetstream?
- Which consumer workflows require self-authenticating firehose data rather
  than the convenience of Jetstream?

## Connections

- **Related sources:** The AT Protocol Sync specification defines the repository
  firehose that the original Jetstream service consumed.
- **Tension:** JSON and filtering reduce consumer work, while the omitted
  cryptographic material reduces independent verification.

## Takeaways

- Jetstream is an optional simplification layer over firehose data, not a
  substitute for every stream consumer.
- Its JSON and filtering benefits come with a different verification model.
- Current operational and compatibility details need version-specific checking.
