# Craftsmanship Test Plugin Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build the `craftsmanship-test` Claude Code plugin — a PreToolUse hook + skill + CLAUDE.md snippet that gates code-comment authorship through an imperative discipline (KEEP / STRIP / REWRITE per comment), mirroring the channelle-test plugin's shape.

**Architecture:** Three layers. (1) `claude-md-snippet.md` ships rules for paste into `~/.claude/CLAUDE.md` — passive, always in context. (2) `hooks/pre-tool-use` fires on Edit|Write|MultiEdit to source files and injects a system-reminder telling Claude to invoke the gate skill if comments are present. (3) `skills/craft-gate/SKILL.md` carries the imperative rules; Claude reads its own comments and emits per-comment verdicts. Hook is dumb (extension match only, no JSON content parsing). Skill is smart (LLM judgment).

**Tech Stack:** Bash 3.2+, inline `python3` for JSON parsing only (soft dependency, mirrors channelle-test). No jq, no Node, no Python packages. Tests are shell scripts that pipe JSON fixtures to the hook and assert on stdout.

**Reference plugin:** `/Users/hook/Documents/coding/python/Personal_AI  Projects/channelle_test` — mirror its shape exactly. Several files (`emit-context.sh`, the `_glob_to_regex` helper) port verbatim.

**Plugin root for this work:** `/Users/hook/Documents/coding/python/Personal_AI  Projects/crafstemnship`
(Note: the parent directory is named `crafstemnship` — typo of `craftsmanship` — but the *plugin name* in `plugin.json` is `craftsmanship-test`. The mismatch is harmless. Rename the parent later if desired.)

---

## Task 1: Initialize plugin scaffold + test runner

**Files:**
- Create: `/Users/hook/Documents/coding/python/Personal_AI  Projects/crafstemnship/.gitignore`
- Create: `/Users/hook/Documents/coding/python/Personal_AI  Projects/crafstemnship/tests/run-tests.sh`

- [ ] **Step 1: Initialize git and create directory tree**

```bash
cd "/Users/hook/Documents/coding/python/Personal_AI  Projects/crafstemnship"
git init -b master
mkdir -p .claude-plugin hooks/lib skills/craft-gate commands tests/fixtures docs/superpowers/specs docs/superpowers/plans
```

- [ ] **Step 2: Write .gitignore**

Create `/Users/hook/Documents/coding/python/Personal_AI  Projects/crafstemnship/.gitignore`:

```
.DS_Store
*.swp
*.swo
.envrc
node_modules/
__pycache__/
```

- [ ] **Step 3: Write tests/run-tests.sh**

Create `/Users/hook/Documents/coding/python/Personal_AI  Projects/crafstemnship/tests/run-tests.sh`:

```bash
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
```

```bash
chmod +x "/Users/hook/Documents/coding/python/Personal_AI  Projects/crafstemnship/tests/run-tests.sh"
```

- [ ] **Step 4: Run the empty test suite to confirm it executes**

Run:
```bash
bash "/Users/hook/Documents/coding/python/Personal_AI  Projects/crafstemnship/tests/run-tests.sh"
```

Expected output: `ALL TESTS PASSED` (no `test_*.sh` files exist yet, so the loop is empty).

- [ ] **Step 5: Commit**

```bash
cd "/Users/hook/Documents/coding/python/Personal_AI  Projects/crafstemnship"
git add .gitignore tests/run-tests.sh docs/
git commit -m "chore: initialize craftsmanship-test plugin scaffold and test runner"
```

---

## Task 2: Plugin manifest (plugin.json + marketplace.json)

**Files:**
- Create: `.claude-plugin/plugin.json`
- Create: `.claude-plugin/marketplace.json`
- Create: `tests/test_marketplace.sh`

- [ ] **Step 1: Write the failing test**

Create `tests/test_marketplace.sh`:

```bash
#!/usr/bin/env bash
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PLUGIN_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
fail=0

assert_field() {
  local file="$1" field="$2" expected="$3"
  local actual
  actual=$(python3 -c "import json; print(json.load(open('$file')).get('$field',''))")
  if [ "$actual" = "$expected" ]; then
    echo "PASS: $file has $field=$expected"
  else
    echo "FAIL: $file expected $field=$expected, got '$actual'"
    fail=1
  fi
}

assert_field "${PLUGIN_ROOT}/.claude-plugin/plugin.json" "name" "craftsmanship-test"
assert_field "${PLUGIN_ROOT}/.claude-plugin/plugin.json" "version" "0.1.0"
assert_field "${PLUGIN_ROOT}/.claude-plugin/marketplace.json" "name" "craftsmanship-test-local"

# Validate JSON parseable
python3 -c "import json; json.load(open('${PLUGIN_ROOT}/.claude-plugin/plugin.json'))" \
  && echo "PASS: plugin.json is valid JSON" || { echo "FAIL: plugin.json invalid JSON"; fail=1; }
python3 -c "import json; json.load(open('${PLUGIN_ROOT}/.claude-plugin/marketplace.json'))" \
  && echo "PASS: marketplace.json is valid JSON" || { echo "FAIL: marketplace.json invalid JSON"; fail=1; }

exit $fail
```

```bash
chmod +x tests/test_marketplace.sh
```

- [ ] **Step 2: Run test to verify it fails**

Run: `bash tests/run-tests.sh`
Expected: FAIL — files don't exist.

- [ ] **Step 3: Write plugin.json**

Create `.claude-plugin/plugin.json`:

