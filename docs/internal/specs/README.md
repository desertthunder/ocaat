# ocaat feature specifications

## Product direction

ocaat is an OCaml implementation of the AT Protocol CLI space represented
by goat, and to be useful for PDS operators. Its delivery sequence is:

1. Read-only AT Protocol querying.
2. Programmatic read-only interfaces for agents and HTTP clients.
3. PDS management and broader goat feature parity, with Tempest-specific
   capabilities treated as integrations.

The first release is complete only when a user can inspect an actor, record,
PLC identity, Lexicon, PDS, JSONL batch, and local repository CAR through the
CLI, with stable provenance and machine-readable output. It also ships the
atproto-read, atproto-research, and atproto-lexicons agent skills.

## v0.1 specifications

- [CLI foundations](cli-foundations.md)
- [Resource resolution and universal get](resource-resolution-and-universal-get.md)
- [Record and PLC reads](record-and-plc-reads.md)
- [Lexicon and XRPC reads](lexicon-and-xrpc-reads.md)
- [Batch JSONL](batch-jsonl.md)
- [Local repository CAR inspection](repository-car-inspection.md)
- [Agent skills and self-description](agent-skills-and-self-description.md)

## Next: programmatic read interfaces

- [MCP server](mcp-server.md)
- [HTTP gateway](http-gateway.md)
- [Generated API documentation](generated-api-documentation.md)

## Planned

- [PDS observability](pds-observability.md)
- [Account migration](account-migration.md)
- [PDS administration](pds-administration.md)
- [Repository transfer](repository-transfer.md)
- [Blob management](blob-management.md)
- [Tempest backup helpers](tempest-backup.md)
- [Account and session management](account-and-session-management.md)
- [Relay and firehose operations](relay-and-firehose.md)
- [Lexicon development](lexicon-development.md)
- [Bluesky conveniences](bluesky-conveniences.md)
- [Documentation and release readiness](documentation-and-release.md)
