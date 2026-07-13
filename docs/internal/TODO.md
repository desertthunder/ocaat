# TODO

## Milestone 0: reusable read foundations

**Exit criterion:** New read-only features share a tested result contract and
fixture boundary, while CAR implementation risk has an explicit, evidence-backed
decision.

### T01: Establish the document output contract

**Spec:** [CLI foundations](specs/cli-foundations.md)
**Status:** complete

Replaced the shared boolean JSON setting with the Markdown,
JSON, JSONL, and raw format contract; add versioned documents, provenance,
renderers, and versioned errors.

### T02: Add a reusable CLI HTTP fixture harness

**Spec:** [CLI foundations](specs/cli-foundations.md)
**Status:** complete

Created a deterministic local HTTP fixtures that run commands through the executable
boundary and assert request method, URL, headers, body, response body, stderr, stdout,
and exit status.

### T03: Decide the bounded CAR implementation path

**Spec:** [Local repository CAR inspection](specs/repository-car-inspection.md)
**Status:** complete

Ran a compatibility spike against Tempest-compatible CAR fixtures, documented
parser limits, and evaluated Pegasus `ipld` as the exact OCaml dependency
candidate. Its current reader lacks the validation and limits required for
untrusted input, so T12 retains a bounded native implementation while treating
Pegasus as the primary reference and future dependency candidate.

### T04: Render useful Markdown documents

**Status:** complete
**Spec:** [Useful Markdown output](specs/useful-markdown-output.md)

Replaced the JSON-only Markdown view with semantic, kind-aware summaries, visible
provenance, and a final `Raw` section containing the complete redacted result envelope.
Construct and serialize CommonMark with the approved, pinned cmarkit 0.4.0 dependency.

## Milestone 1: read-only CLI and skill release

**Exit criterion:** A user or agent can investigate a resource, PDS, record,
PLC identity, Lexicon, JSONL batch, and local CAR using stable provenance; all
three bundled skills install safely into the default skills directory.

### T05: Migrate existing PDS reads to result documents

**Spec:** [PDS observability](specs/pds-observability.md)

**What to build:** Move PDS describe, health, stats, admin-status, and account
read output to the document and provenance contract without changing their
endpoint or authentication semantics.

**Blocked by:** T01

**Acceptance criteria:**

- [x] Public and admin PDS responses retain their current useful summaries.
- [x] Missing optional metrics remain absent rather than becoming zero values.
- [x] JSON output includes the actual PDS endpoint and source metadata.

**Verification:**

- dune runtest
- dune exec -- ocaat pds health --pds https://tempest.desertthunder.dev --format json

### T06: Implement identity resolution

**Spec:** [Resource resolution and universal get](specs/resource-resolution-and-universal-get.md)

**What to build:** Add handle resolution, did:plc and did:web document lookup,
PDS service extraction, and the resolve command.

**Blocked by:** T01, T02

**Acceptance criteria:**

- [ ] Handles resolve through the AT Protocol algorithm without AppView
      fallback.
- [ ] DID results include normalized identity, DID document, and discovered PDS
      evidence where present.
- [ ] Unsupported DID methods and invalid service bindings fail before PDS
      access.

**Verification:**

- dune runtest
- dune exec -- ocaat resolve did:plc:oga6ppys7zwxlheuqmcm7dac --format json

### T07: Implement record and PLC reads

**Spec:** [Record and PLC reads](specs/record-and-plc-reads.md)

**What to build:** Add record get, record-list page and collection-summary
modes, PLC show, and PLC history using the identity result.

**Blocked by:** T01, T02, T06

**Acceptance criteria:**

- [ ] Record reads use the actor PDS unless --pds explicitly overrides it.
- [ ] Collection summaries and record pages are distinct validated modes.
- [ ] PLC responses are direct directory evidence, not inferred from PDS state.

**Verification:**

- dune runtest
- dune exec -- ocaat record list did:plc:oga6ppys7zwxlheuqmcm7dac --collections --format json

### T08: Complete read-only XRPC calls and descriptions

**Spec:** [Lexicon and XRPC reads](specs/lexicon-and-xrpc-reads.md)

**What to build:** Make xrpc call the primary query command, retain query as an
alias, apply the document contract, and add XRPC description from Lexicon data.

**Blocked by:** T01, T02

**Acceptance criteria:**

- [ ] Query calls validate NSIDs and parameters before connection.
- [ ] Procedures are rejected clearly by the first-release command.
- [ ] Call and query have identical successful behavior.

**Verification:**

