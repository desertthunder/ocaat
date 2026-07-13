---
title: Agent Skills
description: Read-only guidance for using ocaat with AT Protocol resources.
---

## Overview

Ocaat packages focused, read-only instructions for agents that need to inspect
AT Protocol data. Each skill[^skill-spec] explains the commands it supports, the source
selection rules, and the provenance fields to preserve. Skills do not grant
permission to change a repository or service.

## Available skills

| Skill              | Use it for                                                                 | Status   |
| ------------------ | -------------------------------------------------------------------------- | -------- |
| `atproto-research` | Investigation of identities, repositories, records, and PLC histories.     | Packaged |
| `atproto-lexicons` | Fetching published Lexicons and describing their primary XRPC definitions. | Packaged |
| `atproto-read`     | The general command, resource, batch, and output guide.                    | Planned  |

The packaged skill sources live under `skills/` in the repository.

## Skill contents

Each packaged skill contains a `SKILL.md` and only the references needed for its workflow:

- `atproto-research` includes discovery and provenance references.
  It records resolution, PDS, record, collection-summary, and PLC evidence while
  keeping collection discovery and backlinks as planned capabilities.
- `atproto-lexicons` includes a Lexicon workflow reference.
  It covers `lexicon get`, `lexicon describe`, and `xrpc describe`, including
  DNS authority resolution, DID-selected PDS reads, definition selection, and
  `ocaat.document.v1` provenance.

## CLI self-description

_todo_

## Installation

_todo_

## Related

- [Resource resolution](/protocol/resource-resolution) explains DID, handle,
  and PDS selection.
- [Record & PLC reads](/protocol/record-and-plc) covers the data reads used
  by the research skill.
- [Lexicons & XRPC](/protocol/lexicon-and-xrpc) documents the protocol reads
  used by the Lexicon skill.

[^skill-spec]: https://agentskills.io/specification
