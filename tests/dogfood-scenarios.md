# Dogfood Scenarios

The skill body's behavior is evaluated by Claude at runtime, so it cannot be unit-tested in shell. Validate it manually by running these scenarios after install. Record observed verdicts next to each scenario for regression tracking.

## Setup

```bash
# Pre-req: add the local marketplace (run once from the plugin root)
claude plugins marketplace add .

claude plugins install craftsmanship-test@craft-gate
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

### S11: MultiEdit with mixed sub-edits (expect per-sub-edit gate)

Ask Claude: "use a MultiEdit on `/tmp/main.go` to make two changes — first edit adds a `// helper counter` comment above an existing line; second edit just renames a variable, no comments."

Expected: hook fires (extension match, MultiEdit matcher), reminder mentions "per sub-edit", and Claude evaluates each sub-edit's comments independently. The first sub-edit gets a CRAFT GATE verdict on `// helper counter`; the second sub-edit emits no verdict (no comments).

Recorded result: _______

## How to investigate failures

If observed verdicts disagree with expected:

1. Check whether the rules in `skills/craft-gate/SKILL.md` are being read by Claude (look for skill invocation in the transcript)
2. Check whether `claude-md-snippet.md` is in `~/.claude/CLAUDE.md` (if not, expect more rationalization toward KEEP)
3. Tighten the rationalization table in `SKILL.md` if Claude is finding new excuses
4. Add a Not/Yes pair if the rule is unclear on a specific edge case
