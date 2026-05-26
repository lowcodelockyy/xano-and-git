#!/usr/bin/env bash
set -u

status=0

run() {
  printf '\n$ %s\n' "$*"
  "$@"
  rc=$?
  if [ "$rc" -ne 0 ]; then
    status=1
    printf 'command failed with exit code %s\n' "$rc" >&2
  fi
}

capture() {
  printf '\n$ %s\n' "$*"
  CAPTURED_OUTPUT="$("$@" 2>&1)"
  rc=$?
  printf '%s\n' "$CAPTURED_OUTPUT"
  if [ "$rc" -ne 0 ]; then
    status=1
    printf 'command failed with exit code %s\n' "$rc" >&2
  fi
  return "$rc"
}

blocker() {
  status=1
  printf '\nREADINESS BLOCKER: %s\n' "$*" >&2
}

run git status --short --branch
run git remote -v
run git branch --show-current
run git fetch --dry-run origin
run git check-ref-format --branch dev-example-feature

if command -v xano >/dev/null 2>&1; then
  run xano --version
  run xano profile list --details
  if capture xano workspace get; then
    workspace_output="$CAPTURED_OUTPUT"
    if printf '%s\n' "$workspace_output" | grep -q 'Allow Push: false'; then
      blocker 'Direct workspace push is disabled. Enable Workspace Settings -> CLI -> Allow Direct Workspace Push, or redesign CI around xano sandbox.'
    fi
  fi
  run xano branch list
  if capture xano unit_test list --branch v1; then
    unit_output="$CAPTURED_OUTPUT"
    if printf '%s\n' "$unit_output" | grep -q 'No unit tests found'; then
      blocker 'No Xano unit tests are configured on v1. CI can run, but it cannot prove unit-level regression safety yet.'
    fi
  fi
  if capture xano workflow_test list --branch v1; then
    workflow_output="$CAPTURED_OUTPUT"
    if printf '%s\n' "$workflow_output" | grep -q 'No workflow tests found'; then
      blocker 'No Xano workflow tests are configured on v1. CI can run, but it cannot prove end-to-end regression safety yet.'
    fi
  fi
  if capture xano sandbox push --directory xano --sync --delete --dry-run --no-guids; then
    push_output="$CAPTURED_OUTPUT"
    if printf '%s\n' "$push_output" | grep -q 'Direct push is disabled'; then
      blocker 'Xano sandbox dry-run push was blocked because direct push is disabled.'
    fi
  fi
  if capture xano sandbox unit_test list; then
    sandbox_unit_output="$CAPTURED_OUTPUT"
    if printf '%s\n' "$sandbox_unit_output" | grep -q 'No unit tests found'; then
      blocker 'No unit tests are defined in the xano/ code yet (test blocks live inside each .xs file). The sandbox gate will run zero unit tests until some are written.'
    fi
  fi
else
  status=1
  printf '\nxano CLI is not installed or not on PATH\n' >&2
fi

run git diff --check

if command -v ruby >/dev/null 2>&1; then
  run ruby -e 'require "yaml"; Dir[".github/**/*.yml"].sort.each { |f| YAML.load_file(f); puts "ok #{f}" }'
else
  status=1
  printf '\nruby is not installed or not on PATH; skipped workflow YAML parse\n' >&2
fi

if [ -f .github/scripts/run-xano-tests.sh ]; then
  run bash -n .github/scripts/run-xano-tests.sh
else
  status=1
  printf '\n.github/scripts/run-xano-tests.sh is missing\n' >&2
fi

exit "$status"