- dune runtest
- dune exec -- ocaat xrpc call com.atproto.server.describeServer --pds https://tempest.desertthunder.dev --format json

### T09: Implement Lexicon reads

**Spec:** [Lexicon and XRPC reads](specs/lexicon-and-xrpc-reads.md)

**What to build:** Add Lexicon get and describe with DNS authority discovery,
DID resolution, PDS record retrieval, source evidence, and bounded network
handling.

**Blocked by:** T01, T02, T06

**Acceptance criteria:**

- [ ] The returned document id must equal the requested NSID.
- [ ] Redirects, oversized responses, invalid JSON, and source mismatch are
      rejected.
- [ ] Diagnostics identify the failing resolution stage without hiding source
      provenance.

**Verification:**

- dune runtest
- dune exec -- ocaat xrpc describe com.atproto.repo.getRecord --format json

### T10: Add universal get

**Spec:** [Resource resolution and universal get](specs/resource-resolution-and-universal-get.md)

**What to build:** Add the get dispatcher for handles, DIDs, AT URIs, supported
AT Protocol web URLs, NSIDs, and PDS URLs.

**Blocked by:** T05, T06, T07, T09

**Acceptance criteria:**

- [ ] Each input class dispatches to exactly one documented read path.
- [ ] Web URLs normalize only when their shape is documented.
- [ ] Failed PDS reads never trigger hidden AppView, relay, or backlink calls.

**Verification:**

- dune runtest
- dune exec -- ocaat get did:plc:oga6ppys7zwxlheuqmcm7dac --format json

### T11: Add deterministic JSONL batch reads

**Spec:** [Batch JSONL](specs/batch-jsonl.md)

**What to build:** Add sequential JSONL batch input and one JSONL document or
error per input record.

**Blocked by:** T01, T10

**Acceptance criteria:**

- [ ] Batch preserves input order, continues after failures, and emits no
      non-JSONL stdout text.
- [ ] Each result carries request index and sanitized resource context.
- [ ] The final process status is the first failure after all input is handled.

**Verification:**

- dune runtest
- Pipe valid, invalid, then valid resource lines through dune exec -- ocaat batch.

### T12: Implement bounded CAR parsing and verification

**Spec:** [Local repository CAR inspection](specs/repository-car-inspection.md)

**What to build:** Implement the approved CAR v1, CID, deterministic DRISL-CBOR,
commit, and MST subset with explicit decode limits and repo verify.

**Blocked by:** T01, T03

**Acceptance criteria:**

- [ ] Valid repository fixtures verify with deterministic JSON.
- [ ] Invalid root, version, CID, digest, section size, commit, and MST cases
      fail safely.
- [ ] The implementation does not invoke an external runtime binary.

**Verification:**

- dune runtest
- dune exec -- ocaat repo verify test/fixtures/repos/valid.car --format json

### T13: Add CAR inspection views

**Spec:** [Local repository CAR inspection](specs/repository-car-inspection.md)

**What to build:** Add repo inspect, list, and mst views on top of verified local
CAR parsing.

**Blocked by:** T12

**Acceptance criteria:**

- [ ] Inspect reports commit and count data.
- [ ] List is deterministically ordered by record path.
- [ ] Mst produces structured JSON and a stable human view without writes.

**Verification:**

- dune runtest
- dune exec -- ocaat repo inspect test/fixtures/repos/valid.car --format json

### T14: Package the atproto-read skill

**Spec:** [Agent skills and self-description](specs/agent-skills-and-self-description.md)

**What to build:** Write the first release atproto-read SKILL.md and its command,
resource, and output-contract reference files.

**Blocked by:** T05, T06, T07, T08, T09, T10, T11, T13

**Acceptance criteria:**

- [ ] It teaches the implemented command surface and format contract only.
- [ ] It requires provenance reporting and explicit source overrides.
- [ ] It contains no write instructions or executable installer logic.

**Verification:**

- Review each documented command against dune exec -- ocaat --help=plain.

### T15: Package the atproto-research skill

**Spec:** [Agent skills and self-description](specs/agent-skills-and-self-description.md)

**What to build:** Write the research SKILL.md plus discovery and provenance
references for evidence-oriented resource investigation.

**Blocked by:** T06, T07, T10

**Acceptance criteria:**

- [ ] Discovery workflows use available resolve, get, record, PLC, and
      collection-summary commands.
- [ ] Collection discovery and backlinks are marked planned rather than
      described as working features.
- [ ] Every research workflow records source, endpoint, fetch time, and gaps.

**Verification:**

