---
title: Documentation and release readiness
status: ready
---

## Purpose

Make the CLI installable, safe to operate, and verifiable before each milestone
is represented as a release.

## Requirements

- Keep the README command tree synchronized with implemented commands only.
- Publish a Tempest migration runbook, backup and restore runbook, credential
  safety guidance, format and JSONL examples, and skill-install guidance.
- Generate shell completions if supported by the settled CLI implementation.
- Run formatter, build, CLI tests, and deterministic smoke checks in CI.
- State release milestones in terms of observable completed specs, not a count
  of commands.

## Initial release exit criterion

The read-only first release has passed all first-release specifications,
installs atproto-read, atproto-research, and atproto-lexicons into the default
skills directory safely, and has a documented manual check against the supplied
Tempest DID.

## Verification

~~~sh
dune runtest
dune exec -- ocaat --help=plain
dune exec -- ocaat capabilities --format json
dune exec -- ocaat skill install atproto-read --dest /tmp/ocaat-skills-test
~~~

Review documentation examples against the built CLI before release.
