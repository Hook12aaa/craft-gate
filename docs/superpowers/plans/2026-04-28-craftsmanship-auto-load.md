# Craftsmanship-test auto-load Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Eliminate the manual `cat claude-md-snippet.md >> ./CLAUDE.md` install step. Rules load automatically per session via SessionStart, and a project-type detector silences the plugin on educational/notebook-dominant projects with denylist semantics.

**Architecture:** SessionStart hook reads a new `using-craftsmanship-test` skill body and emits it as `additionalContext` after passing a project-type detector. PreToolUse hook also gates on the detector. Override via `CRAFTSMANSHIP_PROJECT_TYPE` in `.craftsmanship-test.sh`. Mirrors `channelle-test` shape with `CODE_PROJECT`/`SUPPRESS` verdict vocabulary instead of `PUBLIC_APP`/`SUPPRESS`.

**Tech stack:** Bash 3.2+ (macOS default), inline `python3 -c` for JSON parsing, no other dependencies.

---

## File structure

**Add:**
- `skills/using-craftsmanship-test/SKILL.md` — bootstrap skill, frontmatter + body. Inlined into SessionStart payload.
- `hooks/session-start` — bash entry, ~30 lines. Resolves verdict, inlines skill body or emits silent.
- `hooks/lib/detect-project-type.sh` — sourceable helper defining `craft_detect_project_type` and `_craft_is_educational`.
- `tests/test_session_start.sh` — fixtures: code project, educational project, override-suppress, override-enable.
- `tests/test_detect_project_type.sh` — fixtures for each denylist signal, override paths, default-on path.

**Modify:**
- `hooks/hooks.json` — add SessionStart matcher.
- `hooks/pre-tool-use` — source detector, exit silent if verdict != `CODE_PROJECT` before extension gate.
- `tests/test_pre_tool_use.sh` — add SUPPRESS-verdict cases.
- `README.md` — drop the `cat snippet >> CLAUDE.md` step; add detector + override paragraph.
- `CLAUDE.md` (contributor notes) — refresh "Architecture notes" and "Layout" sections.

**Delete:**
- `claude-md-snippet.md` — content folds into the using- skill.

---

## Task 1: Bootstrap skill `using-craftsmanship-test`

**Files:**
- Create: `skills/using-craftsmanship-test/SKILL.md`

- [ ] **Step 1: Create the skill file**

Create `skills/using-craftsmanship-test/SKILL.md` with this exact content:

````markdown
---
name: using-craftsmanship-test
description: Bootstrap context for the Craftsmanship Test plugin. Auto-loaded at session start. Defers all gating to the project-type detector and craftsmanship-test:craft-gate skill. Not a runtime-triggered skill — use craftsmanship-test:craft-gate for the actual gate.
---

# Using the Craftsmanship Test

<HARD-GATE>
Do NOT invoke the craftsmanship-test:craft-gate skill without a CODE_PROJECT verdict from the project-type detector. STOP and stay silent.
</HARD-GATE>

<HARD-GATE>
Do NOT infer the project type from prose, file extensions, or your own reasoning. Trust the detector's verdict. Override only when CRAFTSMANSHIP_PROJECT_TYPE is explicitly set in .craftsmanship-test.sh.
</HARD-GATE>

## Core principle

Comments are a last resort. If naming, decomposition, or types can say it, the code should. A comment must earn its place by saying something the code cannot say.

## Iron law

No comment ships without a `CRAFT GATE: KEEP` verdict.

A comment is STRIP by default. The burden of justification is on the comment, not on its absence.

## When the gate fires

When the PreToolUse hook fires on `Edit`, `Write`, or `MultiEdit` of a source-code file in a CODE_PROJECT, invoke `craftsmanship-test:craft-gate` via the Skill tool. Emit one verdict per new or modified comment, on its own line:

- `CRAFT GATE: KEEP`
- `CRAFT GATE: STRIP — <rule number>`
- `CRAFT GATE: REWRITE — <replacement comment text>`

Apply the verdict to the diff before the tool call completes.

## The eight rules in summary

STRIP: paraphrase, language basics, section dividers, scope-end labels, commented-out code.
KEEP: public-API contracts, real why (non-obvious constraint, workaround, surprising business rule).
REWRITE: partially why but mostly what — trim to the why-only part.