- Review the skill against fixture-backed CLI examples.

### T16: Package the atproto-lexicons skill

**Spec:** [Agent skills and self-description](specs/agent-skills-and-self-description.md)

**What to build:** Write the Lexicon SKILL.md and read-only workflow reference.

**Blocked by:** T08, T09

**Acceptance criteria:**

- [ ] It covers Lexicon get, describe, and XRPC-description workflows.
- [ ] Local validation, publishing, and compatibility analysis are marked as
      planned work.
- [ ] It explains authority resolution and source provenance.

**Verification:**

- Review documented examples through dune exec -- ocaat xrpc describe.

### T17: Add skill installation and CLI self-description

**Spec:** [Agent skills and self-description](specs/agent-skills-and-self-description.md)

**What to build:** Add skill list, show, path, and safe named installation;
also add capabilities, doctor, and shell completions.

**Blocked by:** T01, T14, T15, T16

**Acceptance criteria:**

- [ ] Each named skill installs under HOME/.agents/skills by default without
      replacing an existing copy unless --force is supplied.
- [ ] Capabilities reports formats, safety class, and availability.
- [ ] Doctor is local by default and makes a PDS request only with --pds.

**Verification:**

- dune runtest
- dune exec -- ocaat skill install atproto-read --dest /tmp/ocaat-skills-test
- dune exec -- ocaat capabilities --format json

### T18: Verify and document the first release

**Spec:** [Documentation and release readiness](specs/documentation-and-release.md)

**What to build:** Run the complete first-release CLI verification matrix,
document the three skill installations, and update the public command examples
to match the executable.

**Blocked by:** T04, T05, T06, T07, T08, T09, T10, T11, T13, T17

**Acceptance criteria:**

- [ ] Deterministic fixtures cover all first-release command classes.
- [ ] README examples match the built CLI.
- [ ] A non-destructive manual check against the supplied Tempest DID is
      documented with provenance.

**Verification:**

- dune runtest
- dune exec -- ocaat --help=plain

## Milestone 2: programmatic read interfaces

**Exit criterion:** The completed read-only domain surface is available through
MCP and a loopback-first HTTP gateway, with generated documentation that is
verified against the registered interfaces.

### T19: Build the read-only MCP server

**Spec:** [MCP server](specs/mcp-server.md)

**What to build:** Expose completed read-only domain modules as stdio MCP tools
and resources without shelling out to the CLI.

**Blocked by:** T04, T05, T06, T07, T08, T09, T10, T11, T13, T17

**Acceptance criteria:**

- [ ] Tool schemas and results match their CLI JSON contracts.
- [ ] Tool discovery advertises read-only safety and exposes the packaged skills
      when supported.
- [ ] Startup makes no network request or filesystem write.

**Verification:**

- Run an MCP initialization, tool-list, success, invalid-input, error, and
  cancellation fixture suite.

### T20: Build the loopback-first HTTP gateway

**Spec:** [HTTP gateway](specs/http-gateway.md)

**What to build:** Add the read-only serve command and documented loopback HTTP
endpoints using shared domain modules.

**Blocked by:** T04, T05, T06, T07, T09, T10, T11, T17

**Acceptance criteria:**

- [ ] The default listener is loopback and non-loopback binding needs explicit
      opt-in.
- [ ] Endpoint responses match CLI document and error schemas.
- [ ] Request, response, timeout, and CORS defaults enforce the specification.

**Verification:**

- Execute loopback endpoint integration tests and compare representative JSON
  with CLI output.

### T21: Generate API reference artifacts

**Spec:** [Generated API documentation](specs/generated-api-documentation.md)

**What to build:** Generate deterministic CLI, skill, MCP, and HTTP API
reference artifacts from the shared capability registry.

**Blocked by:** T17, T19, T20

**Acceptance criteria:**

- [ ] CLI, MCP, and HTTP output describes only registered implemented
      interfaces.
- [ ] Generated OpenAPI, skills, and output-contract artifacts are stable.
- [ ] CI fails if regenerated output differs from committed artifacts.

**Verification:**

- Run generation twice, compare outputs, then run the CI-style diff check.

## Milestone 3: authenticated PDS operations and integrations

**Exit criterion:** Authenticated procedures, account work, migration, repository
transfer, blobs, and PDS administration are all explicit, preflighted, and
fixture-covered. Tempest-specific capabilities remain isolated integrations.

### T22: Extend XRPC for procedures and binary transfer

**Spec:** [CLI foundations](specs/cli-foundations.md)

