---
title: Read-only HTTP gateway
status: planned
---

## Purpose

Provide a small, local HTTP interface to the read-only domain modules for
scripts and services that cannot speak MCP.

## Server and API contract

The server binds to loopback by default. A non-loopback listen address requires
an explicit flag and a visible warning. It performs no startup network probe.

~~~text
ocaat serve [--listen 127.0.0.1:8080]

GET  /v1/resolve/{actor}
GET  /v1/get?resource=<resource>&pds=<optional-url>
GET  /v1/records/{actor}?collection=<nsid>&limit=<n>&cursor=<cursor>
GET  /v1/plc/{actor}
GET  /v1/plc/{actor}/history
GET  /v1/lexicons/{nsid}
POST /v1/batch
GET  /v1/capabilities
GET  /v1/health
~~~

Responses use ocaat.document.v1 or ocaat.error.v1. Batch accepts JSONL or a
JSON array only when its response representation preserves one result per input
record. HTTP status represents request-level failure; per-item batch errors
remain in the batch response.

## Requirements

- Reuse the same resource, output, provenance, and redaction modules as the CLI
  and MCP server.
- Validate all request parameters before network access.
- Reject CORS by default. If CORS is later enabled, require explicit origins.
- Set response-size, request-size, and timeout limits. Do not proxy arbitrary
  URLs beyond the existing explicit resource and PDS contracts.
- Provide graceful shutdown and do not write persistent state.

## Verification

Run a loopback integration suite covering each endpoint, malformed input,
oversize request, PDS override, batch partial failure, loopback default, and
non-loopback opt-in. Compare representative responses with CLI JSON.

## Boundaries

- Ask first: add a web-server dependency, listen beyond loopback, or add auth.
- Never: expose write, admin, credential, or skill-install endpoints.

## Subsequent planned work

Authenticated or remote-facing gateway deployments require explicit transport
security, authentication, rate limiting, and operational review.
