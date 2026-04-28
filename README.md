# Craftsmanship Test

A Claude Code plugin that gates every comment Claude writes against a craftsmanship discipline, before the comment lands in your code.

Status: 0.1.0, MIT.

AI comments are often just technical debt in disguise. While working on my latest ML project, I realized Claude’s comments were "rotting" faster than I could refactor. Taking a page from the Software Craftsmanship handbook (shoutout to my time at Codurance), I built a plugin that gates AI prose.

Naming improved. Functions got smaller. The comments that survived had reasons. 

This plugin enforces the discipline. The gate runs per-comment (KEEP, STRIP, or REWRITE) every time Claude is about to write a comment in source code.

## How it works

Three layers.

1. SessionStart auto-load. A bash hook reads the `using-craftsmanship-test` skill body at session start and emits it as system context. Claude sees the rules every session, no manual paste. The hook silences itself on projects the detector classifies as educational.

2. PreToolUse hook (trigger). Fires when Claude is about to `Edit`, `Write`, or `MultiEdit` a source file. Matches file extension only. No content parsing.

3. craft-gate skill (judgment). When the hook fires, Claude invokes the skill, reads its own diff, and emits one verdict per comment: `CRAFT GATE: KEEP`, `CRAFT GATE: STRIP, <rule>`, or `CRAFT GATE: REWRITE, <text>`.

Trigger lives in regex. Judgment lives in the LLM.

## Quickstart

```bash
claude plugins marketplace add /path/to/craft-gate
claude plugins install craftsmanship-test@craftsmanship-test-local
```

The plugin loads its rules into context automatically at session start. There is no manual paste step.

By default the gate runs on any project that looks like a code project. It stays silent on educational projects (Quarto books, mdBook, Jupyter Book, mkdocs-only sites, notebook-dominant repos). Override per-project by creating a `.craftsmanship-test.sh` at the project root with `CRAFTSMANSHIP_PROJECT_TYPE=code-project` (force enable) or `CRAFTSMANSHIP_PROJECT_TYPE=suppress` (force silent).

If your path has spaces, symlink it first.

If you previously pasted the snippet into your project's `CLAUDE.md`, remove it. The rules now load via SessionStart.

## The rules

| | What it catches |
|---|---|
| STRIP 1 | Paraphrases the next 1-3 lines of code |
| STRIP 2 | Teaches a language or library basic |
| STRIP 3 | Section dividers inside a function |
| STRIP 4 | Scope-end labels (`} // end if`) |
| STRIP 5 | Commented-out code |
| KEEP 6 | Public-API contract: params, raises, invariants the caller cannot infer |
| KEEP 7 | Real why: non-obvious constraint, hidden invariant, workaround |
| REWRITE 8 | Partially why but mostly what. Trim to the why-only part |

Full skill: `skills/craft-gate/SKILL.md`.

## Configuration

Per-project override: drop a `.craftsmanship-test.sh` at your project root.

```bash
# Disable the gate for this project
CRAFT_SOURCE_GLOBS=()

# Or restrict to a custom subset
CRAFT_SOURCE_GLOBS=("**/*.py" "**/src/**/*.ts")
```

Defaults cover Python, TS/JS, Go, Rust, Java, Kotlin, Scala, Ruby, Swift, C/C++, C#, PHP, and Elixir.

## Inspirations

- [Caveman](https://github.com/JuliusBrussee/caveman). One tight constraint-style skill in its own constrained voice changes behaviour reliably.
- Sandro Mancuso, The Software Craftsman. The voice the rules are written in.
- Robert Martin, Clean Code Ch. 4. "Comments are always failures."
- John Ousterhout, A Philosophy of Software Design. Why public-API docstrings still matter.
- [Superpowers](https://github.com/anthropics/claude-plugins-official). The harness this rides on.

## Licence

MIT.
