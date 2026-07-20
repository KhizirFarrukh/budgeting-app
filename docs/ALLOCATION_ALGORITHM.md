# PookieBudget — the allocation algorithm

| | |
|---|---|
| **Status** | In progress — Stage 2 |
| **Derived from** | `docs/PRD.md` §4 (money model), §5.6 (interaction cases); manifest INV-01, INV-02, INV-07, INV-08 |
| **Sections assembled** | 1, 2, 5 (2.5); 3 (2.6); 4, 6 (2.7); 7, 8, 9, 10 (2.8) — **complete** |
| **Vectors** | 15 vectors in 16 fixtures, every expected value produced by executing the algorithm (§10.2) |

**Stage 5 implements this document verbatim.** It is written so that implementation is a
transcription exercise, not an invention exercise: every rule is stated, every tie is broken, every
bound is derived and shown. If Stage 5 finds itself making a decision, this document has failed and
must be amended rather than worked around.

> **Section order.** Sections are numbered to match the references in the Stage 5 plan, not reading
> order. Read: §1 → §2 → **§5 (phase A)** → §3 (phase B) → §4 (overrides) → §6 (errors) → §7–§10.

**Vocabulary:** PRD §9 glossary terms only.

---

## 1. The request contract

The engine is a pure function. **Its entire world arrives in this object.** A field missing here is a
field the engine will be tempted to fetch, which would destroy INV-08.

### 1.1 `AllocationRequest`

| Field | Type | Meaning |
|---|---|---|
| `income_amount_minor` | int64 | The amount to distribute. Must be `> 0` and `≤ MAX_MONEY_MINOR` (§5.6) |
| `evaluated_at_ms` | int64 | UTC epoch milliseconds. **Passed in, never read from a clock** (INV-08) |
| `rule_version_id` | string | Identifies the rule snapshot below; echoed into the result so the event records what it used |
| `group_shares` | list of `GroupShare` | The group-level split |
| `categories` | list of `CategorySnapshot` | Every **active, non-archived** category, with its current state |
| `sink_category_id` | string | The personal terminal sink |
| `business_sink_category_id` | string \| null | The business terminal sink; null when business scope is off |
| `overrides` | map<string, int64> \| null | Category id → amount. A verbatim record of user input (§4) |
| `period` | `PeriodDefinition` | The current period window for fixed-recurring categories |
| `scope` | enum | `PERSONAL` \| `BUSINESS` — selects which sink terminates chains for this event |

### 1.2 `GroupShare`

| Field | Type | Meaning |
|---|---|---|
| `group_id` | string | |
| `kind` | enum | `SPENDING` \| `SAVINGS` \| `BUSINESS` |
| `basis_points` | int | 0–10000. Across all entries, must total **exactly 10000** |
| `sort_order` | int | First tie-break key (§5.4) |

### 1.3 `CategorySnapshot`

Everything the engine needs to know about one category. **All balances arrive computed**; the engine
never derives one.

| Field | Type | Meaning |
|---|---|---|
| `id` | string | |
| `group_id` | string | |
| `type` | enum | `FIXED_RECURRING` \| `ACCUMULATING_RESERVE` \| `UNCAPPED_FLOW` |
| `basis_points` | int | Its share **within its group**. Within each group these must total exactly 10000 |
| `sort_order` | int | First tie-break key (§5.4) |
| `current_balance_minor` | int64 | Ledger-derived. **May be negative** — spending can overdraw a category (PRD A-04) |
| `ceiling_minor` | int64 \| null | Set iff `type = ACCUMULATING_RESERVE` |
| `bill_amount_minor` | int64 \| null | Set iff `type = FIXED_RECURRING` |
| `allocated_in_current_period_minor` | int64 | How much this category has already received **in the current period**. Computed by the data layer (§3), not here. Zero for non-fixed-recurring types |
| `redirect_target_category_id` | string \| null | Where overflow goes. Null means "straight to the sink" |
| `is_sink` | bool | |
| `carry_forward_policy` | enum | `CARRY_FORWARD` \| `REDIRECT_SURPLUS`. Per PRD A-03 the default is `CARRY_FORWARD`. **An input, not a constant** — substage 5.5.3 requires this |

### 1.4 `PeriodDefinition`

Computed by the caller from `domain/allocation/period.dart` (ARCHITECTURE §8.4), passed in so the
engine performs no calendar arithmetic against a clock.

| Field | Type | Meaning |
|---|---|---|
| `start_ms` | int64 | Inclusive start of the current period |
| `end_ms` | int64 | Exclusive end |
| `anchor_day` | int | 1–31, the configured anchor |

### 1.5 Why each field exists — the test for completeness

| If this were absent | The engine would have to… |
|---|---|
| `current_balance_minor` | query the database — destroys purity |
| `allocated_in_current_period_minor` | query and do calendar arithmetic — destroys purity |
| `evaluated_at_ms` | read a clock — destroys determinism |
| `period` | compute period boundaries from a clock — destroys determinism |
| `sort_order` on both shares and categories | fall back to iteration order — destroys byte-identical output |
| `carry_forward_policy` | hardcode a policy — makes OQ-05 unchangeable without an engine change |
| `sink_category_id` | search for a sink — destroys purity, and it may not exist |

---

## 2. The result contract and the purity contract

### 2.1 `AllocationResult`

| Field | Type | Meaning |
|---|---|---|
| `line_items` | ordered list of `AllocationLine` | The allocations. **Ordering is part of the contract** — identical inputs produce an identically ordered list |
| `diagnostics` | ordered list of `DiagnosticEvent` | Human-readable narration of every acceptance and every redirect |
| `rule_version_id` | string | Echoed from the request |
| `summary` | `AllocationSummary` | Totals |

### 2.2 `AllocationLine`

| Field | Type | Meaning |
|---|---|---|
| `category_id` | string | |
| `amount_minor` | int64 | Always `> 0`. A line item is never zero — a category that accepts nothing produces **no line**, not a zero line |
| `reason` | enum | `BASE` \| `REDIRECT` \| `MANUAL_OVERRIDE` \| `SINK_TERMINAL` |
| `redirected_from_category_id` | string \| null | Set iff `reason = REDIRECT` or `SINK_TERMINAL` |
| `hop_count` | int | 0 for a base allocation; incremented per redirect |

> **Why no zero-amount lines.** A zero line would write a ledger row recording that no money moved,
> inflating the highest-volume table (PRD §7.3) with rows that carry no information. The fact that a
> category accepted nothing is recorded in `diagnostics`, where it belongs, and is what the preview
> shows the user (PRD §5.6 case I-2).

### 2.3 `DiagnosticEvent`

**Written for the user, not the developer.** Substage 6.4.3 renders these directly in the allocation
preview; if they read as developer output, that substage has nowhere to go.

| Field | Type | Meaning |
|---|---|---|
| `kind` | enum | `BASE_ALLOCATION` \| `CATEGORY_FILLED` \| `REDIRECTED` \| `PERIOD_FUNDED` \| `SINK_TERMINAL` \| `CYCLE_DEFENDED` \| `HOP_LIMIT_REACHED` \| `DEGRADED_TARGET` \| `OVERRIDE_APPLIED` \| `OVERRIDE_EXCEEDS_CEILING` |
| `category_id` | string | The category this concerns |
| `target_category_id` | string \| null | Where money went, when it moved |
| `amount_minor` | int64 \| null | The amount concerned |
| `severity` | enum | `INFO` \| `WARNING` |

The engine emits **structured** events with ids and amounts; the presentation layer turns them into
sentences and resolves ids to names. The engine does not build strings — it has no access to
category names and no locale.

### 2.4 `AllocationSummary`

| Field | Type | Meaning |
|---|---|---|
| `total_allocated_minor` | int64 | **Must equal `income_amount_minor` exactly** |
| `total_redirected_minor` | int64 | Sum of amounts that moved at least one hop |
| `categories_filled` | list of string | Categories that reached their ceiling or period cap during this run |
| `max_hop_count` | int | The deepest chain travelled; useful for diagnosing configuration |

