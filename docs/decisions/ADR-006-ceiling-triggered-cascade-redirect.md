# ADR-006 — Ceiling-triggered cascade redirect: multiple targets, split or priority

- **Status:** Accepted
- **Date:** 2026-07-22
- **Raised during:** Stage 4, between substage 4.3 and 4.4
- **Amends:** PRD.md (Stage 1 gate), SCHEMA.md and ALLOCATION_ALGORITHM.md (Stage 2 gate)
- **Supersedes in part:** the single `categories.redirect_target_category_id` column

---

## Context

A requirement arrived after both the Stage 1 and Stage 2 gates:

> Each Accumulating Reserve category has a Reference Monthly Amount and a Ceiling. While a category's
> balance is below its ceiling, its reference amount is allocated to it normally on every income
> event. The moment its balance reaches or would exceed the ceiling, that category stops receiving
> its allocation — instead, that amount redirects to one or more explicitly user-configured fallback
> categories (not auto-inferred), with a user-configurable split or priority order if there are
> multiple targets. […] This cascade logic is the core intelligence that makes this app worth
> building over a static spreadsheet.

Requirements arriving after a gate are the normal case, not a failure. The manifest's
`sdlc_discipline` rule is that they are **recorded as amendments with their ripple traced**, rather
than absorbed into whichever stage happens to be open.

## What was already designed

Most of this requirement was already specified and, in part, already built. Recording that precisely
matters: re-implementing an existing mechanism under a new name is how a codebase acquires two
sources of truth for one behaviour.

| Requirement clause | Where it already lives | Built? |
|---|---|---|
| "check must happen live on every income event, not periodically" | ALLOCATION_ALGORITHM §3.2, `accepted_so_far` | Yes — substage 4.2, `Category.headroom(acceptedSoFarMinor:)` |
| "if a category crosses its ceiling mid-calculation, the overflow for that same event should already redirect correctly" | §3.2 verbatim — *"a category can be reached more than once: once by its own base share, and again by overflow redirected from another category"* | Yes — tested at 4.2 |
| "cascade further down that target's own redirect target" | §3.3 FIFO worklist; vector **V-05**, which produces five line items from three categories | Specified; engine is Stage 5 |
| "rather than silently absorbing or dropping the overflow" | INV-07; zero-amount lines are forbidden (§2.2) | Yes — `AllocationLine` rejects a zero amount |
| "route the funds to a default Unallocated Surplus bucket" | The sink (OQ-07), `AllocationReason.SINK_TERMINAL`, vector **V-06** | Yes — `is_sink`, C-19, U-08 |
| "flag this to the user in the UI rather than losing the funds silently" | `DiagnosticEvent` (§2.3), rendered by substage 6.4.3 | Specified |
| "applies only to Accumulating Reserve […] don't conflate the two" | §3.1 headroom table; `CategoryType.requiresCeiling` / `requiresBill` | Yes — separate headroom formulas, tested |

**Two clauses were genuinely new**, and this ADR is about them.

## Decision 1 — a category may have **many** redirect targets, ordered or split

`categories.redirect_target_category_id` held exactly one target. The requirement asks for several,
with a user-chosen split or priority order.

**A new table, `redirect_targets`, replaces the column outright.** The single column is removed, not
kept alongside for the one-target case.

Keeping both would give two places to read "where does this category's overflow go", and this
project has already rejected that shape twice for the same reason: `accounts` has no
`balance_minor` (INV-04), and `ledger_entries` carries a positive amount plus a direction rather
than a signed amount, because *"a signed amount plus a direction gives two ways to express the same
thing and eventually they disagree"* (SCHEMA §3.7). One target is the one-row case of many.

Nothing is released, so this lands in schema version 1 with no migration.

### Two modes, because the requirement names two

| Mode | Behaviour | When |
|---|---|---|
| `PRIORITY` *(default)* | Offer the overflow to each live target in `priority` order; each takes `min(remaining, its headroom)`. | The example's *"until those are satisfied"* reading. Easier to reason about, and the natural default for savings goals. |
| `SPLIT` | Divide the overflow across live targets by basis points, which must total exactly 10000 among them. | When the user wants both goals to advance together rather than one at a time. |

`SPLIT` uses `Money.multiplyByBasisPoints` with **divisor = the sum of the live targets' weights**,
not a constant 10000. This is precisely the primitive the substage 2.8 defect produced: hardcoding
10000 silently loses money whenever the participating weights total less, which is exactly what
happens when one of several targets is archived or already full. The fix made for override
redistribution turns out to be the same fix this feature needs.

### Sibling fallback and descendant cascade are different axes, and FIFO already separates them

The requirement contains two statements that could conflict:

- *"a user-configurable split or priority order if there are multiple targets"* — try the **source's
  own** targets in turn (**sibling fallback**).
- *"If so, cascade further down that target's own redirect target"* — follow the **target's**
  chain (**descendant cascade**).

They are not in conflict; they are two levels of the same walk. The source's overflow is offered to
its own targets first, and only what none of them can accept descends into their chains.

