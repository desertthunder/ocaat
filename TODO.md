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
ocaat                                      lib/cli_root.ml
  pds                                     lib/cli_pds.ml
    describe <host>                       lib/cli_pds.ml
    account                               lib/cli_pds.ml
      list [--handles] [--json] <host>    lib/cli_pds.ml
      status [--pds <url>] <did>          lib/cli_pds.ml
    admin                                 lib/cli_pds_admin.ml
      account                             lib/cli_pds_admin.ml
        create --handle <handle> --email <email> [--password <password>]
                                             lib/cli_pds_admin.ml
        list [--json]                     lib/cli_pds_admin.ml
        info <handle-or-did>              lib/cli_pds_admin.ml
        update <handle-or-did> [--email <email>] [--handle <handle>]
                                             lib/cli_pds_admin.ml
        reset-password <handle-or-did>    lib/cli_pds_admin.ml
        takedown [--reverse] <handle-or-did>
                                             lib/cli_pds_admin.ml
        delete [--yes] <handle-or-did>    lib/cli_pds_admin.ml
      blob                                lib/cli_pds_admin.ml
        status <handle-or-did> <cid>      lib/cli_pds_admin.ml
        purge [--reverse] <handle-or-did> <cid>
                                             lib/cli_pds_admin.ml
      invite                              lib/cli_pds_admin.ml
        create --count <n> --uses <n>     lib/cli_pds_admin.ml

  account                                 lib/cli_account.ml
    login --pds <url> --identifier <handle-or-email>
                                             lib/cli_account.ml
    logout                                lib/cli_account.ml
    status [<handle-or-did>]              lib/cli_account.ml
    check-auth                            lib/cli_account.ml
    service-auth --aud <did> --lxm <nsid> lib/cli_account.ml
    missing-blobs                         lib/cli_account.ml
    activate                              lib/cli_account.ml
    deactivate                            lib/cli_account.ml
    migrate                               lib/cli_account.ml
      --source-pds <url>
      --target-pds <url>
      --target-service-did <did>
      --handle <handle>
      --did <did>
      --email <email>
      [--artifact-dir <dir>]
                                             lib/cli_account.ml
    plc                                    lib/cli_account.ml
      recommended                         lib/cli_account.ml
      request-token                       lib/cli_account.ml
      sign [--token <token>] <recommended.json>
                                             lib/cli_account.ml
      submit <operation.json>             lib/cli_account.ml
      current <did-or-handle>             lib/cli_account.ml

  repo                                    lib/cli_repo.ml
    export <handle-or-did> [-o <file.car>] lib/cli_repo.ml
    import <file.car>                     lib/cli_repo.ml
    list <file.car>                       lib/cli_repo.ml
    inspect <file.car>                    lib/cli_repo.ml
    unpack <file.car> [-o <dir>]          lib/cli_repo.ml

  blob                                    lib/cli_blob.ml
    list <handle-or-did>                  lib/cli_blob.ml
    download <handle-or-did> <cid> [-o <path>]
                                             lib/cli_blob.ml
    export <handle-or-did> [-o <dir>]     lib/cli_blob.ml
    upload <file>                         lib/cli_blob.ml

  record                                  lib/cli_record.ml
    get <at-uri>                          lib/cli_record.ml
    list [--collections] <handle-or-did>  lib/cli_record.ml
    create <file.json>                    lib/cli_record.ml
    update --rkey <rkey> <file.json>      lib/cli_record.ml
    delete --collection <nsid> --rkey <rkey>
                                             lib/cli_record.ml

  resolve                                 lib/cli_resolve.ml
    <handle-or-did>                       lib/cli_resolve.ml
    --did <handle-or-did>                 lib/cli_resolve.ml

  plc                                     lib/cli_plc.ml
    history <did-or-handle>               lib/cli_plc.ml
    data <did-or-handle>                  lib/cli_plc.ml
    dump [--cursor <cursor>] [--tail]     lib/cli_plc.ml

  xrpc                                    lib/cli_xrpc.ml
    query <method> [--param k=v]...       lib/cli_xrpc.ml
    procedure <method> [--body <file>] [--param k=v]...
                                             lib/cli_xrpc.ml

  syntax                                  lib/cli_syntax.ml
    handle check <handle>                 lib/cli_syntax.ml
    did check <did>                       lib/cli_syntax.ml
    nsid check <nsid>                     lib/cli_syntax.ml
    at-uri check <at-uri>                 lib/cli_syntax.ml
    rkey check <rkey>                     lib/cli_syntax.ml
    cid check <cid>                       lib/cli_syntax.ml
    tid check <tid>                       lib/cli_syntax.ml
    tid generate                          lib/cli_syntax.ml
    datetime now                          lib/cli_syntax.ml
    datetime check <datetime>             lib/cli_syntax.ml
```

The `lib/cli_*.ml` modules should stay thin: parse command-line arguments,
call reusable modules such as `Syntax`, `Xrpc`, `Pds`, `Pds_admin`, `Account`,
`Migration`, `Repo`, `Blob`, `Record`, `Identity`, and `Plc`, then format the
result.

## Build Order

- [x] Keep the current `syntax` commands.
- [x] Add shared global options:
  - `--color=auto|always|never`
  - `-v`, `--verbose`
  - `--verbosity=quiet|error|warning|info|debug`
  - `-q`, `--quiet`
  - `--json`
  - `--pds <url>`
  - `--auth <token>`
- [ ] Implement `xrpc query` and `pds describe`; this proves HTTP, URI, JSON, and
      output formatting.
- [ ] Add read-only `pds account list/status`.
- [ ] Port the Tempest Python migration flow into `account migrate` subcommands.
- [ ] Add admin commands with explicit confirmation for destructive operations.
- [ ] Add repo/blob backup commands.
- [ ] Add lower-priority firehose, lexicon, key, and relay commands only if they
      become useful for operating Tempest.

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

Low-priority areas:

- Bluesky app posting helpers
- Lexicon publishing workflows
- Relay admin commands
- Key generation/inspection unless needed for migration or PLC work

## Differences From Goat

- Prefer Tempest defaults but keep flags generic enough for any AT Protocol PDS.
- Do not store app passwords or access tokens in cleartext by default.
- Destructive admin commands require `--yes`.
- Keep `xrpc` as an escape hatch so every XRPC method does not need a bespoke
  command immediately.
- Implement personal PDS needs first; lexicon publishing, relay admin, and
  Bluesky post helpers can wait.