**What to build:** Add JSON and binary procedure bodies, binary query responses,
custom headers, typed remote errors, safe debug logging, and timeouts.

**Blocked by:** T02, T08

**Acceptance criteria:**

- [ ] Procedures validate input and required auth before connection.
- [ ] JSON, binary, timeout, and remote-error behavior is fixture-covered.
- [ ] Debug logs redact every sensitive request and response field.

**Verification:**

- dune runtest
- Execute fixture-backed xrpc procedure success and failure commands.

### T23: Implement account and session lifecycle

**Spec:** [Account and session management](specs/account-and-session-management.md)

**What to build:** Add login, logout, session, refresh, auth checks, service
auth, app-password, activation, deactivation, and deletion commands.

**Blocked by:** T22

**Acceptance criteria:**

- [ ] Password prompts and all output modes redact credentials.
- [ ] Persistent storage defaults to keychain or pass; plaintext requires an
      explicit warning flag.
- [ ] Destructive account commands require target summary and confirmation.

**Verification:**

- dune runtest
- Run isolated mocked session and credential-store lifecycle tests.

### T24: Implement PDS admin account operations

**Spec:** [PDS administration](specs/pds-administration.md)

**What to build:** Add PDS admin account create, list, info, update, and
password-reset operations with admin preflight.

**Blocked by:** T02, T22

**Acceptance criteria:**

- [ ] Admin auth, identifiers, and request bodies are validated before request.
- [ ] Password input never appears in output or logs.
- [ ] Every command has fixture coverage for success and protected failures.

**Verification:**

- dune runtest

### T25: Implement destructive PDS admin controls

**Spec:** [PDS administration](specs/pds-administration.md)

**What to build:** Add account takedown and delete, admin blob status and purge,
and invite creation with explicit confirmation behavior.

**Blocked by:** T24

**Acceptance criteria:**

- [ ] Takedown, purge, and delete stop without --yes in non-interactive use.
- [ ] Reverse operations are explicit and fixture-covered.
- [ ] Human summaries identify target PDS, object, and mutation before action.

**Verification:**

- dune runtest

### T26: Harden account migration

**Spec:** [Account migration](specs/account-migration.md)

**What to build:** Complete migration status, artifact reuse, safe full flow,
cutover, PLC preview, readiness checks, and fixture coverage.

**Blocked by:** T22

**Acceptance criteria:**

- [ ] Plan and status report all required source, target, artifact, and
      readiness facts.
- [ ] Artifact-producing steps never overwrite without --force and are
      repeatably resumable.
- [ ] Full does not cut over by default; --cutover is explicit.

**Verification:**

- Execute the mocked dry-run migration twice and prove artifact reuse.

### T27: Implement repository transfer artifacts

**Spec:** [Repository transfer](specs/repository-transfer.md)

**What to build:** Add remote export, import, describe, latest commit, and safe
unpack on top of local CAR validation and authenticated transport.

**Blocked by:** T06, T12, T22

**Acceptance criteria:**

- [ ] Exports use resolved PDS provenance and deterministic artifact paths.
- [ ] Import rejects invalid CARs before a write request.
- [ ] Unpack rejects unsafe record paths and honors no-overwrite behavior.

**Verification:**

- dune runtest
- Run binary PDS fixtures for export, resume, import rejection, and unpack.

### T28: Implement blob management

**Spec:** [Blob management](specs/blob-management.md)

**What to build:** Add blob list, download, export, upload, missing, and local
CID computation with safe resume and authenticated writes.

**Blocked by:** T06, T22

**Acceptance criteria:**

- [ ] Read operations use source discovery and report transfer counts.
- [ ] Upload reports CID, media facts when known, and sanitized result.
- [ ] Resume validates existing files before skipping.

**Verification:**

- dune runtest
- Run fixture-backed partial export, CID mismatch, upload, and missing-blob checks.

### T29: Add Tempest backup helpers

**Spec:** [Tempest backup helpers](specs/tempest-backup.md)

**What to build:** Add Tempest backup create, status, verify, and repo verify in
a dedicated command and domain module.

**Blocked by:** T22

**Acceptance criteria:**

- [ ] Remote operations require admin auth.
- [ ] Backup artifacts are path-validated and never silently replaced.
- [ ] Results use the common document contract with Tempest provenance.

**Verification:**

- dune runtest

### T30: Implement record and PLC writes

**Spec:** [Record and PLC reads](specs/record-and-plc-reads.md)

**What to build:** Add record create, update, delete, and PLC draft, sign, and
submit flows with JSON validation and explicit mutation review.

