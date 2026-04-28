# Craftsmanship-test auto-load design

**Goal:** Eliminate the manual `cat claude-md-snippet.md >> ./CLAUDE.md` install step. Rules load automatically per session via a SessionStart hook. A project-type detector decides per-project whether the gate is active, with an educational-content denylist and an explicit override.

**Architecture:** Three layers, mirrored from `channelle-test` with denylist semantics in place of allowlist. SessionStart hook injects the rules; project-type detector gates both the SessionStart payload and the existing PreToolUse hook; explicit `CRAFTSMANSHIP_PROJECT_TYPE` override always wins.

**Tech stack:** Bash 3.2+ (macOS default), inline `python3 -c` for JSON parsing, no other dependencies.

---

## Why this exists

Today the install path is:

```bash
claude plugins marketplace add /path/to/craft-gate
claude plugins install craftsmanship-test@craftsmanship-test-local
cat /path/to/craft-gate/claude-md-snippet.md >> ./CLAUDE.md   # ← manual, per-project, easy to forget
```

The third step is friction and it's stateful: snippet drift if the plugin updates. Channelle-test removed this with SessionStart auto-load. We're porting that pattern.

We're also adding the project-type detector that channelle-test ships with, so the rules don't fire on projects where comment narration is the point (notebooks, Quarto books, mkdocs sites). Default behaviour: enabled. Educational projects: silent.

---

## Layer A. SessionStart auto-load

### Skill: `skills/using-craftsmanship-test/SKILL.md`

Replaces `claude-md-snippet.md` outright. Same content, repurposed as a Claude Code skill so the SessionStart hook can read its body and inline it.

Frontmatter:

```yaml
---
name: using-craftsmanship-test
description: Bootstrap context for the Craftsmanship Test plugin. Auto-loaded at session start. Defers all gating to the project-type detector and craftsmanship-test:craft-gate skill. Not a runtime-triggered skill — use craftsmanship-test:craft-gate for the actual gate.
---
```

Body:

```markdown
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
```

### Hook: `hooks/session-start`

Bash entry. Mirrors `channelle_test/hooks/session-start` exactly except for the skill path and the preamble text.

Behaviour:
1. Resolve `PLUGIN_ROOT` (the plugin directory).
2. Source `hooks/lib/emit-context.sh` (existing helper, ported in iteration 1).
3. Source `config.sh` and the optional project override (`.craftsmanship-test.sh`).
4. Source `hooks/lib/detect-project-type.sh`.
5. Run `craft_detect_project_type "${CLAUDE_PROJECT_DIR:-$PWD}"`.
6. If verdict is not `CODE_PROJECT`, call `emit_silent` and exit 0. **No rules in context for educational projects.**
7. Otherwise, read `skills/using-craftsmanship-test/SKILL.md` body, wrap it in the preamble below, and emit via `emit-context.sh`.

Preamble template (the wrapping that goes around the inlined skill body):

```
<EXTREMELY_IMPORTANT>
The craftsmanship-test plugin is active.

HARD RULE: When you write or modify a comment in source code, invoke the `craftsmanship-test:craft-gate` skill via the Skill tool and emit one verdict per comment (CRAFT GATE: KEEP / STRIP — <rule> / REWRITE — <text>) before the edit completes.

If the verdict is STRIP, delete the comment from the diff. If REWRITE, replace it with the verdict's replacement text. Do not ship comments that have not earned a KEEP verdict.

Below is the full content of your `craftsmanship-test:using-craftsmanship-test` bootstrap skill, which names the gate triggers. For the gate itself, invoke the `craftsmanship-test:craft-gate` skill.

Comments are a last resort. If the code can say it, the code should.

[SKILL.md body inlined here]
</EXTREMELY_IMPORTANT>
```

### Hook config: `hooks/hooks.json`

Add a SessionStart matcher alongside the existing PreToolUse matcher.

```json
{
  "hooks": {
    "SessionStart": [
      {
        "matcher": "startup|clear|compact",
        "hooks": [
          {
            "type": "command",
            "command": "${CLAUDE_PLUGIN_ROOT}/hooks/session-start"
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
            "command": "${CLAUDE_PLUGIN_ROOT}/hooks/pre-tool-use"
          }
        ]
      }
    ]
  }
}
```

---

## Layer B. Project-type detector

### Helper: `hooks/lib/detect-project-type.sh`

Defines `craft_detect_project_type <dir>` and emits `CODE_PROJECT` or `SUPPRESS` to stdout.

Verdict resolution order (first match wins):

1. **Explicit override.** If `CRAFTSMANSHIP_PROJECT_TYPE` is set:
   - `code-project` → emit `CODE_PROJECT`, return.
   - `suppress` → emit `SUPPRESS`, return.
   - `auto` or empty → fall through.
   - Any other value → fall through (auto).

2. **Educational denylist.** If any of the following at `<dir>` (project root, not recursive):
   - `_quarto.yml` exists.
   - `book.toml` exists.
   - `_bookdown.yml` exists.
   - `_config.yml` exists AND `grep -qE 'jupyter-book|bookdown' _config.yml` matches.
   - `mkdocs.yml` exists AND none of `src/`, `lib/`, `app/`, `cmd/`, `pkg/`, `internal/` exist.
   - Notebook-dominant: count of `.ipynb` files at `<dir>` and one level deep is more than twice the count of files matching `CRAFT_SOURCE_GLOBS` at the same scope.

   → emit `SUPPRESS`, return.

3. **Default.** Emit `CODE_PROJECT`.

