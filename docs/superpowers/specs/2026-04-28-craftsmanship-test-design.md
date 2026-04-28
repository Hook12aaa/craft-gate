# Craftsmanship Test — V1 Design Spec

**Date:** 2026-04-28
**Author:** hook (with Claude as scribe)
**Status:** Approved for implementation planning
**Sibling plugin:** `channelle-test` (mirror its shape)

---

## Motivation

LLM-generated code over-comments. The dominant failure modes are name-echo (`# get user by id` above `def get_user_by_id`), line-narration (`# increment counter` above `counter += 1`), and tutorial commentary (`# this is a list comprehension`). These accumulate as drift, mask intent, and rot independently of the code they describe.

Mainstream lint covers TODOs, commented-out code, and empty docstrings. It does not cover semantic redundancy, structural patterns inside scopes, or restating-but-non-empty docstrings — which are exactly the patterns LLMs produce most.

The Channelle Test gates customer-view UX decisions through a four-question simplicity lens. The Craftsmanship Test gates code-comment decisions through an imperative discipline derived from Mancuso (*The Software Craftsman*), Martin (*Clean Code*), Beck (Four Rules of Simple Design), Fowler (*Refactoring*), and Ousterhout (*A Philosophy of Software Design*). Same plugin shape, different lens.

V1 ships **comment discipline only**. Other craftsmanship dimensions (function size, naming clarity, duplication) are out of scope for V1; the architecture supports adding them later as sibling skills without rework.

## Goals

- Discipline an LLM coder against bad comment patterns at the point of authoring, before they land in source.
- Survive `/clear`, compaction, and long sessions via passive reinforcement in CLAUDE.md.
- Defer to existing lint where it already covers (Ruff `ERA`, `TD`, `FIX`; pylint `W0511`; eslint `no-warning-comments`). The plugin's defensible scope is what lint cannot do well.
- Mirror channelle-test's plugin shape so install, configuration, and contributor workflows are familiar.
- Keep the hook layer dumb and the skill layer smart: regex for syntactic gating; LLM-via-skill for semantic judgment.

## Non-goals

- No replacement for lint. The plugin assumes (and recommends) `ruff`/`eslint` are configured to handle TODO and commented-out-code rules.
- No regex-based judgment of comment quality. Detection of "is this comment good" is a skill task, not a hook task.
- No PostToolUse backstop. The hook is best-effort, not enforcement; gate compliance relies on Claude reading CLAUDE.md and obeying the skill verdict.
- No SessionStart auto-load. Rules ride passively in CLAUDE.md instead of being injected per-session.
- No additional craftsmanship dimensions in V1 (function size, naming, etc.).
- No language-specific AST parsing. The hook is language-agnostic; the skill judges in whatever language Claude is editing.

## Architecture

Three layers. Strict separation of concerns.

```
┌──────────────────────────────────────────────────────────────────┐
│  Layer 1 — CLAUDE.md snippet (passive reinforcement)             │
│  Lives in: ~/.claude/CLAUDE.md or project .claude/CLAUDE.md      │
│  Cost: zero per turn (already in system context)                 │
│  Job: keep the rules in Claude's working memory always           │
└──────────────────────────────────────────────────────────────────┘
                              ▲ informs
┌──────────────────────────────────────────────────────────────────┐
│  Layer 2 — PreToolUse hook (live trigger)                        │
│  Fires on: Edit | Write | MultiEdit                              │
│  Filter: source-code file extension                              │
│  Cost: ~5ms regex pass; ~80 tokens of additionalContext per fire │
│  Job: detect when Claude is editing source code; remind Claude   │
│        that the gate must run if any comments are present        │
└──────────────────────────────────────────────────────────────────┘
                              ▲ invokes via system-reminder
┌──────────────────────────────────────────────────────────────────┐
│  Layer 3 — craft-gate skill (LLM judgment)                       │
│  Body: imperative rules, anti-rationalization table, Not/Yes,    │
│        per-comment output protocol                               │
│  Output: per-comment verdict — KEEP / STRIP / REWRITE            │
│  Cost: ~150–250 tokens per fire                                  │
│  Job: Claude reads its own comments, judges them by the rules    │
└──────────────────────────────────────────────────────────────────┘
```

The hook does not parse `new_string` or attempt to detect comments at the script level. It checks file extension only. The reminder it injects tells Claude to invoke the skill **if** comments are involved in the edit; Claude does the comment-presence check via inspection of its own diff.

### What's notably different from channelle-test