### 2.5 The purity contract

The engine's entry point is:

```
allocate(AllocationRequest) -> Result<AllocationResult, AllocationFailure>
```

**Binding, and mechanically enforced by guard G2 (ARCHITECTURE §2.3):**

| # | Rule |
|---|---|
| P-1 | **Synchronous.** No `async`, no `await`, no `Future`, no `Stream`, no callback. The signature and body contain none of these |
| P-2 | **No I/O.** No file, network, database or platform channel access. The engine holds no repository |
| P-3 | **No clock.** `DateTime.now()` never appears. Time arrives as `evaluated_at_ms` |
| P-4 | **No randomness.** No RNG, no hash-order dependence, no `identityHashCode` |
| P-5 | **No global or static mutable state.** Every value the engine needs is a parameter or a local |
| P-6 | **No logging.** Diagnostics are returned in the result, never written to a log (ARCHITECTURE §8.2) |
| P-7 | **Byte-identical output for identical input**, including the ordering of `line_items` and `diagnostics` |
| P-8 | **No floating point.** No `double`, `float` or `num` in any expression, including intermediates — guard G3 |

**Consequence, stated so nobody has to discover it:** iteration over a map is forbidden anywhere the
result could depend on order. Every traversal is over an explicitly sorted list. This is the single
most common way P-7 gets broken in practice.

### 2.6 Failure behaviour

**The engine returns either a complete, conserved result or a typed failure. There is no third
outcome.** No partial allocation is ever returned, and no failure path emits line items. Substage
2.7.7 states this; §6 enumerates the failures.

---

## 3. Phase B — headroom, the worklist, redirects and termination

Phase A divided the income by percentage. Phase B resolves **capacity**: what each category can
actually accept, and where the rest goes. FR-10 and FR-11 live here, and this is where naive
implementations silently lose money.

### 3.1 Headroom, per category type

Headroom is how much a category can still accept **right now, in this run**.

| Type | Headroom |
|---|---|
| `ACCUMULATING_RESERVE` | `max(0, ceiling_minor − current_balance_minor − accepted_so_far)` |
| `FIXED_RECURRING` | `max(0, bill_amount_minor − allocated_in_current_period_minor − accepted_so_far)` |
| `UNCAPPED_FLOW` | **Unbounded** |
| Any category with `is_sink = true` | **Unbounded** — guaranteed by constraint C-19 |

**`max(0, …)` is not decoration.** A balance may exceed its ceiling — after a manual override
(§4), or after the user lowered a ceiling, or after a sync merge brought in entries from another
device. In those cases the subtraction is negative and headroom must clamp to zero. Without the
clamp, a negative headroom propagates into a negative allocation, `accepted = min(pending, headroom)`
returns a negative number, and conservation breaks. This is the case substage 5.3.5 calls "already
over ceiling"; it is common, not exotic.

**Unbounded must be represented explicitly**, as a distinct value — not as `int64.max`. If unbounded
were a very large number, `ceiling − balance − accepted_so_far` arithmetic against it would overflow
the moment anything is added. Substage 5.3.3 requires this, and the `must_not` is explicit: *do not
represent unbounded as int64 max, which then overflows when added to.*

### 3.2 `accepted_so_far` — the within-run tracker

**The single most commonly missed detail in this algorithm.**

Within one allocation run, a category can be reached more than once: once by its own base share from
phase A, and again by overflow redirected from another category. If headroom were computed once at
the start of the run and reused, both parcels would see the same headroom and both would be
accepted — putting the category above its ceiling and breaking FR-10.

`accepted_so_far` is a map from category id to the total accepted **during this run only**. It
starts empty, is added to on every acceptance, and is included in every headroom computation. It is
never persisted; the next run starts from the freshly derived balances.

> Substage 5.3.4 requires writing the test for the two-parcel case **before** writing the tracker.

### 3.3 The worklist

An **explicit FIFO queue**, not recursion. Recursion invites a stack overflow on a pathological
chain and hides the hop count, which is needed both for the termination guard and for the
diagnostics the user sees.

```
FUNCTION phase_b(parcels, categories, sink_id) -> list of AllocationLine

    queue          := parcels sorted by (sort_order ASC, id ASC)      // deterministic seeding
    accepted_so_far := empty map
    lines          := []
    diagnostics    := []

    WHILE queue is not empty:
        parcel := queue.removeFirst()                  // FIFO — front
        dest   := lookup(parcel.category_id)

        // --- degraded destination (§3.6) ---
        IF dest is missing OR dest.is_archived:
            redirect_to_sink(parcel, reason: DEGRADED_TARGET)
            CONTINUE

        room     := headroom(dest, accepted_so_far)     // §3.1
        accepted := min(parcel.pending, room)           // room may be UNBOUNDED → accepted = pending

        IF accepted > 0:
            lines += AllocationLine(
                category_id             : dest.id,
                amount_minor            : accepted,
                reason                  : parcel.reason,
                redirected_from_category_id : parcel.from_id,
                hop_count               : parcel.hops)
            accepted_so_far[dest.id] += accepted
            diagnostics += acceptance event

        overflow := parcel.pending − accepted
        IF overflow == 0:
            CONTINUE

        // --- the category is full; the surplus must go somewhere ---
        diagnostics += CATEGORY_FILLED or PERIOD_FUNDED event

        next_id := dest.redirect_target_category_id

        IF next_id is null:
            redirect_to_sink(overflow, reason: SINK_TERMINAL); CONTINUE
        IF next_id IN parcel.visited:
            redirect_to_sink(overflow, reason: SINK_TERMINAL, diag: CYCLE_DEFENDED); CONTINUE
        IF parcel.hops + 1 > MAX_HOPS:
            redirect_to_sink(overflow, reason: SINK_TERMINAL, diag: HOP_LIMIT_REACHED); CONTINUE

        queue.addLast(Parcel(                            // FIFO — back
            category_id : next_id,
            pending     : overflow,
            reason      : REDIRECT,
            from_id     : dest.id,
            hops        : parcel.hops + 1,
            visited     : parcel.visited ∪ {dest.id}))

    ASSERT sum(lines.amount_minor) == income_amount_minor      // §3.8
    RETURN lines, diagnostics
```

**`redirect_to_sink`** appends a parcel addressed to the run's sink with `reason = SINK_TERMINAL` and
an empty `visited` set. The sink is uncapped by construction (C-19), so that parcel always terminates
on its next pop.

### 3.4 The queue is FIFO, and that is observable

New parcels join the **back** of the queue. This is not an arbitrary choice — it changes what the
user sees, so it is fixed here rather than left to the implementer.

Consider a category whose base share is still queued when overflow arrives for it from elsewhere.
Under FIFO, the base share is processed first and the redirected parcel later, so the category
produces **two line items** with different reasons and hop counts. Under LIFO, or if parcels were
merged by destination, it would produce one combined line and the user would lose the ability to see
that part of the money arrived as overflow from a named category.

**Therefore:** parcels are never merged, never reordered after seeding, and always appended to the
back. The reference example in §3.9 shows exactly this happening, and vector V-05 asserts it.

### 3.5 Termination — three independent defences

INV-07 requires that redirect chains always terminate. Three mechanisms guarantee it, and the design
deliberately keeps all three rather than relying on any one:

| # | Defence | Trigger | Outcome |
|---|---|---|---|
| T-1 | **Visited set, per parcel** | The next target is already in this parcel's visited set | Remainder to the sink; `CYCLE_DEFENDED` warning |
| T-2 | **Hop limit** | `hops + 1 > MAX_HOPS` | Remainder to the sink; `HOP_LIMIT_REACHED` warning |
| T-3 | **The sink is uncapped** | Always | The final destination can never refuse, so the chain ends |

**`MAX_HOPS = 32`**, as recommended by substage 2.6.4. With at most 100 categories (PRD §7.1's Stress
profile), a legitimate chain longer than 32 hops indicates a configuration the user did not intend,
so terminating there and warning is more useful than following it.