The full skill at `skills/craft-gate/SKILL.md` is the source of truth for the rules.
````

- [ ] **Step 2: Verify the file is valid markdown with the expected frontmatter**

Run:
```bash
head -5 skills/using-craftsmanship-test/SKILL.md
```
Expected: lines 1, 5 are `---`. Line 2 starts with `name: using-craftsmanship-test`.

- [ ] **Step 3: Commit**

```bash
git add skills/using-craftsmanship-test/SKILL.md
git commit -m "feat: add using-craftsmanship-test bootstrap skill"
```

---

## Task 2: Project-type detector helper

**Files:**
- Create: `hooks/lib/detect-project-type.sh`
- Create: `tests/test_detect_project_type.sh`

- [ ] **Step 1: Write the failing test file**

Create `tests/test_detect_project_type.sh`:

```bash
#!/usr/bin/env bash
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PLUGIN_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

# shellcheck source=/dev/null
source "${PLUGIN_ROOT}/hooks/lib/detect-project-type.sh"

PASS=0
FAIL=0

assert_eq() {
  local expected="$1" actual="$2" name="$3"
  if [ "$expected" = "$actual" ]; then
    printf 'PASS %s\n' "$name"
    PASS=$((PASS + 1))
  else
    printf 'FAIL %s: expected "%s", got "%s"\n' "$name" "$expected" "$actual" >&2
    FAIL=$((FAIL + 1))
  fi
}

run_case() {
  local dir="$1"; shift
  craft_detect_project_type "$dir" | tr -d '\n'
}

# 1. Default empty dir
d=$(mktemp -d); unset CRAFTSMANSHIP_PROJECT_TYPE
assert_eq "CODE_PROJECT" "$(run_case "$d")" "default empty dir is CODE_PROJECT"
rm -rf "$d"

# 2. _quarto.yml triggers SUPPRESS
d=$(mktemp -d); touch "$d/_quarto.yml"; unset CRAFTSMANSHIP_PROJECT_TYPE
assert_eq "SUPPRESS" "$(run_case "$d")" "_quarto.yml triggers SUPPRESS"
rm -rf "$d"

# 3. book.toml triggers SUPPRESS
d=$(mktemp -d); touch "$d/book.toml"; unset CRAFTSMANSHIP_PROJECT_TYPE
assert_eq "SUPPRESS" "$(run_case "$d")" "book.toml triggers SUPPRESS"
rm -rf "$d"

# 4. _bookdown.yml triggers SUPPRESS
d=$(mktemp -d); touch "$d/_bookdown.yml"; unset CRAFTSMANSHIP_PROJECT_TYPE
assert_eq "SUPPRESS" "$(run_case "$d")" "_bookdown.yml triggers SUPPRESS"
rm -rf "$d"

# 5. _config.yml with jupyter-book -> SUPPRESS
d=$(mktemp -d); printf 'theme: jupyter-book\n' > "$d/_config.yml"; unset CRAFTSMANSHIP_PROJECT_TYPE
assert_eq "SUPPRESS" "$(run_case "$d")" "_config.yml with jupyter-book triggers SUPPRESS"
rm -rf "$d"

# 6. _config.yml without educational marker -> CODE_PROJECT
d=$(mktemp -d); printf 'theme: minima\n' > "$d/_config.yml"; unset CRAFTSMANSHIP_PROJECT_TYPE
assert_eq "CODE_PROJECT" "$(run_case "$d")" "_config.yml without marker is CODE_PROJECT"
rm -rf "$d"

# 7. mkdocs.yml without source dir -> SUPPRESS
d=$(mktemp -d); touch "$d/mkdocs.yml"; unset CRAFTSMANSHIP_PROJECT_TYPE
assert_eq "SUPPRESS" "$(run_case "$d")" "mkdocs.yml without src/ triggers SUPPRESS"
rm -rf "$d"

# 8. mkdocs.yml WITH src/ -> CODE_PROJECT
d=$(mktemp -d); touch "$d/mkdocs.yml"; mkdir -p "$d/src"; touch "$d/src/main.py"
unset CRAFTSMANSHIP_PROJECT_TYPE
assert_eq "CODE_PROJECT" "$(run_case "$d")" "mkdocs.yml with src/ is CODE_PROJECT"
rm -rf "$d"

# 9. notebook-dominant (5 ipynb, 1 py) -> SUPPRESS
d=$(mktemp -d)
for i in 1 2 3 4 5; do touch "$d/lesson_${i}.ipynb"; done
touch "$d/util.py"
unset CRAFTSMANSHIP_PROJECT_TYPE
assert_eq "SUPPRESS" "$(run_case "$d")" "notebook-dominant repo triggers SUPPRESS"
rm -rf "$d"

# 10. code-dominant (1 ipynb, 5 py) -> CODE_PROJECT
d=$(mktemp -d)
touch "$d/notebook.ipynb"
for i in 1 2 3 4 5; do touch "$d/file_${i}.py"; done
unset CRAFTSMANSHIP_PROJECT_TYPE
assert_eq "CODE_PROJECT" "$(run_case "$d")" "code-dominant with one notebook is CODE_PROJECT"
rm -rf "$d"

# 11. override=suppress -> SUPPRESS
d=$(mktemp -d); touch "$d/main.py"; CRAFTSMANSHIP_PROJECT_TYPE=suppress
assert_eq "SUPPRESS" "$(run_case "$d")" "override=suppress wins"
unset CRAFTSMANSHIP_PROJECT_TYPE; rm -rf "$d"

# 12. override=code-project on educational -> CODE_PROJECT
d=$(mktemp -d); touch "$d/_quarto.yml"; CRAFTSMANSHIP_PROJECT_TYPE=code-project
assert_eq "CODE_PROJECT" "$(run_case "$d")" "override=code-project wins on educational"
unset CRAFTSMANSHIP_PROJECT_TYPE; rm -rf "$d"

# 13. override=auto uses heuristics
d=$(mktemp -d); touch "$d/main.py"; CRAFTSMANSHIP_PROJECT_TYPE=auto
assert_eq "CODE_PROJECT" "$(run_case "$d")" "override=auto uses heuristics"
unset CRAFTSMANSHIP_PROJECT_TYPE; rm -rf "$d"

# 14. invalid override falls through to heuristics
d=$(mktemp -d); touch "$d/main.py"; CRAFTSMANSHIP_PROJECT_TYPE=garbage
assert_eq "CODE_PROJECT" "$(run_case "$d")" "invalid override falls through"
unset CRAFTSMANSHIP_PROJECT_TYPE; rm -rf "$d"

if [ "$FAIL" -eq 0 ]; then
  printf 'detect-project-type: %d/%d passed\n' "$PASS" "$((PASS+FAIL))"
  exit 0
else
  printf 'detect-project-type: %d/%d passed (FAIL)\n' "$PASS" "$((PASS+FAIL))" >&2
  exit 1
fi
```