| Aspect | channelle-test | craftsmanship-test |
|---|---|---|
| Bootstrap mechanism | Active SessionStart hook auto-injects bootstrap skill | Passive inheritance via CLAUDE.md snippet (paste once, every project picks up) |
| UserPromptSubmit hook | Yes (keyword trigger) | No — purely syntactic trigger via PreToolUse |
| Skill count | 2 (using-channelle-test bootstrap, channelle-gate) | 1 (craft-gate only) |
| Trigger filter | Customer-view file globs | Source-code file extensions |
| Hook script language | Bash with inline `python3` for JSON parsing | Same — direct port |
| Verdict vocabulary | SHIP / REWORK / DROP (per design decision) | KEEP / STRIP / REWRITE (per comment) |

## File tree

```
craftsmanship-test/
├── .claude-plugin/
│   ├── plugin.json
│   └── marketplace.json
├── skills/
│   └── craft-gate/
│       └── SKILL.md
├── hooks/
│   ├── hooks.json
│   ├── pre-tool-use
│   └── lib/
│       ├── detect-source-file.sh
│       └── emit-context.sh
├── commands/
│   └── craft-check.md
├── claude-md-snippet.md
├── config.sh
├── README.md
├── CLAUDE.md
└── tests/
    ├── run-tests.sh
    ├── test_pre_tool_use.sh
    ├── test_detect_source_file.sh
    ├── test_marketplace.sh
    ├── test_emit_context.sh
    ├── dogfood-scenarios.md
    └── fixtures/
        ├── edit_python_source.json
        ├── edit_markdown_doc.json
        ├── write_new_typescript.json
        ├── multiedit_go.json
        └── edit_unmatched_extension.json
```

## Component details

### `.claude-plugin/plugin.json`

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

### `.claude-plugin/marketplace.json`

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

### `hooks/hooks.json`

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

Single matcher, single hook. No SessionStart, no UserPromptSubmit.

### `hooks/pre-tool-use` (bash)

Reads stdin, extracts `tool_name` and `file_path` via inline `python3`, checks file extension against `CRAFT_SOURCE_GLOBS`, emits the EXTREMELY_IMPORTANT reminder if matched.

```bash
#!/usr/bin/env bash
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PLUGIN_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

source "${PLUGIN_ROOT}/config.sh"
[ -n "${CLAUDE_PROJECT_DIR:-}" ] && [ -f "${CLAUDE_PROJECT_DIR}/.craftsmanship-test.sh" ] \
  && source "${CLAUDE_PROJECT_DIR}/.craftsmanship-test.sh"
source "${SCRIPT_DIR}/lib/detect-source-file.sh"

payload="$(cat)"
read_payload=$(HOOK_PAYLOAD="$payload" python3 - <<'PY'
import json, os
data = json.loads(os.environ.get("HOOK_PAYLOAD","") or "{}")
print(f"{data.get('tool_name','')}\t{(data.get('tool_input',{}) or {}).get('file_path','')}")
PY
)
tool_name="${read_payload%%$'\t'*}"
file_path="${read_payload##*$'\t'}"

if [ -n "$file_path" ] && craft_path_triggers "$file_path"; then
  cat <<EOF | bash "${SCRIPT_DIR}/lib/emit-context.sh" PreToolUse
<EXTREMELY_IMPORTANT>
CRAFT GATE AUTO-TRIGGERED.

You are about to ${tool_name} \`${file_path}\`. If this edit adds or modifies any comment in the code (lines starting with \`#\`, \`//\`, \`/*\`, \`"""\`, \`'''\`, or \`<!--\`), invoke the \`craftsmanship-test:craft-gate\` skill via the Skill tool on each new/modified comment before this tool call completes.

If the verdict on any comment is STRIP or REWRITE, revise the edit before proceeding. Never skip the gate silently when comments are present.

If this edit contains no new or modified comments, proceed.
</EXTREMELY_IMPORTANT>
EOF
else
  printf '' | bash "${SCRIPT_DIR}/lib/emit-context.sh" PreToolUse
fi
```

### `hooks/lib/detect-source-file.sh`

Direct port of channelle-test's `detect-customer-view.sh`. Single function `craft_path_triggers <path>` returning 0 if path matches any glob in `CRAFT_SOURCE_GLOBS`. Includes the `_glob_to_regex` helper verbatim.

### `hooks/lib/emit-context.sh`

Reused **verbatim** from channelle-test. JSON-safe context emitter using `python3` for escaping.

### `config.sh`

