---
name: xano-feature-shipping
description: Ship Xano backend features safely through Git, Xano CLI, and GitHub Actions. Use when Codex is asked to start a new Xano feature, pull latest, create a dev branch, validate XanoScript, push or dry-run Xano workspace changes, run Xano unit/workflow tests, open a PR, prepare deployment, or troubleshoot this repo's Xano CI/CD flow.
---

# Xano Feature Shipping

## Overview

Use this skill to ship backend changes in the `xano-and-git` repo without bypassing the CI/CD safety checks.

The normal path is: sync latest `main`, create `dev-*`, edit `xano/`, validate locally, let GitHub Actions validate the change in the Xano sandbox and (if green) deploy the dev branch, open a PR, then merge to `main` for a sandbox-gated production deploy.

All CI testing runs in the **Xano sandbox** (a separate workspace that cannot touch production). Real branches (`dev-*`, `v1`) are pushed only after the sandbox gate passes. The sandbox is a per-user singleton and is not seeded with secrets, so sandbox tests must mock or skip external API calls (e.g. Gemini).

## Start Checks

Always inspect the repo before changing anything:

```bash
git status --short --branch
git remote -v
git branch --show-current
```

If the worktree is dirty, do not pull or switch branches until the existing changes are understood. Ask before stashing or committing user changes.

Check Xano readiness:

```bash
xano --version
xano profile list --details
xano workspace get
xano branch list
xano unit_test list --branch v1
xano workflow_test list --branch v1
```

Important blockers to surface:

- `Allow Push: false` means direct `xano workspace push` and the GitHub deploy workflows cannot push until Workspace Settings -> CLI -> Allow Direct Workspace Push is enabled, or the repo is redesigned around `xano sandbox`.
- `No unit tests found` or `No workflow tests found` means CI can run, but it is not proving regression safety yet.
- Only `v1` existing is fine for a fresh repo; dev and CI branches are created by workflows.

## Dry Run

Prefer the bundled dry-run helper when available:

```bash
bash skills/xano-feature-shipping/scripts/dry-run-xano-feature.sh
```

If using an installed copy of the skill instead:

```bash
bash ~/.codex/skills/xano-feature-shipping/scripts/dry-run-xano-feature.sh
```

If running manually, use this sequence:

```bash
git fetch --dry-run origin
git check-ref-format --branch dev-example-feature
xano workspace push --directory xano --branch v1 --sync --delete --dry-run --no-guids
```

Then run local validations:

```bash
git diff --check
ruby -e 'require "yaml"; Dir[".github/**/*.yml"].sort.each { |f| YAML.load_file(f); puts "ok #{f}" }'
bash -n .github/scripts/run-xano-tests.sh
```

Use the Xano MCP validator for `.xs` files when available:

```text
xano_validate_xanoscript(directory="xano", pattern="**/*.xs")
```

## Shipping A Feature

1. Get current and confirm no unsafe local changes:

```bash
git status --short --branch
git fetch origin
git switch main
git pull --ff-only origin main
```

2. Create a dev branch:

```bash
git switch -c dev-short-feature-name
```

Use a `dev-*` branch name so `.github/workflows/xano-deploy-dev.yml` runs after push.

3. Make scoped changes under `xano/` and matching docs/tests. Validate XanoScript before committing.

4. Commit and push:

```bash
git status --short
git add xano .github github-actions skills
git commit -m "Add short feature name"
git push -u origin dev-short-feature-name
```

5. Watch GitHub Actions:

- `xano-deploy-dev.yml` should create or reuse the matching Xano dev branch.
- It should push `xano/`.
- It should run unit tests and workflow tests.
- It should upload JSON reports.

6. Open a PR to `main`. The PR workflow should run the sandbox gate (reset, push, test) and upload reports. It does not write to any real workspace branch.

7. Merge after review and passing CI. The `main` workflow should run the sandbox gate in a preflight job, then in a separate `xano-production` job push to `XANO_PROD_BRANCH` and verify production tests.

8. Delete the Git dev branch after merge. The cleanup workflow should remove the matching Xano dev branch.

## CI/CD Files

Know these files in this repo:

- `.github/actions/setup-xano-cli/action.yml` configures Xano CLI from GitHub secrets and variables.
- `.github/actions/xano-sandbox-gate/action.yml` resets the sandbox, pushes `xano/` to it, and runs sandbox tests. Reused by the PR, dev, and main workflows.
- `.github/scripts/run-xano-tests.sh` runs both branch test suites (post-deploy verification / regression) and preserves both JSON reports.
- `.github/scripts/run-sandbox-tests.sh` runs both sandbox test suites for the preflight gate.
- `.github/workflows/xano-pr-ci.yml` validates pull requests in the sandbox only.
- `.github/workflows/xano-deploy-dev.yml` runs the sandbox gate, then deploys `dev-*` branches.
- `.github/workflows/xano-deploy-main.yml` runs the sandbox gate, then deploys and verifies production.
- `.github/workflows/xano-cleanup-dev.yml` deletes stale dev branches.
- `.github/workflows/xano-regression-tests.yml` runs scheduled production regression tests.

## GitHub Configuration

Confirm these are set before expecting Actions to work:

- Secret `XANO_AUTH`
- Variable `XANO_INSTANCE_URL`
- Variable `XANO_WORKSPACE_ID`
- Optional variable `XANO_PROD_BRANCH`, default `v1`
- Optional variable `XANO_CLI_VERSION`, default `latest`
- Optional protected environment `xano-production`

Never hard-code the Xano token, instance URL, or workspace ID into workflow YAML.