```json
{
  "name": "craftsmanship-test",
  "description": "The Craft Gate — every comment authored or modified in code must pass a craftsmanship gate (KEEP / STRIP / REWRITE) before the edit completes. Self-fires on Edit/Write/MultiEdit to source files.",
  "version": "0.1.0",
  "author": { "name": "hook" },
  "license": "MIT",
  "homepage": "https://github.com/hook/craftsmanship-test",
  "repository": "https://github.com/hook/craftsmanship-test",
  "keywords": ["code-quality", "comments", "craftsmanship", "skills", "hooks"]
}
```

- [ ] **Step 4: Write marketplace.json**

Create `.claude-plugin/marketplace.json`:

```json
{
  "$schema": "https://anthropic.com/claude-code/marketplace.schema.json",
  "name": "craftsmanship-test-local",
  "description": "Local marketplace for the Craftsmanship Test plugin.",
  "owner": { "name": "hook" },
  "plugins": [
    {
      "name": "craftsmanship-test",
      "description": "The Craft Gate — comments must earn KEEP before they ship.",
      "category": "code-quality",
      "source": "./",
      "keywords": ["code-quality", "comments", "craftsmanship", "skills"]
    }
  ]
}
```

- [ ] **Step 5: Run test to verify it passes**

Run: `bash tests/run-tests.sh`
Expected: ALL TESTS PASSED.

- [ ] **Step 6: Commit**

```bash
git add .claude-plugin/ tests/test_marketplace.sh
git commit -m "feat: add plugin manifest and marketplace config"
```

---

## Task 3: Source-file detection (config.sh + detect-source-file.sh + tests)

**Files:**
- Create: `config.sh`
- Create: `hooks/lib/detect-source-file.sh`
- Create: `tests/test_detect_source_file.sh`

- [ ] **Step 1: Write the failing test**

Create `tests/test_detect_source_file.sh`:

```bash
#!/usr/bin/env bash
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PLUGIN_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
source "${PLUGIN_ROOT}/config.sh"
source "${PLUGIN_ROOT}/hooks/lib/detect-source-file.sh"
fail=0

assert_match() {
  local desc="$1" path="$2"
  if craft_path_triggers "$path"; then
    echo "PASS: $desc"
  else
    echo "FAIL: $desc — expected match for path: $path"
    fail=1
  fi
}

assert_no_match() {
  local desc="$1" path="$2"
  if craft_path_triggers "$path"; then
    echo "FAIL: $desc — expected NO match for path: $path"
    fail=1
  else
    echo "PASS: $desc"
  fi
}

assert_match     ".py file matches"           "/abs/path/src/foo.py"
assert_match     ".ts file matches"           "/abs/path/src/foo.ts"
assert_match     ".tsx nested matches"        "/abs/path/src/components/Foo.tsx"
assert_match     ".go file matches"           "/abs/path/main.go"
assert_match     ".rs file matches"           "/abs/path/src/lib.rs"
assert_no_match  ".md file does not match"    "/abs/path/README.md"
assert_no_match  ".json file does not match"  "/abs/path/package.json"
assert_no_match  ".csv file does not match"   "/abs/path/data.csv"
assert_no_match  "no extension"               "/abs/path/Makefile"

exit $fail
```

```bash
chmod +x tests/test_detect_source_file.sh
```

- [ ] **Step 2: Run test to verify it fails**

Run: `bash tests/run-tests.sh`
Expected: FAIL — `config.sh` and `detect-source-file.sh` don't exist.

- [ ] **Step 3: Write config.sh**

Create `config.sh`:

```bash
# craftsmanship-test plugin configuration
#
# Projects may override these by creating a `.craftsmanship-test.sh` at the
# target project root that redefines this array. The plugin sources it if present.
#
# Glob patterns identifying source-code files where comments should be gated.
# Comments in non-source files (markdown, yaml, json, etc.) are not gated.

CRAFT_SOURCE_GLOBS=(
  "**/*.py" "**/*.pyi"
  "**/*.ts" "**/*.tsx" "**/*.js" "**/*.jsx" "**/*.mjs" "**/*.cjs"
  "**/*.go" "**/*.rs"
  "**/*.java" "**/*.kt" "**/*.scala"
  "**/*.rb" "**/*.swift"
  "**/*.cpp" "**/*.cc" "**/*.c" "**/*.h" "**/*.hpp"
  "**/*.cs" "**/*.php"
  "**/*.ex" "**/*.exs"
)
```

- [ ] **Step 4: Write detect-source-file.sh**

Port `_glob_to_regex` and the matching loop verbatim from channelle-test (`/Users/hook/Documents/coding/python/Personal_AI  Projects/channelle_test/hooks/lib/detect-customer-view.sh`), renaming the function and the array variable.

Create `hooks/lib/detect-source-file.sh`:

```bash
#!/usr/bin/env bash
# Source-file path detector for the craftsmanship-test plugin.
# Source this file after sourcing config.sh (or .craftsmanship-test.sh).
#
# Exposes:
#   craft_path_triggers <path>   -> exit 0 if path matches a source-code glob

: "${CRAFT_SOURCE_GLOBS:?source config.sh before sourcing this library}"

# Convert a **-style glob to an extended regex suitable for grep -E.
# **/ -> (.*/)?   (zero or more path segments)
# *   -> [^/]*    (any chars within one segment)
# .   -> \.       (literal dot)
_glob_to_regex() {
  local glob="$1"
  printf '%s' "$glob" \
    | sed "s/\./\\\\./g" \
    | sed "s|\*\*/|ANYPATH_SEP|g" \
    | sed "s|\*|[^/]*|g" \
    | sed "s|ANYPATH_SEP|(.*/)?|g"
}

craft_path_triggers() {
  local path="$1"
  # Empty or zero CRAFT_SOURCE_GLOBS = disabled (project override sentinel)
  [ "${#CRAFT_SOURCE_GLOBS[@]}" -eq 0 ] && return 1
  local glob
  for glob in "${CRAFT_SOURCE_GLOBS[@]}"; do
    local regex
    regex=$(_glob_to_regex "$glob")
    if echo "$path" | grep -qE "^${regex}$"; then
      return 0
    fi
  done
  return 1
}
```