```bash
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

Project override via `${CLAUDE_PROJECT_DIR}/.craftsmanship-test.sh` — same pattern as channelle-test. To disable the gate for a specific project, set `CRAFT_SOURCE_GLOBS=()` in the override file.

No per-edit skip token. Channelle-test's skip token is checked at UserPromptSubmit time against prompt text; this plugin has no UserPromptSubmit hook (trigger is purely syntactic via PreToolUse), so there is no clean wire-in for a skip token without parsing the JSON payload's content fields. Per-project disable is the supported escape hatch.

### `skills/craft-gate/SKILL.md`

The full imperative-judgment skill body. Structure:

1. **Frontmatter** — name, description (used for trigger detection)
2. **Three stacked `<HARD-GATE>` blocks** — block rationalization, block prose answers, "letter is the spirit"
3. **Iron Law** — `NO COMMENT SHIPS WITHOUT A KEEP VERDICT.`
4. **Eight numbered rules** — five STRIP rules, two KEEP rules, one REWRITE rule, with attribution to Beck/Fowler/Martin/Mancuso/Ousterhout
5. **Rationalization table** — ten "You think... / Reality" pairs covering the LLM's likely self-talk
6. **Red flags** — bare phrases of comment-text smells
7. **Not/Yes pairs** — three Nots, two Yeses, demonstrating the rules on concrete code
8. **Output protocol** — `CRAFT GATE: KEEP` / `STRIP — <rule>` / `REWRITE — <text>` per comment

Target length: 700 words. Full content: see Section 3 of the brainstorming conversation; included verbatim in implementation.

### `claude-md-snippet.md`

A condensed (~28 line) markdown section the user pastes into `~/.claude/CLAUDE.md` (global) or project `.claude/CLAUDE.md`. Contains:

- The iron law
- The five STRIP rules in compressed form
- The two KEEP rules in compressed form
- The REWRITE rule
- Pointer to invoke `craftsmanship-test:craft-gate` when the hook fires
- Source attribution

The snippet is the passive layer; the skill body is the depth layer. The snippet does not duplicate the skill — it references it.

### `commands/craft-check.md`

```markdown
---
description: "Run the Craft Gate on the comments in the current edit or file"
---

Use the Skill tool to invoke the `craftsmanship-test:craft-gate` skill. Apply it to the comments in the file or edit currently under discussion. Output a one-line verdict per comment.
```

For on-demand evaluation of files Claude is reading rather than editing.

## Data flow

```
1. User asks Claude to edit a Python file
2. Claude composes an Edit tool call with new_string containing code + comments
3. Claude Code dispatches PreToolUse hook
4. Hook script:
   a. Reads JSON payload from stdin
   b. Extracts tool_name, file_path via python3
   c. Sources config.sh + project override + detect-source-file.sh
   d. Checks file_path against CRAFT_SOURCE_GLOBS
   e. If match → emits <EXTREMELY_IMPORTANT> reminder via emit-context.sh
      If no match → emits empty additionalContext, exits 0
5. Claude receives the additionalContext as a system-reminder
6. Claude inspects its pending Edit:
   - If no new/modified comments → proceeds with the Edit unchanged
   - If new/modified comments → invokes craftsmanship-test:craft-gate via Skill tool
7. craft-gate skill body loads; Claude reads the rules, rationalization table, Not/Yes pairs
8. For each new/modified comment, Claude emits one verdict line:
     CRAFT GATE: KEEP / STRIP — <rule> / REWRITE — <text>
