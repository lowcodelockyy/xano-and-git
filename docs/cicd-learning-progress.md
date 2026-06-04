# CI/CD Learning Progress

A running checklist of what you should deeply understand from `cicd-explained-simply.md`.
Status: ⬜ not started · 🟡 in progress · ✅ mastered

---

## Stage 1 — The Problem (and why it exists)
- ✅ Why storing the Xano backend "as code" in a repo is valuable
- ✅ The core danger: **all Xano branches share one single database**
- ✅ Why that makes a bad push to *any* branch dangerous (isolating branch ≠ isolating data)
- ✅ Why we need a place that *physically cannot* touch production
- ✅ What the different Git branches are (`dev-*`, `main`) and their roles

> Context: this repo is a **showcase/demo** of GitHub-driven CI/CD for a Xano backend.
> Headline goal = prevent bad changes from reaching production.

## Stage 2 — The Solution (sandbox + design decisions)
- ⬜ What the sandbox is and why it's safe
- ⬜ The one governing rule: "test in sandbox, write to real backend only after tests pass"
- ⬜ The 5 triggers → 5 automations mapping
- ⬜ Why PR runs deploy *nothing* (safety-check only)
- ⬜ Why production needs a **human approval** + post-deploy re-test
- ⬜ Why tests live *inside* the backend code
- ⬜ Why the sandbox must **mock** external APIs (no real secrets)
- ⬜ Edge cases: cleanup refuses non-`dev-*`; serialization ("one-at-a-time")

## Stage 3 — The Broader Context (why it matters / impact)
- ⬜ The 5 guardrails and what each protects against
- ⬜ What breaks / what's at risk if a guardrail is removed
- ⬜ How this changes day-to-day work for a teammate
- ⬜ The role of the nightly regression run (catching *external* drift)

---

### Notes / misconceptions to revisit
- (none yet)