- [ ] **Step 5: Run test to verify it passes**

Run: `bash tests/run-tests.sh`
Expected: ALL TESTS PASSED. The 9 detector assertions pass.

- [ ] **Step 6: Commit**

```bash
git add config.sh hooks/lib/detect-source-file.sh tests/test_detect_source_file.sh
git commit -m "feat: add source-file glob detection with config.sh and helper library"
```

---

## Task 4: Context emitter (emit-context.sh ported verbatim)

**Files:**
- Create: `hooks/lib/emit-context.sh`
- Create: `tests/test_emit_context.sh`

- [ ] **Step 1: Write the failing test**

Create `tests/test_emit_context.sh`:

```bash
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
```

```bash
chmod +x tests/test_emit_context.sh
```

- [ ] **Step 2: Run test to verify it fails**

Run: `bash tests/run-tests.sh`
Expected: FAIL — `emit-context.sh` does not exist.

- [ ] **Step 3: Port emit-context.sh verbatim from channelle-test**

Copy the file content from `/Users/hook/Documents/coding/python/Personal_AI  Projects/channelle_test/hooks/lib/emit-context.sh` (already read into context earlier in conversation).

Create `hooks/lib/emit-context.sh`:

```bash
#!/usr/bin/env bash
# Reads raw text from stdin, emits a Claude Code hook JSON response
# with the text placed in additionalContext. Uses python3 for JSON escaping
# so every control character is handled correctly.
#
# Usage: some_text | hooks/lib/emit-context.sh <hook-event-name>
set -euo pipefail

event_name="${1:-UnknownEvent}"

# Read stdin into a bash variable first so it is not consumed by the Python heredoc.
content="$(cat)"

HOOK_EVENT_NAME="$event_name" HOOK_CONTENT="$content" python3 - <<'PY'
import json, os, sys
event_name = os.environ["HOOK_EVENT_NAME"]
content = os.environ["HOOK_CONTENT"]

# Claude Code plugin hooks expect hookSpecificOutput when invoked under
# ${CLAUDE_PLUGIN_ROOT}; bare hooks (e.g. Copilot CLI) use a flat shape.
if os.environ.get("CLAUDE_PLUGIN_ROOT") and not os.environ.get("COPILOT_CLI"):
    out = {
        "hookSpecificOutput": {
            "hookEventName": event_name,
            "additionalContext": content,
        }
    }
else:
    out = {"additionalContext": content}

print(json.dumps(out))
PY
```

- [ ] **Step 4: Run test to verify it passes**

Run: `bash tests/run-tests.sh`
Expected: ALL TESTS PASSED. Three emit-context assertions pass plus all earlier tests still pass.

- [ ] **Step 5: Commit**

```bash
git add hooks/lib/emit-context.sh tests/test_emit_context.sh
git commit -m "feat: add JSON-safe context emitter (ported from channelle-test)"
```

---

## Task 5: Pre-tool-use hook + integration tests

**Files:**
- Create: `tests/fixtures/edit_python_source.json`
- Create: `tests/fixtures/edit_markdown_doc.json`
- Create: `tests/fixtures/write_new_typescript.json`
- Create: `tests/fixtures/multiedit_go.json`
- Create: `tests/fixtures/edit_unmatched_extension.json`
- Create: `tests/test_pre_tool_use.sh`
- Create: `hooks/pre-tool-use`
- Create: `hooks/hooks.json`

- [ ] **Step 1: Write all five test fixtures**

Create `tests/fixtures/edit_python_source.json`:

```json
{
  "session_id": "test-session",
  "transcript_path": "/tmp/test",
  "cwd": "/abs/path",
  "permission_mode": "default",
  "hook_event_name": "PreToolUse",
  "tool_name": "Edit",
  "tool_input": {
    "file_path": "/abs/path/src/foo.py",
    "old_string": "x = 1",
    "new_string": "x = 2"
  },
  "tool_use_id": "toolu_test_001"
}
```

Create `tests/fixtures/edit_markdown_doc.json`:

```json
{
  "session_id": "test-session",
  "transcript_path": "/tmp/test",
  "cwd": "/abs/path",
  "permission_mode": "default",
  "hook_event_name": "PreToolUse",
  "tool_name": "Edit",
  "tool_input": {
    "file_path": "/abs/path/README.md",
    "old_string": "Hello",
    "new_string": "Hello world"
  },
  "tool_use_id": "toolu_test_002"
}
```

Create `tests/fixtures/write_new_typescript.json`:

```json
{
  "session_id": "test-session",
  "transcript_path": "/tmp/test",
  "cwd": "/abs/path",
  "permission_mode": "default",
  "hook_event_name": "PreToolUse",
  "tool_name": "Write",
  "tool_input": {
    "file_path": "/abs/path/src/foo.ts",
    "content": "export const x = 1;"
  },
  "tool_use_id": "toolu_test_003"
}
```

Create `tests/fixtures/multiedit_go.json`:

```json
{
  "session_id": "test-session",
  "transcript_path": "/tmp/test",
  "cwd": "/abs/path",
  "permission_mode": "default",
  "hook_event_name": "PreToolUse",
  "tool_name": "MultiEdit",
  "tool_input": {
    "file_path": "/abs/path/main.go",
    "edits": [
      {"old_string": "x", "new_string": "y"},
      {"old_string": "a", "new_string": "b"}
    ]
  },
  "tool_use_id": "toolu_test_004"
}
```

Create `tests/fixtures/edit_unmatched_extension.json`:

```json
{
  "session_id": "test-session",
  "transcript_path": "/tmp/test",
  "cwd": "/abs/path",
  "permission_mode": "default",
  "hook_event_name": "PreToolUse",
  "tool_name": "Edit",
  "tool_input": {
    "file_path": "/abs/path/data.csv",
    "old_string": "1,2",
    "new_string": "1,3"
  },
  "tool_use_id": "toolu_test_005"
}
```

- [ ] **Step 2: Write the failing test**

Create `tests/test_pre_tool_use.sh`:

```bash
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

exit $fail
```

```bash
chmod +x tests/test_pre_tool_use.sh
```

- [ ] **Step 3: Run test to verify it fails**

Run: `bash tests/run-tests.sh`
Expected: FAIL — `hooks/pre-tool-use` does not exist.

- [ ] **Step 4: Write hooks/pre-tool-use**

Create `hooks/pre-tool-use`:

```bash
#!/usr/bin/env bash
# PreToolUse hook: self-triggers the craft-gate reminder when Claude
# is about to Edit or Write a source-code file.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PLUGIN_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

# shellcheck source=/dev/null
source "${PLUGIN_ROOT}/config.sh"
if [ -n "${CLAUDE_PROJECT_DIR:-}" ] && [ -f "${CLAUDE_PROJECT_DIR}/.craftsmanship-test.sh" ]; then
  # shellcheck source=/dev/null
  source "${CLAUDE_PROJECT_DIR}/.craftsmanship-test.sh"
fi
# shellcheck source=/dev/null
source "${SCRIPT_DIR}/lib/detect-source-file.sh"

# Read stdin into a bash var first so the heredoc does not displace it,
# then extract tool_name and file_path via python3.
payload="$(cat)"
read_payload=$(HOOK_PAYLOAD="$payload" python3 - <<'PY'
import json, os
try:
    data = json.loads(os.environ.get("HOOK_PAYLOAD", "") or "{}")
except Exception:
    data = {}
tool = data.get("tool_name", "")
file_path = (data.get("tool_input", {}) or {}).get("file_path", "")
print(f"{tool}\t{file_path}")
PY
)

tool_name="${read_payload%%$'\t'*}"
file_path="${read_payload##*$'\t'}"

should_trigger=false
case "$tool_name" in
  Edit|Write|MultiEdit|NotebookEdit)
    if [ -n "$file_path" ] && craft_path_triggers "$file_path"; then
      should_trigger=true
    fi
    ;;
esac

if $should_trigger; then
  reminder=$(cat <<EOF
<EXTREMELY_IMPORTANT>
CRAFT GATE AUTO-TRIGGERED.

You are about to ${tool_name} \`${file_path}\`. If this edit adds or modifies any comment in the code (lines starting with \`#\`, \`//\`, \`/*\`, \`"""\`, \`'''\`, or \`<!--\`), invoke the \`craftsmanship-test:craft-gate\` skill via the Skill tool on each new/modified comment before this tool call completes.

If the verdict on any comment is STRIP or REWRITE, revise the edit before proceeding. Never skip the gate silently when comments are present.

If this edit contains no new or modified comments, proceed.
</EXTREMELY_IMPORTANT>
EOF
)
  printf '%s' "$reminder" | bash "${SCRIPT_DIR}/lib/emit-context.sh" PreToolUse
else
  printf '' | bash "${SCRIPT_DIR}/lib/emit-context.sh" PreToolUse
fi
```

```bash
chmod +x hooks/pre-tool-use
```

- [ ] **Step 5: Write hooks.json**

Create `hooks/hooks.json`:

```json
{
  "hooks": {
    "PreToolUse": [
      {
        "matcher": "Edit|Write|MultiEdit",
        "hooks": [
          {
            "type": "command",
            "command": "\"${CLAUDE_PLUGIN_ROOT}/hooks/pre-tool-use\"",
            "async": false
          }
        ]
      }
    ]
  }
}
```

- [ ] **Step 6: Run test to verify it passes**

Run: `bash tests/run-tests.sh`
Expected: ALL TESTS PASSED. Six pre-tool-use assertions pass plus all earlier tests.

- [ ] **Step 7: Commit**

```bash
git add hooks/pre-tool-use hooks/hooks.json tests/test_pre_tool_use.sh tests/fixtures/
git commit -m "feat: add PreToolUse hook with source-file matcher and reminder injection"
```

---

## Task 6: Craft-gate skill body

**Files:**
- Create: `skills/craft-gate/SKILL.md`

- [ ] **Step 1: Write SKILL.md verbatim**

Create `skills/craft-gate/SKILL.md`:

````markdown
---
name: craft-gate
description: Use when about to write or edit a comment in code — evaluates each new or modified comment against the craftsmanship rules and returns KEEP / STRIP / REWRITE per comment. Fires upstream of the comment landing in the file.
---

# The Craft Gate

<HARD-GATE>
Do NOT ship a comment without a KEEP verdict from this gate. STRIP means delete the comment. REWRITE means replace it with a real "why:" reason. Never rationalize a STRIP into a KEEP.
</HARD-GATE>

