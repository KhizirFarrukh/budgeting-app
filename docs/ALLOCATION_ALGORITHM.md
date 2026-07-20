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
