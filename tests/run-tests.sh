#!/usr/bin/env bash
# Discover and run every test_*.sh in this directory.
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
fail=0

for test_file in "${SCRIPT_DIR}"/test_*.sh; do
  [ -f "$test_file" ] || continue
  echo "=== $(basename "$test_file") ==="
  if ! bash "$test_file"; then
    fail=1
  fi
done

if [ "$fail" -eq 0 ]; then
  echo "ALL TESTS PASSED"
else
  echo "TESTS FAILED"
fi
exit "$fail"
