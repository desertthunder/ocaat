---
title: Read-only MCP server
status: planned
---

## Objective

Expose the completed read-only CLI capabilities to MCP clients without
duplicating protocol logic, widening write authority, or creating an alternate
result contract.

## Initial transport and tools

The initial server runs over standard input and output using MCP JSON-RPC.
Structured protocol messages own standard output; diagnostics use standard
error. The default tool surface is read-only:

~~~text
resolve
get
record_get
record_list
plc_show
plc_history
lexicon_get
lexicon_describe
xrpc_call
car_verify
car_inspect
car_list
car_mst
batch
capabilities
doctor
~~~

Tool input schemas match the CLI argument contracts. Successful tool results
embed the same ocaat.document.v1 data as CLI JSON. Errors preserve the same
sanitized categories and never become unstructured text.

## Requirements

- Invoke shared domain modules, not shell out to the ocaat executable.
- Advertise read-only safety annotations for every tool.
- Provide the three packaged skills and the generated command reference as MCP
  resources when the protocol library supports them.
- Make network access follow the same PDS discovery and explicit override rules
  as the CLI.
- Keep server startup free of network activity, credential discovery, and
  filesystem writes.

## Verification

Add protocol fixtures for initialization, tool discovery, valid calls, invalid
arguments, remote errors, and cancellation. Execute an MCP client smoke test
against the built server and compare tool JSON with the equivalent CLI output.

## Boundaries

- Ask first: add an MCP dependency or expose a new tool.
- Never: expose a procedure, session, admin, install, or other write operation
  in this release.

## Subsequent planned work

Authenticated and write-capable MCP tools require a separate authorization and
confirmation model after the CLI write surface is complete.
