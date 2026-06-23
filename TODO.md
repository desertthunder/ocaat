# TODO

Tasks for implementing the Tempest-first `ocaat` CLI described in `SPEC.md`.

`*` at the end of a checkbox item marks a read-only command task.

## Current Library Choices

- CLI parsing: `cmdliner`
- Output: `fmt` and `fmt.tty`
- Logging: `logs` and `logs.fmt`
- HTTP: `cohttp-lwt-unix`
- JSON: `yojson`
- URIs/query strings: `uri`

## Progress Snapshot

- [x] Keep the current `syntax` commands.
- [x] Add shared global options:
  - `--color=auto|always|never`
  - `NO_COLOR`
  - `-v`, `--verbose`
  - `--verbosity=quiet|error|warning|info|debug`
  - `-q`, `--quiet`
  - `--json`
  - `--pds <url>`
  - `--auth <token>`
- [x] Implement `xrpc query` and `pds describe`. *
- [x] Add read-only `pds account list/status`. *
- [x] Port the Tempest Python migration flow into `account migrate` subcommands.
- [x] Add low-complexity read-only `key inspect`, local `key generate`, and
      relay `account/host list/status`.

## Phase 0: shared foundations

- [x] Add `--admin-token <token>` and `OCAAT_ADMIN_TOKEN` support to the shared
      context.
- [x] Add global `--yes`, `--dry-run`, and `--force` plumbing.
- [x] Define stable process exit codes for usage, validation, auth, network,
      remote XRPC, filesystem, and interrupted-stream failures.
- [x] Standardize human error rendering across commands.
- [x] Standardize JSON error rendering across commands.
- [x] Ensure every command redacts access JWTs, refresh JWTs, passwords, app
      passwords, service auth tokens, and admin tokens in logs/errors/output.
- [x] Add a command preflight helper for required PDS URL, auth, admin auth,
      DID/handle, input file, output path, and artifact state.
- [x] Add shared confirmation prompts for destructive operations.
- [x] Add artifact overwrite/resume helpers that honor `--force`.
- [x] Add a shared progress reporting interface for human and JSON modes.

## Phase 1: XRPC client

- [ ] Extend the reusable XRPC client to support procedures.
- [ ] Add JSON request body support.
- [ ] Add binary request body support.
- [ ] Add binary response body support.
- [ ] Add custom request headers.
- [ ] Add typed HTTP/XRPC error values.
- [ ] Add sanitized request/response debug logging.
- [ ] Add configurable request timeouts.
- [ ] Add streaming response support for firehose commands.
- [ ] Implement `ocaat xrpc procedure <method> [--body <file>] [--param k=v]...`.
- [ ] Add tests for query/procedure success, remote error, auth failure, invalid
      JSON, binary response, and timeout behavior.

## Phase 2: validation and syntax helpers

- [ ] Audit existing validators for DID, handle, NSID, AT URI, record key, CID,
      TID, datetime, and language tags.
- [ ] Add URL validation for PDS and relay hosts.
- [ ] Add artifact path validation for input and output files/directories.
- [ ] Ensure validators are available as reusable library functions rather than
      only CLI commands.
- [x] Add missing CLI syntax checks from `SPEC.md`. *
- [ ] Add unit tests for valid and invalid examples for each validator.

## Phase 3: migration hardening

- [ ] Compare current `account migrate` behavior against
      `~/Projects/tempest/scripts/src/tempest_py/main.py` and document any gaps.
- [ ] Ensure `account migrate plan` prints source/target hosts, source DID, *
      target service DID, handle, artifact directory, expected artifact paths,
      and artifact reuse status.
- [ ] Ensure every artifact-producing migration step is resumable.
- [ ] Ensure artifact-producing steps overwrite only with `--force`.
- [ ] Add `account migrate full` safe default flow.
- [ ] Add `account migrate full --cutover` for PLC submit and activation.
- [ ] Ensure `account migrate status` reports `migrationReady`, missing blob *
      count, repo import status, activation state, session presence, and PLC
      operation state.
- [ ] Ensure `account migrate plc-sign` displays the resulting `atproto_pds`
      service endpoint before writing the signed operation.
- [ ] Ensure `account migrate activate` refuses to run until status is ready,
      unless `--force` is passed.
- [ ] Add mocked HTTP fixtures for every migration step.
- [ ] Add an end-to-end dry-run migration test proving artifact reuse.
- [ ] Add failure tests for missing auth, missing artifact, wrong host, invalid
      DID, invalid handle, and remote XRPC errors.
- [ ] Add JSON output snapshot tests for migration commands.

## Phase 4: PDS inspection

- [x] Implement `ocaat pds health [--pds <url>] [--json]` using `/xrpc/_health`. *
- [x] Implement `ocaat pds stats [--pds <url>] [--json]` using `/xrpc/_stats`. *
- [x] Implement `ocaat pds admin-status [--pds <url>] [--admin-token <token>] [--json]` *
      using `/xrpc/_admin/status`.
- [x] Make human PDS output include hostname, service DID, health state, account
      count, repo count, blob count, sequencer cursor, configured crawlers,
      storage backend, admin auth configured, and status cues.