<HARD-GATE>
Do NOT think the rules in prose. Apply them silently and emit only the one-line verdict per comment. STOP if you catch yourself drafting prose answers.
</HARD-GATE>

<HARD-GATE>
**Violating the letter of these rules is violating the spirit of these rules.** "It clarifies intent" is not a why. "Future readers will need this" is not a why.
</HARD-GATE>

## The Iron Law

**NO COMMENT SHIPS WITHOUT A KEEP VERDICT.**

A comment is presumed STRIP until it earns KEEP. The burden of justification is on the comment, not on its absence.

## The Rules (apply silently to each comment)

1. **STRIP if the comment paraphrases the code.** If the next 1–3 lines of code can be summarized using the identifier names alone, the comment is restating the code. *(Beck — "reveals intention" — the code itself should reveal intention.)*

2. **STRIP if the comment teaches a language or library basic.** "this is a list comprehension", "requests.get sends an HTTP GET", "create empty dict". The reader is a developer, not a student.

3. **STRIP if the comment is a section divider inside a function.** `# --- validation ---`, `// === main logic ===`, `############`. The function is doing too much. Extract a function whose name is the divider. *(Fowler — "the comment becomes the new function name.")*

4. **STRIP if the comment is a scope-end label.** `} // end if`, `# end for loop`, `} // class Foo`. The scope is too long. Refactor to make the close obvious.

5. **STRIP if the comment is commented-out code.** Git is the archive. *(Martin — "Others won't have the courage to delete it.")*

6. **KEEP if the comment is a public-API contract docstring.** Docstrings on exported/public symbols that document params, returns, raises, thread-safety, or invariants the caller cannot infer from the signature. *(Ousterhout — "if there are no comments accompanying the interface, there is no abstraction.")*

7. **KEEP if the comment is a real "why."** A non-obvious constraint, hidden invariant, workaround for a specific bug/CVE/upstream quirk, performance trick that looks wrong, or surprising business rule. The "why" must be something the reader cannot derive from the code or function name.

8. **REWRITE if the comment is partially "why" but mostly "what."** Trim to the why-only part. If no why remains, the verdict is STRIP.

## Rationalization Table

| You think... | Reality |
|---|---|
| "It clarifies intent." | The code should clarify intent. STRIP. |
| "Future readers will thank me." | Future readers read code, not prose. STRIP. |
| "It explains what this function does." | The function name should. Rename, then STRIP. |
| "It's helpful context." | Context that isn't a why is paraphrase. STRIP. |
| "It's just a one-liner." | One-liners accumulate into noise. STRIP. |
| "I'll improve it later." | Comments rot. Later never comes. STRIP now. |
| "It's standard practice in this team." | Standard practice is the rot you inherited. STRIP. |
| "Removing it will lose information." | If the information matters, it belongs in the code or in a real why-comment. REWRITE or STRIP. |
| "But the LLM said this comment is helpful." | The LLM is the comment-rot machine. STRIP. |

## Red Flags (comment-text smells)

- "This function..." / "This method..." / "This class..."
- "Now we..." / "Then we..." / "First we..."
- "Step 1:" / "Step 2:" / numbered narration
- "Returns the result of..." / "Loops through..." / "Iterates over..."
- "Increment..." / "Decrement..." / "Set..." / "Initialize..."
- "Helper function for..."
- Banner ASCII (`#######`, `=====`, `-----`)
- Closing-brace labels (`} // end`)

## Not / Yes

```
Not: # increment counter by 1
     counter += 1

Not: # this is a list comprehension
     squared = [x*x for x in nums]

Not: // === Validation ===
     if (!email.includes('@')) throw new Error('bad email');

Yes: # server timestamps lag 1s on Tuesdays after the 2024-11 NTP
     # rollover; subtract before comparing
     normalized = ts - 1 if ts.weekday() == 1 and ts > NTP_ROLLOVER else ts

Yes: """Charge a customer.

     Raises ChargeFailed on declined cards. Idempotent on retry within
     30s via the Stripe-Idempotency-Key header.
     """
```

## Output Protocol

For each new or modified comment in the diff, emit exactly one line:

`CRAFT GATE: KEEP` — the comment earns its place
`CRAFT GATE: STRIP — <which rule>` — delete it
`CRAFT GATE: REWRITE — <suggested replacement>` — replace it

No prose answers. No verdict without applying the rules. No comment ships without KEEP.

After emitting verdicts, revise the Edit/Write to reflect them before the tool call completes.
````

- [ ] **Step 2: Validate frontmatter parses**

Run:
```bash
python3 -c "
import re
with open('skills/craft-gate/SKILL.md') as f: txt = f.read()
m = re.match(r'^---\n(.*?)\n---', txt, re.DOTALL)
assert m, 'frontmatter not found'
fm = m.group(1)
assert 'name: craft-gate' in fm, 'name field missing'
assert 'description:' in fm, 'description field missing'
print('PASS: SKILL.md frontmatter is valid')
"
```

Expected: `PASS: SKILL.md frontmatter is valid`

- [ ] **Step 3: Commit**

```bash
git add skills/craft-gate/SKILL.md
git commit -m "feat: add craft-gate skill with imperative comment-discipline rules"
```

---

## Task 7: CLAUDE.md snippet (passive reinforcement)

**Files:**
- Create: `claude-md-snippet.md`

- [ ] **Step 1: Write the snippet**

Create `claude-md-snippet.md`:

```markdown
## Craftsmanship — comment discipline

This project uses the `craftsmanship-test` plugin. When you write or modify a comment in code, the `craft-gate` skill fires and must return a KEEP verdict before the edit completes. Apply these rules pre-emptively.

**Iron law: no comment ships without KEEP.** A comment is STRIP by default; it must earn its place.

**STRIP** any comment that:
- Paraphrases the next 1–3 lines of code
- Teaches a language or library basic (`# this is a list comprehension`)
- Is a section divider inside a function (`# --- validation ---` → extract a function instead)
- Is a scope-end label (`} // end if`, `# end for loop`)
- Is commented-out code (git is the archive)

**KEEP** any comment that:
- Is a public-API contract docstring (params, returns, raises, thread-safety, invariants the caller cannot infer from the signature)
- Is a real "why": non-obvious constraint, hidden invariant, workaround for a specific bug/CVE, performance trick that looks wrong, surprising business rule

**REWRITE** if the comment is partially "why" but mostly "what" — trim to the why-only part.

When the hook fires, invoke `craftsmanship-test:craft-gate` via the Skill tool, emit one verdict per new/modified comment (`CRAFT GATE: KEEP` / `STRIP — <rule>` / `REWRITE — <text>`), and revise the edit before the tool call completes.

Sources: Mancuso (*The Software Craftsman*), Martin (*Clean Code* Ch. 4), Fowler (*Refactoring*), Beck (Four Rules of Simple Design), Ousterhout (*A Philosophy of Software Design*).
```

- [ ] **Step 2: Commit**

```bash
git add claude-md-snippet.md
git commit -m "feat: add CLAUDE.md snippet for passive rule reinforcement"
```

---

## Task 8: /craft-check slash command

**Files:**
- Create: `commands/craft-check.md`

- [ ] **Step 1: Write the slash command**

Create `commands/craft-check.md`:

```markdown
---
description: "Run the Craft Gate on the comments in the current edit or file"
---

Use the Skill tool to invoke the `craftsmanship-test:craft-gate` skill. Apply it to the comments in the file or edit currently under discussion. Output a one-line verdict per comment (`CRAFT GATE: KEEP` / `STRIP — <rule>` / `REWRITE — <text>`).
```

- [ ] **Step 2: Commit**

```bash
git add commands/craft-check.md
git commit -m "feat: add /craft-check slash command for on-demand evaluation"
```

---

## Task 9: User-facing README

**Files:**
- Create: `README.md`

- [ ] **Step 1: Write README.md**

Create `README.md`:

````markdown
# Craftsmanship Test

The Craft Gate — every comment authored or modified in code must earn KEEP before it ships.

## What it does

When Claude is about to Edit, Write, or MultiEdit a source-code file, a PreToolUse hook fires and reminds Claude that the `craft-gate` skill must run if any comments are present in the diff. The skill applies imperative rules from Mancuso, Martin, Fowler, Beck, and Ousterhout, and returns one verdict per comment: `KEEP`, `STRIP — <rule>`, or `REWRITE — <text>`. Claude revises the edit before the tool call completes.

The hook is dumb (matches file extension only). The skill is smart (LLM judgment). Rules are reinforced passively via a CLAUDE.md snippet.

## Install

```bash
# 1. Add the local marketplace
claude plugins marketplace add /path/to/craftsmanship-test

# 2. Install the plugin
claude plugins install craftsmanship-test@craftsmanship-test-local

# 3. (Strongly recommended) Paste the snippet into your CLAUDE.md
cat /path/to/craftsmanship-test/claude-md-snippet.md >> ~/.claude/CLAUDE.md
```

Step 3 puts the rules in passive system context, so Claude self-suppresses bad comments before authoring them. Without this paste the plugin still works, but only reactively when the hook fires.

## How it fires

1. Claude composes an Edit/Write/MultiEdit on a file ending in `.py`, `.ts`, `.go`, `.rs`, `.java`, etc.
2. The PreToolUse hook checks the file extension against `CRAFT_SOURCE_GLOBS`.
3. If matched, the hook injects an `<EXTREMELY_IMPORTANT>` reminder telling Claude to invoke `craftsmanship-test:craft-gate` if any comments are present.
4. Claude inspects its pending edit:
   - No new/modified comments → proceeds
   - Comments present → invokes the gate skill, gets per-comment verdicts, revises the edit
5. The edit completes.

## Configuration

Per-project override: create `.craftsmanship-test.sh` at your project root.

```bash
# Disable the gate entirely for this project
CRAFT_SOURCE_GLOBS=()

# Or restrict to a custom set
CRAFT_SOURCE_GLOBS=("**/*.py" "**/src/**/*.ts")
```

## The rules (one-line summary)

- **STRIP** comments that paraphrase code, teach language basics, divide functions internally, label scope ends, or are commented-out code.
- **KEEP** public-API contract docstrings and real "why" comments (non-obvious constraints, hidden invariants, bug workarounds, surprising business rules).
- **REWRITE** "what" comments that contain a partial "why" — trim to the why.

Full rules in `skills/craft-gate/SKILL.md`.

## Requirements

- `bash` 3.2+
- `python3` (used inline for JSON parsing only — same dependency as channelle-test)

If `python3` is missing, the hook degrades to a no-op; edits proceed without gating.

## Sources / philosophy

- Mancuso, *The Software Craftsman* — "How it is done is as important as getting it done."
- Martin, *Clean Code* Ch. 4 — "Comments are always failures."
- Fowler, *Refactoring* — "When you feel the need to write a comment, refactor first."
- Beck, Four Rules of Simple Design — "Reveals intention."
- Ousterhout, *A Philosophy of Software Design* — "If there are no comments accompanying the interface, there is no abstraction."

## Sibling plugin

Mirrors `channelle-test`'s plugin shape (sister gate for customer-view UX decisions).

## Contributing

See `CLAUDE.md` for plugin internals.
````

- [ ] **Step 2: Commit**

```bash
git add README.md
git commit -m "docs: add user-facing README with install, fire-flow, configuration, philosophy"
```

---

## Task 10: Contributor CLAUDE.md

**Files:**
- Create: `CLAUDE.md`

- [ ] **Step 1: Write contributor notes**

Create `CLAUDE.md`:

```markdown
# CLAUDE.md — plugin contributor notes