**The existing FIFO worklist produces this ordering for free.** All of a source's targets are
enqueued together at hop *N*; a target's own targets can only be enqueued at hop *N+1*, so every
sibling is tried before any descendant. §3.3 chose FIFO over recursion to avoid a stack overflow and
to keep the hop count visible — it turns out to also be what makes sibling-before-descendant correct
without a second mechanism. Had the worklist been LIFO, a deep chain under the first target would
have starved the second.

### What carries over unchanged

The cycle defences apply to the new table without modification, and both are still needed: V-12's
save-time acyclicity check (a graph walk, now over `redirect_targets`) and the engine's runtime
visited-set plus hop limit, because a merge of two independently valid edits can still produce a
cycle. Vector V-07 continues to cover it.

## Decision 2 — `reference_monthly_amount_minor` is stored, but does **not** by itself change how money is split

The requirement describes an **absolute** monthly figure: *"a Reference Monthly Amount of 193,000"*.
The approved design allocates by **percentage** — FR-02, a MUST-level requirement, reads *"Set a
fixed percentage of income allocated to each category."*

These are not the same mechanism, and the difference is observable. On a 700,000 month where the
reference income is 550,000, does the bike receive 193,000 or 245,000?

Answering "absolute" is not a small change. It requires deciding, at minimum:

- what happens when the reference amounts total **more** than the income (prorate? priority order?);
- what happens when they total **less** (does the remainder follow percentages? sit in the sink?);
- how conservation (INV-02) is preserved in both cases, given that the largest-remainder split
  currently guarantees it by construction.

That is a redesign of phase A, contradicting an approved MUST requirement, and it would invalidate
several of the fifteen golden vectors.

**Decision: store the field now; do not let it drive allocation until the question is answered.**
`reference_monthly_amount_minor` is added to `categories` as a nullable column, permitted only on
`ACCUMULATING_RESERVE`. It records the user's stated intent and drives projections ("at this rate
you reach your ceiling in 2 months"). Whether it *also* replaces the percentage as the allocation
mechanism is raised as **OQ-19** with a recommendation.

**The cascade behaviour is unaffected by how that question resolves.** Whether the bike's 193,000
arrives as an absolute figure or as its percentage share, the ceiling test, the redirect, the
cascade and the terminal sink behave identically. This is why Decision 1 can be implemented now with
full confidence while Decision 2 waits: the fork is upstream of the interesting part.

Recording the column now also means that if OQ-19 resolves toward absolute amounts, the data is
already being captured rather than needing backfill.

## Consequences

### Ripple across gated stages

| Document | Change |
|---|---|
| `PRD.md` | **FR-16** and user stories **US-038**, **US-039**. FR-10's overflow behaviour now points at the multi-target model |
| `SCHEMA.md` | New table §3.14 `redirect_targets`; `categories` gains `reference_monthly_amount_minor` and `redirect_mode`, loses `redirect_target_category_id`; constraints **C-29…C-33**; validators **V-28…V-31**; index **IX-13** |
| `ALLOCATION_ALGORITHM.md` | New §3.10 for multi-target redirect; four golden vectors **V-16…V-19** |
| `OPEN_QUESTIONS.md` | **OQ-19**, non-blocking, answered by default |
| `TRACEABILITY.md` | FR-16 row |

### Stage impact

| Stage | Impact |
|---|---|
| **4** (open) | Schema and entities change — 4.2 and 4.3 outputs amended in place, with the comparison table regenerated. 4.8's validator gains the multi-target cycle walk |
| **5** | Engine implements §3.10 and must pass V-16…V-19. The four cases the requirement names map one-to-one onto those vectors |
| **6** | A redirect-target editor (list, reorder, mode, shares) rather than a single-target picker. The surplus-arrival flag |
| **9** | Four vectors added to the conformance set |

### Costs accepted

- **Schema churn one substage after 4.3 shipped.** Unavoidable and cheap now; the alternative is
  building 4.4's repositories against a model known to be wrong.
- **The redirect editor is a harder screen** than a single dropdown. Named here so Stage 6 sizes it
  correctly rather than discovering it.
- **A `SPLIT` group whose targets do not total 10000 is a new way to misconfigure.** Mitigated by
  C-31 and validator V-29, which mirror the existing V-01/V-02 percentage rules.

## Alternatives rejected

**Keep one target and let users chain manually.** The user could point EV Bike at Hajj and Hajj at
Wedding. This is what the cascade already does, and it is genuinely close — but it forces a total
order where the user asked for a split, and it makes "Hajj and Wedding advance together" impossible
to express. Rejected because it satisfies the letter of the cascade while losing the configurability
the requirement asks for twice.

**Add a second target column** (`redirect_target_2`). Rejected immediately: it caps the count at two
and encodes priority in column names.

**Infer targets** — send overflow to the nearest under-ceiling category in the same group. The
requirement forbids this explicitly (*"not auto-inferred"*), and rightly: a redirect the user did
not choose moves their money somewhere they did not expect, which is the trust failure this app
cannot afford.