**The visited set is per parcel, not shared across the run.** A shared set would wrongly block a
category from being reached twice by two legitimately different chains. Substage 5.4's
`common_pitfalls` names this exact error.

**Configuration-time cycle detection (§6, substage 2.10.3) does not remove the need for T-1.** A
merge can produce a cycle from two independently valid edits made on different devices, so the
configuration may be cyclic at the moment allocation runs. The runtime defence is not redundant with
the save-time check; it covers a case the save-time check structurally cannot.

### 3.6 Degraded redirect targets

A redirect target may be missing, archived, soft-deleted, or point at itself. Each of these is
possible after a sync merge even though validation forbids creating them locally.

**In every case: route the remainder to the sink, record a `DEGRADED_TARGET` warning in diagnostics,
and never throw.** Money is moving while the user watches; a crash here loses the whole event. A
warning that says "the category this was meant to go to is no longer available, so it went to
Unallocated buffer instead" is honest and recoverable.

Self-reference is additionally prevented at rest by constraint C-20, so it should be unreachable —
but it is handled anyway, because "should be unreachable" is not a guarantee across a merge.

### 3.7 A missing sink is a typed failure, not a warning

If `sink_category_id` names a category absent from the request, the engine returns `SinkMissing`
(§6) and allocates nothing.

This is deliberately different from a degraded redirect target. A missing redirect target has a safe
fallback — the sink. A missing **sink** has none: there is nowhere guaranteed to accept the money,
so proceeding would risk losing it. This is a configuration bug that validation (§6) should have
caught, and INV-07's guarantee depends on the sink existing, so the engine refuses rather than
improvising.

Same for a sink that is capped — `SinkIsCapped`. Constraint C-19 makes this unreachable at rest, but
the engine checks anyway, because the engine's termination proof depends on it.

### 3.8 The final conservation assertion

Before returning, and after every parcel has been resolved:

```
ASSERT sum(line.amount_minor for line in lines) == request.income_amount_minor
```

**On failure, throw with the full diagnostics trace attached.** Never adjust a line item to make the
sum work — the stage plan names that as an anti-pattern and it is the mechanism by which a rounding
bug becomes invisible and permanent. As in §5.7: a failed assertion means the engine is wrong, which
is the most serious defect class this project admits (INV-02).

Substage 5.4.8 requires demonstrating this assertion firing on a deliberately broken run, then
reverting.

### 3.9 The reference chained example, worked pop by pop

Three savings categories using seeded names. **Every intermediate value is shown so the arithmetic
can be checked by hand.**

**Setup** — the Savings group receives **300,000**:

| Category | sort | bp | Type | Ceiling | Balance before | Redirect target |
|---|---|---|---|---|---|---|
| Medical reserve | 1 | 4000 | ACCUMULATING_RESERVE | 500,000 | 420,000 | Emergency fund |
| Emergency fund | 2 | 3500 | ACCUMULATING_RESERVE | 1,000,000 | 900,000 | Trip savings |
| Trip savings | 3 | 2500 | UNCAPPED_FLOW | — | 12,500 | — |

**Phase A** — `split(300000, [4000, 3500, 2500])`:

| Category | product | floor | remainder |
|---|---|---|---|
| Medical | 300,000 × 4000 = 1,200,000,000 | 120,000 | 0 |
| Emergency | 300,000 × 3500 = 1,050,000,000 | 105,000 | 0 |
| Trip | 300,000 × 2500 = 750,000,000 | 75,000 | 0 |

`floor_sum = 300,000`, `leftover = 0`. No tie-break needed.

**Queue seeded** in `sort_order` order: `[Medical 120,000] [Emergency 105,000] [Trip 75,000]`.

**Phase B, pop by pop:**

| Pop | Parcel | Headroom at that moment | Accepted | Overflow | Queue action |
|---|---|---|---|---|---|
| 1 | Medical 120,000, hop 0 | `500,000 − 420,000 − 0 = 80,000` | **80,000** | 40,000 | Push `[Emergency 40,000, hop 1]` to **back** |
| 2 | Emergency 105,000, hop 0 | `1,000,000 − 900,000 − 0 = 100,000` | **100,000** | 5,000 | Push `[Trip 5,000, hop 1]` to **back** |
| 3 | Trip 75,000, hop 0 | unbounded | **75,000** | 0 | — |
| 4 | Emergency 40,000, hop 1 | `1,000,000 − 900,000 − 100,000 = 0` | **0** | 40,000 | Push `[Trip 40,000, hop 2]` to **back** |
| 5 | Trip 5,000, hop 1 | unbounded | **5,000** | 0 | — |
| 6 | Trip 40,000, hop 2 | unbounded | **40,000** | 0 | — |

**Line items produced — five, not three:**

| # | Category | Amount | Reason | Redirected from | Hops |
|---|---|---|---|---|---|
| 1 | Medical reserve | 80,000 | BASE | — | 0 |
| 2 | Emergency fund | 100,000 | BASE | — | 0 |
| 3 | Trip savings | 75,000 | BASE | — | 0 |
| 4 | Trip savings | 5,000 | REDIRECT | Emergency fund | 1 |
| 5 | Trip savings | 40,000 | REDIRECT | Emergency fund | 2 |

**Per-category totals:** Medical **80,000**, Emergency **100,000**, Trip 75,000 + 5,000 + 40,000 =
**120,000**.

**Conservation:** 80,000 + 100,000 + 120,000 = **300,000** ✓ — equals the group amount exactly.

**What pop 4 demonstrates.** By the time Medical's overflow reaches Emergency, `accepted_so_far` for
Emergency is already 100,000, so its headroom is exactly zero and it accepts nothing. Without
`accepted_so_far` (§3.2), pop 4 would have recomputed headroom as `1,000,000 − 900,000 = 100,000`
and accepted 40,000 — putting Emergency at 1,040,000, **40,000 above its ceiling**, and silently
breaking FR-10. This single row is why the tracker exists.

**Why Trip receives three separate lines rather than one of 120,000.** Because the queue is FIFO
(§3.4): Emergency's base parcel was already queued ahead of Medical's overflow, so the two arrive at
Trip separately and at different hop counts. The user therefore sees "75,000 by your rules, plus
5,000 and 40,000 that overflowed from Emergency fund" rather than an unexplained 120,000.

### 3.10 Diagnostics emitted by the reference example

In order, as the user would see them:

| # | Kind | Reads as |
|---|---|---|
| 1 | `BASE_ALLOCATION` | Medical reserve receives 80,000 |
| 2 | `CATEGORY_FILLED` | Medical reserve is now full at its target of 500,000 |
| 3 | `REDIRECTED` | 40,000 moves on to Emergency fund |
| 4 | `BASE_ALLOCATION` | Emergency fund receives 100,000 |
| 5 | `CATEGORY_FILLED` | Emergency fund is now full at its target of 1,000,000 |
| 6 | `REDIRECTED` | 5,000 moves on to Trip savings |
| 7 | `BASE_ALLOCATION` | Trip savings receives 75,000 |
| 8 | `REDIRECTED` | Emergency fund is full, so its 40,000 moves on to Trip savings |
| 9 | `REDIRECTED` | Trip savings receives 5,000 that overflowed |
| 10 | `REDIRECTED` | Trip savings receives 40,000 that overflowed |

Every hop is visible. PRD §5.6 case I-3 requires exactly this: *the user never sees money leave
category A and simply appear in category D unexplained.*

---

## 4. Manual overrides and reversals

### 4.1 What an override is

FR-12 lets the user adjust the split for **one payment** without changing their standing rules. The
override map arrives in the request (§1.1) as a verbatim record of user input: category id → amount
in minor units.

**An override is an input to the event, never an edit of its output.** This is assumption A-23 and
closes escalation E-02, and it is why `income_events.overrides_json` exists (SCHEMA §3.6). INV-08
requires identical inputs to produce byte-identical output; an override that modified results after
the engine ran would make the event unreproducible, and INV-11's promise that history stays
explainable would break at the next rule change.

### 4.2 Override semantics, step by step