Make it executable:

```bash
chmod +x tests/test_detect_project_type.sh
```

- [ ] **Step 2: Run the test to verify it fails**

```bash
bash tests/test_detect_project_type.sh
```
Expected: FAIL with `source: hooks/lib/detect-project-type.sh: No such file or directory` (helper does not exist yet).

- [ ] **Step 3: Implement the detector helper**

Create `hooks/lib/detect-project-type.sh`:

```bash
#!/usr/bin/env bash
# Project-type detector for craftsmanship-test plugin.
#
# Returns CODE_PROJECT or SUPPRESS to stdout. Denylist semantics:
# default CODE_PROJECT; SUPPRESS only on strong educational signals.
#
# Source this file, then call: craft_detect_project_type <project_dir>

_craft_is_educational() {
  local dir="$1"

  for f in _quarto.yml book.toml _bookdown.yml; do
    if [ -f "$dir/$f" ]; then
      return 0
    fi
  done

  if [ -f "$dir/_config.yml" ] && grep -qE 'jupyter-book|bookdown' "$dir/_config.yml" 2>/dev/null; then
    return 0
  fi

  if [ -f "$dir/mkdocs.yml" ]; then
    local has_source=false
    for d in src lib app cmd pkg internal; do
      if [ -d "$dir/$d" ]; then
        has_source=true
        break
      fi
    done
    if ! $has_source; then
      return 0
    fi
  fi

  local notebook_count source_count
  notebook_count=$(find "$dir" -maxdepth 2 -name '*.ipynb' -type f 2>/dev/null | wc -l | tr -d ' ')
  source_count=$(find "$dir" -maxdepth 2 -type f \( \
    -name '*.py' -o -name '*.pyi' \
    -o -name '*.ts' -o -name '*.tsx' -o -name '*.js' -o -name '*.jsx' \
    -o -name '*.mjs' -o -name '*.cjs' \
    -o -name '*.go' -o -name '*.rs' \
    -o -name '*.java' -o -name '*.kt' -o -name '*.scala' \
    -o -name '*.rb' -o -name '*.swift' \
    -o -name '*.cpp' -o -name '*.cc' -o -name '*.c' -o -name '*.h' -o -name '*.hpp' \
    -o -name '*.cs' -o -name '*.php' \
    -o -name '*.ex' -o -name '*.exs' \
    \) 2>/dev/null | wc -l | tr -d ' ')

  if [ "$notebook_count" -gt 0 ] && [ "$notebook_count" -gt $((source_count * 2)) ]; then
    return 0
  fi

  return 1
}

craft_detect_project_type() {
  local dir="${1:?dir required}"

  case "${CRAFTSMANSHIP_PROJECT_TYPE:-auto}" in
    code-project) printf 'CODE_PROJECT\n'; return 0 ;;
    suppress)     printf 'SUPPRESS\n';     return 0 ;;
    auto|"")      : ;;
    *) ;;
  esac

  if _craft_is_educational "$dir"; then
    printf 'SUPPRESS\n'
    return 0
  fi

  printf 'CODE_PROJECT\n'
}
```

