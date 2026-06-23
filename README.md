# ocaat

Object Categorical Abstract Authenticated Transfer Command-line Interface

`ocaat` is an OCaml/Dune CLI for operating [my PDS](https://github.com/desertthunder/tempest).

<details>
<summary>Commands</summary>

```text
ocaat
  version
  account
    migrate
      full
      login-source
      service-auth
      source-session-status
      export-car
      list-source-blobs
      download-source-blobs
      create-account
      refresh-session
      import-repo
      status
      missing-blobs
      upload-missing-blobs
      plc-recommended
      plc-request-token
      plc-sign
      plc-submit
      activate
  pds
    describe <host>
    account
      list [--handles] [--json] <host>
      status [--pds <url>] [--json] <did>
  key
    generate [--type P-256|K-256] [--terse]
    inspect <key>
  relay
    account
      list [--relay-host <url>] [--collection <nsid>] [--json]
      status [--relay-host <url>] [--json] <did>
    host
      list [--relay-host <url>] [--json]
      status [--relay-host <url>] [--json] <hostname>
  tempest
    migration-plan
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
    language check <language>
    url check <url>
    artifact-path check <path>
  xrpc
    query <method> [--param k=v]...
```

</details>

<details>
<summary>Global Options</summary>

```text
--color=auto|always|never
-v, --verbose
--verbosity=quiet|error|warning|info|debug
-q, --quiet
--json
--pds <url>              # or OCAAT_PDS
--auth <token>           # or OCAAT_AUTH
--admin-token <token>    # or --admin; also OCAAT_ADMIN_TOKEN
--yes, -y
--dry-run
--force, -f
```

Note: NO_COLOR=1 disables default color output[^nc]

Stable command error exit codes:

```text
64  usage error
65  validation error
66  authentication/authorization error
69  network error
70  remote HTTP/XRPC error
74  filesystem error
130 interrupted stream
```

</details>

## Account Migration

`ocaat account migrate` ports an account into Tempest as explicit, resumable
steps. Each step writes an artifact that later steps can reuse. Commands fail
before network access when required configuration, credentials, or artifacts are
missing.

<details>
<summary>Required configuration</summary>

```text
OLD_PDS
TEMPEST
TEMPEST_SERVICE_DID
DID
HANDLE
```

</details>

<details>
<summary>Optional overrides</summary>

```text
OLD_AUTH_PDS
OLD_LOGIN_PDS
OLD_IDENTIFIER
OLD_AUTH_FACTOR_TOKEN
```

</details>

<details>
<summary>Step-specific credentials and tokens</summary>

```text
OLD_PASSWORD
EMAIL
TEMPEST_PASSWORD
OLD_ACCESS
SERVICE_AUTH
TEMPEST_ACCESS
TEMPEST_REFRESH
PLC_TOKEN
```

</details>

<details>
<summary>Artifact locations</summary>

```text
ARTIFACT_DIR
OLD_SESSION_JSON
SERVICE_AUTH_JSON
REPO_CAR
SOURCE_BLOBS_JSON
TEMPEST_CREATE_ACCOUNT_JSON
TEMPEST_IMPORT_REPO_JSON
TEMPEST_STATUS_JSON
TEMPEST_MISSING_BLOBS_JSON
PLC_RECOMMENDED_JSON
PLC_TOKEN_JSON
PLC_SIGNED_OPERATION_JSON
PLC_SUBMIT_JSON
TEMPEST_ACTIVATE_JSON
```

`ARTIFACT_DIR` defaults to `.sandbox`. Other artifact variables default to files
inside that directory.

</details>

`full` runs the non-activation sequence through missing-blob discovery.

Activation and PLC update steps remain separate so they can be reviewed before
the account is cut over.

## Development

Use read-only checks during local development to verify CLI behavior without
mutating a PDS or public account.

### Local Tempest PDS

Assume Tempest is running at:

```text
http://localhost:4000
```

Check with:

```sh
ocaat pds describe http://localhost:4000
ocaat pds health --pds http://localhost:4000
ocaat pds stats --pds http://localhost:4000
ocaat pds account list --pds http://localhost:4000 --json
```

Keep a few local seeded accounts with stable handles and DIDs for manual checks,
for example:

| Handle          | DID           | Notes                    |
| --------------- | ------------- | ------------------------ |
| alice.localhost | `did:plc:...` | normal records/blobs     |
| bob.localhost   | `did:plc:...` | empty or minimal account |
| admin.localhost | `did:plc:...` | admin-created account    |

Useful local account checks:

```sh
ocaat pds account status --pds http://localhost:4000 did:plc:...
ocaat repo describe --pds http://localhost:4000 did:plc:...
ocaat repo latest-commit --pds http://localhost:4000 did:plc:...
ocaat blob list --pds http://localhost:4000 did:plc:...
ocaat record list --pds http://localhost:4000 did:plc:...
```

### Public read-only accounts

Use these public accounts for Bluesky-hosted interoperability checks:

| Handle              | Purpose                             |
| ------------------- | ----------------------------------- |
| `desertthunder.dev` | personal/public account check       |
| `bsky.app`          | hosted service account sanity check |
| `atproto.com`       | AT Protocol identity/PLC check      |

Examples:

```sh
ocaat resolve desertthunder.dev
ocaat resolve bsky.app
ocaat resolve atproto.com
ocaat plc history atproto.com
ocaat plc data atproto.com
ocaat record list bsky.app --collection app.bsky.actor.profile
ocaat repo describe bsky.app --pds https://bsky.social
ocaat blob list bsky.app --pds https://bsky.social
```

Public accounts are useful for manual development checks, but avoid strict CI
snapshots against them because records and repo heads can change.

### Local fixtures

Prefer local fixtures for repeatable repo/blob checks:

```sh
ocaat repo verify test/fixtures/repos/alice.car
ocaat repo list test/fixtures/repos/alice.car
ocaat repo inspect test/fixtures/repos/alice.car
ocaat repo mst test/fixtures/repos/alice.car
ocaat blob compute test/fixtures/blobs/avatar.png
```

Useful fixtures to keep:

- valid small repo CAR;
- empty repo CAR;
- malformed CAR;
- repo with multiple collections;
- repo with blob references;
- random non-CAR file.

[^nc]: https://no-color.org/