```
1. Validate the override map (§4.4). On any failure, return it — allocate nothing.

2. overridden_total := sum of override amounts
   remaining       := income_amount_minor − overridden_total

3. Each overridden category takes its stated amount as a line item,
   with reason = MANUAL_OVERRIDE and hop_count = 0.
   These amounts BYPASS phase A entirely — they are not shares, they are instructions.

4. IF remaining == 0:
       No further distribution. Skip to phase B with only the override parcels.
   IF remaining > 0:
       Redistribute `remaining` across the NON-overridden categories,
       in proportion to their RELATIVE basis points (§4.3).

5. Feed all parcels — overridden and redistributed — into phase B (§3),
   with one exception stated in §4.5.
```

### 4.3 Redistribution is by relative weight, not evenly

The non-overridden categories rarely have basis points totalling 10000 between them, because the
overridden ones took some of that weight. Their **relative** proportions are preserved:

```
share_i := split(remaining, non_overridden_categories_with_their_raw_basis_points)
```

The split primitive from §5.1 is called **directly, with the non-overridden categories' raw basis
points**. No scaling step is needed, because the primitive derives its divisor from the weights it
is given (§5.2) — passing weights totalling 6000 makes 6000 the divisor, which is exactly the
relative-weight semantics required here.

**The primitive is called, never re-implemented** — substage 5.6.2 forbids a second rounding path,
because two rounding paths eventually disagree. That instruction is only safe given §5.2's rule
that the divisor comes from the inputs; an implementation that hardcodes 10000 satisfies every
phase A vector and silently under-distributes here.

Redistributing **evenly** instead of by weight is named as a pitfall by the stage plan and would
surprise the user: someone who set Emergency to 35% and Trip to 25% expects that ratio to survive
overriding a third category.

### 4.4 Override validation rules

Each returns its own typed failure from §6, and none allocates anything.

| # | Condition | Failure | Class |
|---|---|---|---|
| O-1 | `overridden_total > income_amount_minor` | `OverridesExceedIncome` | User input error |
| O-2 | Any override amount `< 0` | `OverrideNegative` | User input error |
| O-3 | Any override amount `> MAX_MONEY_MINOR` | `IncomeExceedsMaximum` | User input error |
| O-4 | `remaining > 0` **and** there are no non-overridden categories to receive it | `NoCategoriesAvailableForRemainder` | User input error |
| O-5 | An override names a category absent from the request | `OverrideTargetUnknown` | Configuration bug |

**`overridden_total == income_amount_minor` is valid**, not an error — the user has assigned every
unit explicitly and there is nothing to redistribute (substage 2.7.2 requires this to be stated).

**A zero override is an explicit instruction, not an absence.** `{cat_A: 0}` means "category A gets
nothing this time", which is different from omitting A (which means "A takes its normal share").
Substage 5.6's `common_pitfalls` names conflating these; the map's *keys* determine which categories
are overridden, and the values may legitimately be zero.

### 4.5 An override may exceed a ceiling — the I-1 policy

**Decision: permitted. The amount stays where the user put it and is not redirected away.**

This implements PRD §5.6 case I-1 and §4.7. When an overridden amount exceeds the destination's
headroom:

- The line item is written at the full overridden amount, `reason = MANUAL_OVERRIDE`.
- A `OVERRIDE_EXCEEDS_CEILING` diagnostic is emitted at `WARNING` severity.
- **The excess is not redirected.** Override parcels skip the phase B capacity check entirely.
- The category's balance may end above its ceiling. §3.1's `max(0, …)` then handles the
  already-over case at the *next* income event, where the category accepts nothing and redirects its
  whole share until spending brings it back under.

**The alternative and its consequence, recorded so the choice is visible** (substage 2.7.3 requires
this): the excess *could* be redirected like any other overflow. That was rejected because it makes
the override silently not do what the user typed — they enter 200,000 for Medical, press confirm,
and find 80,000 there. An explicit instruction that the app quietly overrules is worse than a
warning the user can act on. The cost of the chosen policy is that a category can sit above its
ceiling, which the design accommodates everywhere: §3.1 clamps headroom, SCHEMA has no constraint
forbidding it, and substage 8.3.5 requires the progress indicator to render an over-ceiling category
without clipping.

### 4.6 An override never touches the rule version

The rule version snapshot in the request is **read-only** to the engine. An override changes one
event's outcome and nothing else; the next income event previews by the standing rules, unchanged
(INV-11). Substage 5.6.5 requires a test asserting the snapshot is unmodified after an override.

### 4.7 Worked override example

Income of **500,000** to the Savings group. Medical is overridden to 200,000; Emergency (3500 bp) and
Trip (2500 bp) are not overridden.

```
overridden_total = 200,000
remaining        = 500,000 − 200,000 = 300,000
relative_total   = 3500 + 2500 = 6000
```

Redistribute 300,000 across Emergency and Trip by relative weight:

`weight_total = 6000` — derived from the weights passed in, per §5.2.

| Category | bp | `product = 300,000 × bp` | `product / 6000` | remainder |
|---|---|---|---|---|
| Emergency | 3500 | 1,050,000,000 | 175,000 | 0 |
| Trip | 2500 | 750,000,000 | 125,000 | 0 |

`floor_sum = 300,000`, `leftover = 0`.

**Result:** Medical **200,000** (MANUAL_OVERRIDE), Emergency **175,000** (BASE), Trip **125,000**
(BASE).

**Conservation:** 200,000 + 175,000 + 125,000 = **500,000** ✓

This is vector V-09. **The divisor is 6000, not 10000** — see §5.2. Dividing by 10000 here yields
105,000 and 75,000, totalling 180,000 against a `remaining` of 300,000: 120,000 would vanish. This
is the single most likely way an implementer reusing the primitive gets redistribution wrong, and
V-09 exists to catch it.

### 4.8 Reversal generation

A reversal undoes a previously confirmed income event. OQ-09's answer: available for any event,
however old, always leaving a visible pair.

**A reversal mirrors the recorded allocations. It does not re-run the algorithm.**

```
FUNCTION generate_reversal(original_event, original_entries) -> list of LedgerEntry

    GUARD original_event.is_reversal == false          → CannotReverseAReversal
    GUARD original_event.reversed_by_event_id == null  → AlreadyReversed

    reversal_entries := []
    FOR EACH entry IN original_entries:
        reversal_entries += LedgerEntry(
            id                : new UUID v7,
            category_id       : entry.category_id,
            account_id        : entry.account_id,
            direction         : OPPOSITE of entry.direction,
            amount_minor      : entry.amount_minor,          // same magnitude
            source_type       : REVERSAL,
            source_id         : reversal_event.id,
            reverses_entry_id : entry.id,
            reason            : entry.reason,
            hop_count         : entry.hop_count)

    ASSERT sum(reversal_entries) == sum(original_entries)    // equal magnitude, opposite direction
    RETURN reversal_entries
```

**Why mirroring rather than recomputing — the critical reason.** If the user changed their
percentages between the event and the reversal, re-running the engine would produce *different*
amounts, and subtracting those would leave every affected balance wrong. Worse, if a ceiling was
involved, the recomputed split would differ structurally: the categories were in different states
then. Mirroring is the only method that returns every balance to exactly its pre-event value
regardless of what changed in between.

Substage 5.7.5 requires exactly this test: change the distribution rules between the event and its
reversal, then assert every affected balance returns exactly to its pre-event value.

**Guards:**

| # | Guard | Reason |
|---|---|---|
| R-1 | An event cannot be reversed twice | Silently doubles the correction |
| R-2 | A reversal cannot itself be reversed | Use a new income event instead; reversing a reversal is indistinguishable from re-entering the money and makes history harder to read |

**Nothing about the original is modified.** The link is recorded on the *new* rows
(`reverses_entry_id`) and by setting `income_events.reversed_by_event_id` on the original — the one
permitted mutation, on the event row, never on a ledger entry. Substage 4.5.6 specifies how
"reversed" is represented without mutating an immutable ledger row: by lookup, not by flag.

---

## 6. The error taxonomy

Every failure the engine can return. **Sealed** — Stage 5 implements exactly these and adds none.