- [ ] **Step 4: Run the test to verify it passes**

```bash
bash tests/test_detect_project_type.sh
```
Expected: PASS, `detect-project-type: 14/14 passed`.

- [ ] **Step 5: Commit**

```bash
git add hooks/lib/detect-project-type.sh tests/test_detect_project_type.sh
git commit -m "feat: add project-type detector with educational denylist"
```

---

## Task 3: SessionStart hook + hooks.json wiring

**Files:**
- Create: `hooks/session-start`
- Create: `tests/test_session_start.sh`
- Modify: `hooks/hooks.json`

- [ ] **Step 1: Write the failing test file**

Create `tests/test_session_start.sh`:

```bash
#!/usr/bin/env bash
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PLUGIN_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

PASS=0
FAIL=0

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
d=$(mktemp -d); touch "$d/main.py"
unset CRAFTSMANSHIP_PROJECT_TYPE
out=$(CLAUDE_PROJECT_DIR="$d" CLAUDE_PLUGIN_ROOT="$PLUGIN_ROOT" \
  bash "${PLUGIN_ROOT}/hooks/session-start" </dev/null)
assert_contains "craftsmanship-test plugin is active" "$out" "session-start emits reminder on code project"
assert_contains "Iron law" "$out" "session-start inlines using- skill body"
rm -rf "$d"

# 2. Educational project emits silent payload
d=$(mktemp -d); touch "$d/_quarto.yml"
unset CRAFTSMANSHIP_PROJECT_TYPE
out=$(CLAUDE_PROJECT_DIR="$d" CLAUDE_PLUGIN_ROOT="$PLUGIN_ROOT" \
  bash "${PLUGIN_ROOT}/hooks/session-start" </dev/null)
assert_not_contains "craftsmanship-test plugin is active" "$out" "session-start silent on educational project"
rm -rf "$d"

# 3. Override=suppress silences a code project
d=$(mktemp -d); touch "$d/main.py"
printf 'CRAFTSMANSHIP_PROJECT_TYPE=suppress\n' > "$d/.craftsmanship-test.sh"
out=$(CLAUDE_PROJECT_DIR="$d" CLAUDE_PLUGIN_ROOT="$PLUGIN_ROOT" \
  bash "${PLUGIN_ROOT}/hooks/session-start" </dev/null)
assert_not_contains "craftsmanship-test plugin is active" "$out" "override=suppress silences code project"
rm -rf "$d"

# 4. Override=code-project enables on educational
d=$(mktemp -d); touch "$d/_quarto.yml"
printf 'CRAFTSMANSHIP_PROJECT_TYPE=code-project\n' > "$d/.craftsmanship-test.sh"
out=$(CLAUDE_PROJECT_DIR="$d" CLAUDE_PLUGIN_ROOT="$PLUGIN_ROOT" \
  bash "${PLUGIN_ROOT}/hooks/session-start" </dev/null)
assert_contains "craftsmanship-test plugin is active" "$out" "override=code-project enables on educational"
rm -rf "$d"

# 5. Malformed override file does not block reminder emission
d=$(mktemp -d); touch "$d/main.py"
printf 'CRAFTSMANSHIP_PROJECT_TYPE=suppress\n@@@ syntax garbage\n' > "$d/.craftsmanship-test.sh"
out=$(CLAUDE_PROJECT_DIR="$d" CLAUDE_PLUGIN_ROOT="$PLUGIN_ROOT" \
  bash "${PLUGIN_ROOT}/hooks/session-start" </dev/null)
assert_contains "craftsmanship-test plugin is active" "$out" "malformed override is ignored, reminder still fires"
rm -rf "$d"

if [ "$FAIL" -eq 0 ]; then
  printf 'session-start: %d/%d passed\n' "$PASS" "$((PASS+FAIL))"; exit 0
else
  printf 'session-start: %d/%d passed (FAIL)\n' "$PASS" "$((PASS+FAIL))" >&2; exit 1
fi
```

