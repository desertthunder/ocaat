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
--pds <url>
--auth <token>
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