Each says whether it is a **configuration bug** (validation §6 of SCHEMA should have prevented it;
if it reaches the engine, something upstream failed) or a **user input error** (the user can fix it
directly, and the UI should say how).

| # | Failure | Condition | Class | Carries | UI intent |
|---|---|---|---|---|---|
| E-01 | `IncomeNotPositive` | `income_amount_minor <= 0` | User input | the amount | "Enter an amount greater than zero" |
| E-02 | `IncomeExceedsMaximum` | `income_amount_minor > MAX_MONEY_MINOR`, or any override above it | User input | the amount, the maximum | State the limit; this is effectively unreachable in real use |
| E-03 | `GroupBasisPointsInvalid` | Group shares do not total exactly 10000, or one is outside 0–10000 | Configuration bug | the actual total, the offending group | Route the user to the group percentage screen |
| E-04 | `CategoryBasisPointsInvalid` | Within some group, category shares do not total exactly 10000 | Configuration bug | the group, the actual total | Route to that group's category percentages |
| E-05 | `EmptyGroupWithNonZeroShare` | A group has a non-zero share but no active categories | Configuration bug | the group | "This group receives money but has nowhere to put it" — offer to add a category or zero the group |
| E-06 | `SinkMissing` | `sink_category_id` names no category in the request | Configuration bug | the id sought | Serious; route to a repair path. §3.7 explains why this is fatal rather than a warning |
| E-07 | `SinkIsCapped` | The named sink has a ceiling or a bill amount | Configuration bug | the sink id | Serious; INV-07's termination proof depends on the sink being uncapped |
| E-08 | `OverridesExceedIncome` | Override amounts total more than the income | User input | the total, the income, the difference | Show the difference in place; confirmation stays blocked (US-016) |
| E-09 | `OverrideNegative` | Any override amount is below zero | User input | the category, the amount | Reject on the spot |
| E-10 | `NoCategoriesAvailableForRemainder` | Money remains after overrides but no non-overridden category can take it | User input | the remaining amount | "Assign the remaining X, or leave a category un-overridden" |
| E-11 | `OverrideTargetUnknown` | An override names a category absent from the request | Configuration bug | the unknown id | Indicates a stale UI; reload the configuration |
| E-12 | `PeriodDefinitionInvalid` | `period.start_ms >= period.end_ms`, or the anchor day is outside 1–31 | Configuration bug | the period | Should be unreachable; C-05 constrains the anchor at rest |

### 6.1 Warnings are not failures

These conditions are **recorded in diagnostics and do not stop the allocation.** They are listed
here so the boundary between "warn" and "fail" is explicit rather than a judgement call at
implementation time:

| Condition | Diagnostic | Why not a failure |
|---|---|---|
| A redirect target is missing, archived or deleted | `DEGRADED_TARGET` | The sink is a safe fallback (§3.6) |
| A redirect chain contains a cycle | `CYCLE_DEFENDED` | T-1 handles it; the money still lands (§3.5) |
| A chain exceeds `MAX_HOPS` | `HOP_LIMIT_REACHED` | T-2 handles it; the money still lands |
| An override pushes a category past its ceiling | `OVERRIDE_EXCEEDS_CEILING` | The user asked for it explicitly (§4.5) |
| A fixed-recurring category is already funded | `PERIOD_FUNDED` | Correct behaviour, not an error (PRD I-2) |

**The distinguishing rule:** it is a failure when the engine cannot produce a conserved result, and a
warning when it can but the user should know something unexpected happened.

### 6.2 No partial results, ever

**On any failure the engine returns the failure alone — no line items, no partial allocation, no
"best effort".** Substage 2.7.7 requires this and substage 5.1 implements it.

The reason is that a partial allocation is worse than no allocation: the caller would have to decide
whether to write it, and a partially written income event breaks conservation permanently in the
ledger, which INV-03 then makes unfixable by editing. A failure the user can act on is recoverable;
a half-allocated event is not.

---

## 5. Phase A — the base split

Phase A divides the income by percentage, using integer arithmetic only. Phase B (§3) then resolves
capacity. The two are separate because phase A's job — dividing exactly, with no unit lost — is a
solved problem with a known-correct method, and mixing it with capacity resolution is how
implementations lose units.

### 5.1 The largest-remainder method

Given an `amount` and a list of weights in basis points totalling exactly 10000, produce integer
shares summing to exactly `amount`.

```
FUNCTION split(amount, weights) -> list of int64
    // weights: list of (key, basis_points, sort_order, id)
    // PRECONDITION: sum of basis_points > 0
    // PRECONDITION: 0 < amount <= MAX_MONEY_MINOR

    weight_total := sum of w.basis_points over weights    // 10000 in the normal case;
                                                          // the RELATIVE total under override (§4.3)
    floors     := []
    remainders := []

    FOR EACH w IN weights:                       // in given order; sorting happens later
        product   := amount * w.basis_points     // int64; bounded by §5.6
        floors    += product / weight_total      // integer division, truncates toward zero
        remainders += product % weight_total     // exact remainder, 0 .. weight_total-1

    floor_sum := sum(floors)
    leftover  := amount - floor_sum              // ALWAYS 0 <= leftover < count(weights)

    // Distribute the leftover, one minor unit at a time, to the largest remainders.
    order := indices of weights
             SORTED BY remainders[i]        DESCENDING,
                  THEN weights[i].sort_order ASCENDING,
                  THEN weights[i].id         ASCENDING (ordinal string comparison)

    result := copy of floors
    FOR i := 0 TO leftover - 1:
        result[order[i]] += 1

    ASSERT sum(result) == amount                 // §5.7
    RETURN result
```

**Why `leftover` is always less than the number of weights.** Each share's discarded fraction is
strictly less than one minor unit, so the total discarded is strictly less than the count of
weights. Distributing one unit to each of the first `leftover` entries is therefore always possible
and never exhausts the list.

### 5.2 Integer division, and why the divisor is `weight_total` rather than 10000

`product / weight_total` is **integer division truncating toward zero**, and `product % weight_total`
is the matching non-negative remainder. Since `amount > 0` and `basis_points ≥ 0`, `product` is never
negative and the two are unambiguous. Stage 5 must not use any operation that rounds.

**The divisor is the sum of the weights actually passed in, never the constant 10000.** In the two
phase A applications (§5.3) the weights total exactly 10000, so the two are identical. But override
redistribution (§4.3) passes only the *non-overridden* categories, whose basis points total less than
10000 — 6000 in the worked example. Dividing those by 10000 would produce shares summing to 60% of
the amount, leaving 40% undistributed and `leftover` enormously larger than the number of weights.

> **This was a real defect in an earlier draft of this section**, caught by executing the algorithm
> against vector V-09 rather than checking it by eye. It is recorded here rather than quietly
> corrected, because "reuse the split primitive for redistribution" (§4.3, and substage 5.6.2's
> instruction not to write a second rounding path) is only safe if the primitive derives its divisor
> from its inputs. An implementation that hardcodes 10000 will pass every phase A vector and fail
> only under override.

The invariant that makes the method correct is therefore: **`sum(result) == amount` for any weight
list whose basis points sum to a positive value** — not "whose basis points sum to 10000". The
10000 requirement is a *configuration* rule enforced by validation (failures E-03 and E-04), not a
precondition of this function.

### 5.3 The two applications

The **identical routine** runs twice — this is one function called twice, never two implementations
(substage 5.2.3 forbids a second copy, because two copies diverge):

1. **Across groups.** `split(income_amount_minor, group_shares)` → each group's amount.
2. **Within each group.** `split(group_amount, categories_of_that_group)` → each category's base
   allocation.

A group receiving 0 is skipped entirely; splitting 0 across its categories would produce nothing but
is wasted work, and the validation in §6 already guarantees a zero-share group is permitted to be
empty.

### 5.4 The tie-break, stated so a reader can predict the winner

When two candidates have equal remainder numerators, the leftover unit goes to:

1. the one with the **lower `sort_order`**; and if those are equal,
2. the one with the **lower `id`**, compared as an **ordinal (code-unit) string comparison**, not a
   locale-aware one.