- [x] Add tests for healthy, degraded, and unavailable PDS responses.
- [x] Add tests for admin-status without admin auth and with invalid admin auth.

## Phase 5: PDS admin commands

- [ ] Add a lightweight mocked HTTP fixture harness for CLI tests, covering
      request method/path/query, bearer/admin auth headers, response status/body,
      and deterministic port allocation.
- [ ] Create `lib/cli_pds_admin.ml`.
- [ ] Add reusable `Pds_admin` module for admin API calls.
- [ ] Implement `pds admin account create --handle <handle> --email <email> [--password <password>]`.
- [ ] Implement `pds admin account list [--json]`. *
- [ ] Implement `pds admin account info <handle-or-did>`. *
- [ ] Implement `pds admin account update <handle-or-did> [--email <email>] [--handle <handle>]`.
- [ ] Implement `pds admin account reset-password <handle-or-did>`.
- [ ] Implement `pds admin account takedown [--reverse] <handle-or-did>`.
- [ ] Implement `pds admin account delete [--yes] <handle-or-did>`.
- [ ] Implement `pds admin blob status <handle-or-did> <cid>`. *
- [ ] Implement `pds admin blob purge [--reverse] <handle-or-did> <cid>`.
- [ ] Implement `pds admin invite create --count <n> --uses <n>`.
- [ ] Add confirmation/preflight summaries for reset-password, takedown, purge,
      and delete.
- [ ] Add password prompt input for account create/reset flows.
- [ ] Add JSON output tests for admin commands.

## Phase 6: repo commands

- [ ] Create or complete `lib/cli_repo.ml`.
- [ ] Add reusable `Repo` module.
- [ ] Implement `repo export <handle-or-did> [-o <file.car>]`. *
- [ ] Implement `repo import <file.car>`.
- [ ] Implement `repo describe <handle-or-did> [--pds <url>] [--json]`. *
- [ ] Implement `repo latest-commit <handle-or-did> [--pds <url>] [--json]`. *
- [ ] Implement `repo verify <file.car>`. *
- [ ] Implement `repo list <file.car>`. *
- [ ] Implement `repo inspect <file.car>`. *
- [ ] Implement `repo mst <file.car>`. *
- [ ] Implement `repo unpack <file.car> [-o <dir>]`. *
- [ ] Add deterministic default output paths for exports/unpacks.
- [ ] Add CAR structure validation and useful summaries: commits, records,
      blocks, collection counts, and malformed data.
- [ ] Add tests with valid, malformed, and empty CAR fixtures.

## Phase 7: blob commands

- [ ] Create or complete `lib/cli_blob.ml`.
- [ ] Add reusable `Blob` module.
- [ ] Implement `blob list <handle-or-did> [--pds <url>] [--json]`. *
- [ ] Implement `blob download <handle-or-did> <cid> [-o <path>]`. *
- [ ] Implement `blob export <handle-or-did> [-o <dir>]`. *
- [ ] Implement `blob upload <file> [--pds <url>] [--auth <token>]`.
- [ ] Implement `blob missing [--pds <url>] [--auth <token>] [--json]`. *
- [ ] Implement `blob compute <file>`. *
- [ ] Add safe resume/skip behavior for blob downloads and exports.
- [ ] Report requested, downloaded, skipped, failed, and missing counts.
- [ ] Add tests for successful export, partial export resume, upload, and missing
      blob reporting.

## Phase 8: Tempest backup helpers

- [ ] Create `lib/cli_tempest.ml`.
- [ ] Add reusable `Tempest` module for Tempest-specific admin endpoints.
- [ ] Implement `tempest backup create [--pds <url>] [--admin-token <token>] [--json]`.
- [ ] Implement `tempest backup status [--pds <url>] [--admin-token <token>] [--json]`. *
- [ ] Implement `tempest backup verify <backup-dir>`. *
- [ ] Implement `tempest repo verify --did <did> [--pds <url>] [--admin-token <token>]`. *
- [ ] Add tests using mocked Tempest admin responses and local backup fixtures.

## Phase 9: account/session commands

- [ ] Implement `account login --pds <url> --identifier <handle-or-email>` with
      password prompt input.
- [ ] Implement `account logout`.
- [ ] Implement `account session [--json]` with token redaction. *
- [ ] Implement `account refresh`.
- [ ] Implement `account status [<handle-or-did>]`. *
- [ ] Implement `account check-auth [--json]`. *
- [ ] Implement `account service-auth --aud <did> --lxm <nsid>`.
- [ ] Implement `account app-password list`. *
- [ ] Implement `account app-password create <name>`.
- [ ] Implement `account app-password revoke <name-or-id>`.
- [ ] Implement `account missing-blobs`. *
- [ ] Implement `account activate`.
- [ ] Implement `account deactivate`.
- [ ] Implement `account delete --yes`.
- [ ] Add OS keychain/pass-backed persistent credential storage.
- [ ] Add explicit `--store-plaintext` support with warning text, if plaintext
      storage is needed for testing or portability.
- [ ] Add auth/session lifecycle tests.

