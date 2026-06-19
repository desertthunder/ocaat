# ocaat

Object Categorical Abstract Authenticated Transfer Command-line Interface

`ocaat` is an OCaml/Dune CLI for operating [my PDS](https://github.com/desertthunder/tempest).

## Commands

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
    defaults
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

## Global Options

```text
--color=auto|always|never
-v, --verbose
--verbosity=quiet|error|warning|info|debug
-q, --quiet
--json
--pds <url>
--auth <token>
```