Ids are UUIDs, so they are always distinct and step 2 always resolves. **Locale-aware comparison is
forbidden** — it would make output depend on device locale and break P-7 across devices, which is
exactly the kind of defect that only appears after release on someone else's phone.

**Worked tie-break — vector V-03.** Income of 3 minor units across three categories at
3333 / 3333 / 3334 basis points:

| Category | bp | `product = 3 × bp` | floor | remainder |
|---|---|---|---|---|
| A (sort 1) | 3333 | 9,999 | 0 | 9,999 |
| B (sort 2) | 3333 | 9,999 | 0 | 9,999 |
| C (sort 3) | 3334 | 10,002 | 1 | 2 |

`floor_sum = 1`, so `leftover = 3 − 1 = 2`.
Sort by remainder descending: A and B tie at 9,999 → broken by `sort_order`, so **A then B**; then C
at 2.
The two leftover units go to A and B.

**Result: A = 1, B = 1, C = 1.** Total 3 ✓.

Note what would happen without the tie-break: A and B are indistinguishable by remainder, so the
winner would depend on sort stability and map ordering — the output would differ between runs,
platforms or Dart versions. This vector exists precisely to lock that down.

### 5.5 Second worked example — vector V-02

Income of 100 across the same weights:

| Category | bp | `product = 100 × bp` | floor | remainder |
|---|---|---|---|---|
| A | 3333 | 333,300 | 33 | 3,300 |
| B | 3333 | 333,300 | 33 | 3,300 |
| C | 3334 | 333,400 | 33 | 3,400 |

`floor_sum = 99`, `leftover = 1`. Largest remainder is C at 3,400.

**Result: A = 33, B = 33, C = 34.** Total 100 ✓.

### 5.6 The overflow bound and the documented maximum income

The only multiplication in the algorithm is `amount × basis_points`, where `basis_points ≤ 10000`.
The bound follows directly.

**Derivation:**

```
int64 maximum                = 2^63 − 1     = 9,223,372,036,854,775,807
Largest possible multiplier  = 10,000       (basis points)

Require:  amount × 10,000 ≤ 9,223,372,036,854,775,807
          amount          ≤ 9,223,372,036,854,775,807 / 10,000
          amount          ≤ 922,337,203,685,477.5807

MAX_MONEY_MINOR = 922,337,203,685,477      (floor)
```

**Verification that the bound is exact and tight:**

```
922,337,203,685,477 × 10,000 = 9,223,372,036,854,770,000  ≤ 9,223,372,036,854,775,807   ✓ fits
922,337,203,685,478 × 10,000 = 9,223,372,036,854,780,000  >  9,223,372,036,854,775,807   ✗ overflows
```

**`MAX_MONEY_MINOR = 922,337,203,685,477` minor units.** In a two-decimal currency that is
9,223,372,036,854.77 currency units — roughly nine trillion. No real income approaches it; the bound
exists so that a corrupted input or a malicious paste fails cleanly rather than wrapping into a
negative allocation.

**The bound applies to every money value in the request, not just the income.** Validation rejects
any `income_amount_minor`, `ceiling_minor`, `bill_amount_minor`, `current_balance_minor` (by absolute
value) or override amount exceeding it.

**Why that is sufficient for every other operation.** Beyond the multiplication, the engine only
adds and subtracts a small, fixed number of bounded values — headroom is
`ceiling − balance − accepted_so_far`, three such values. The worst case is three times the bound:

```
3 × 922,337,203,685,477 ≈ 2.77 × 10^15   versus int64 max ≈ 9.22 × 10^18
```

A margin of roughly 3,300×. No addition or subtraction in the engine can overflow once every input
is within `MAX_MONEY_MINOR`.

An income above the maximum returns `IncomeExceedsMaximum` (§6) rather than wrapping — substage
5.2.4 implements the check, and vector V-15 exercises a value near the bound.

### 5.7 Phase A conservation assertions

Two assertions run **inside** the engine. They are correctness checks, not error handling.

| # | Assertion | Where |
|---|---|---|
| A-1 | `sum(group_amounts) == income_amount_minor` | After the group split |
| A-2 | For each group, `sum(category_base_amounts) == that group's amount` | After each within-group split |

**These fail loudly.** They throw — they do not return a typed failure and they never adjust a value
to make a sum work. The distinction matters and is deliberate:

- A **typed failure** means the *inputs* were unacceptable. The user can fix it. It is a value.
- An **assertion breach** means the *engine* is wrong. The user cannot fix it, and continuing would
  silently create or destroy money. It is a bug, and INV-02 makes it the most serious kind this
  project can have.

Substage 5.2.5 requires demonstrating that a deliberately broken split trips these assertions, then
reverting. An assertion that has never fired has never been tested.

> **Never "fix" a conservation failure by adjusting the last allocation.** The stage plan names this
> as an anti-pattern, and it is the mechanism by which a rounding bug becomes invisible and
> permanent. If the sum is wrong, the algorithm is wrong.

### 5.8 Phase A output

Phase A produces, for each category with a non-zero base amount, a **parcel**: a category id and a
pending amount. These become the initial worklist for phase B (§3) in deterministic order —
`sort_order` then `id` — which is what makes the whole allocation reproducible.

---

## 7. Complete pseudocode

End to end, integer-only, every loop bounded, assertions inline where they run.

```
CONSTANT MAX_MONEY_MINOR = 922_337_203_685_477      // §5.6, derived
CONSTANT MAX_HOPS        = 32                        // §3.5

FUNCTION allocate(req) -> Result<AllocationResult, AllocationFailure>

    // ---------- 1. VALIDATION — return before computing anything (§6) ----------
    IF req.income_amount_minor <= 0                 RETURN Fail(IncomeNotPositive)
    IF req.income_amount_minor > MAX_MONEY_MINOR    RETURN Fail(IncomeExceedsMaximum)
    IF req.period.start_ms >= req.period.end_ms     RETURN Fail(PeriodDefinitionInvalid)
    IF req.period.anchor_day NOT IN 1..31           RETURN Fail(PeriodDefinitionInvalid)

    IF sum(g.basis_points for g in req.group_shares) != 10000
                                                    RETURN Fail(GroupBasisPointsInvalid)
    FOR EACH g IN req.group_shares:
        cats_in_g := [c in req.categories WHERE c.group_id == g.group_id]
        IF g.basis_points > 0 AND cats_in_g is empty
                                                    RETURN Fail(EmptyGroupWithNonZeroShare(g))
        IF cats_in_g not empty AND sum(c.basis_points for c in cats_in_g) != 10000
                                                    RETURN Fail(CategoryBasisPointsInvalid(g))

    sink := lookup(req.categories, active_sink_id(req))     // business sink when scope==BUSINESS
    IF sink is null                                 RETURN Fail(SinkMissing)
    IF sink.ceiling_minor != null OR sink.bill_amount_minor != null
                                                    RETURN Fail(SinkIsCapped)

    FOR EACH c IN req.categories:
        IF |c.current_balance_minor| > MAX_MONEY_MINOR   RETURN Fail(IncomeExceedsMaximum)
        IF c.ceiling_minor    > MAX_MONEY_MINOR          RETURN Fail(IncomeExceedsMaximum)
        IF c.bill_amount_minor > MAX_MONEY_MINOR         RETURN Fail(IncomeExceedsMaximum)

    // ---------- 2. PARCEL CONSTRUCTION ----------
    IF req.overrides is not empty:
        parcels := build_override_parcels(req)      // §4.2; may return a failure
        IF parcels is a failure RETURN it
    ELSE:
        parcels := build_base_parcels(req)          // phase A, §5

    // ---------- 3. PHASE B — capacity resolution (§3.3) ----------
    lines, diagnostics := phase_b(parcels, req, sink)

    // ---------- 4. FINAL CONSERVATION ASSERTION (§3.8) ----------
    ASSERT sum(l.amount_minor for l in lines) == req.income_amount_minor
           ELSE THROW ConservationViolation(lines, diagnostics)   // a bug, not a failure

    RETURN Ok(AllocationResult(lines, diagnostics, req.rule_version_id, summarise(lines)))


FUNCTION build_base_parcels(req) -> list of Parcel
    group_amounts := split(req.income_amount_minor, req.group_shares)      // §5.1
    ASSERT sum(group_amounts) == req.income_amount_minor                    // A-1, §5.7

    parcels := []
    FOR EACH (g, amount) IN zip(req.group_shares, group_amounts):
        IF amount == 0: CONTINUE                                            // §5.3
        cats := [c in req.categories WHERE c.group_id == g.group_id]
               SORTED BY (sort_order ASC, id ASC)
        shares := split(amount, cats)                                       // §5.1, same function
        ASSERT sum(shares) == amount                                        // A-2, §5.7
        FOR EACH (c, share) IN zip(cats, shares):
            IF share > 0:                                                   // no zero lines, §2.2
                parcels += Parcel(c.id, share, reason: BASE, from: null,
                                  hops: 0, visited: {}, bypass_capacity: false)
    RETURN parcels


FUNCTION build_override_parcels(req) -> list of Parcel | failure
    // §4.2 and §4.4
    overridden_total := 0
    FOR EACH (cat_id, amount) IN req.overrides:
        IF amount < 0                      RETURN Fail(OverrideNegative(cat_id))
        IF amount > MAX_MONEY_MINOR        RETURN Fail(IncomeExceedsMaximum)
        IF lookup(req.categories, cat_id) is null
                                           RETURN Fail(OverrideTargetUnknown(cat_id))
        overridden_total += amount
    IF overridden_total > req.income_amount_minor
                                           RETURN Fail(OverridesExceedIncome)

    parcels := []
    FOR EACH (cat_id, amount) IN req.overrides SORTED BY cat_id:
        IF amount > 0:
            parcels += Parcel(cat_id, amount, reason: MANUAL_OVERRIDE, from: null,
                              hops: 0, visited: {}, bypass_capacity: TRUE)   // §4.5

    remaining := req.income_amount_minor - overridden_total
    IF remaining > 0:
        others := [c in req.categories WHERE c.id NOT IN req.overrides.keys]
                  SORTED BY (sort_order ASC, id ASC)
        IF others is empty                 RETURN Fail(NoCategoriesAvailableForRemainder)
        shares := split(remaining, others)      // divisor = their OWN total, §5.2
        FOR EACH (c, share) IN zip(others, shares):
            IF share > 0:
                parcels += Parcel(c.id, share, reason: BASE, from: null,
                                  hops: 0, visited: {}, bypass_capacity: false)
    RETURN parcels
```

