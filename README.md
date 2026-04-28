# Craftsmanship Test

> A Claude Code plugin that gates every comment Claude writes against a craftsmanship discipline, before the comment lands in your code.

**Status:** 0.1.0 · MIT.

I built this while working on [model-trainer](https://github.com/Hook12aaa/model-trainer). Claude was generating perfectly good ML pipelines — and burying them under comments like `# increment counter by 1` and `# this is a list comprehension`. The comments piled up. They rotted. When the code changed, the comments didn't, and they started lying. Worse, every time Claude reached for a comment to explain what `data` or `helper` did, that was a missed opportunity to give those things real names.

So I started constraining. I told Claude not to comment unless it had a real reason. Naming improved. Function decomposition improved. The codebase got readable the way Mancuso, Martin, Beck, and Fowler keep telling us code should be readable — with the code itself, not with prose layered on top.

This plugin enforces that constraint. It runs a per-comment gate — KEEP, STRIP, or REWRITE — every time Claude is about to write a comment in a source file. The hook fires. The skill judges. The bad comments do not ship.

If that sounds like the discipline you want, keep reading. If it sounds annoying, it is, and you should not use this.

---

## How it works

Three layers. Strict separation of concerns.

**1. CLAUDE.md snippet (passive).** You paste a short markdown block into your `~/.claude/CLAUDE.md`. The rules live in the system prompt from then on. Claude self-suppresses bad comments before authoring them.

**2. PreToolUse hook (trigger).** Fires when Claude is about to `Edit`, `Write`, or `MultiEdit` a source-code file. The hook is dumb on purpose. It matches the file extension and nothing else. No JSON content parsing. No regex on the diff.

**3. craft-gate skill (judgment).** When the hook fires, Claude invokes the skill. The skill carries the rules. Claude reads its own diff, judges each comment, and emits one verdict per comment: `CRAFT GATE: KEEP` / `STRIP — <rule>` / `REWRITE — <text>`.

The hook stays out of the judgment business. The skill stays out of the trigger business. Neither layer tries to do the other's job, and you can swap or extend either one without rewriting the other.

---

## Quickstart

```bash
claude plugins marketplace add /path/to/craftsmanship-test
claude plugins install craftsmanship-test@craftsmanship-test-local
cat /path/to/craftsmanship-test/claude-md-snippet.md >> ~/.claude/CLAUDE.md
```

That third step is where most of the value is. The hook is the safety net; the snippet is the discipline.

If your path has spaces, symlink it:

```bash
ln -s "/path/with spaces/craftsmanship-test" ~/craftsmanship-test-dev
claude plugins marketplace add ~/craftsmanship-test-dev
```

---

## The rules

Eight imperative rules. Five strip, two keep, one rewrite.

| | What it catches |
|---|---|
| STRIP 1 | Comments that paraphrase the next 1–3 lines of code |
| STRIP 2 | Comments that teach a language or library basic (`# this is a list comprehension`) |
| STRIP 3 | Section dividers inside a function (`# --- validation ---`) |
| STRIP 4 | Scope-end labels (`} // end if`) |
| STRIP 5 | Commented-out code |
| KEEP 6 | Public-API contract docstrings — params, raises, thread-safety, invariants the caller cannot infer |
| KEEP 7 | Real "why" — non-obvious constraint, hidden invariant, workaround for a specific bug, surprising business rule |
| REWRITE 8 | Comments that are partially "why" but mostly "what" — trim to the why-only part |

A comment is presumed STRIP until it earns KEEP. The burden of justification is on the comment, not on its absence.

The full skill is at `skills/craft-gate/SKILL.md`. About 100 lines.

---

## What it actually does in a session

You ask Claude to write a Python function. Claude composes the `Write` tool call. Before the file lands on disk, the hook fires and injects a `system-reminder` telling Claude to invoke `craftsmanship-test:craft-gate` if any comments are present in the diff. Claude reads its own pending output, finds a `# increment counter by 1`, applies rule 1, emits `CRAFT GATE: STRIP — rule 1`, deletes the comment, and the cleaned file is what gets written.

If the comment was a real "why" — `# 30s idempotency window per Stripe API docs` — Claude emits `CRAFT GATE: KEEP` and the comment ships untouched.

If the comment was partially right but vague — `# subtract 1 because of NTP rollover bug` — Claude emits `CRAFT GATE: REWRITE — # NTP rollover bug in upstream feed reports timestamps 1s ahead; normalize before comparing` and the rewritten comment is what lands.

You see none of this unless you look. The verdicts appear in the conversation log. The file on disk is the post-gate version.

---

## When not to use this

Skip this if any of the following are true.

- **You like comments that narrate `i++`.** The skill will strip them. You will be unhappy.
- **Your team documents through prose, not naming.** The skill assumes good naming is the documentation. Some shops genuinely run differently.
- **You have a comment style guide that conflicts.** The skill is opinionated. It will fight your style guide. Pick one.
- **You are writing literate programming, notebooks, or teaching material.** The skill is for production source.
- **You bounce off discipline-heavy tools.** The voice in the skill is strict on purpose. It is not going to flatter you.

---

## Configuration

Per-project override: drop a `.craftsmanship-test.sh` at your project root.

```bash
# Disable the gate entirely for this project
CRAFT_SOURCE_GLOBS=()

# Or restrict to a custom subset
CRAFT_SOURCE_GLOBS=("**/*.py" "**/src/**/*.ts")
```

Default extensions cover Python, TypeScript/JavaScript, Go, Rust, Java, Kotlin, Scala, Ruby, Swift, C/C++, C#, PHP, and Elixir.

The hook is best-effort. If `python3` is missing, it degrades to a no-op and your edits proceed without gating.

---

## Repository layout

```
.
├── .claude-plugin/        # plugin manifest + local marketplace
├── skills/
│   └── craft-gate/        # the imperative judgment skill
├── hooks/
│   ├── hooks.json
│   ├── pre-tool-use       # bash entry; matches file extension
│   └── lib/               # detect-source-file.sh, emit-context.sh
├── commands/              # /craft-check slash command
├── claude-md-snippet.md   # what you paste into ~/.claude/CLAUDE.md
├── config.sh              # default CRAFT_SOURCE_GLOBS
└── tests/                 # shell-based tests + dogfood scenarios
```

---

## The principles I will not bend on

1. **Comments are presumed STRIP.** A comment is guilty until proven innocent.
2. **Why, not what.** A comment must say something the code cannot say. If the code can say it, the code should.
3. **Public APIs are the exception, not the rule.** Contract docstrings on exported symbols are different from inline narration. Keep the contract; strip the narration.
4. **Imperatives over examples.** The skill body is rules, not "here's what good output looks like". Examples seed mimicry; rules transfer.
5. **The hook stays dumb.** Detection lives in regex; judgment lives in the LLM. Do not move judgment into bash.
6. **Defer to lint where it already covers.** Ruff `ERA001` for commented-out code. Pylint `W0511` for FIXMEs. This skill only picks up what lint cannot reach: semantic redundancy, structural patterns inside scopes, restating-but-non-empty docstrings.
7. **Status is a vocabulary, not a feeling.** `KEEP`, `STRIP`, `REWRITE`. There is no "looks fine".

---

## Lessons learned

The first draft tried to detect bad comments via regex in the hook. Token-subset rules, name-paraphrase scoring, the lot. It would have worked. It also would have been brittle in five languages and impossible to tune. The right architecture turned out to be: regex for syntactic gating (is there a comment?), LLM for semantic judgment (is this comment good?). Once that split was clean, the rest fell into place.

The second mistake was trying to enumerate every comment marker (`#`, `//`, `/* */`, `"""`, `'''`, `<!--`) in the hook's reminder text. The skill body has the rich language. The reminder does not need to teach Claude what a comment looks like; it just needs to fire.

The third was over-rotating on JSON parsing. A research cycle decided between `jq`, vendored `JSON.sh`, and pure bash. The right answer was already sitting in another plugin I had built — inline `python3 -c`. Same dependency surface, fewer moving parts. Match what works; do not reinvent what is already proven.

---

## Inspirations

- **[Caveman](https://github.com/JuliusBrussee/caveman).** Showed that one tight constraint-style skill, written in its own constrained voice, changes behaviour reliably. The Not/Yes pattern, the persistence clause, the rationalization table — all owe to caveman.
- **Sandro Mancuso, *The Software Craftsman*.** The voice the rules are written in.
- **Robert Martin, *Clean Code* Ch. 4.** "Comments are always failures." Hard rule, well-defended.
- **John Ousterhout, *A Philosophy of Software Design*.** The case for keeping interface docstrings even when the rest of the code self-documents. Without it the skill would over-strip.
- **[Superpowers](https://github.com/anthropics/claude-plugins-official).** The harness this kind of skill rides on.

---

## Contributing

Open invitation. If you have a sharper rule, a better worked example, or a rationalization table row I have not seen yet, send it. See `CLAUDE.md` for the contributor notes.

---

## Licence

MIT. Use it. Fork it. Build on it. Attribution welcome, not required.