## Phase 10: identity, PLC, and records

- [ ] Create or complete `lib/cli_resolve.ml` and reusable `Identity` module.
- [ ] Implement `resolve <handle-or-did> [--json]`. *
- [ ] Implement `resolve --did <handle-or-did> [--json]`. *
- [ ] Create or complete `lib/cli_plc.ml` and reusable `Plc` module.
- [ ] Implement `plc history <did-or-handle> [--json]`. *
- [ ] Implement `plc data <did-or-handle> [--json]`. *
- [ ] Implement `plc current <did-or-handle> [--json]`. *
- [ ] Implement `plc dump [--cursor <cursor>] [--tail]`. *
- [ ] Implement `plc genesis`. *
- [ ] Implement `plc calc-did <signed-genesis.json>`. *
- [ ] Implement `plc update <did>` as a draft/preview operation. *
- [ ] Implement `plc sign <operation.json>`.
- [ ] Implement `plc submit <signed-operation.json>`.
- [ ] Create or complete `lib/cli_record.ml` and reusable `Record` module.
- [ ] Implement `record get <at-uri> [--json]`. *
- [ ] Implement `record list [--collections] <handle-or-did> [--collection <nsid>] [--json]`. *
- [ ] Implement `record create --repo <did> --collection <nsid> <file.json>`.
- [ ] Implement `record update --repo <did> --collection <nsid> --rkey <rkey> <file.json>`.
- [ ] Implement `record delete --repo <did> --collection <nsid> --rkey <rkey>`.
- [ ] Add tests for handle/DID resolution, PLC history/data/current, record
      reads, record writes, and JSON validation failures.

## Phase 11: relay and firehose

- [ ] Complete relay account list/status behavior and JSON tests. *
- [ ] Complete relay host list/status behavior and JSON tests. *
- [ ] Implement `relay host diff <relay-a-url> <relay-b-url>`. *
- [ ] Implement `relay host request-crawl <hostname>`.
- [ ] Implement `relay admin account list`. *
- [ ] Implement `relay admin host list`. *
- [ ] Implement `relay admin domain list`. *
- [ ] Implement `relay admin consumer list`. *
- [ ] Implement `relay admin account takedown [--reverse] <account>`.
- [ ] Implement `relay admin host add <hostname>`.
- [ ] Implement `relay admin host block [--reverse] <hostname>`.
- [ ] Implement `relay admin host config <hostname> [--account-limit <n>]`.
- [ ] Implement `relay admin domain ban [--reverse] <domain>`.
- [ ] Create or complete `lib/cli_firehose.ml`.
- [ ] Implement `firehose stream [--relay-host <url>] [--cursor <cursor>]`. *
- [ ] Implement `firehose tail [--account-events] [--collection <nsid>]`. *
- [ ] Add stream parsing, interrupt handling, and JSON event output tests.

## Phase 12: lexicon helpers

- [ ] Create or complete `lib/cli_lex.ml` and reusable `Lexicon` module.
- [ ] Implement `lex resolve [--did] <nsid>`. *
- [ ] Implement `lex list <nsid>`. *
- [ ] Implement `lex parse <path>...`. *
- [ ] Implement `lex validate <uri-or-path>`. *
- [ ] Implement `lex lint [<file-or-dir>]...`. *
- [ ] Implement `lex status [<file-or-dir>]...`. *
- [ ] Implement `lex breaking [<file-or-dir>]...`. *
- [ ] Implement `lex diff <from> <to>`. *
- [ ] Implement `lex check-dns [<file-or-dir>]...`. *
- [ ] Implement `lex pull <nsid-pattern>...`.
- [ ] Implement `lex new <nsid>`.
- [ ] Implement `lex publish <path>...`.
- [ ] Implement `lex unpublish <nsid>...`.
- [ ] Add diagnostics with file/path/line information.
- [ ] Add tests against Tempest official and smoke lexicon fixtures.

## Phase 13: Bluesky convenience commands

- [ ] Create `lib/cli_bsky.ml` and reusable `Bsky` module.
- [ ] Implement `bsky prefs export`. *
- [ ] Implement `bsky prefs import <file>`.
- [ ] Implement `bsky post <text>`.
- [ ] Add tests for auth validation, preference JSON, and created post URI/CID
      output.

## Phase 14: documentation and release readiness

- [ ] Update `README.md` with installed command examples.
- [ ] Add a Tempest migration runbook.
- [ ] Add a Tempest backup/restore runbook.
- [ ] Add credential safety documentation.
- [ ] Add JSON output examples for automation.
- [ ] Add shell completion generation if supported by the command tree.
- [ ] Add CI coverage for unit tests, CLI smoke tests, and formatter/lint checks.
- [ ] Define the minimum useful Tempest release milestone:
  - safe global output/auth behavior;
  - complete migration parity with the Tempest Python script;
  - `pds health`, `pds stats`, and `pds admin-status`;
  - `repo export`, `repo verify`, `blob export`, `blob missing`, and
    `blob upload`;
  - `xrpc procedure`;
  - read-only identity, record, PLC, relay, and lexicon inspection commands.