`split` is §5.1 and `phase_b` is §3.3; both are reproduced there in full and not repeated here.

**Loop bounds, for the termination argument.** `build_base_parcels` is bounded by the category
count. `phase_b`'s queue is bounded because every parcel either terminates or advances: it gains a
hop and a visited entry, and both `MAX_HOPS` and the finite category set cap that growth, with the
uncapped sink absorbing anything that hits either limit. No loop in this algorithm is unbounded.

---

## 8. Worked examples

Four examples, each already worked through in full with every intermediate value shown. They are
cross-referenced rather than repeated:

| Example | Where | Demonstrates |
|---|---|---|
| Tie-break at equal remainders | §5.4 | Why the tie-break exists; without it the output varies by platform |
| Ordinary rounding | §5.5 | The largest-remainder method on a simple case |
| The chained multi-hop redirect | §3.9 | `accepted_so_far`, FIFO ordering, five line items from three categories |
| Override with redistribution | §4.7 | The relative-total divisor, and the 120,000 that vanishes if it is 10000 |

**Every figure in all four was verified by executing the algorithm**, not by inspection — see §10.2.

---

## 9. Golden vector fixtures and the required properties

### 9.1 Fixture format

Vectors are stored one per file under `test/fixtures/allocation/`. Stage 3 substage 3.8.5 builds a
loader that reads the directory and yields cases, so **adding a vector requires no code change**.

```jsonc
{
  "id": "V-05",
  "description": "chained multi-hop redirect ending in an uncapped category",
  "request": {
    "income_amount_minor": 300000,
    "evaluated_at_ms": 1750000000000,
    "rule_version_id": "rv-test-001",
    "scope": "PERSONAL",
    "sink_category_id": "trip",
    "business_sink_category_id": null,
    "overrides": null,
    "period": { "start_ms": 1748736000000, "end_ms": 1751328000000, "anchor_day": 1 },
    "group_shares": [
      { "group_id": "SAVINGS", "kind": "SAVINGS", "basis_points": 10000, "sort_order": 1 }
    ],
    "categories": [
      { "id": "medical",   "group_id": "SAVINGS", "type": "ACCUMULATING_RESERVE",
        "basis_points": 4000, "sort_order": 1,
        "current_balance_minor": 420000, "ceiling_minor": 500000,
        "bill_amount_minor": null, "allocated_in_current_period_minor": 0,
        "redirect_target_category_id": "emergency", "is_sink": false,
        "carry_forward_policy": "CARRY_FORWARD" }
      // … emergency, trip
    ]
  },
  "expected_allocations": [
    { "category_id": "medical",   "amount_minor":  80000, "reason": "BASE",     "redirected_from_category_id": null,        "hop_count": 0 },
    { "category_id": "emergency", "amount_minor": 100000, "reason": "BASE",     "redirected_from_category_id": null,        "hop_count": 0 },
    { "category_id": "trip",      "amount_minor":  75000, "reason": "BASE",     "redirected_from_category_id": null,        "hop_count": 0 },
    { "category_id": "trip",      "amount_minor":   5000, "reason": "REDIRECT", "redirected_from_category_id": "emergency", "hop_count": 1 },
    { "category_id": "trip",      "amount_minor":  40000, "reason": "REDIRECT", "redirected_from_category_id": "emergency", "hop_count": 2 }
  ],
  "expected_total_minor": 300000,
  "expected_failure": null,
  "notes": "Line-item shape is part of the assertion, not just per-category totals — see §3.4."
}
```

**Rules for the format:**

- Exactly one of `expected_allocations` and `expected_failure` is non-null. A fixture format that
  cannot express an expected failure causes the rejection cases to be quietly omitted, which is
  named as a pitfall by substage 5.8.
- `expected_total_minor` is asserted **in addition to** the per-item amounts, so conservation is
  checked even if a future edit changes the line-item shape.
- All monetary values are integers. **No decimal point may appear anywhere in a fixture** — this is
  part of INV-01 and applies to test data as strictly as to production code.
- `expected_allocations` is **ordered**, and the order is asserted. Determinism (P4) is otherwise
  untested.

### 9.2 The seven properties Stage 5 must verify

Design requirements, not an implementer's idea. Substage 5.9 implements these over thousands of
generated configurations.

| # | Property | Statement | Note |
|---|---|---|---|
| **P1** | Conservation | `sum(line.amount_minor) == income_amount_minor`, exactly, for every generated case | The central property; INV-02 |
| **P2** | Non-negativity | No line item has a negative amount, and no line has amount zero | Zero lines are suppressed (§2.2), so their absence is also asserted |
| **P3** | Ceiling respect | No `ACCUMULATING_RESERVE` ends above its ceiling **unless** a `MANUAL_OVERRIDE` line caused it, in which case that line is marked accordingly | The exception is the I-1 policy (§4.5), so the property must encode it rather than forbid it |
| **P4** | Determinism | Running the same request twice produces byte-identical output, including the order of `line_items` and `diagnostics` | INV-08 |
| **P5** | Termination | Every case completes within `MAX_HOPS`, with no stack overflow and no unbounded loop | Generated configurations include deliberate cycles |
| **P6** | Input-order independence | Shuffling the order of `categories` and `group_shares` in the request does not change the result | This is what proves the sort keys are doing the work rather than incidental input order |
| **P7** | Scaling | With no ceilings in play, doubling the income changes each allocation by its doubled share to within at most one minor unit | Bounds rounding drift; the one-unit tolerance is inherent to largest-remainder |

