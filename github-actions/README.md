# Xano GitHub Actions

This repo uses GitHub Actions to push the `xano/` workspace to Xano branches and run Xano's native unit and workflow tests.

The actual workflows live in `.github/workflows/`. This folder is retained for CI/CD setup notes.

## Required GitHub Configuration

Create these repository settings before running the workflows:

| Type | Name | Required | Example |
| --- | --- | --- | --- |
| Secret | `XANO_AUTH` | Yes | Xano API token |
| Variable | `XANO_INSTANCE_URL` | Yes | `https://your-instance.xano.io` |
| Variable | `XANO_WORKSPACE_ID` | Yes | `90` |
| Variable | `XANO_PROD_BRANCH` | No | `v1` |
| Variable | `XANO_CLI_VERSION` | No | `latest` or a pinned CLI version |

For production approvals, configure the GitHub environment named `xano-production`. The main deploy workflow targets that environment before it writes to the production Xano branch.

## Workflows

All preflight testing runs in the **Xano sandbox** — a separate, per-user workspace
that cannot touch production. Real workspace branches (`dev-*`, `v1`) are written only
after the sandbox tests pass. See `../docs/ci-cd-pipeline.md` for the full rationale.

### `xano-pr-ci.yml`

Runs on pull requests to `main` when Xano code or CI files change.

1. Runs the sandbox gate (`xano-sandbox-gate`): reset the sandbox, push `xano/` to it,
   run all sandbox unit and workflow tests.
2. Uploads JSON test output as a GitHub artifact.

No real workspace branch is created, so a PR cannot affect production. Forked pull
requests are skipped because repository secrets are not available to untrusted forks.

### `xano-deploy-dev.yml`

Runs on pushes to Git branches matching `dev-*`, plus manual dispatch.

It derives a sanitized Xano branch label, runs the sandbox gate, and **only if the gate
passes** creates the `dev-*` branch from production if needed and pushes `xano/` to it.
These branches are persistent so iterative dev work keeps the same Xano branch between
pushes.

### `xano-deploy-main.yml`

Runs on pushes to `main`, plus manual dispatch. Two jobs:

1. **`preflight`** runs the sandbox gate (no environment / approval).
2. **`deploy`** (`needs: preflight`, `xano-production` environment) pushes to
   `XANO_PROD_BRANCH` and then runs all tests against production to verify the deploy.

If the sandbox gate fails, the deploy job never runs and production is never touched.
Because the gate is a separate job, the production approval prompt only appears after
the change is proven in isolation.

### `xano-cleanup-dev.yml`

Runs when a `dev-*` Git branch is deleted, plus manual dispatch.

It deletes the matching sanitized Xano branch and refuses to delete anything that does not start with `dev-`.

### `xano-regression-tests.yml`

Runs nightly and on manual dispatch.

It does not push code. It only runs all unit and workflow tests against `XANO_PROD_BRANCH`, which helps catch regressions caused by environment, data, dependency, or external API drift.

## Branch Model

- All preflight testing happens in the **sandbox**, never in a real workspace branch.
- `main` deploys to `XANO_PROD_BRANCH` (default `v1`) after the sandbox gate passes.
- `dev-*` Git branches deploy to matching persistent Xano branches after the gate passes.
- Pull requests are sandbox-only; they never write to the workspace.
- All workflows share one concurrency group. This is required for sandbox safety: the
  sandbox is a per-account singleton, so runs must be serialized to avoid clobbering
  each other's reset/push/test cycle.

## Sandbox env vars

The sandbox is a separate workspace with its own environment variables and is **not**
seeded with secrets such as `GEMINI_API_KEY`. Sandbox tests must mock or skip external
API calls; a test that requires a live key will fail in the gate. If you later want the
gate to exercise real Gemini calls, add a `xano sandbox env set` step fed by a GitHub
secret.

## Test Ownership

Tests live in the XanoScript source: unit tests are `test "..."` blocks inside each
function/query `.xs` file, and workflow tests are `workflow_test "..."` definitions in
their own folder. They are pushed with the workspace, so the sandbox runs the exact
tests for the code under review. GitHub Actions just executes them through the Xano CLI
— sandbox subcommands for the preflight gate, branch subcommands for post-deploy
verification and regression:

```bash
# Sandbox gate (preflight)
xano sandbox unit_test run_all --output json
xano sandbox workflow_test run_all --output json

# Branch verification / regression
xano unit_test run_all --branch "$BRANCH" --output json
xano workflow_test run_all --branch "$BRANCH" --output json
```

Keep a small smoke workflow test around critical user paths, then use unit tests for reusable functions and edge cases. That gives the CI pipeline a fast signal and a meaningful end-to-end regression signal.
