---
title: Generated API documentation
status: planned
---

## Objective

Generate accurate CLI, MCP, and HTTP reference material from one capability
registry so that released interfaces cannot silently drift from their
documentation.

## Outputs

~~~text
ocaat docs generate [--output <directory>]

generated/
  cli.md
  mcp-tools.md
  http-openapi.json
  skills.md
  output-contracts.md
~~~

The generator reads command names, argument schemas, output formats, safety
class, capability status, and examples from the shared registry. It does not
scrape help text as its primary data source.

## Requirements

- Produce deterministic files with stable ordering and no timestamps unless a
  reproducible build flag explicitly requests one.
- Document required PDS and auth inputs, provenance fields, error documents,
  batch semantics, and the read-only safety boundary.
- Generate OpenAPI only for the HTTP gateway endpoints actually implemented.
- Generate MCP tool documentation only from registered MCP tools.
- Fail verification when generated artifacts differ from committed output.

## Verification

Run generation twice and compare output. Add a CI check that regenerates the
reference and fails on a diff. Review a representative CLI command, MCP tool,
HTTP endpoint, and installed-skill listing against the generated documents.

## Subsequent planned work

Write-capable APIs are documented only after their authorization and confirmation
contracts are settled.
