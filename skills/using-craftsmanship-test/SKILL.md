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
