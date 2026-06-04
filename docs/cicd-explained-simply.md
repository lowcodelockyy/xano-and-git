# CI/CD, Explained Simply

A plain-language guide to how this project ships changes to the Xano backend safely.
If you want the full technical reference, see [`ci-cd-pipeline.md`](./ci-cd-pipeline.md)
or the visual overview in [`../github-actions/cicd-overview.html`](../github-actions/cicd-overview.html).

---

## The one-sentence version

> Every change is **tested in a throwaway copy first**, and nothing reaches the
> real backend until those tests pass — and production also needs a **human to click "approve."**

---

## The problem we're solving

Our Xano backend (the database tables, APIs, and functions) is saved as code in this
repository. That's great — every change can be reviewed and undone like normal code.

But there's a catch: **in Xano, all "branches" share one single database.** So if you
push a bad change to *any* branch, you can accidentally damage real production data —
drop a table, change a column, lose records.

We need a place to test changes that **physically cannot touch production.**

---

## The solution: the sandbox

Xano gives each account a **sandbox** — a completely separate workspace with its own
database. Pushing to the sandbox can't affect production, no matter what.

So the rule for this whole pipeline is simple:

> **Test in the sandbox. Only write to the real backend after the tests pass.**

---

## What actually triggers each automation

Each automation is wired to a **specific GitHub event** — not just "you changed a file."
GitHub watches for these exact events and runs the matching workflow:

| The trigger (what you do) | Fires this automation |
| ------------------------- | --------------------- |
| **Push** to a `dev-*` branch | `xano-deploy-dev` |
| **Open or update a pull request** targeting `main` | `xano-pr-ci` |
| **Push to `main`** (e.g. merging a PR) | `xano-deploy-main` |
| **Delete** a `dev-*` branch | `xano-cleanup-dev` |
| **A timer** (every night, automatically) | `xano-regression-tests` |

Two important details about the push/PR triggers:

- **It's not the whole repo — it's the backend and the CI itself.** The push and PR
  workflows only fire when the change touches `xano/**` *or* the pipeline files
  (`.github/workflows/xano-*.yml`, the shared actions, and scripts). Editing a README
  won't kick anything off.
- **Every workflow can also be run by hand.** In the GitHub *Actions* tab there's a
  "Run workflow" button (this is the `workflow_dispatch` trigger) — handy for re-running
  the nightly tests on demand or deploying a specific dev branch manually.

---

## What happens, step by step

### 1. You're working on a feature (`dev-*` branch)
```
TRIGGER: you push to a dev-* branch
You push  →  Test in sandbox  →  If it passes, deploy to your dev branch
```
Your personal dev branch updates automatically, but only if the tests are green.

### 2. You open a pull request
```
TRIGGER: you open (or push more commits to) a PR aimed at main
You open PR  →  Test in sandbox  →  Done (nothing is deployed)
```
A pull request is *only* a safety check. It runs the tests but never writes anywhere.
This is your "is this change safe?" preview. (Updating the PR with new commits re-runs it.)

### 3. You merge to `main` (going to production)
```
TRIGGER: a commit lands on main (usually by merging your PR)
Merge  →  Test in sandbox  →  👤 Human approves  →  Deploy to production  →  Re-test production
```
This is the careful one. Even after the tests pass, **a person has to approve** before
production (`v1`) is touched. After deploying, the tests run again against the live
backend to confirm everything still works.

### 4. You delete a feature branch
```
TRIGGER: you delete a dev-* Git branch
Delete dev-* branch  →  Clean up its matching Xano branch
```
Housekeeping — it tidies up so old branches don't pile up. It refuses to delete anything
that isn't a `dev-*` branch.

### 5. Every night
```
TRIGGER: a scheduled timer (cron), 16:17 UTC daily — no push needed
Nightly  →  Run all tests against production
```
A scheduled check makes sure production still works, even when nobody pushed anything.
This catches problems from the outside world — like an external API (e.g. Gemini)
changing behavior.

---

## Where do the tests come from?

The tests live **inside the backend code itself**:

- **Unit tests** check small pieces — a single function or query.
- **Workflow tests** check whole flows — e.g. "sign up, then log in, then search."

Because they're part of the code, they travel with it automatically. When we push to the
sandbox, the tests come along for the ride and run against exactly the change being reviewed.

> **Note:** The sandbox has no real secrets (like the Gemini API key). So tests should
> **fake (mock) external API calls** rather than make real ones.

---

## The five automations (in plain terms)

| File | Triggered by | What it does |
| ---- | ------------ | ------------ |
| `xano-pr-ci.yml` | PR opened/updated against `main` | Safety check for pull requests. Tests only — never deploys. |
| `xano-deploy-dev.yml` | Push to a `dev-*` branch | Deploys your `dev-*` feature branch after it passes the sandbox. |
| `xano-deploy-main.yml` | Push to `main` | Deploys to production — but only after tests **and** a human approval. |
| `xano-cleanup-dev.yml` | A `dev-*` branch is deleted | Deletes the matching Xano branch when you delete the Git branch. |
| `xano-regression-tests.yml` | Nightly timer (cron) | Nightly health check against production. |

*(All five can also be launched by hand from the GitHub Actions tab.)*

---

## The guardrails (why this is safe)

- 🧪 **Sandbox isolation** — all testing runs in a separate workspace that can't reach production.
- 🔒 **Human approval** — production deploys pause for a required reviewer to sign off.
- 🛡️ **Branch protection** — `main` requires a pull request; no force-pushes or deletions.
- ✅ **Post-deploy check** — after deploying to production, the tests run again to confirm it worked.
- 🚦 **One-at-a-time** — Xano operations are serialized so two runs never collide in the shared sandbox.

---

## TL;DR for a new teammate

1. Work on a `dev-*` branch. Push freely — it's auto-tested and deployed to your own dev branch.
2. Open a PR to `main`. It gets tested in the sandbox. Get it reviewed.
3. Merge. Someone approves the production deploy. It ships and re-verifies itself.
4. The nightly job keeps watching production for you.

That's the whole thing: **test in a safe copy, get a human's OK for production, and let the
robots handle the rest.**
