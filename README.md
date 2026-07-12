# ocaat

The one true `o`bjective `c`ategorical `a`bstract `a`uthenticated `t`ransfer
`c`ommand-`l`ine `i`nterface

`ocaat` is an CLI for developing with the AT Protocol and managing your PDS.

## Documentation

- [Getting started](docs/website/src/content/docs/getting-started.md)
- [Command reference](docs/website/src/content/docs/reference/commands.md)
- [CLI foundations](docs/website/src/content/docs/development/cli-foundations.md)
- [Account migration](docs/website/src/content/docs/pds/account-migration.md)
- [Local development](docs/website/src/content/docs/development/local-development.md)

## Quick start

Build the CLI with Dune:

```sh
dune build
```

Run a read-only PDS check:

```sh
dune exec ./bin/main.exe -- \
  pds describe https://tempest.desertthunder.dev --json
```

## Output and safety

See the [CLI foundations](docs/website/src/content/docs/development/cli-foundations.md)
for the format, provenance, redaction, and error codes.

## Account migration

`ocaat account migrate` is a step-oriented, resumable workflow for moving an
account between PDSes.

It stores explicit artifacts and requires configuration and credentials before network work.

See the [account migration guide](docs/website/src/content/docs/pds/account-migration.md)
for configuration, artifact paths, and the sequence.

## Development checks

Use deterministic tests for automated checks:

```sh
dune runtest
dune build @doc
```

See [Local development](docs/website/src/content/docs/development/local-development.md)
for read-only PDS checks and fixture guidance.
