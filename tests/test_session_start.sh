#!/usr/bin/env bash
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PLUGIN_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

PASS=0
FAIL=0

TMPDIRS=()
cleanup() {
  for td in "${TMPDIRS[@]:-}"; do
    [ -n "$td" ] && [ -d "$td" ] && rm -rf "$td"
  done
  return 0
}
trap cleanup EXIT

mktmp() {
  local td
  td="$(mktemp -d)"
  TMPDIRS+=("$td")
  printf '%s' "$td"
}

assert_contains() {
  local needle="$1" haystack="$2" name="$3"
  if printf '%s' "$haystack" | grep -qF -- "$needle"; then
    printf 'PASS %s\n' "$name"; PASS=$((PASS+1))
  else
    printf 'FAIL %s: missing "%s"\n' "$name" "$needle" >&2; FAIL=$((FAIL+1))
  fi
}

assert_not_contains() {
  local needle="$1" haystack="$2" name="$3"
  if ! printf '%s' "$haystack" | grep -qF -- "$needle"; then
    printf 'PASS %s\n' "$name"; PASS=$((PASS+1))
  else
    printf 'FAIL %s: unexpected "%s"\n' "$name" "$needle" >&2; FAIL=$((FAIL+1))
  fi
}

# 1. Code project emits the reminder
d=$(mktmp); touch "$d/main.py"
unset CRAFTSMANSHIP_PROJECT_TYPE
out=$(CLAUDE_PROJECT_DIR="$d" CLAUDE_PLUGIN_ROOT="$PLUGIN_ROOT" \
  bash "${PLUGIN_ROOT}/hooks/session-start" </dev/null)
assert_contains "craftsmanship-test plugin is active" "$out" "session-start emits reminder on code project"
assert_contains "Iron law" "$out" "session-start inlines using- skill body"

# 2. Educational project emits silent payload
d=$(mktmp); touch "$d/_quarto.yml"
unset CRAFTSMANSHIP_PROJECT_TYPE
out=$(CLAUDE_PROJECT_DIR="$d" CLAUDE_PLUGIN_ROOT="$PLUGIN_ROOT" \
  bash "${PLUGIN_ROOT}/hooks/session-start" </dev/null)
assert_not_contains "craftsmanship-test plugin is active" "$out" "session-start silent on educational project"

# 3. Override=suppress silences a code project
d=$(mktmp); touch "$d/main.py"
printf 'CRAFTSMANSHIP_PROJECT_TYPE=suppress\n' > "$d/.craftsmanship-test.sh"
out=$(CLAUDE_PROJECT_DIR="$d" CLAUDE_PLUGIN_ROOT="$PLUGIN_ROOT" \
  bash "${PLUGIN_ROOT}/hooks/session-start" </dev/null)
assert_not_contains "craftsmanship-test plugin is active" "$out" "override=suppress silences code project"

# 4. Override=code-project enables on educational
d=$(mktmp); touch "$d/_quarto.yml"
printf 'CRAFTSMANSHIP_PROJECT_TYPE=code-project\n' > "$d/.craftsmanship-test.sh"
out=$(CLAUDE_PROJECT_DIR="$d" CLAUDE_PLUGIN_ROOT="$PLUGIN_ROOT" \
  bash "${PLUGIN_ROOT}/hooks/session-start" </dev/null)
assert_contains "craftsmanship-test plugin is active" "$out" "override=code-project enables on educational"

# 5. Malformed override file does not block reminder emission
d=$(mktmp); touch "$d/main.py"
printf 'CRAFTSMANSHIP_PROJECT_TYPE=suppress\nCRAFT_SOURCE_GLOBS=(\n' > "$d/.craftsmanship-test.sh"
out=$(CLAUDE_PROJECT_DIR="$d" CLAUDE_PLUGIN_ROOT="$PLUGIN_ROOT" \
  bash "${PLUGIN_ROOT}/hooks/session-start" </dev/null)
assert_contains "craftsmanship-test plugin is active" "$out" "malformed override is ignored, reminder still fires"

if [ "$FAIL" -eq 0 ]; then
  printf 'session-start: %d/%d passed\n' "$PASS" "$((PASS+FAIL))"; exit 0
else
  printf 'session-start: %d/%d passed (FAIL)\n' "$PASS" "$((PASS+FAIL))" >&2; exit 1
fi
