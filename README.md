# ocaat

Object Categorical Abstract Authenticated Transfer Command-line Interface

`ocaat` is an OCaml/Dune CLI for operating [my PDS](https://github.com/desertthunder/tempest).

## Commands

```text
ocaat
  version
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
    datetime check <datetime>

    datetime now
    tid generate
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

These shared options come after the leaf command:

```sh
dune exec -- ocaat version --json
dune exec -- ocaat syntax handle check tempest.desertthunder.dev --verbosity=debug
```