This file is for anyone modifying the craftsmanship-test plugin itself. End-user install and usage live in `README.md`.

## Layout

- `.claude-plugin/plugin.json` — plugin manifest
- `.claude-plugin/marketplace.json` — local marketplace descriptor (required for `claude plugins marketplace add`)
- `skills/craft-gate/SKILL.md` — the imperative-judgment gate skill (KEEP / STRIP / REWRITE per comment)
- `hooks/hooks.json` — declares PreToolUse matcher
- `hooks/pre-tool-use` — bash entry point: extracts tool_name + file_path via inline python3, checks file extension, emits reminder
- `hooks/lib/detect-source-file.sh` — `craft_path_triggers` and `_glob_to_regex` helpers (ported from channelle-test)
- `hooks/lib/emit-context.sh` — JSON-safe context emitter (ported verbatim from channelle-test)
- `config.sh` — default `CRAFT_SOURCE_GLOBS` (override per-project via `.craftsmanship-test.sh`)
- `claude-md-snippet.md` — markdown the user pastes into their CLAUDE.md for passive reinforcement
- `commands/craft-check.md` — `/craft-check` slash command for on-demand evaluation
- `tests/` — shell-based tests for every hook + helper, plus dogfood scenarios

## Testing

```bash
bash tests/run-tests.sh
```

Every hook and helper has a test. Add one when you add a feature. Tests must pass before commit.

For LLM-judgment validation of the skill body itself (which shell tests cannot reach), follow `tests/dogfood-scenarios.md`.

## Updating the gate content

The gate lives in `skills/craft-gate/SKILL.md`. Edits to that file do not require code changes — the hook simply tells Claude to invoke it.

## Updating triggers

- Source-file extensions: edit `CRAFT_SOURCE_GLOBS` in `config.sh`
- Per-project override: create `.craftsmanship-test.sh` at the project root with a redefined `CRAFT_SOURCE_GLOBS`
- Re-run `bash tests/run-tests.sh`

## Architecture notes

Three layers, deliberately separated:

1. **Passive (CLAUDE.md snippet)** — rules in system context. Free per turn. Survives compaction.
2. **Trigger (PreToolUse hook)** — fires on source-file edits. Purely syntactic (extension match), no JSON content parsing. Dumb on purpose.
3. **Judgment (craft-gate skill)** — LLM applies imperative rules to its own comments. Smart on purpose.

The hook does NOT detect bad comments. It detects that Claude is editing a source file. Claude itself checks for comment presence and invokes the skill if needed.

## Sibling plugin

Mirrors `channelle-test`. Shape is identical except:
- No SessionStart auto-load (replaced by CLAUDE.md snippet)
- No UserPromptSubmit (purely syntactic trigger)
- One skill instead of two (no bootstrap)
- Source-file globs instead of customer-view globs
- Verdict vocabulary: KEEP / STRIP / REWRITE per comment instead of SHIP / REWORK / DROP per design decision
```

- [ ] **Step 2: Commit**

```bash
git add CLAUDE.md
git commit -m "docs: add contributor CLAUDE.md with layout and architecture notes"
```

---

## Task 11: Dogfood scenarios

**Files:**
- Create: `tests/dogfood-scenarios.md`

- [ ] **Step 1: Write the dogfood scenarios**

Create `tests/dogfood-scenarios.md`:

````markdown
# Dogfood Scenarios

The skill body's behavior is evaluated by Claude at runtime, so it cannot be unit-tested in shell. Validate it manually by running these scenarios after install. Record observed verdicts next to each scenario for regression tracking.

## Setup

```bash
claude plugins install craftsmanship-test@craftsmanship-test-local
cat claude-md-snippet.md >> ~/.claude/CLAUDE.md
```

## Scenarios

### S1: paraphrase comment (expect STRIP)

Ask Claude: "edit `/tmp/foo.py` to add a counter increment with a comment explaining what it does."

Observed verdict expected on the comment `# increment counter by 1`:
`CRAFT GATE: STRIP — rule 1 (paraphrases the code)`

Recorded result: _______

### S2: tutorial comment (expect STRIP)

Ask Claude: "write a Python list comprehension in `/tmp/bar.py` with a comment explaining what a list comprehension is."

Observed verdict expected on `# this is a list comprehension`:
`CRAFT GATE: STRIP — rule 2 (teaches a language basic)`

Recorded result: _______

### S3: section divider (expect STRIP)

Ask Claude: "write a Python function in `/tmp/baz.py` with sections for validation, processing, and output, marked by `# --- section ---` dividers."

Observed verdict expected on each divider:
`CRAFT GATE: STRIP — rule 3 (section divider inside function; extract function instead)`

Recorded result: _______

### S4: scope-end label (expect STRIP)

Ask Claude: "write a TypeScript function in `/tmp/qux.ts` with a `} // end main` label at the closing brace."

