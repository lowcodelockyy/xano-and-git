#!/usr/bin/env bash
set -euo pipefail

if [ "$#" -lt 1 ]; then
  echo "usage: $0 <xano-branch> [report-prefix] [report-dir]" >&2
  exit 2
fi

branch="$1"
prefix="${2:-}"
report_dir="${3:-reports}"

mkdir -p "$report_dir"

xano unit_test list --branch "$branch"
xano workflow_test list --branch "$branch"

status=0
set -o pipefail

if ! xano unit_test run_all --branch "$branch" --output json | tee "${report_dir}/${prefix}unit-tests.json"; then
  status=1
fi

if ! xano workflow_test run_all --branch "$branch" --output json | tee "${report_dir}/${prefix}workflow-tests.json"; then
  status=1
fi

exit "$status"
