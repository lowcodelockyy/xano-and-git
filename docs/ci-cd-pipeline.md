# Backend Source Control & CI/CD Pipeline

This document explains how the Xano backend in this repository is version-controlled
with Git/GitHub and how the CI/CD pipeline deploys and tests it automatically.

---

## 1. Is the backend in Git/GitHub?

**Yes.** The Xano backend is stored as [XanoScript](https://docs.xano.com) (`.xs`)
source files under `xano/`, version-controlled in this Git repository and pushed to
the GitHub remote:

```
origin  https://github.com/lowcodelockyy/xano-and-git.git
```

### What's tracked

```
xano/
├── workspace/
│   └── google_multimodal_embeddings.xs   # Workspace config: description, env vars, preferences
├── table/
│   ├── user.xs                           # Auth user table
│   └── embedding_item.xs                 # Stored text/image embeddings (pgvector)
├── function/
│   └── gemini_embed.xs                   # Reusable fn: call Gemini Embedding 2
└── api/
    ├── embeddings/
    │   ├── api_group.xs
    │   ├── embed_POST.xs                  # Create + store a multimodal embedding
    │   └── search_POST.xs                 # Vector similarity search
    └── authentication/
        ├── authentication.xs
        └── auth/
            ├── signup_POST.xs
            ├── login_POST.xs
            └── me_GET.xs
```

Because the backend is plain text, every change is reviewable in a pull request,
diffable, and revertible — the same workflow you'd use for any application code.

---

## 2. Is there a CI/CD pipeline?

**Yes.** The pipeline is built on **GitHub Actions** and the **Xano CLI** (`@xano/cli`).
It lives in `.github/`:

```
.github/
├── workflows/
│   ├── xano-pr-ci.yml             # Validate pull requests in the isolated sandbox
│   ├── xano-deploy-dev.yml        # Sandbox gate, then deploy dev-* branches
│   ├── xano-deploy-main.yml       # Sandbox gate, then deploy + verify production
│   ├── xano-cleanup-dev.yml       # Tear down dev branches when deleted
│   └── xano-regression-tests.yml  # Nightly regression run against production
├── actions/
│   ├── setup-xano-cli/action.yml  # Reusable: install + configure the Xano CLI
│   └── xano-sandbox-gate/action.yml  # Reusable: reset + push + test in the sandbox
└── scripts/
    ├── run-xano-tests.sh          # Runs branch unit + workflow tests, emits JSON
    └── run-sandbox-tests.sh       # Runs sandbox unit + workflow tests, emits JSON
```

> Note: `github-actions/README.md` contains the original setup notes. The active
> workflows now live in `.github/workflows/`. This document is the consolidated
> overview.

---

## 3. The core idea: test in the sandbox, deploy to branches

### Why the sandbox?

A Xano **branch** versions your logic and schema *definitions*, but all branches live
inside **one workspace with one database**. That means pushing a schema change to any
branch — even an ephemeral preflight branch — can affect the shared datastore. A bad
`--sync --delete` (dropping a table, changing a column type) is therefore a production
risk, not just a logic risk.

To remove that risk, **all testing happens in the Xano sandbox** — a *separate*,
per-user workspace that physically cannot touch production. The pipeline only writes to
real workspace branches (`dev-*`, `v1`) **after** the sandbox tests pass.

| Git event             | Tested in        | Then deployed to                | Notes |
| --------------------- | ---------------- | ------------------------------- | ----- |
| Pull request → `main` | Sandbox          | *(nothing)*                     | Pure validation; never touches the workspace |
| Push to `dev-*`       | Sandbox (gate)   | `dev-*` (persistent branch)     | Deploy only if the gate passes |
| Push to `main`        | Sandbox (gate)   | `v1` (prod), then verified      | Deploy gated by sandbox **and** the `xano-production` environment |
| Delete `dev-*` branch | —                | Matching `dev-*` branch deleted | Cleanup |
| Nightly schedule      | `v1` (live prod) | —                               | Read-only regression against the real thing |

The production branch defaults to **`v1`** (configurable via `XANO_PROD_BRANCH`).

### The sandbox gate (the universal test step)

The reusable `xano-sandbox-gate` composite action runs the same three steps wherever
preflight is needed:

```bash
xano sandbox get                                              # provision the singleton sandbox
xano sandbox reset --force                                    # clean slate for a reproducible run
xano sandbox push -d xano --sync --delete --force --no-guids  # isolated push — cannot touch prod
bash .github/scripts/run-sandbox-tests.sh                     # sandbox unit_test + workflow_test run_all
```

> ⚠️ **The sandbox is a per-user singleton** (one per account, tied to `XANO_AUTH`).
> The shared `concurrency` group is therefore load-bearing: it serializes every run so
> the reset-then-push of two runs can never interleave. There is no per-run parallelism.

> ⚠️ **The sandbox is not seeded with secrets.** It has its own env vars and does *not*
> receive a real `GEMINI_API_KEY`. Sandbox tests must **mock or skip** external API
> calls — a test that requires a live Gemini key will fail in the gate by design.

### The deploy primitive

Real deploys (only `dev-*` and `v1`) push the Git workspace into a branch:

```bash
xano workspace push \
  --directory xano \
  --branch "$BRANCH" \
  --sync --delete --force --no-guids
```

- `--sync --delete` makes the branch an exact mirror of the repo (removes anything no
  longer in source).
- `--force` only skips the interactive confirmation prompt (it is the documented
  "for CI/CD" flag, **not** a destructive git-style force).
- `--no-guids` keeps pushes deterministic across branches.

### Tests live in the code (and ride along to the sandbox)

Tests are part of the XanoScript source, so they deploy with the workspace:

- **Unit tests** are `test "..."` blocks embedded inside each function/query `.xs` file.
- **Workflow tests** are `workflow_test "..."` definitions in their own folder under `xano/`.

This is exactly what makes the sandbox gate meaningful: `sandbox push -d xano` pushes
the tests together with the code, so the sandbox always runs precisely the tests that
match the change under review — no separate seeding step, and `reset` is safe because
the next push restores them. The runners just execute what was pushed:

```bash
# sandbox (preflight)                # branch (post-deploy verify / regression)
xano sandbox unit_test run_all       xano unit_test     run_all --branch "$BRANCH"
xano sandbox workflow_test run_all   xano workflow_test run_all --branch "$BRANCH"
```

Keep a small workflow (end-to-end) smoke test over critical paths, plus unit tests for
reusable functions and edge cases. Mock external calls (e.g. Gemini) in tests so the
gate doesn't depend on secrets the sandbox lacks.

---

## 4. How each workflow works

### `xano-pr-ci.yml` — Pull request validation
**Triggers:** PRs to `main` that touch `xano/**` or CI files; manual dispatch.

1. Install + configure the Xano CLI (`setup-xano-cli`).
2. Run the **sandbox gate** (`xano-sandbox-gate`): reset → push → test.
3. Upload test reports as an artifact.

No real workspace branch is created or pushed, so a PR can **never** affect production
schema or data. Forked PRs are skipped because repository secrets aren't exposed to
untrusted forks.

### `xano-deploy-dev.yml` — Dev branch deploys
**Triggers:** pushes to `dev-*` Git branches; manual dispatch (optional branch label).

1. Derive a sanitized Xano branch label from the Git ref (guards reject non-`dev-*`
   labels and the production branch).
2. Run the **sandbox gate**.
3. **Only if the gate passed:** create the `dev-*` Xano branch from production if it
   doesn't exist, then `workspace push` to it.

These Xano dev branches are **persistent**, so iterative work keeps the same branch
between pushes — but nothing reaches even a dev branch until it has passed the sandbox.

### `xano-deploy-main.yml` — Production deploy
**Triggers:** pushes to `main`; manual dispatch. Two jobs:

**Job 1 — `preflight`:** runs the **sandbox gate** (no environment, no approval needed).

**Job 2 — `deploy`** (`needs: preflight`, protected `xano-production` environment):
1. **Only if the gate passed** and the environment approval (if configured) is granted,
   `workspace push` to the production branch (`v1`).
2. Re-run all tests **against production** to verify the live deploy.

Splitting into two jobs means the sandbox tests run *first*, and the production
approval prompt only appears once the change is already proven in isolation. If the
gate fails, the deploy job never starts and production is never touched.

### `xano-cleanup-dev.yml` — Dev teardown
**Triggers:** deletion of a `dev-*` Git branch; manual dispatch.

Deletes the matching Xano `dev-*` branch. Hard guards refuse to delete anything that
isn't a `dev-*` branch, and never the production branch.

### `xano-regression-tests.yml` — Nightly regression
**Triggers:** daily cron (`17 16 * * *` UTC); manual dispatch.

Does **not** push code. It only runs the full unit + workflow test suite against
production (`v1`) to catch regressions from data, dependency, environment, or
external-API drift (e.g. the Gemini embeddings API).

---

## 5. Shared building blocks

### `setup-xano-cli` composite action
Installs Node 20, installs `@xano/cli`, and creates a default CLI profile named `ci`
pointed at your instance/workspace/branch. It fails fast if any required
secret/variable is missing.

### `xano-sandbox-gate` composite action
Reusable preflight used by the PR, dev, and main workflows. It runs `sandbox get` →
`sandbox reset` → `sandbox push` → `run-sandbox-tests.sh`, validating the change in an
isolated workspace. Accepts a `report-prefix` input so callers can label their report
artifacts (e.g. `preflight-`).

### Concurrency & safety
All workflows share one concurrency group:

```yaml
concurrency:
  group: xano-${{ github.repository }}
  cancel-in-progress: false
```

This serializes every Xano operation across the whole repo. It is **especially
critical for the sandbox**, which is a per-account singleton: serialization guarantees
one run's `reset`→`push`→`test` cycle completes before another begins, so runs can't
clobber each other's sandbox state. `cancel-in-progress: false` lets in-flight deploys
finish instead of being interrupted mid-push.

---

## 6. Required GitHub configuration

Set these before the workflows can run (Settings → Secrets and variables → Actions):

| Type     | Name                | Required | Example                          |
| -------- | ------------------- | -------- | -------------------------------- |
| Secret   | `XANO_AUTH`         | Yes      | Xano API token                   |
| Variable | `XANO_INSTANCE_URL` | Yes      | `https://your-instance.xano.io`  |
| Variable | `XANO_WORKSPACE_ID` | Yes      | `90`                             |
| Variable | `XANO_PROD_BRANCH`  | No       | `v1` (default)                   |
| Variable | `XANO_CLI_VERSION`  | No       | `latest` or a pinned version     |

For production approvals, configure a GitHub **environment** named `xano-production`;
the main deploy workflow targets it before writing to the production Xano branch.

---

## 7. Day-to-day developer flow

```
            ┌────────────────────────────────────────────────────────────┐
            │  Local: edit xano/*.xs, push to your sandbox to iterate      │
            └────────────────────────────────────────────────────────────┘
                                     │
              git push dev-myfeature │
                                     ▼
        ┌───────────────────────────────────────────────────────────────┐
        │ xano-deploy-dev → SANDBOX GATE → if green, deploy `dev-myfeature` │
        └───────────────────────────────────────────────────────────────┘
                                     │
                 open PR → main      ▼
        ┌───────────────────────────────────────────────────────────────┐
        │ xano-pr-ci → SANDBOX GATE only (no workspace write)             │
        └───────────────────────────────────────────────────────────────┘
                                     │
                 merge to main       ▼
        ┌───────────────────────────────────────────────────────────────┐
        │ xano-deploy-main → SANDBOX GATE → [prod approval] → `v1` → verify │
        └───────────────────────────────────────────────────────────────┘
                                     │
                 delete dev-myfeature▼
        ┌───────────────────────────────────────────────────────────────┐
        │ xano-cleanup-dev → deletes Xano `dev-myfeature`                 │
        └───────────────────────────────────────────────────────────────┘

        Nightly: xano-regression-tests → full suite vs production (v1)
```

1. Create a `dev-*` Git branch and develop. Each push runs the sandbox gate, then —
   if green — deploys to a matching persistent Xano dev branch.
2. Open a PR to `main`. CI validates the change entirely in the sandbox, touching no
   real workspace branch.
3. Merge. The main workflow runs the sandbox gate, then (after approval) deploys to
   production and re-verifies against the live branch.
4. Delete the `dev-*` branch to tear down its Xano counterpart.
5. The nightly job continuously guards production against drift.
