# SPEC

## Purpose

`ocaat` is an OCaml CLI for operating AT Protocol PDS instances from
a terminal. It should cover account lifecycle, migration, PDS inspection, admin
operations, repo/blob backup and verification, identity, records, relay checks,
firehose observation, lexicon utilities, syntax helpers, and a generic XRPC
escape hatch.

[Tempest](https://github.com/desertthunder/temptest) is the primary target environment,
but command names and flags should stay portable where the underlying operation is standard
AT Protocol or XRPC.

## Current Context

Tempest is a Phoenix PDS with local/S3 blob storage, SQLite repo storage, browser
account/admin tools, Mix tasks for repo and backup operations, XRPC coverage
across `com.atproto.server`, `com.atproto.identity`, `com.atproto.repo`, and
`com.atproto.sync`, plus a Python migration script at
`~/Projects/tempest/scripts/src/tempest_py/main.py`.

`ocaat` already has a useful foundation:

- global output/auth/PDS options;
- syntax checks;
- generic `xrpc query`;
- `pds describe`;
- read-only PDS account listing/status;
- key generation/inspection;
- relay account/host read commands;
- Account migration `account migrate`.

## Design Principles

- Keep `lib/cli_*.ml` modules thin
  - parse arguments, call reusable domain
    modules, and format results.
- Put reusable logic in modules such as `Syntax`, `Xrpc`, `Pds`, `Pds_admin`,
  `Account`, `Migration`, `Repo`, `Blob`, `Record`, `Identity`, `Plc`, `Relay`,
  `Lexicon`, and `Firehose`.
- Prefer structured result types over passing `Yojson.Safe.t` through the codebase.
- Validate DIDs, handles, NSIDs, CIDs, TIDs, record keys, AT URIs, URLs, artifact
  paths, and required auth before making network requests.
- Keep filesystem artifact names stable, predictable, and resumable.
- Support human-readable output by default and JSON output for automation.
- Redact secrets in human output, JSON output where possible, logs, and errors.
- Make long-running repo/blob operations observable with progress in human mode
  and structured progress records in JSON mode.
- Make destructive operations explicit, reviewable, and difficult to run by
  accident.

## Library Choices

- CLI parsing: `cmdliner`
- Output: `fmt` and `fmt.tty`
- Logging: `logs` and `logs.fmt`
- HTTP: `cohttp-lwt-unix`
- JSON: `yojson`
- URIs/query strings: `uri`

## Operator Safety Contract

All commands should follow one consistent operational contract.

### Output

- `--json` works for every command whose output may be scripted.
- Human output is compact, boring, and operational.
- Human output redacts secrets and reports token presence with booleans such as
  `has_accessJwt=true` rather than token values.
- Errors should include the command, target host, method, status code, and a
  sanitized response body when available.

### Auth and credentials

- Commands accept explicit flags and environment variables first:
  - `--pds <url>` / `OCAAT_PDS`
  - `--auth <token>` / `OCAAT_AUTH`
  - refresh token env support where applicable, e.g. `OCAAT_REFRESH`
  - admin token env support where applicable, e.g. `OCAAT_ADMIN_TOKEN`
- Persistent login, when implemented, should use an OS keychain/pass integration
  by default.
- Plaintext credential storage requires an explicit escape hatch such as
  `--store-plaintext` and clear warning text.

### Writes and destructive operations

- Every write/destructive command prints the target PDS, DID/handle, method, and
  artifact path before doing work.
- Destructive commands require `--yes` or an interactive confirmation.
- Commands that write artifacts avoid replacing existing files unless `--force`
  is passed.
- Commands should support `--dry-run` whenever the operation can be planned or
  validated without mutation.
- Network commands fail before the request when required auth, host, DID, input
  file, or artifact state is missing.

## Global Options

Supported globally where relevant:

```text
--color=auto|always|never
NO_COLOR
-v, --verbose
--verbosity=quiet|error|warning|info|debug
-q, --quiet
--json
--pds <url>
--auth <token>
--admin-token <token>
--yes
--dry-run
--force
```

## Command Tree

```text
ocaat                                     lib/cli_root.ml
  pds                                     lib/cli_pds.ml
    describe <host>                       [read-only]
    health [--pds <url>]                  [read-only]
    stats [--pds <url>]                   [read-only]
    admin-status [--pds <url>]            [read-only, admin auth]
    account
      list [--handles] [--json] <host>    [read-only]
      status [--pds <url>] <did>          [read-only]
    admin
      account                             lib/cli_pds_admin.ml
        create --handle <handle> --email <email> [--password <password>]
        list [--json]                     [read-only]
        info <handle-or-did>              [read-only]
        update <handle-or-did> [--email <email>] [--handle <handle>]
        reset-password <handle-or-did>
        takedown [--reverse] <handle-or-did>
        delete [--yes] <handle-or-did>
      blob                                lib/cli_pds_admin.ml
        status <handle-or-did> <cid>      [read-only]
        purge [--reverse] <handle-or-did> <cid>
      invite
        create --count <n> --uses <n>

  account                                 lib/cli_account.ml
    login --pds <url> --identifier <handle-or-email>
    logout
    session [--json]                      [read-only]
    refresh
    status [<handle-or-did>]              [read-only]
    check-auth                            [read-only]
    service-auth --aud <did> --lxm <nsid>
    app-password
      list                                [read-only]
      create <name>
      revoke <name-or-id>
    missing-blobs                         [read-only]
    activate
    deactivate
    delete --yes
    migrate                               lib/cli_migration.ml
      plan                                [read-only]
      login-source
      source-session-status               [read-only]
      service-auth
      export-car                          [read-only artifact write]
      list-source-blobs                   [read-only]
      download-source-blobs               [read-only artifact write]
      create-account
      refresh-session
      import-repo
      status                              [read-only]
      missing-blobs                       [read-only]
      upload-missing-blobs
      plc-recommended                     [read-only artifact write]
      plc-request-token
      plc-sign
      plc-submit
      activate
      full
    plc                                   lib/cli_account.ml
      recommended                         [read-only]
      request-token
      sign [--token <token>] <recommended.json>
      submit <operation.json>
      current <did-or-handle>             [read-only]

  repo                                    lib/cli_repo.ml
    export <handle-or-did> [-o <file.car>] [read-only artifact write]
    import <file.car>
    describe <handle-or-did>              [read-only]
    latest-commit <handle-or-did>         [read-only]
    verify <file.car>                     [read-only]
    list <file.car>                       [read-only]
    inspect <file.car>                    [read-only]
    mst <file.car>                        [read-only]
    unpack <file.car> [-o <dir>]          [read-only artifact write]

  blob                                    lib/cli_blob.ml
    list <handle-or-did>                  [read-only]
    download <handle-or-did> <cid> [-o <path>] [read-only artifact write]
    export <handle-or-did> [-o <dir>]     [read-only artifact write]
    upload <file>
    missing [--pds <url>]                 [read-only]
    compute <file>                        [read-only]

  record                                  lib/cli_record.ml
    get <at-uri>                          [read-only]
    list [--collections] <handle-or-did>  [read-only]
    create --repo <did> --collection <nsid> <file.json>
    update --repo <did> --collection <nsid> --rkey <rkey> <file.json>
    delete --repo <did> --collection <nsid> --rkey <rkey>

  resolve                                 lib/cli_resolve.ml
    <handle-or-did>                       [read-only]
    --did <handle-or-did>                 [read-only]

  plc                                     lib/cli_plc.ml
    history <did-or-handle>               [read-only]
    data <did-or-handle>                  [read-only]
    current <did-or-handle>               [read-only]
    dump [--cursor <cursor>] [--tail]     [read-only]
    genesis                               [read-only]
    calc-did <signed-genesis.json>        [read-only]
    update <did>                          [read-only draft]
    sign <operation.json>
    submit <signed-operation.json>

  key                                     lib/cli_key.ml
    inspect <key>                         [read-only]
    generate [--type P-256|K-256] [--terse] [local secret generation]

  relay                                   lib/cli_relay.ml
    account
      list [--relay-host <url>] [--collection <nsid>] [--json] [read-only]
      status [--relay-host <url>] [--json] <did>      [read-only]
    host
      list [--relay-host <url>] [--json]              [read-only]
      status [--relay-host <url>] [--json] <hostname> [read-only]
      diff <relay-a-url> <relay-b-url>                [read-only]
      request-crawl <hostname>
    admin
      account list                        [read-only]
      host list                           [read-only]
      domain list                         [read-only]
      consumer list                       [read-only]
      account takedown [--reverse] <account>
      host add <hostname>
      host block [--reverse] <hostname>
      host config <hostname> [--account-limit <n>]
      domain ban [--reverse] <domain>

  lex                                     lib/cli_lex.ml
    resolve [--did] <nsid>                [read-only]
    list <nsid>                           [read-only]
    parse <path>...                       [read-only]
    validate <uri-or-path>                [read-only]
    lint [<file-or-dir>]...               [read-only]
    status [<file-or-dir>]...             [read-only]
    breaking [<file-or-dir>]...           [read-only]
    diff <from> <to>                      [read-only]
    check-dns [<file-or-dir>]...          [read-only]
    pull <nsid-pattern>...                [local file write]
    new <nsid>                            [local file write]
    publish <path>...
    unpublish <nsid>...

  firehose                                lib/cli_firehose.ml
    stream [--relay-host <url>] [--cursor <cursor>] [read-only stream]
    tail [--account-events] [--collection <nsid>]    [read-only stream]

  bsky                                    lib/cli_bsky.ml
    prefs export                          [read-only]
    prefs import <file>
    post <text>

  tempest                                 lib/cli_tempest.ml
    backup
      create [--pds <url>]                [admin write]
      status [--pds <url>]                [read-only, admin auth]
      verify <backup-dir>                 [read-only]
    repo
      verify --did <did> [--pds <url>]    [read-only, admin auth]

  xrpc                                    lib/cli_xrpc.ml
    query <method> [--param k=v]...       [read-only]
    procedure <method> [--body <file>] [--param k=v]...

  syntax                                  lib/cli_syntax.ml
    handle check <handle>                 [read-only]
    did check <did>                       [read-only]
    nsid check <nsid>                     [read-only]
    at-uri check <at-uri>                 [read-only]
    rkey check <rkey>                     [read-only]
    cid check <cid>                       [read-only]
    tid check <tid>                       [read-only]
    tid inspect <tid>                     [read-only]
    tid generate                          [local generation]
    datetime now                          [read-only]
    datetime check <datetime>             [read-only]
    language check <language>             [read-only]
```

## Priority 0: shared foundations

### Global CLI/runtime

- Implement global option parsing once and make command modules consume a shared
  context.
- Support color, verbosity, quiet mode, JSON mode, PDS URL, auth token, admin
  token, yes/dry-run/force flags.
- Use stable exit codes for usage errors, validation failures, auth failures,
  network failures, remote errors, and interrupted streams.
- Add consistent error rendering for human and JSON modes.

### XRPC client

The reusable XRPC client should support:

- query and procedure calls;
- bearer auth;
- admin bearer auth;
- JSON request bodies;
- binary request bodies;
- binary response bodies;
- custom headers;
- query parameters;
- typed HTTP errors;
- sanitized response logging;
- request timeout configuration;
- streaming responses for firehose commands.

### Validation

Add reusable validation and parsing for:

- DID;
- handle;
- NSID;
- CID;
- TID;
- record key;
- AT URI;
- ISO datetime;
- language tag;
- service URL;
- filesystem artifact path.

## Priority 1: migration parity and operator flow

The migration command set should replace the current Tempest Python migration
workflow and add a safer, resumable operator experience.

```text
ocaat account migrate plan
ocaat account migrate login-source
ocaat account migrate source-session-status
ocaat account migrate service-auth
ocaat account migrate export-car
ocaat account migrate list-source-blobs
ocaat account migrate download-source-blobs
ocaat account migrate create-account
ocaat account migrate refresh-session
ocaat account migrate import-repo
ocaat account migrate status
ocaat account migrate missing-blobs
ocaat account migrate upload-missing-blobs
ocaat account migrate plc-recommended
ocaat account migrate plc-request-token
ocaat account migrate plc-sign
ocaat account migrate plc-submit
ocaat account migrate activate
ocaat account migrate full
```

Required behavior:

- `plan` shows resolved source/target hosts, source DID, target service DID,
  handle, artifact directory, expected artifact paths, and artifact reuse status.
- `full` runs through safe pre-cutover steps by default.
- `full --cutover` is required before PLC submit and activation.
- `status` summarizes `migrationReady`, missing blob count, repo import status,
  activation state, session presence, and PLC operation state.
- `plc-sign` shows the resulting `atproto_pds` service endpoint before writing
  the signed operation.
- `activate` refuses to run unless status is ready, unless `--force` is passed.
- Every artifact-producing step is resumable.
- Existing artifacts are reused by default and overwritten only with `--force`.

Acceptance coverage:

- mocked HTTP fixture for every step;
- end-to-end dry-run path proving artifact reuse;
- failure cases for missing auth, missing artifact, wrong host, invalid DID,
  invalid handle, and remote XRPC errors;
- JSON output snapshots for scripted operation.

## Priority 2: PDS inspection and admin status

Commands:

```text
ocaat pds describe <host>
ocaat pds health [--pds <url>] [--json]
ocaat pds stats [--pds <url>] [--json]
ocaat pds admin-status [--pds <url>] [--admin-token <token>] [--json]
ocaat pds account list [--handles] [--json] <host>
ocaat pds account status [--pds <url>] [--json] <did>
```

Tempest mapping:

- `health` calls `/xrpc/_health`.
- `stats` calls `/xrpc/_stats`.
- `admin-status` calls `/xrpc/_admin/status` with admin bearer auth.
- `account status` calls `com.atproto.server.checkAccountStatus`.
- Public account lists use `com.atproto.sync.listRepos`.

Human output should include:

- hostname;
- service DID;
- health state;
- account count;
- repo count;
- blob count;
- sequencer cursor;
- configured crawlers;
- storage backend;
- admin auth configured;
- red/yellow/green status cues.

## Priority 3: PDS admin operations

Commands:

```text
ocaat pds admin account create --handle <handle> --email <email> [--password <password>]
ocaat pds admin account list [--json]
ocaat pds admin account info <handle-or-did>
ocaat pds admin account update <handle-or-did> [--email <email>] [--handle <handle>]
ocaat pds admin account reset-password <handle-or-did>
ocaat pds admin account takedown [--reverse] <handle-or-did>
ocaat pds admin account delete [--yes] <handle-or-did>
ocaat pds admin blob status <handle-or-did> <cid>
ocaat pds admin blob purge [--reverse] <handle-or-did> <cid>
ocaat pds admin invite create --count <n> --uses <n>
```

Required behavior:

- Before adding the admin command surface, tests should have a lightweight local
  HTTP fixture harness. It should bind an ephemeral local port, assert request
  method/path/query and bearer/admin auth headers, return configured status/body
  pairs, and let CLI tests cover success, auth failure, remote XRPC errors, and
  invalid JSON without depending on a live Tempest deployment.
- All commands require admin auth.
- Account and blob mutations print a preflight summary.
- Takedown, purge, delete, and reset-password require confirmation or `--yes`.
- JSON output includes machine-readable operation result and target identifiers.
- Password handling supports prompt input and avoids shell history exposure.

## Priority 4: repo and blob backup workflows

Protocol-level commands:

```text
ocaat repo export <did-or-handle> [-o <file.car>]
ocaat repo import <file.car> [--pds <url>] [--auth <token>]
ocaat repo describe <did-or-handle> [--pds <url>] [--json]
ocaat repo latest-commit <did-or-handle> [--pds <url>] [--json]
ocaat repo verify <file.car>
ocaat repo list <file.car>
ocaat repo inspect <file.car>
ocaat repo mst <file.car>
ocaat repo unpack <file.car> [-o <dir>]

ocaat blob list <did-or-handle> [--pds <url>] [--json]
ocaat blob download <did-or-handle> <cid> [-o <path>]
ocaat blob export <did-or-handle> [-o <dir>]
ocaat blob upload <file> [--pds <url>] [--auth <token>]
ocaat blob missing [--pds <url>] [--auth <token>] [--json]
ocaat blob compute <file>
```

Tempest admin helpers:

```text
ocaat tempest backup create [--pds <url>] [--admin-token <token>] [--json]
ocaat tempest backup status [--pds <url>] [--admin-token <token>] [--json]
ocaat tempest backup verify <backup-dir>
ocaat tempest repo verify --did <did> [--pds <url>] [--admin-token <token>]
```

Required behavior:

- Exports choose deterministic default paths when `-o` is omitted.
- Download/export commands resume safely when files already exist.
- CAR verification validates structure and reports commits, records, blocks,
  collection counts, and malformed data.
- Blob export reports requested, downloaded, skipped, failed, and missing counts.
- Upload commands report CID, MIME type when known, size, and remote result.

## Priority 5: account and session management

Commands:

```text
ocaat account login --pds <url> --identifier <handle-or-email>
ocaat account logout
ocaat account session [--json]
ocaat account refresh
ocaat account status [<handle-or-did>]
ocaat account check-auth [--json]
ocaat account service-auth --aud <did> --lxm <nsid>
ocaat account app-password list
ocaat account app-password create <name>
ocaat account app-password revoke <name-or-id>
ocaat account missing-blobs
ocaat account activate
ocaat account deactivate
ocaat account delete --yes
```

Required behavior:

- Login accepts password prompt input.
- Session output redacts JWT values.
- Refresh updates stored credentials only when credential storage is enabled.
- Account delete requires `--yes` plus a target summary.

## Priority 6: records, identity, and PLC

Commands:

```text
ocaat resolve <handle-or-did> [--json]
ocaat resolve --did <handle-or-did> [--json]

ocaat plc history <did-or-handle> [--json]
ocaat plc data <did-or-handle> [--json]
ocaat plc current <did-or-handle> [--json]
ocaat plc dump [--cursor <cursor>] [--tail]
ocaat plc genesis
ocaat plc calc-did <signed-genesis.json>
ocaat plc update <did>
ocaat plc sign <operation.json>
ocaat plc submit <signed-operation.json>

ocaat record get <at-uri> [--json]
ocaat record list <did-or-handle> [--collection <nsid>] [--collections] [--json]
ocaat record create --repo <did> --collection <nsid> <file.json>
ocaat record update --repo <did> --collection <nsid> --rkey <rkey> <file.json>
ocaat record delete --repo <did> --collection <nsid> --rkey <rkey>
```

Required behavior:

- Read commands resolve handles and DIDs consistently.
- Record list supports collection filtering and collection summary mode.
- Write commands validate JSON before network submission.
- PLC commands expose current operation, history, and signing/submission flow in
  both human and JSON modes.

## Priority 7: relay and firehose checks

Commands:

```text
ocaat firehose stream [--relay-host <url>] [--cursor <cursor>]
ocaat firehose tail [--account-events] [--collection <nsid>]
ocaat relay account list [--relay-host <url>] [--collection <nsid>] [--json]
ocaat relay account status [--relay-host <url>] [--json] <did>
ocaat relay host list [--relay-host <url>] [--json]
ocaat relay host status [--relay-host <url>] [--json] <hostname>
ocaat relay host diff <relay-a-url> <relay-b-url>
ocaat relay host request-crawl <hostname>
ocaat relay admin account list
ocaat relay admin host list
ocaat relay admin domain list
ocaat relay admin consumer list
ocaat relay admin account takedown [--reverse] <account>
ocaat relay admin host add <hostname>
ocaat relay admin host block [--reverse] <hostname>
ocaat relay admin host config <hostname> [--account-limit <n>]
ocaat relay admin domain ban [--reverse] <domain>
```

For Tempest operation, the most important checks are:

- whether a relay can crawl the public hostname;
- whether `com.atproto.sync.subscribeRepos` emits expected commit/account events;
- whether account events can be tailed during migration and activation.

## Priority 8: lexicon helpers

Commands:

```text
ocaat lex resolve [--did] <nsid>
ocaat lex list <nsid>
ocaat lex parse <path>...
ocaat lex validate <uri-or-path>
ocaat lex lint [<file-or-dir>]...
ocaat lex status [<file-or-dir>]...
ocaat lex breaking [<file-or-dir>]...
ocaat lex diff <from> <to>
ocaat lex check-dns [<file-or-dir>]...
ocaat lex pull <nsid-pattern>...
ocaat lex new <nsid>
ocaat lex publish <path>...
ocaat lex unpublish <nsid>...
```

Required behavior:

- Local commands can operate against Tempest's official and smoke lexicons.
- Validation and linting produce actionable file/path/line diagnostics.
- Diff/breaking commands distinguish additive, compatible, and breaking changes.
- Publishing commands require explicit auth and confirmation.

## Priority 9: Bluesky convenience commands

Commands:

```text
ocaat bsky prefs export
ocaat bsky prefs import <file>
ocaat bsky post <text>
```

Required behavior:

- Preference export/import should be scriptable and JSON-friendly.
- Posting should validate auth, repo, and text before submission.
- Human output should show the created record URI/CID.

## Minimum Useful Tempest Release

A minimum Tempest-operator release includes:

1. Safe global output/auth behavior.
2. Complete migration parity with the Tempest Python script.
3. `pds health`, `pds stats`, and `pds admin-status`.
4. `repo export`, `repo verify`, `blob export`, `blob missing`, and
   `blob upload`.
5. `xrpc procedure` in addition to `xrpc query`.
6. Read-only identity, record, PLC, relay, and lexicon inspection commands that
   help verify repo and PDS correctness from the terminal.
