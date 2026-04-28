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
