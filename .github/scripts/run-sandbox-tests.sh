#!/usr/bin/env bash
# Run Xano unit + workflow tests inside the personal sandbox (an isolated,
# separate workspace) and write JSON reports. Unlike run-xano-tests.sh, this
# never targets a real workspace branch, so it cannot affect production.
set -euo pipefail

prefix="${1:-}"
report_dir="${2:-reports}"

mkdir -p "$report_dir"

xano sandbox unit_test list
xano sandbox workflow_test list

status=0
set -o pipefail

if ! xano sandbox unit_test run_all --output json | tee "${report_dir}/${prefix}unit-tests.json"; then
  status=1
fi

if ! xano sandbox workflow_test run_all --output json | tee "${report_dir}/${prefix}workflow-tests.json"; then
  status=1
fi

exit "$status"