Notes:
- The notebook count uses `find <dir> -maxdepth 2 -name '*.ipynb'` to bound cost on large repos.
- The source-file count reuses the glob-to-regex helper from `hooks/lib/detect-source-file.sh` so the heuristic stays consistent with the file-extension gate.
- Helper is sourceable: defines functions, returns from main function, no top-level side effects.

### Override file: `.craftsmanship-test.sh`

Lives at project root. Already supported in the existing hook for the `CRAFT_SOURCE_GLOBS` array. Adds `CRAFTSMANSHIP_PROJECT_TYPE` to the recognised overrides.

Example:

```bash
# Force-enable on a project the detector wrongly classifies as educational
CRAFTSMANSHIP_PROJECT_TYPE=code-project

# Or force-disable
CRAFTSMANSHIP_PROJECT_TYPE=suppress

# Or disable the gate entirely without changing project type
CRAFT_SOURCE_GLOBS=()
```

The override file is sourced inside `bash -n` syntax check, same as today, so a malformed override doesn't take down all edits.

---

## Layer C. PreToolUse verdict gate

### Modify: `hooks/pre-tool-use`

Insert the verdict gate after `config.sh` and override sourcing, before the file-extension match.

```bash
source "${PLUGIN_ROOT}/hooks/lib/detect-project-type.sh"

verdict="$(craft_detect_project_type "${CLAUDE_PROJECT_DIR:-$PWD}")"
if [ "$verdict" != "CODE_PROJECT" ]; then
  emit_silent
  exit 0
fi

# existing file-extension gate continues from here
```

`emit_silent` is the existing helper from `hooks/lib/emit-context.sh` (emits `{"hookSpecificOutput": {"hookEventName": "PreToolUse", "additionalContext": ""}}`).

The file-extension gate stays in place. Defence in depth: even on a CODE_PROJECT verdict, the hook still skips non-source-file edits.

---

## File deltas

**Add:**
- `skills/using-craftsmanship-test/SKILL.md` — bootstrap skill (content from `claude-md-snippet.md`, restructured).
- `hooks/session-start` — bash entry, mirrors channelle's session-start.
- `hooks/lib/detect-project-type.sh` — detector helper.
- `tests/test_session_start.sh` — fixtures: code project (asserts reminder emitted), educational project (asserts silent), override force-suppress (asserts silent), override force-enable (asserts reminder).
- `tests/test_detect_project_type.sh` — fixtures for each denylist signal, override behaviour, default-on case.
- `tests/fixtures/educational_project/` — minimal fixture with `_quarto.yml`.
- `tests/fixtures/notebook_project/` — minimal fixture with three `.ipynb` files and one `.py`.

**Modify:**
- `hooks/hooks.json` — add `SessionStart` block.
- `hooks/pre-tool-use` — verdict gate before extension gate.
- `config.sh` — document `CRAFTSMANSHIP_PROJECT_TYPE=auto` default at top of file.
- `tests/test_pre_tool_use.sh` — add cases asserting silent exit on `SUPPRESS` verdict.
- `README.md` — drop step 3 (`cat snippet >> CLAUDE.md`); add a paragraph on the detector + override.
- `CLAUDE.md` (contributor notes) — update the "Architecture notes" section: SessionStart auto-load, project-type detector, override file expanded.

**Delete:**
- `claude-md-snippet.md` — content folds into the using-craftsmanship-test skill.

---

## Test strategy

Same shell-script pattern as today's `tests/run-tests.sh`. Each new test sets up a temp directory fixture, sets env vars (`CLAUDE_PROJECT_DIR`, `CRAFTSMANSHIP_PROJECT_TYPE`), invokes the hook or detector, and asserts on stdout / exit code.

Coverage matrix:

| Scenario | SessionStart | PreToolUse | Detector |
|---|---|---|---|
| Plain Python project, no override | reminder | gate fires | CODE_PROJECT |
| Plain Python project, override=suppress | silent | silent | SUPPRESS |
| Plain Python project, override=code-project | reminder | gate fires | CODE_PROJECT |
| Quarto book (has `_quarto.yml`) | silent | silent | SUPPRESS |
| Quarto book + override=code-project | reminder | gate fires | CODE_PROJECT |
| Notebook-dominant repo (5 `.ipynb`, 1 `.py`) | silent | silent | SUPPRESS |
| mkdocs site without `src/` | silent | silent | SUPPRESS |
| mkdocs site with `src/` | reminder | gate fires | CODE_PROJECT |
| Malformed override file | reminder (not fatal) | gate fires (not fatal) | CODE_PROJECT |

Plus the existing pre-tool-use coverage stays green: source-file extension match, unmatched extension, MultiEdit fixtures.

LLM-judgment validation of the bootstrap skill body itself (its hard gates, preamble) is dogfood territory — add scenarios to `tests/dogfood-scenarios.md` for: (a) Claude in an educational project does not invoke the craft-gate skill, (b) Claude in a code project picks up the rules from SessionStart and applies them.

---

## Out of scope

- Auto-installing the override file (the user creates it manually if they need it).
- Detecting partial-educational repos (a code project with a `tutorial/` directory still counts as CODE_PROJECT — the override exists for the rare case where this is wrong).
- Detecting language-specific educational signals (e.g., `_lesson.ipynb` naming). Keep heuristics narrow.
- Removing the existing CLAUDE.md snippet flow with backwards-compatibility shim. The snippet file is gone; users on the previous install just delete the manually-pasted block.

---

## Migration notes

Users who already pasted `claude-md-snippet.md` into their CLAUDE.md will have duplicate rules in context (one from the manual paste, one from SessionStart). It's harmless but noisy. README should call this out: "If you previously pasted the snippet manually, remove it from your CLAUDE.md — the rules now load via SessionStart."

---

## Open questions

None. All design decisions resolved in brainstorming.
