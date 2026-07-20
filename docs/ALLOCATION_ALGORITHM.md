# PookieBudget — the allocation algorithm

| | |
|---|---|
| **Status** | In progress — Stage 2 |
| **Derived from** | `docs/PRD.md` §4 (money model), §5.6 (interaction cases); manifest INV-01, INV-02, INV-07, INV-08 |
| **Sections assembled** | 1, 2, 5 (substage 2.5) |
| **Sections pending** | 3 (2.6); 4, 6 (2.7); 7, 8, 9, 10 (2.8) |

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
    // PRECONDITION: sum of basis_points == 10000 exactly
    // PRECONDITION: 0 < amount <= MAX_MONEY_MINOR

    products   := []          // exact int64, no rounding yet
    floors     := []
    remainders := []

    FOR EACH w IN weights:                       // in given order; sorting happens later
        product   := amount * w.basis_points     // int64; bounded by §5.6
        floors    += product / 10000             // integer division, truncates toward zero
        remainders += product % 10000            // exact remainder, 0..9999
        products  += product

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

### 5.2 Integer division, precisely

`product / 10000` is **integer division truncating toward zero**, and `product % 10000` is the
matching non-negative remainder. Since `amount > 0` and `basis_points ≥ 0`, `product` is never
negative and the two are unambiguous. Stage 5 must not use any operation that rounds.

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
