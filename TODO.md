# TODO

## Goal

Build `ocaat` into a Tempest-first OCaml CLI that covers the PDS-relevant parts
of `goat` without inheriting unnecessary scope.

## Current Library Choices

- CLI parsing: `cmdliner`
- Output: `fmt` and `fmt.tty`
- Logging: `logs` and `logs.fmt`
- HTTP: `cohttp-lwt-unix`
- JSON: `yojson`
- URIs/query strings: `uri`

## Proposed Command Tree

```text
ocaat                                     lib/cli_root.ml
  pds                                     lib/cli_pds.ml
    describe <host>                       [read-only]
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
    status [<handle-or-did>]              [read-only]
    check-auth                            [read-only]
    service-auth --aud <did> --lxm <nsid>
    missing-blobs                         [read-only]
    activate
    deactivate
    migrate
      --source-pds <url>
      --target-pds <url>
      --target-service-did <did>
      --handle <handle>
      --did <did>
      --email <email>
      [--artifact-dir <dir>]
    plc                                  lib/cli_account.ml
      recommended                         [read-only]
      request-token
      sign [--token <token>] <recommended.json>
      submit <operation.json>
      current <did-or-handle>             [read-only]
  repo                                    lib/cli_repo.ml
    export <handle-or-did> [-o <file.car>] [read-only]
    import <file.car>
    list <file.car>                       [read-only]
    inspect <file.car>                    [read-only]
    mst <file.car>                        [read-only]
    unpack <file.car> [-o <dir>]          [read-only]
  blob                                    lib/cli_blob.ml
    list <handle-or-did>                  [read-only]
    download <handle-or-did> <cid> [-o <path>] [read-only]
    export <handle-or-did> [-o <dir>]     [read-only]
    upload <file>
    compute <file>                        [read-only]
  record                                  lib/cli_record.ml
    get <at-uri>                          [read-only]
    list [--collections] <handle-or-did>  [read-only]
    create <file.json>
    update --rkey <rkey> <file.json>
    delete --collection <nsid> --rkey <rkey>
  resolve                                 lib/cli_resolve.ml
    <handle-or-did>                       [read-only]
    --did <handle-or-did>                 [read-only]
  plc                                     lib/cli_plc.ml
    history <did-or-handle>               [read-only]
    data <did-or-handle>                  [read-only]
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
      account list                       [read-only]
      host list                          [read-only]
      domain list                        [read-only]
      consumer list                      [read-only]
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
    stream [--cursor <cursor>]            [read-only stream]
  bsky                                    lib/cli_bsky.ml
    prefs export                          [read-only]
    prefs import <file>
    post <text>
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

The `lib/cli_*.ml` modules should stay thin: parse command-line arguments,
call reusable modules such as `Syntax`, `Xrpc`, `Pds`, `Pds_admin`, `Account`,
`Migration`, `Repo`, `Blob`, `Record`, `Identity`, and `Plc`, then format the
result.

## Build Order

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
- [x] Implement `xrpc query` and `pds describe`; this proves HTTP, URI, JSON, and
      output formatting.
- [x] Add read-only `pds account list/status`.
- [x] Port the Tempest Python migration flow into `account migrate` subcommands.
- [x] Add low-complexity read-only `key inspect`, local `key generate`, and
      relay `account/host list/status`.
- [ ] Add admin commands with explicit confirmation for destructive operations.
- [ ] Add repo/blob backup commands.
- [ ] Add remaining lower-priority firehose, lexicon, key, and relay commands
      only if they become useful for operating Tempest.

## Goat Feature Inventory

High-priority replacement areas:

- PDS inspection: `pds describe`, `pds account list`, `pds account status`
- PDS admin: account create/list/info/update/reset/takedown/delete, blob
  status/purge, invite creation
- Account migration: login, service auth, missing blobs, PLC recommended/token
  request/sign/submit, activate/deactivate, full migration
- Repo/blob backup: repo export/import, blob list/download/export/upload
- Generic XRPC: query/procedure escape hatch for methods without dedicated
  commands

Medium-priority areas:

- Identity resolution
- Record get/list/create/update/delete
- Syntax helpers beyond the current starter set
- Firehose inspection
- PLC directory inspection
- Additional read-only goat commands worth considering:
  `account status/check-auth/missing-blobs`, `account plc recommended/current`,
  `repo list/inspect/mst/unpack`, `blob compute`, `bsky prefs export`,
  `relay host diff`, and lexicon lint/status/diff/validation helpers.

Low-priority areas:

- Bluesky app posting helpers
- Lexicon publishing workflows
- Relay admin commands
- Additional key management beyond generation/inspection unless needed for
  migration or PLC work

## Differences From Goat

- Keep migration targets explicit while keeping flags generic enough for any AT
  Protocol PDS.
- Do not store app passwords or access tokens in cleartext by default.
- Destructive admin commands require `--yes`.
- Keep `xrpc` as an escape hatch so every XRPC method does not need a bespoke
  command immediately.
- Implement personal PDS needs first; lexicon publishing, relay admin, and
  Bluesky post helpers can wait.