Make it executable:
```bash
chmod +x tests/test_session_start.sh
```

- [ ] **Step 2: Run the test to verify it fails**

```bash
bash tests/test_session_start.sh
```
Expected: FAIL with hook script not found / not executable.

- [ ] **Step 3: Implement the hook**

Create `hooks/session-start`:

```bash
#!/usr/bin/env bash
# SessionStart hook for craftsmanship-test plugin.
# Emits the using-craftsmanship-test skill body as additionalContext on
# CODE_PROJECT verdicts; emits silent on SUPPRESS.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PLUGIN_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

# shellcheck source=/dev/null
source "${PLUGIN_ROOT}/config.sh"

if [ -n "${CLAUDE_PROJECT_DIR:-}" ] && [ -f "${CLAUDE_PROJECT_DIR}/.craftsmanship-test.sh" ]; then
  override="${CLAUDE_PROJECT_DIR}/.craftsmanship-test.sh"
  if bash -n "$override" 2>/dev/null; then
    # shellcheck source=/dev/null
    source "$override"
  fi
fi

# shellcheck source=/dev/null
source "${SCRIPT_DIR}/lib/detect-project-type.sh"

verdict="$(craft_detect_project_type "${CLAUDE_PROJECT_DIR:-$PWD}")"
verdict="${verdict//$'\n'/}"

if [ "$verdict" != "CODE_PROJECT" ]; then
  printf '' | bash "${SCRIPT_DIR}/lib/emit-context.sh" SessionStart
  exit 0
fi

skill_body=$(cat "${PLUGIN_ROOT}/skills/using-craftsmanship-test/SKILL.md")

payload=$(cat <<EOF
<EXTREMELY_IMPORTANT>
The craftsmanship-test plugin is active.

HARD RULE: When you write or modify a comment in source code, invoke the \`craftsmanship-test:craft-gate\` skill via the Skill tool and emit one verdict per comment (CRAFT GATE: KEEP / STRIP — <rule> / REWRITE — <text>) before the edit completes.

If the verdict is STRIP, delete the comment from the diff. If REWRITE, replace it with the verdict's replacement text. Do not ship comments that have not earned a KEEP verdict.

Below is the full content of your \`craftsmanship-test:using-craftsmanship-test\` bootstrap skill, which names the gate triggers. For the gate itself, invoke the \`craftsmanship-test:craft-gate\` skill.

Comments are a last resort. If the code can say it, the code should.

${skill_body}
</EXTREMELY_IMPORTANT>
EOF
)

printf '%s' "$payload" | bash "${SCRIPT_DIR}/lib/emit-context.sh" SessionStart
```

Make it executable:
```bash
chmod +x hooks/session-start
```

- [ ] **Step 4: Wire SessionStart into hooks.json**

Replace the contents of `hooks/hooks.json` with:

```json
{
  "hooks": {
    "SessionStart": [
      {
        "matcher": "startup|clear|compact",
        "hooks": [
          {
            "type": "command",
            "command": "\"${CLAUDE_PLUGIN_ROOT}/hooks/session-start\"",
            "async": false
          }
        ]
      }
    ],
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

Verify it's valid JSON:
```bash
python3 -c "import json; json.load(open('hooks/hooks.json'))"
```
Expected: silent success.

- [ ] **Step 5: Run the test to verify it passes**

```bash
bash tests/test_session_start.sh
```
Expected: PASS, `session-start: 5/5 passed`.

- [ ] **Step 6: Commit**

```bash
git add hooks/session-start hooks/hooks.json tests/test_session_start.sh
git commit -m "feat: add SessionStart auto-load gated on project-type verdict"
```

---

## Task 4: PreToolUse verdict gate

**Files:**
- Modify: `hooks/pre-tool-use`
- Modify: `tests/test_pre_tool_use.sh`

- [ ] **Step 1: Add a failing test case for SUPPRESS-verdict silence**

Open `tests/test_pre_tool_use.sh`. Append the following block immediately before the final pass/fail summary block (the `if [ "$FAIL" -eq 0 ]; then` line):

```bash
# Educational project: pre-tool-use exits silent even on a source-file edit
d=$(mktemp -d); touch "$d/_quarto.yml"
unset CRAFTSMANSHIP_PROJECT_TYPE
out=$(CLAUDE_PROJECT_DIR="$d" CLAUDE_PLUGIN_ROOT="$PLUGIN_ROOT" \
  bash "${PLUGIN_ROOT}/hooks/pre-tool-use" \
  <<<'{"tool_name":"Edit","tool_input":{"file_path":"main.py"}}')
if printf '%s' "$out" | grep -qF "CRAFT GATE AUTO-TRIGGERED"; then
  printf 'FAIL pre-tool-use silent on SUPPRESS verdict: reminder leaked\n' >&2
  FAIL=$((FAIL+1))
else
  printf 'PASS pre-tool-use silent on SUPPRESS verdict\n'
  PASS=$((PASS+1))
fi
rm -rf "$d"

# Override=suppress silences edit on a real code file
d=$(mktemp -d); touch "$d/main.py"
printf 'CRAFTSMANSHIP_PROJECT_TYPE=suppress\n' > "$d/.craftsmanship-test.sh"
out=$(CLAUDE_PROJECT_DIR="$d" CLAUDE_PLUGIN_ROOT="$PLUGIN_ROOT" \
  bash "${PLUGIN_ROOT}/hooks/pre-tool-use" \
  <<<'{"tool_name":"Edit","tool_input":{"file_path":"main.py"}}')
if printf '%s' "$out" | grep -qF "CRAFT GATE AUTO-TRIGGERED"; then
  printf 'FAIL pre-tool-use override=suppress: reminder leaked\n' >&2
  FAIL=$((FAIL+1))
else
  printf 'PASS pre-tool-use override=suppress silences\n'
  PASS=$((PASS+1))
fi
rm -rf "$d"
```

- [ ] **Step 2: Run the test to verify the new case fails**

```bash
bash tests/test_pre_tool_use.sh
```
Expected: the two new cases FAIL with `reminder leaked` (the verdict gate doesn't exist yet).

- [ ] **Step 3: Add the verdict gate to pre-tool-use**

Open `hooks/pre-tool-use`. Find this block (around line 21):

```bash
# shellcheck source=/dev/null
source "${SCRIPT_DIR}/lib/detect-source-file.sh"
```

Replace it with:

```bash
# shellcheck source=/dev/null
source "${SCRIPT_DIR}/lib/detect-project-type.sh"

verdict="$(craft_detect_project_type "${CLAUDE_PROJECT_DIR:-$PWD}")"
verdict="${verdict//$'\n'/}"

if [ "$verdict" != "CODE_PROJECT" ]; then
  printf '' | bash "${SCRIPT_DIR}/lib/emit-context.sh" PreToolUse
  exit 0
fi