**P6 is the property most likely to fail on a first implementation**, because it catches any
reliance on map iteration order — the exact defect purity rule P-7's consequence note warns about.

### 9.3 Generator requirements

Substage 5.9.1's generator must produce, over its case space: 1 to 60 categories across the three
groups; valid basis-point splits totalling exactly 10000 at both levels; ceilings and balances
including **already-over-ceiling** states; redirect graphs with long chains and deliberate cycles;
fixed-recurring categories in varied period states; and always a valid uncapped sink.

A generator that never produces the interesting cases makes every property pass vacuously — named
as a pitfall by substage 5.9. Substage 5.9.4 requires the seed to be recorded so any failure
reproduces.

---

## 10. The golden vector table

Fifteen vectors. **Every expected value below was produced by executing the algorithm specified in
this document, not by inspection** — see §10.2 for the method and §10.3 for what that caught.

Configurations use a single `SAVINGS` group at 10000 basis points unless stated otherwise.

| # | Case | Input | Expected result |
|---|---|---|---|
| **V-01** | Plain three-group split | 1,000,000 across groups 5000 / 3000 / 2000, one uncapped category each | spend **500,000**, save **300,000**, biz **200,000** · total 1,000,000 |
| **V-02** | Largest-remainder rounding | 100 across 3333 / 3333 / 3334 | **33 / 33 / 34** · total 100 |
| **V-03** | Rounding tie-break | 3 across 3333 / 3333 / 3334 | **1 / 1 / 1** · floors 0/0/1, remainders 9999/9999/2, leftover 2 to A and B by `sort_order` |
| **V-04** | Single ceiling redirect | 300,000; Medical 4000bp ceiling 500,000 balance 420,000 → Buffer 6000bp uncapped | Medical **80,000** BASE; Buffer **180,000** BASE; Buffer **40,000** REDIRECT from Medical hop 1 · total 300,000 |
| **V-05** | Chained multi-hop redirect | 300,000; the §3.9 configuration | Medical **80,000**; Emergency **100,000**; Trip **75,000** BASE + **5,000** hop 1 + **40,000** hop 2 — **five line items** · totals 80,000 / 100,000 / 120,000 = 300,000 |
| **V-06** | Everything full lands in the sink | 100,000; A and B both at ceiling, A→B→sink | Sink **50,000** hop 1 + **50,000** hop 2 · sink total 100,000 |
| **V-07** | Redirect cycle defended at runtime | 100,000; A→B and B→A, both full, sink present | Sink **50,000** SINK_TERMINAL from B hop 2 + **50,000** from A hop 2 · total 100,000 · two `CYCLE_DEFENDED` diagnostics · terminates |
| **V-08** | Fixed-recurring overflow | 300,000; Internet bill 250,000 with 200,000 already allocated this period, 4000bp → Buffer | Internet **50,000** BASE; Buffer **180,000** BASE; Buffer **70,000** REDIRECT hop 1 · total 300,000 |
| **V-09** | Override with redistribution | 500,000; Medical overridden to 200,000; Emergency 3500bp, Trip 2500bp | Medical **200,000** MANUAL_OVERRIDE; Emergency **175,000**; Trip **125,000** · total 500,000 · divisor 6000 |
| **V-10** | Override exceeding income | 100,000 with Medical overridden to 150,000 | **Fail: `OverridesExceedIncome`** · no line items |
| **V-11a** | Zero income | 0 | **Fail: `IncomeNotPositive`** |
| **V-11b** | Negative income | −500 | **Fail: `IncomeNotPositive`** |
| **V-12** | Group with share but no categories | Groups 5000 / 5000; SAVINGS has no active categories | **Fail: `EmptyGroupWithNonZeroShare`** |
| **V-13** | Smallest indivisible income | 1 across 3333 / 3333 / 3334 | **C = 1**, a **single** line item — A and B produce no line, per §2.2 |
| **V-14** | Simultaneous ceiling hits to one target | 100,000; A, B, C all full at 3000bp each → Buffer 1000bp | Buffer **10,000** BASE + **30,000** from A + **30,000** from B + **30,000** from C, all hop 1 · buffer total 100,000 |
| **V-15** | Very large income near the maximum | `MAX_MONEY_MINOR` = 922,337,203,685,477 across 40 uncapped categories at 250bp each | **37 categories at 23,058,430,092,137** and **3 at 23,058,430,092,136** · total 922,337,203,685,477 exactly |

**Sixteen fixture files for fifteen vectors** — V-11 is split into `v11a` and `v11b` because the
fixture format holds one request per file.

### 10.1 Coverage of this table

| Concern | Vectors |
|---|---|
| Percentage split and rounding | V-01, V-02, V-03, V-13, V-15 |
| Determinism and tie-breaking | V-03, V-15 |
| Ceilings and redirects | V-04, V-05, V-06, V-14 |
| Termination defences | V-06, V-07 |
| Fixed-recurring period logic | V-08 |
| Manual override | V-09, V-10 |
| Input rejection | V-10, V-11a, V-11b, V-12 |
| Boundary values | V-13 (smallest), V-15 (largest) |

### 10.2 How these values were produced

Substage 2.8.4 requires every expected value to be verified independently and forbids carrying an
unverified value into Stage 5, where it would become "a test that enshrines a bug".

The method used was stronger than hand-checking: **the algorithm as specified in §5.1, §5.2, §3.1,
§3.3 and §4.2 was implemented in a scratch script and all fifteen vectors were executed through it.**
Each result was then compared against the independently reasoned expectation. Where the two
disagreed, the disagreement was investigated rather than resolved in favour of either side.

### 10.3 What that caught — a genuine defect in this document

Executing V-09 revealed that the split primitive, as originally written in §5.1, divided by the
constant **10000**. That is correct for both phase A applications, where weights total exactly 10000
— and wrong for override redistribution, where the non-overridden categories' weights total 6000.

With the constant divisor, V-09 would have produced Emergency 105,000 and Trip 75,000: a total of
180,000 against a `remaining` of 300,000, **leaving 120,000 undistributed** and driving `leftover`
to 120,000 against a two-item weight list.

The defect is now fixed in §5.1 and §5.2, with the reasoning recorded rather than silently
corrected. It is worth stating plainly what it demonstrates: **the design would have passed every
phase A vector and failed only under override**, and inspection had not caught it across two
readings. This is the concrete justification for substage 2.8.4's rule.

### 10.4 Verified output

All fifteen vectors, executed against the corrected algorithm:

```
V-01  spend 500000 / save 300000 / biz 200000                       sum=1000000  conserved
V-02  A 33 / B 33 / C 34                                            sum=100      conserved
V-03  A 1 / B 1 / C 1                                               sum=3        conserved
V-04  medical 80000 | buffer 180000 + 40000 REDIRECT hop1           sum=300000   conserved
V-05  medical 80000 | emergency 100000 | trip 75000+5000+40000      sum=300000   conserved
V-06  sink 50000 hop1 + 50000 hop2                                  sum=100000   conserved
V-07  sink 50000 SINK_TERMINAL from b hop2 + 50000 from a hop2      sum=100000   conserved
V-08  internet 50000 | buffer 180000 + 70000 REDIRECT hop1          sum=300000   conserved
V-09  medical 200000 OVERRIDE | emergency 175000 | trip 125000      sum=500000   conserved
V-10  FAILURE -> OverridesExceedIncome
V-11a FAILURE -> IncomeNotPositive
V-11b FAILURE -> IncomeNotPositive
V-12  FAILURE -> EmptyGroupWithNonZeroShare
V-13  C 1  (single line item; A and B suppressed)                   sum=1        conserved
V-14  buffer 10000 BASE + 30000 from a + 30000 from b + 30000 from c sum=100000  conserved
V-15  40 lines: 37 at 23058430092137, 3 at 23058430092136           sum=922337203685477  conserved
```

Stage 5 substage 5.8.5 must confirm these trace to this document or to a recorded hand calculation —
they trace here, and the execution method is recorded above.
