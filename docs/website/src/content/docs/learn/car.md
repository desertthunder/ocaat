---
title: Content Addressable aRchives (CAR)
sources:
  - https://ipld.io/specs/transport/car/carv1/
  - https://atproto.com/specs/data-model
  - https://atproto.com/specs/repository
  - https://atproto.com/specs/sync
author: IPLD and AT Protocol contributors
date: captured
captured: 2026-07-12
tags:
  - car
  - content-addressing
  - ipld
  - atproto
---

## Summary

A CAR file is a simple stream of content-addressed blocks plus root identifiers.
The container supplies transport framing, while the linked data format and the
application determine what the blocks mean and how completely they must be
verified.

## Source Boundary

- **IPLD CAR v1 specification:** defines the container header, section framing,
  CID encoding, and the format's limits.
- **AT Protocol data model and repository specifications:** describe one use of
  CAR v1, including normalized CBOR, commits, records, and Merkle Search Trees.
- **AT Protocol sync specification:** explains how complete repository exports
  are transported and the operational limits of redistributing snapshots.

CAR is a general container. AT Protocol repository rules are an application
profile layered on top of it.

## Key Ideas

- **Blocks are content-addressed:** every data section carries a CID that names
  the following bytes by codec and digest.
- **Roots are entry points, not a manifest:** a root CID points into the block
  set, but the CAR format alone does not prove that the graph is complete or
  that every included block belongs to it.
- **Framing is stream-friendly:** unsigned varint lengths let readers process
  the header and blocks sequentially.
- **Meaning lives above CAR:** a reader needs the CID codec and an application
  schema to interpret and validate block contents.

## What CAR Does

- Stores IPLD blocks in a portable binary stream.
- Identifies one or more graph roots in a small header.
- Keeps each block's CID adjacent to its bytes.
- Supports sequential processing without a built-in index.

CAR does not define graph traversal, guarantee block order, verify application
signatures, or require every included block to be reachable from a root.

## How It Works

### CAR v1 Layout

```text
[ header length | DAG-CBOR header ]
[ section length | CID | block bytes ]
[ section length | CID | block bytes ]
...
```

Lengths are unsigned LEB128 varints. The header contains `version`, which is
`1`, and a `roots` array of CIDs. Each later length covers both the CID and the
block bytes, but not the length prefix itself.

### CIDs and Verification

A CID encodes a version, a content codec, and a multihash. The multihash names
the hash function and digest length before carrying the digest. A reader must
therefore decode the CID incrementally rather than assume a fixed size.

Checking a block requires recomputing the permitted hash over the exact block
bytes and comparing it with the CID digest. Successfully decoding the CID does
not perform this integrity check by itself.

### Reading a CAR Safely

A defensive reader should:

1. Decode varints with overflow and canonical-encoding checks.
2. Reject unsupported versions and enforce an application-specific root policy.
3. Bound the header, each section, block count, total bytes, and in-memory index.
4. Ensure a section is long enough to contain its decoded CID.
5. Read the declared bytes completely and reject truncation.
6. Recompute every supported CID digest.
7. Define how duplicate CIDs and conflicting duplicate blocks are handled.
8. Apply codec and application validation separately from container parsing.

### Indexing and Traversal

CAR v1 has no internal index. A reader that needs random access can scan once
and build a bounded map from CID to byte offset and length. A graph walk then
starts from a root and follows links through that index. Unreachable blocks may
still exist in the file and need an explicit accept, report, or reject policy.

### AT Protocol Repository Profile

AT Protocol repository exports use CAR v1. The first root identifies the most
relevant signed commit. A full export includes the commit, the Merkle Search
Tree nodes reachable from its `data` link, and the records referenced by the
tree. Blocks use normalized DRISL-CBOR, the successor to DAG-CBOR in the AT
Protocol data model.

Repository verification adds requirements that CAR does not provide: commit
shape and version checks, CID restrictions, MST key ordering and depth checks,
record-path validation, graph completeness, and commit-signature verification
against identity keys when authenticity is required.

## Claims & Evidence

| Claim                                                                              | Support                                                                                                   | Caveat / Confidence                                                   |
| ---------------------------------------------------------------------------------- | --------------------------------------------------------------------------------------------------------- | --------------------------------------------------------------------- |
| CAR v1 is a length-prefixed header followed by length-prefixed CID/block sections. | The CAR v1 format description specifies this byte layout.                                                 | High.                                                                 |
| A valid CAR is not necessarily a complete or coherent DAG.                         | The CAR specification permits arbitrary blocks and does not require all blocks to belong to a root graph. | High.                                                                 |
| CAR creation is not inherently deterministic.                                      | The specification leaves block and root ordering rules to applications.                                   | High.                                                                 |
| AT Protocol repository exports use CAR v1.                                         | The repository specification names CAR v1 as the standard export format.                                  | High.                                                                 |
| Content integrity and repository authenticity are different checks.                | CIDs authenticate block bytes; repository commits add signatures and application structure.               | High. Signature verification also depends on identity-key resolution. |

## Important Terms

| Term       | Meaning                                                                          |
| ---------- | -------------------------------------------------------------------------------- |
| Block      | A byte sequence addressed by a CID.                                              |
| CID        | A self-describing content identifier containing codec and multihash information. |
| Codec      | The code identifying how block bytes should be interpreted.                      |
| Multihash  | A hash-function code, digest length, and digest packaged together.               |
| Root       | A CID advertised as an entry point into blocks in the archive.                   |
| DAG        | A directed acyclic graph formed when decoded blocks link to other blocks.        |
| DRISL-CBOR | The normalized CBOR profile used by current AT Protocol data.                    |
| MST        | The deterministic Merkle Search Tree used for AT Protocol repository records.    |

## Lessons To Reuse

- Validate binary framing before allocating or decoding application objects.
- Keep container validity, block integrity, graph completeness, and application
  authenticity as distinct states.
- Do not infer deterministic meaning from physical block order unless an
  application profile explicitly requires it.
- Preserve exact bytes whenever hashes or signatures depend on serialization.

## Questions for Review

- What information does a CAR v1 header contain?
  - A version number and an array of root CIDs.
- Why can a CAR with valid framing still be unusable?
  - Its blocks may fail CID digest checks, omit linked blocks, use unsupported
    codecs, or violate the application schema.
- Why must a parser bound section lengths before allocating?
  - The length prefixes come from untrusted input and could otherwise cause
    excessive allocation or resource exhaustion.
- What does an AT Protocol repository verifier add beyond CAR parsing?
  - It validates commits, normalized CBOR, CID restrictions, MST structure,
    record paths, reachable blocks, and optionally the commit signature.

## Connections

- **Related ideas:** content-addressed storage, Merkle DAGs, streaming binary
  formats, deterministic serialization, and archive indexes.
- **Tension:** CAR is deliberately permissive, while applications often need a
  narrow and strict acceptance profile.
- **Useful applications:** offline graph transfer, repository export, backup,
  synchronization, and test fixtures.

## Open Questions

- Should a particular application accept multiple roots or require exactly one?
- How should duplicate CIDs and unreachable blocks be reported?
- Which codecs, CID versions, and hash algorithms should an application admit?
- Does a use case require block integrity, graph completeness, signatures, or
  all three?

## Takeaways

- CAR v1 is transport framing for content-addressed blocks, not a complete
  verification protocol.
- Safe readers need explicit resource limits and must verify CID digests.
- Application formats such as AT Protocol repositories add their own graph,
  encoding, and authenticity rules.