Observed verdict expected:
`CRAFT GATE: STRIP — rule 4 (scope-end label)`

Recorded result: _______

### S5: commented-out code (expect STRIP)

Ask Claude: "edit `/tmp/foo.py` to add a function and leave one prior implementation as commented-out code above it."

Observed verdict expected on the commented-out lines:
`CRAFT GATE: STRIP — rule 5 (commented-out code; git is the archive)`

Recorded result: _______

### S6: public-API docstring (expect KEEP)

Ask Claude: "write a public function `charge_customer(card_id, amount_cents)` in `/tmp/billing.py` with a docstring documenting params, what it raises on declined cards, and idempotency behavior."

Observed verdict expected on the docstring:
`CRAFT GATE: KEEP`

Recorded result: _______

### S7: real "why" comment (expect KEEP)

Ask Claude: "write a function in `/tmp/timing.py` that subtracts 1 second from server timestamps on Tuesdays after a 2024-11 NTP rollover, with a comment explaining the rationale."

Observed verdict expected:
`CRAFT GATE: KEEP`

Recorded result: _______

### S8: partial-why comment (expect REWRITE)

Ask Claude: "edit `/tmp/timing.py` to add a comment that says 'subtract 1 from timestamp because of NTP rollover bug'."

Observed verdict expected:
`CRAFT GATE: REWRITE — <a more specific replacement that names the rollover date and the affected condition>`

Recorded result: _______

### S9: silent on no-comment edit

Ask Claude: "rename a variable in `/tmp/foo.py` without touching any comments."

Expected: hook fires (extension match), reminder injected, but Claude reads "no comments → proceed" and does NOT invoke the skill. No verdicts emitted.

Recorded result: _______

### S10: hook silent on .md edit

Ask Claude: "edit `/tmp/notes.md` to add a paragraph."

Expected: hook does NOT fire (extension does not match). No reminder, no verdicts.

Recorded result: _______

## How to investigate failures

If observed verdicts disagree with expected:

1. Check whether the rules in `skills/craft-gate/SKILL.md` are being read by Claude (look for skill invocation in the transcript)
2. Check whether `claude-md-snippet.md` is in `~/.claude/CLAUDE.md` (if not, expect more rationalization toward KEEP)
3. Tighten the rationalization table in `SKILL.md` if Claude is finding new excuses
4. Add a Not/Yes pair if the rule is unclear on a specific edge case
````

- [ ] **Step 2: Commit**

```bash
git add tests/dogfood-scenarios.md
git commit -m "test: add dogfood scenarios for skill-body validation"
```

---

## Task 12: Final verification

**Files:** none

- [ ] **Step 1: Run the full test suite**

Run:
```bash
cd "/Users/hook/Documents/coding/python/Personal_AI  Projects/crafstemnship"
bash tests/run-tests.sh
```

Expected: `ALL TESTS PASSED`. Four test files, 23 assertions total.

- [ ] **Step 2: Verify file tree**

Run:
```bash
find . -type f -not -path "./.git/*" -not -path "./docs/*" | sort
```

Expected output (24 files):
```
./.claude-plugin/marketplace.json
./.claude-plugin/plugin.json
./.gitignore
./CLAUDE.md
./README.md
./claude-md-snippet.md
./commands/craft-check.md
./config.sh
./hooks/hooks.json
./hooks/lib/detect-source-file.sh
./hooks/lib/emit-context.sh
./hooks/pre-tool-use
./skills/craft-gate/SKILL.md
./tests/dogfood-scenarios.md
./tests/fixtures/edit_markdown_doc.json
./tests/fixtures/edit_python_source.json
./tests/fixtures/edit_unmatched_extension.json
./tests/fixtures/multiedit_go.json
./tests/fixtures/write_new_typescript.json
./tests/run-tests.sh
./tests/test_detect_source_file.sh
./tests/test_emit_context.sh
./tests/test_marketplace.sh
./tests/test_pre_tool_use.sh
```

- [ ] **Step 3: Verify executables**

Run:
```bash
ls -l hooks/pre-tool-use tests/run-tests.sh tests/test_*.sh
```

Expected: every file shows `x` permission (executable).

- [ ] **Step 4: Verify git log**

Run:
```bash
git log --oneline
```

Expected: 11 commits (Task 1 = scaffold; Tasks 2-11 = features and docs), in reverse chronological order, each with a clear feat:/docs:/test:/chore: prefix.

- [ ] **Step 5: Local install smoke test**

Run:
```bash
PLUGIN_PATH="/Users/hook/Documents/coding/python/Personal_AI  Projects/crafstemnship"
claude plugins marketplace add "$PLUGIN_PATH"
claude plugins install craftsmanship-test@craftsmanship-test-local
```

Expected: plugin installs without error. Confirm in a new Claude Code session that:
- The hook fires when editing a `.py` file
- The reminder mentions `craftsmanship-test:craft-gate`
- Editing a `.md` file produces no reminder

- [ ] **Step 6: Run dogfood scenarios**

Walk through `tests/dogfood-scenarios.md` S1–S10. Record observed verdicts. If any scenario fails, file an issue against the skill body or rationalization table — do not modify rules to match observed behavior; modify rules so behavior matches expectation.

---

## Done criteria

- All 11 feature tasks committed
- `bash tests/run-tests.sh` reports ALL TESTS PASSED
- Plugin installs locally via `claude plugins install`
- Dogfood scenarios S1–S10 pass on a fresh Claude Code session with the snippet pasted into `~/.claude/CLAUDE.md`
- README and CLAUDE.md (contributor notes) are written