# shellcheck source=/dev/null
source "${SCRIPT_DIR}/lib/detect-source-file.sh"
```

- [ ] **Step 4: Run the test to verify all cases pass**

```bash
bash tests/test_pre_tool_use.sh
```
Expected: all existing cases plus the two new ones PASS.

- [ ] **Step 5: Run the full test suite**

```bash
bash tests/run-tests.sh
```
Expected: `ALL TESTS PASSED`.

- [ ] **Step 6: Commit**

```bash
git add hooks/pre-tool-use tests/test_pre_tool_use.sh
git commit -m "feat: gate pre-tool-use on project-type verdict"
```

---

## Task 5: Remove `claude-md-snippet.md` and update docs

**Files:**
- Delete: `claude-md-snippet.md`
- Modify: `README.md`
- Modify: `CLAUDE.md` (contributor notes)

- [ ] **Step 1: Delete the snippet file**

```bash
git rm claude-md-snippet.md
```

- [ ] **Step 2: Update README.md install steps**

Open `README.md`. Find the Quickstart code block:

````
```bash
claude plugins marketplace add /path/to/craft-gate
claude plugins install craftsmanship-test@craftsmanship-test-local

# from inside the project you want the gate active in:
cat /path/to/craft-gate/claude-md-snippet.md >> ./CLAUDE.md
```

The snippet goes in the project's `CLAUDE.md`, not the global one. The plugin is per-project; the rules should be too.

If your path has spaces, symlink it first.
````

Replace with:

````
```bash
claude plugins marketplace add /path/to/craft-gate
claude plugins install craftsmanship-test@craftsmanship-test-local
```

The plugin loads its rules into context automatically at session start. There is no manual paste step.

By default the gate runs on any project that looks like a code project. It stays silent on educational projects (Quarto books, mdBook, Jupyter Book, mkdocs-only sites, notebook-dominant repos). Override per-project by creating a `.craftsmanship-test.sh` at the project root with `CRAFTSMANSHIP_PROJECT_TYPE=code-project` (force enable) or `CRAFTSMANSHIP_PROJECT_TYPE=suppress` (force silent).

If your path has spaces, symlink it first.

If you previously pasted the snippet into your project's `CLAUDE.md`, remove it. The rules now load via SessionStart.
````

Update the "How it works" section's first bullet. Find:

```
1. CLAUDE.md snippet (passive). A short markdown block in your project's `CLAUDE.md` (the one at the project root, not the global one). Claude self-suppresses bad comments before authoring them.
```

Replace with:

```
1. SessionStart auto-load. A bash hook reads the `using-craftsmanship-test` skill body at session start and emits it as system context. Claude sees the rules every session, no manual paste. The hook silences itself on projects the detector classifies as educational.
```

- [ ] **Step 3: Update CLAUDE.md (contributor notes)**

Open `CLAUDE.md`. Find the "Layout" section. Replace these lines:

```
- `skills/craft-gate/SKILL.md` — the imperative-judgment gate skill (KEEP / STRIP / REWRITE per comment)
- `hooks/hooks.json` — declares PreToolUse matcher
- `hooks/pre-tool-use` — bash entry point: extracts tool_name + file_path via inline python3, checks file extension, emits reminder
- `hooks/lib/detect-source-file.sh` — `craft_path_triggers` and `_glob_to_regex` helpers (ported from channelle-test)
- `hooks/lib/emit-context.sh` — JSON-safe context emitter (ported verbatim from channelle-test)
- `config.sh` — default `CRAFT_SOURCE_GLOBS` (override per-project via `.craftsmanship-test.sh`)
- `claude-md-snippet.md` — markdown the user pastes into their CLAUDE.md for passive reinforcement
```

With:

```
- `skills/craft-gate/SKILL.md` — the imperative-judgment gate skill (KEEP / STRIP / REWRITE per comment)
- `skills/using-craftsmanship-test/SKILL.md` — bootstrap skill, inlined into SessionStart payload
- `hooks/hooks.json` — declares SessionStart and PreToolUse matchers
- `hooks/session-start` — bash entry: emits the using- skill body if project-type detector returns CODE_PROJECT, silent otherwise
- `hooks/pre-tool-use` — bash entry: gates on project-type verdict, then on file extension, then emits reminder
- `hooks/lib/detect-project-type.sh` — `craft_detect_project_type` with educational denylist (ported from channelle-test pattern)
- `hooks/lib/detect-source-file.sh` — `craft_path_triggers` and `_glob_to_regex` helpers
- `hooks/lib/emit-context.sh` — JSON-safe context emitter
- `config.sh` — default `CRAFT_SOURCE_GLOBS` (override per-project via `.craftsmanship-test.sh`, which also recognises `CRAFTSMANSHIP_PROJECT_TYPE`)
```

Find the "Architecture notes" section. Replace these lines:

```
Three layers, deliberately separated:

1. **Passive (CLAUDE.md snippet)** — rules in system context. Free per turn. Survives compaction.
2. **Trigger (PreToolUse hook)** — fires on source-file edits. Purely syntactic (extension match), no JSON content parsing. Dumb on purpose.
3. **Judgment (craft-gate skill)** — LLM applies imperative rules to its own comments. Smart on purpose.

The hook does NOT detect bad comments. It detects that Claude is editing a source file. Claude itself checks for comment presence and invokes the skill if needed.
```

With:

```
Three layers, deliberately separated:

1. **Auto-load (SessionStart hook)** — emits the `using-craftsmanship-test` skill body as system context every session, gated on the project-type detector. Replaces the manual snippet-paste flow.
2. **Trigger (PreToolUse hook)** — gates on project-type verdict first, then file extension. Purely syntactic; no JSON content parsing in the hook itself.
3. **Judgment (craft-gate skill)** — LLM applies imperative rules to its own comments. Smart on purpose.

The hook does NOT detect bad comments. It detects that Claude is editing a source file in a code project. Claude itself checks for comment presence and invokes the skill if needed.

The project-type detector uses denylist semantics: default `CODE_PROJECT`, only `SUPPRESS` on strong educational signals (`_quarto.yml`, `book.toml`, `_bookdown.yml`, `_config.yml` with jupyter-book/bookdown markers, `mkdocs.yml` without a source dir, or notebook-dominant ratio). Override via `CRAFTSMANSHIP_PROJECT_TYPE` in the project's `.craftsmanship-test.sh`.
```

Find the "Sister plugin" section. Replace its bullet list:

```
Mirrors `channelle-test`. Shape is identical except:
- No SessionStart auto-load (replaced by CLAUDE.md snippet)
- No UserPromptSubmit (purely syntactic trigger)
- One skill instead of two (no bootstrap)
- Source-file globs instead of customer-view globs
- Verdict vocabulary: KEEP / STRIP / REWRITE per comment instead of SHIP / REWORK / DROP per design decision
```

With:

```
Mirrors `channelle-test`. Shape is identical except:
- No UserPromptSubmit (purely syntactic trigger)
- Two skills (`craft-gate` for judgment, `using-craftsmanship-test` for bootstrap)
- Source-file globs instead of customer-view globs
- Project-type detector uses denylist semantics (default `CODE_PROJECT`, suppress on educational signals) instead of allowlist
- Verdict vocabulary: `CODE_PROJECT` / `SUPPRESS` for project-type and `KEEP` / `STRIP` / `REWRITE` per comment instead of `PUBLIC_APP` / `SUPPRESS` and `SHIP` / `REWORK` / `DROP`
```

- [ ] **Step 4: Run the full test suite**

```bash
bash tests/run-tests.sh
```
Expected: `ALL TESTS PASSED`.

- [ ] **Step 5: Commit**

```bash
git add README.md CLAUDE.md
git commit -m "docs: drop manual-paste install step, document project-type detector"
```

---

## Task 6: Final integration check

**Files:** none modified — verification only.

- [ ] **Step 1: Run the full test suite end-to-end**

```bash
bash tests/run-tests.sh
```
Expected: `ALL TESTS PASSED`. Every test file (`test_marketplace.sh`, `test_emit_context.sh`, `test_detect_source_file.sh`, `test_pre_tool_use.sh`, `test_detect_project_type.sh`, `test_session_start.sh`) reports its own pass count and the runner reports all green.

- [ ] **Step 2: Sanity-check the install surface**

Confirm the README's quickstart no longer mentions `claude-md-snippet.md`:

```bash
grep -F 'claude-md-snippet' README.md
```
Expected: no output (file deleted, references removed).

Confirm the snippet file is gone:

```bash
ls claude-md-snippet.md 2>&1 | head -1
```
Expected: `ls: claude-md-snippet.md: No such file or directory`.

Confirm hooks.json has both matchers:

```bash
python3 -c "import json; d=json.load(open('hooks/hooks.json')); print(sorted(d['hooks'].keys()))"
```
Expected: `['PreToolUse', 'SessionStart']`.

- [ ] **Step 3: No commit** — this task only verifies. If any step fails, return to the task that introduced the regression.
