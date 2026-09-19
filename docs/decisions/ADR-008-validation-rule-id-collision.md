# ADR-008 — Amendment: the duplicated `V-28` validation rule id

## Status

Accepted — 2026-09-19. **Amends `SCHEMA.md` §6.7 and §6.9, and `NAVIGATION.md` §7.**

- **Raised during:** Stage 4, at the start of substage 4.8
- **Amends:** a rule identifier, not a rule. No validation behaviour changes.
- **Cause:** ADR-006, which added `V-28…V-31` without noticing `V-28` was taken

## Context

Substage 4.8 implements *"every validation rule from the design"* and wires each into the write
path. Reading `SCHEMA.md` §6 end to end for that purpose surfaced that **`V-28` names two different
rules**:

| Section | Rule | Added by |
|---|---|---|
| §6.3 — multi-target redirect rules | Every `redirect_targets` row's target exists, is not deleted, and is not archived | **ADR-006** |
| §6.7 — reserved-column rules | `target_date_ms`, `ceiling_param`, `parent_category_id`, `soft_budget_minor`, `soft_budget_period` are all null | substage 2.10 |

The reserved-column rule is the original. ADR-006 introduced `V-28…V-31` for the cascade-redirect
model and collided with it.

This is not cosmetic. Every failure in this codebase carries the rule identifier that produced it —
`EntityFailure.rule`, and now `ValidationFailure.rule` — precisely so a message reaching a log or a
screen can be traced back to the document that required it. **An identifier that names two rules
cannot do that job.** A developer reading `V-28` in a stack trace has no way to know whether a
redirect target is dead or a reserved column was written.

A second, smaller staleness came from the same ADR: two places still describe the block-on-violation
set as the range **`V-01…V-28`**, written when V-28 was the highest rule. ADR-006 took the set to
V-31 without updating either.

## Decision

**Renumber the reserved-column rule `V-28` → `V-32`.** ADR-006's `V-28…V-31` block keeps its
numbers.

That direction is chosen on blast radius, not seniority. The redirect `V-28` is referenced in four
places — `lib/domain/entities/redirect_target.dart`, ADR-006's impact table, `TRACEABILITY.md`'s
FR-16 row, and §6.3 — and twice as part of the contiguous range *"V-28…V-31"*. The reserved-column
`V-28` is referenced **only** in the §6.7 table it is defined in. Moving the older rule touches one
table row; moving the newer one touches a code comment, an ADR, the traceability matrix, and breaks
a range cited as a range.

Seniority would be the better tie-break if both were equally entangled. They are not.

Also amended, for the same root cause:

- `SCHEMA.md` §6.9 — *"Every rule V-01…V-28, at save time"* → **V-01…V-32**
- `NAVIGATION.md` §7, `Category Edit` — *"Any V-01…V-28 violation"* → **V-01…V-32**

## Alternatives considered

**Renumber ADR-006's `V-28` to `V-32`.** Preserves the older rule's identifier, which is the
principled tie-break. Rejected on cost: four references including a shipped code comment, and it
splits a block that two documents cite as the contiguous range `V-28…V-31`, which would then be
wrong in a new way.

**Disambiguate by section rather than renumbering** — `V-28 (§6.3)` and `V-28 (§6.7)`. Rejected
outright. The identifiers exist to be carried in a failure value and read without the document to
hand; one that needs a section reference to disambiguate has stopped being an identifier.

**Leave it and let 4.8 pick whichever it means.** This is what the manifest's `sdlc_discipline`
forbids: *"do not silently patch forward: raise it, amend the earlier document, and note the
amendment in the decision log."* The cost of leaving it is paid later and by someone else, reading a
failure that names a rule they cannot look up.

## Consequences

### Positive

- Rule identifiers are unique again, so `ValidationFailure.rule` is traceable — which is the whole
  reason 4.8 carries it.
- The two stale `V-01…V-28` ranges now cover the rules that actually exist.

### Negative

- A third post-Stage-2 amendment to `SCHEMA.md` (after ADR-005 and ADR-007). All three were found by
  implementation reading the document closely, which is the intended mechanism working — but it does
  mean §6 was not internally consistent at the Stage 2 gate.
- `V-32` now sits alone at the end of the numbering, out of thematic order with §6.7's `V-27`.
  Accepted: gaps and out-of-order identifiers are normal in a stable numbering scheme, and renumbering
  to keep them tidy is how collisions get created.

### Neutral

- **No behaviour changes.** Both rules keep their meaning, their enforcement point and their
  disposition. Only one identifier moves.
- No code change is required. The only code reference to `V-28` is the redirect rule, which keeps
  its number.

## Date

2026-09-19
