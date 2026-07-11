---
title: Agent skills and CLI self-description
status: ready
---

## Objective

Ship three discoverable read-only skills that teach agents how to use ocaat
safely, and let users inspect or install those exact bundled skills without
inventing target-specific behavior.

## Commands

```text
ocaat skill list
ocaat skill show <atproto-read|atproto-research|atproto-lexicons>
ocaat skill path <atproto-read|atproto-research|atproto-lexicons>
ocaat skill install <atproto-read|atproto-research|atproto-lexicons> [--dest <directory>] [--force]
ocaat capabilities
ocaat doctor [--pds <url>]
ocaat completions <bash|zsh|fish>
```

The bundled sources are:

~~~text
skills/
  atproto-read/
    SKILL.md
    references/commands.md
    references/resources.md
    references/output-contracts.md
  atproto-research/
    SKILL.md
    references/discovery.md
    references/provenance.md
  atproto-lexicons/
    SKILL.md
    references/lexicon-workflows.md
~~~

Install copies the complete named skill directory to
HOME/.agents/skills/<skill-name> by default. --dest changes the parent skills
directory. It never overwrites an existing installation unless --force is
present, and it reports the final installed path.

## Skill content

Atproto-read covers commands, resource classification, source selection, batch
JSONL, and output contracts. Atproto-research teaches evidence-oriented
investigation with resolve, get, record, PLC, and current collection summaries;
its discovery reference must name collection discovery and backlinks as planned
capabilities rather than pretend they exist. Atproto-lexicons covers the
available Lexicon get, describe, and XRPC-description workflows and distinguishes
them from planned local validation and publishing work.

Every skill directs agents to read first, report provenance, use explicit --pds
overrides only when intended, and never infer permission for write operations.

## Current state

No skills directory, skill command group, capability registry, doctor command,
or completion command exists. Existing artifact guards provide the no-overwrite
behavior needed for installation.

## Acceptance criteria

- Skill list, show, and path describe the exact packaged content for all three
  skills.
- Install defaults to HOME/.agents/skills and fails clearly if HOME is absent.
- Install is atomic enough that a failed copy does not replace a working skill.
- Capabilities reports commands, format support, read or write safety class, and
  feature availability in JSON and Markdown.
- Doctor performs local checks by default and probes a PDS only when --pds is
  explicit.
- The installed skill contains no executable installer logic or write guidance.

## Verification

```sh
dune runtest
dune exec -- ocaat skill show atproto-read
dune exec -- ocaat skill show atproto-research
dune exec -- ocaat skill show atproto-lexicons
dune exec -- ocaat skill install atproto-read --dest /tmp/ocaat-skills-test
dune exec -- ocaat capabilities --format json
dune exec -- ocaat doctor
```

Use a temporary destination for automated CLI tests. Confirm a second install
fails without --force and preserves the first copy.

## Subsequent planned work

Codex, Claude, and other target adapters may be added after their installation
rules are researched. They must not change the default .agents/skills contract.