9. Claude revises the Edit's new_string per the verdicts
10. Edit completes; file is written
```

## Configuration

| Knob | Default | Override mechanism |
|---|---|---|
| Source-code extensions | Standard list (Python, TS/JS, Go, Rust, Java, etc.) | `CRAFT_SOURCE_GLOBS=(...)` in `${CLAUDE_PROJECT_DIR}/.craftsmanship-test.sh` |
| Disable plugin entirely for one project | n/a | Set `CRAFT_SOURCE_GLOBS=()` in project override |

## Error handling and edge cases

| Case | Behavior |
|---|---|
| Hook script crashes (bash error, missing python3) | `set -euo pipefail` aborts; exit non-zero. Claude proceeds with edit (hook is best-effort, never blocks). README documents python3 as a soft dependency — same dependency as channelle-test. |
| File path contains spaces or unicode | Bash variables quote correctly; `_glob_to_regex` (channelle-test's tested helper) handles via regex escape |
| Edit on a source file with no comments | Hook still fires (extension matched). Reminder tells Claude "if no comments, proceed." Claude reads, no skill invocation, ~10 tokens overhead |
| MultiEdit with mixed comment / no-comment sub-edits | Hook fires once for the whole MultiEdit. Claude is responsible for evaluating each sub-edit's comments via the skill |
| User wants to skip gate on one specific edit | No per-edit skip mechanism in V1. To skip for a project, set `CRAFT_SOURCE_GLOBS=()` in `.craftsmanship-test.sh` |
| Project has its own CLAUDE.md with conflicting rules | User's project CLAUDE.md takes priority (later in context); plugin defers |
| File extension not in default list (e.g. `.zig`, `.nim`) | Silent; user adds extension to project override |
| Hook fires but Claude doesn't invoke skill (drift) | CLAUDE.md snippet provides passive reinforcement to mitigate. Without the snippet, gate is reactive-only and may miss occasionally — documented trade-off |
| Hook fires on a `.py` file inside `docs/` | Currently fires (extension match). User can add `**/docs/**` exclusion in project override if undesired |

## Testing strategy

Mirror channelle-test's shell-test pattern:

- **Hook integration tests** (`test_pre_tool_use.sh`) — feed JSON fixtures to the hook script via stdin, assert on emitted JSON. Verify:
  - Edit on `.py` source → reminder emitted
  - Edit on `.md` doc → silent
  - Write on new `.ts` file → reminder emitted
  - MultiEdit on `.go` → reminder emitted
  - Edit on `.unknown` extension → silent
  - Project override with `CRAFT_SOURCE_GLOBS=()` → silent
- **Unit tests for source-file detection** (`test_detect_source_file.sh`) — exercise `_glob_to_regex` and `craft_path_triggers` against each language extension
- **Marketplace schema validation** (`test_marketplace.sh`) — validate `marketplace.json` and `plugin.json` against expected fields
- **Emit-context output validity** (`test_emit_context.sh`) — verify the JSON output is parseable and includes `hookSpecificOutput.additionalContext`

The skill body itself is not unit-testable in shell — its behavior is evaluated by Claude at runtime. Validation is via dogfooding:

1. Install the plugin locally
2. Run the scripted dogfood scenarios listed in `tests/dogfood-scenarios.md` (e.g. "edit a Python file and add `# create empty list` above `result = []` — expect STRIP verdict")
3. Record observed verdicts in `tests/dogfood-scenarios.md` next to each scenario for regression tracking

## Distribution and install

```
# 1. Add the local marketplace
claude plugins marketplace add /path/to/craftsmanship-test

# 2. Install the plugin
claude plugins install craftsmanship-test@craftsmanship-test-local

# 3. (Strongly recommended) Paste the snippet into ~/.claude/CLAUDE.md
cat /path/to/craftsmanship-test/claude-md-snippet.md >> ~/.claude/CLAUDE.md
```

Plugin is self-contained except for `python3` (used inline for JSON parsing). README documents `python3` as a soft dependency. If `python3` is missing, the hook degrades to a no-op (exit non-zero, edit proceeds without gating).

## What is deliberately NOT in V1

- No SessionStart hook (rules live in CLAUDE.md instead)
- No UserPromptSubmit hook (no keyword triggers; syntactic-only)
- No PostToolUse backstop
- No regex-based judgment of comment quality (skill judges)
- No language-specific AST parsing
- No recommended lint config bundle (V2 — defer to ruff/eslint config separately)
- No additional craftsmanship dimensions (function size, naming, duplication) — V1 is comments only
- No automatic install of the CLAUDE.md snippet — user pastes manually
- No verdict-aware blocking — hook is best-effort

## V2+ candidates (not committed)

- Sibling skills for naming clarity, function size, duplication detection
- Recommended lint config bundle (`pyproject.toml`, `eslint.config.js` snippets)
- A `using-craftsmanship-test` bootstrap skill that routes between dimensions
- Optional PostToolUse backstop for users who want stricter enforcement

## References

- Mancuso, Sandro. *The Software Craftsman: Professionalism, Pragmatism, Pride.* Prentice Hall, 2014.
- Martin, Robert C. *Clean Code: A Handbook of Agile Software Craftsmanship.* Prentice Hall, 2008. (Chapter 4: Comments.)
- Fowler, Martin. *Refactoring: Improving the Design of Existing Code* (2nd ed.). Addison-Wesley, 2018.
- Beck, Kent. Four Rules of Simple Design. (See: martinfowler.com/bliki/BeckDesignRules.html)
- Ousterhout, John. *A Philosophy of Software Design.* Yaknyam Press, 2018.
- Manifesto for Software Craftsmanship — manifesto.softwarecraftsmanship.org
- Channelle Test plugin (sibling) — `/Users/hook/Documents/coding/python/Personal_AI Projects/channelle_test`
- Caveman skill (constraint-style prior art) — github.com/JuliusBrussee/caveman