**Blocked by:** T07, T22

**Acceptance criteria:**

- [ ] Record JSON is validated before network submission.
- [ ] PLC draft and signing output show the intended PDS service endpoint.
- [ ] Submission and destructive record operations use confirmation rules.

**Verification:**

- dune runtest
- Run write fixture tests for validation, auth, conflict, and confirmation.

## Milestone 4: ecosystem breadth and release operations

**Exit criterion:** Relay, firehose, Lexicon-development, Bluesky, and release
work are documented, safely bounded, and verified at their stable CLI boundary.

### T31: Complete relay inspection

**Spec:** [Relay and firehose operations](specs/relay-and-firehose.md)

**What to build:** Complete relay account and host reads, JSON documents, and
host diff behavior.

**Blocked by:** T01, T02

**Acceptance criteria:**

- [ ] List, status, and diff have deterministic fixture coverage.
- [ ] Relay source and host are recorded in provenance.
- [ ] Request-crawl remains a later procedure until T32.

**Verification:**

- dune runtest

### T32: Implement firehose observation

**Spec:** [Relay and firehose operations](specs/relay-and-firehose.md)

**What to build:** Add firehose stream and tail with cursor, collection, and
account-event filtering plus interrupted-stream handling.

**Blocked by:** T02

**Acceptance criteria:**

- [ ] JSONL events remain valid and progress stays on stderr.
- [ ] Interrupt exits with the documented interrupted status.
- [ ] Malformed events and filter behavior are fixture-covered.

**Verification:**

- dune runtest
- Run a local Tempest firehose smoke command after fixture coverage passes.

### T33: Implement relay administration

**Spec:** [Relay and firehose operations](specs/relay-and-firehose.md)

**What to build:** Add relay admin reads, request-crawl, takedown, host, and
domain procedures with authorization and confirmations.

**Blocked by:** T22, T31

**Acceptance criteria:**

- [ ] Public read and admin mutation commands stay distinct.
- [ ] Every mutation has preflight, target summary, and fixture coverage.
- [ ] Reverse actions are explicit and never implicit retries.

**Verification:**

- dune runtest

### T34: Implement local Lexicon development analysis

**Spec:** [Lexicon development](specs/lexicon-development.md)

**What to build:** Add Lexicon list, parse, validate, lint, status, breaking,
diff, and DNS-check workflows with file diagnostics.

**Blocked by:** T09

**Acceptance criteria:**

- [ ] Diagnostics include file, path, and line where applicable.
- [ ] Compatibility results distinguish additive, compatible, and breaking
      changes.
- [ ] Tempest official and smoke Lexicon fixtures are covered.

**Verification:**

- dune runtest
- Run CLI validation against a valid and invalid local Lexicon fixture.

### T35: Implement Lexicon distribution and publishing

**Spec:** [Lexicon development](specs/lexicon-development.md)

**What to build:** Add Lexicon pull, new, publish, and unpublish with safe
artifact behavior and authenticated confirmation.

**Blocked by:** T22, T34

**Acceptance criteria:**

- [ ] Pull and new never overwrite without --force.
- [ ] Publish and unpublish validate inputs, summarize targets, and require
      explicit confirmation.
- [ ] Source and response data remain redacted and provenance-aware.

**Verification:**

- dune runtest

### T36: Add Bluesky convenience commands

**Spec:** [Bluesky conveniences](specs/bluesky-conveniences.md)

**What to build:** Add preferences export and import plus a validated post
command using the shared account and record-write foundations.

**Blocked by:** T22, T23, T30

**Acceptance criteria:**

- [ ] Preference export is scriptable and JSON-friendly.
- [ ] Import validates JSON before a procedure call.
- [ ] Post reports created AT URI and CID without leaking credentials.

**Verification:**

- dune runtest

### T37: Complete broad release documentation and CI

**Spec:** [Documentation and release readiness](specs/documentation-and-release.md)

**What to build:** Complete remaining runbooks, credential documentation,
examples, generated-reference checks, formatter/build/test CI, and per-feature
release evidence.

**Blocked by:** T21, T22, T23, T24, T25, T26, T27, T28, T29, T30, T31, T32, T33, T34, T35, T36

**Acceptance criteria:**

- [ ] Every implemented command has an executable documentation example.
- [ ] CI runs formatting, build, deterministic CLI tests, and generated-doc
      drift checks.
- [ ] Release notes identify verified specs and known planned follow-up work.

**Verification:**

- dune runtest
- Run the documented CLI smoke matrix before release.
