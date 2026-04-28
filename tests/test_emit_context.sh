#!/usr/bin/env bash
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PLUGIN_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
EMIT="${PLUGIN_ROOT}/hooks/lib/emit-context.sh"
fail=0

# Test 1: simple text input produces valid JSON
out=$(printf 'hello world' | bash "$EMIT" PreToolUse)
if echo "$out" | python3 -c 'import json,sys; d=json.load(sys.stdin); assert "additionalContext" in str(d) or "hookSpecificOutput" in d' 2>/dev/null; then
  echo "PASS: simple text emits valid JSON"
else
  echo "FAIL: emit-context.sh did not produce valid JSON for simple input"
  echo "  output: $out"
  fail=1
fi

# Test 2: text with embedded quotes and newlines is escaped properly
input=$(printf 'line one\n"quoted"\nline three')
out=$(printf '%s' "$input" | bash "$EMIT" PreToolUse)
if echo "$out" | python3 -c 'import json,sys; json.load(sys.stdin)' 2>/dev/null; then
  echo "PASS: text with quotes and newlines emits valid JSON"
else
  echo "FAIL: emit-context.sh did not escape special chars correctly"
  echo "  output: $out"
  fail=1
fi

# Test 3: empty input emits valid JSON
out=$(printf '' | bash "$EMIT" PreToolUse)
if echo "$out" | python3 -c 'import json,sys; json.load(sys.stdin)' 2>/dev/null; then
  echo "PASS: empty input emits valid JSON"
else
  echo "FAIL: empty input did not produce valid JSON"
  echo "  output: $out"
  fail=1
fi

exit $fail
