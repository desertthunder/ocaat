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

`piaf` was tried first, but it failed to compile in the current switch because
its C stubs could not find OpenSSL headers. `cohttp-lwt-unix` is the current
HTTP package.

## Proposed Command Tree

```text
ocaat
  pds
    describe <host>
    account
      list [--handles] [--json] <host>
      status [--pds <url>] <did>
    admin
      account
        create --handle <handle> --email <email> [--password <password>]
        list [--json]
        info <handle-or-did>
        update <handle-or-did> [--email <email>] [--handle <handle>]
        reset-password <handle-or-did>
        takedown [--reverse] <handle-or-did>
        delete [--yes] <handle-or-did>
      blob
        status <handle-or-did> <cid>
        purge [--reverse] <handle-or-did> <cid>
      invite
        create --count <n> --uses <n>

  account
    login --pds <url> --identifier <handle-or-email>
    logout
    status [<handle-or-did>]
    check-auth
    service-auth --aud <did> --lxm <nsid>
    missing-blobs
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
    plc
      recommended
      request-token
      sign [--token <token>] <recommended.json>
      submit <operation.json>
      current <did-or-handle>

  repo
    export <handle-or-did> [-o <file.car>]
    import <file.car>
    list <file.car>
    inspect <file.car>
    unpack <file.car> [-o <dir>]

  blob
    list <handle-or-did>
    download <handle-or-did> <cid> [-o <path>]
    export <handle-or-did> [-o <dir>]
    upload <file>

  record
    get <at-uri>
    list [--collections] <handle-or-did>
    create <file.json>
    update --rkey <rkey> <file.json>
    delete --collection <nsid> --rkey <rkey>

  resolve
    <handle-or-did>
    --did <handle-or-did>

  plc
    history <did-or-handle>
    data <did-or-handle>
    dump [--cursor <cursor>] [--tail]

  xrpc
    query <method> [--param k=v]...
    procedure <method> [--body <file>] [--param k=v]...

  syntax
    handle check <handle>
    did check <did>
    nsid check <nsid>
    at-uri check <at-uri>
    rkey check <rkey>
    cid check <cid>
    tid check <tid>
    tid generate
    datetime now
    datetime check <datetime>
```

## Build Order

1. Keep the current `syntax` commands as learning exercises.
2. Add shared global options:
   - `--color=auto|always|never`
   - `-v`, `--verbose`
   - `--verbosity=quiet|error|warning|info|debug`
   - `-q`, `--quiet`
   - `--json`
   - `--pds <url>`
   - `--auth <token>`
3. Implement `xrpc query` and `pds describe`; this proves HTTP, URI, JSON, and
   output formatting.
4. Add read-only `pds account list/status`.
5. Port the Tempest Python migration flow into `account migrate` subcommands.
6. Add admin commands with explicit confirmation for destructive operations.
7. Add repo/blob backup commands.
8. Add lower-priority firehose, lexicon, key, and relay commands only if they
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
