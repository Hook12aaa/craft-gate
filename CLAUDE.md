# CLAUDE.md — plugin contributor notes

This file is for anyone modifying the craftsmanship-test plugin itself. End-user install and usage live in `README.md`.

## Layout

- `.claude-plugin/plugin.json` — plugin manifest
- `.claude-plugin/marketplace.json` — local marketplace descriptor (required for `claude plugins marketplace add`)
- `skills/craft-gate/SKILL.md` — the imperative-judgment gate skill (KEEP / STRIP / REWRITE per comment)
- `skills/using-craftsmanship-test/SKILL.md` — bootstrap skill, inlined into SessionStart payload
- `hooks/hooks.json` — declares SessionStart and PreToolUse matchers
- `hooks/session-start` — bash entry: emits the using- skill body if project-type detector returns CODE_PROJECT, silent otherwise
- `hooks/pre-tool-use` — bash entry: gates on project-type verdict, then on file extension, then emits reminder
- `hooks/lib/detect-project-type.sh` — `craft_detect_project_type` with educational denylist (ported from channelle-test pattern)
- `hooks/lib/detect-source-file.sh` — `craft_path_triggers` and `_glob_to_regex` helpers
- `hooks/lib/emit-context.sh` — JSON-safe context emitter
- `config.sh` — default `CRAFT_SOURCE_GLOBS` (override per-project via `.craftsmanship-test.sh`, which also recognises `CRAFTSMANSHIP_PROJECT_TYPE`)
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

1. **Auto-load (SessionStart hook)** — emits the `using-craftsmanship-test` skill body as system context every session, gated on the project-type detector. Replaces the manual snippet-paste flow.
2. **Trigger (PreToolUse hook)** — gates on project-type verdict first, then file extension. Purely syntactic; no JSON content parsing in the hook itself.
3. **Judgment (craft-gate skill)** — LLM applies imperative rules to its own comments. Smart on purpose.

The hook does NOT detect bad comments. It detects that Claude is editing a source file in a code project. Claude itself checks for comment presence and invokes the skill if needed.

The project-type detector uses denylist semantics: default `CODE_PROJECT`, only `SUPPRESS` on strong educational signals (`_quarto.yml`, `book.toml`, `_bookdown.yml`, `_config.yml` with jupyter-book/bookdown markers, `mkdocs.yml` without a source dir, or notebook-dominant ratio). Override via `CRAFTSMANSHIP_PROJECT_TYPE` in the project's `.craftsmanship-test.sh`.

## Sibling plugin

Mirrors `channelle-test`. Shape is identical except:
- No UserPromptSubmit (purely syntactic trigger)
- Two skills (`craft-gate` for judgment, `using-craftsmanship-test` for bootstrap)
- Source-file globs instead of customer-view globs
- Project-type detector uses denylist semantics (default `CODE_PROJECT`, suppress on educational signals) instead of allowlist
- Verdict vocabulary: `CODE_PROJECT` / `SUPPRESS` for project-type and `KEEP` / `STRIP` / `REWRITE` per comment instead of `PUBLIC_APP` / `SUPPRESS` and `SHIP` / `REWORK` / `DROP`
