## Craftsmanship — comment discipline

This project uses the `craftsmanship-test` plugin. When you write or modify a comment in code, the `craft-gate` skill fires and must return a KEEP verdict before the edit completes. Apply these rules pre-emptively.

**Iron law: no comment ships without KEEP.** A comment is STRIP by default; it must earn its place.

**STRIP** any comment that:
- Paraphrases the next 1–3 lines of code
- Teaches a language or library basic (`# this is a list comprehension`)
- Is a section divider inside a function (`# --- validation ---` → extract a function instead)
- Is a scope-end label (`} // end if`, `# end for loop`)
- Is commented-out code (git is the archive)

**KEEP** any comment that:
- Is a public-API contract docstring (params, returns, raises, thread-safety, invariants the caller cannot infer from the signature)
- Is a real "why": non-obvious constraint, hidden invariant, workaround for a specific bug/CVE, performance trick that looks wrong, surprising business rule

**REWRITE** if the comment is partially "why" but mostly "what" — trim to the why-only part.

When the hook fires, invoke `craftsmanship-test:craft-gate` via the Skill tool, emit one verdict per new/modified comment (`CRAFT GATE: KEEP` / `STRIP — <rule>` / `REWRITE — <text>`), and revise the edit before the tool call completes.

Sources: Mancuso (*The Software Craftsman*), Martin (*Clean Code* Ch. 4), Fowler (*Refactoring*), Beck (Four Rules of Simple Design), Ousterhout (*A Philosophy of Software Design*).
