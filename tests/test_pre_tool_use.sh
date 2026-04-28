#!/usr/bin/env bash
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PLUGIN_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
HOOK="${PLUGIN_ROOT}/hooks/pre-tool-use"
FIX_DIR="${SCRIPT_DIR}/fixtures"
fail=0

# Set CLAUDE_PLUGIN_ROOT so emit-context.sh produces hookSpecificOutput shape
export CLAUDE_PLUGIN_ROOT="$PLUGIN_ROOT"

assert_contains() {
  local desc="$1" output="$2" needle="$3"
  if [[ "$output" == *"$needle"* ]]; then
    echo "PASS: $desc"
  else
    echo "FAIL: $desc — expected to contain: $needle"
    echo "  actual output: $output"
    fail=1
  fi
}

assert_not_contains() {
  local desc="$1" output="$2" needle="$3"
  if [[ "$output" != *"$needle"* ]]; then
    echo "PASS: $desc"
  else
    echo "FAIL: $desc — expected NOT to contain: $needle"
    echo "  actual output: $output"
    fail=1
  fi
}

# Edit on Python source → reminder emitted
out=$(cat "${FIX_DIR}/edit_python_source.json" | "$HOOK")
assert_contains "Edit on .py source emits CRAFT GATE reminder" "$out" "CRAFT GATE AUTO-TRIGGERED"

# Edit on Markdown doc → silent (no reminder)
out=$(cat "${FIX_DIR}/edit_markdown_doc.json" | "$HOOK")
assert_not_contains "Edit on .md doc is silent" "$out" "CRAFT GATE AUTO-TRIGGERED"

# Write on TypeScript → reminder emitted
out=$(cat "${FIX_DIR}/write_new_typescript.json" | "$HOOK")
assert_contains "Write on .ts emits CRAFT GATE reminder" "$out" "CRAFT GATE AUTO-TRIGGERED"

# MultiEdit on Go → reminder emitted
out=$(cat "${FIX_DIR}/multiedit_go.json" | "$HOOK")
assert_contains "MultiEdit on .go emits CRAFT GATE reminder" "$out" "CRAFT GATE AUTO-TRIGGERED"

# Edit on unmatched extension → silent
out=$(cat "${FIX_DIR}/edit_unmatched_extension.json" | "$HOOK")
assert_not_contains "Edit on .csv is silent" "$out" "CRAFT GATE AUTO-TRIGGERED"

# Empty CRAFT_SOURCE_GLOBS via project override → silent
TMPDIR=$(mktemp -d)
cat > "${TMPDIR}/.craftsmanship-test.sh" <<'OVERRIDE'
CRAFT_SOURCE_GLOBS=()
OVERRIDE
out=$(CLAUDE_PROJECT_DIR="$TMPDIR" cat "${FIX_DIR}/edit_python_source.json" | CLAUDE_PROJECT_DIR="$TMPDIR" "$HOOK")
assert_not_contains "Empty CRAFT_SOURCE_GLOBS disables gate" "$out" "CRAFT GATE AUTO-TRIGGERED"
rm -rf "$TMPDIR"

# Regression I-1: NotebookEdit (currently no fixture, but verify the case
# statement no longer matches it). Synthesize a payload inline.
out=$(printf '%s' '{"tool_name":"NotebookEdit","tool_input":{"file_path":"/abs/path/foo.py"}}' | "$HOOK")
assert_not_contains "NotebookEdit does not trigger gate" "$out" "CRAFT GATE AUTO-TRIGGERED"

# Regression I-2: malformed override file does not block the hook
TMPDIR=$(mktemp -d)
cat > "${TMPDIR}/.craftsmanship-test.sh" <<'OVERRIDE'
CRAFT_SOURCE_GLOBS=(
OVERRIDE
out=$(CLAUDE_PROJECT_DIR="$TMPDIR" "$HOOK" < "${FIX_DIR}/edit_python_source.json" 2>/dev/null)
# Hook should still emit valid JSON (not exit non-zero)
if echo "$out" | python3 -c 'import json,sys; json.load(sys.stdin)' 2>/dev/null; then
  echo "PASS: malformed override does not block hook (graceful degrade)"
else
  echo "FAIL: malformed override caused hook to crash or emit invalid JSON"
  echo "  output: $out"
  fail=1
fi
rm -rf "$TMPDIR"

# MultiEdit with mixed comment/no-comment sub-edits → reminder fires (Claude must gate per sub-edit)
out=$(cat "${FIX_DIR}/multiedit_with_comments_go.json" | "$HOOK")
assert_contains "MultiEdit with mixed sub-edits emits reminder" "$out" "CRAFT GATE AUTO-TRIGGERED"
assert_contains "MultiEdit reminder mentions per-sub-edit obligation" "$out" "per sub-edit"

exit $fail
