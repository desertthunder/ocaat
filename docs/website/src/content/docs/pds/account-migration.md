---
title: Account Migration
description: Configure and run the step-oriented account migration workflow.
---

## Overview

`ocaat account migrate` moves an account from a source to destination PDS[^1] through
explicit, resumable steps. Each step writes an artifact that later steps can
reuse. The workflow stops before activation unless the activation command is
run separately.

## Source and target PDSes

Required environment variables identify the source account and target service:

```text
OLD_PDS
TEMPEST
TEMPEST_SERVICE_DID
DID
HANDLE
```

`OLD_AUTH_PDS` and `OLD_LOGIN_PDS` override the source authentication and login
services when they differ from `OLD_PDS`.

Optional account inputs include:

```text
EMAIL
OLD_PASSWORD
TEMPEST_PASSWORD
```

## Migration artifacts

`ARTIFACT_DIR` defaults to `.sandbox`. Individual paths can be overridden with
these variables:

```text
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

The workflow also reads step credentials from `OLD_ACCESS`, `SERVICE_AUTH`,
`TEMPEST_ACCESS`, `TEMPEST_REFRESH`, and `PLC_TOKEN` when those values are not
available in the corresponding artifacts. Use `--force` to replace an
existing artifact.

## Migration sequence

Run the steps in this order:

1. `login-source`
2. `service-auth`
3. `source-session-status`
4. `export-car`
5. `list-source-blobs`
6. `download-source-blobs`
7. `create-account`
8. `refresh-session`
9. `import-repo`
10. `status`
11. `missing-blobs`
12. `upload-missing-blobs`

`full` runs the non-activation sequence through `missing-blobs`. PLC steps are
separate so the identity change can be reviewed before submission:

```text
plc-recommended
plc-request-token
plc-sign
plc-submit
```

For a single step:

```sh
ocaat account migrate status --artifact-dir .sandbox --format json
```

## Cutover

Run `activate` only after the target status and missing-blob checks are ready.
Activation changes the account's operational state and should be treated as the
cutover point. Keep the PLC submission and activation steps separate when
reviewing a migration.

[^1]: currently supports tempest but will eventually be pds-agnostic
