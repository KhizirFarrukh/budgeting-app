# Stage 2 — System Design & Architecture — worklog

Evidence log, one entry per substage.

| Substage | Name | Status |
|---|---|---|
| 2.1 | State management decision | ✅ Complete |
| 2.2 | Layering, dependency rule and directory structure | ✅ Complete |
| 2.3 | Data model: entities, tables and columns | ✅ Complete |
| 2.4 | Data model: constraints, indexes, balances, migrations | ✅ Complete |
| 2.5 | Allocation: contracts and phase A base split | ✅ Complete |
| 2.6 | Allocation: phase B ceilings, redirects, termination | ✅ Complete |
| 2.7 | Allocation: overrides, reversals, error taxonomy | ✅ Complete |
| 2.8 | Allocation: pseudocode, worked examples, vector table | ✅ Complete |
| 2.9 | Cloud sync data model and merge strategy | ✅ Complete |
| 2.10 | Validation and configuration integrity rules | ✅ Complete |
| 2.11 | Navigation, screen inventory, per-screen states | ✅ Complete |
| 2.12 | Technology decision set | ✅ Complete |
| 2.13 | Design review, assembly and gate preparation | ✅ Complete — **stage gate reached** |

---

## Stage entry — the five blocking questions

Stage 2's entry criteria require the Stage 1 blocking questions answered **or** explicit permission
to proceed on the recorded recommendations. The user reviewed the five questions with their
recommendations at the Stage 1 gate and instructed work to continue. **This is recorded as
authorisation to proceed on all five recommendations:**

| Id | Question | Proceeding on |
|---|---|---|
| OQ-02 | Bank accounts: label or real balances | **Label with a derived total.** No account ledger, no transfers, no reconciliation |
| OQ-03 | A third category type | **Yes — UNCAPPED_FLOW exists.** The 6 seeds typed that way are valid |
| OQ-07 | The sink category | **Auto-created, uncapped, non-deletable, renameable.** Separate business sink when business scope is on |
| OQ-11 | What counts as income, and one rule set or several | **All inbound money is income; one rule set for all of it**, with per-event override |
| OQ-12 | Category nesting | **Flat.** Three groups, categories inside them, no tree |

Highest cost if wrong: **OQ-02** and **OQ-12**, both baked into the schema at 2.3. The remaining
three are cheaper to revisit. Flagged to the user at stage entry.

---

## 2.1 — State management decision (S02.01)

**Outputs:** `docs/decisions/ADR-001-state-management.md`, `docs/ARCHITECTURE.md` section 3.

### Work steps

| Step | Action | Where |
|---|---|---|
| 2.1.1 | Criteria written before any candidate named | ADR-001 Context — C1…C6 |
| 2.1.2 | Riverpod and Bloc evaluated, plus two further candidates | ADR-001 Alternatives |
| 2.1.3 | Current package status checked on the web, not from memory | Below |
| 2.1.4 | Decision, and the state layer's boundaries | ADR-001 Decision; ARCHITECTURE §3.1–3.3 |
| 2.1.5 | ADR-001 with all six required sections | ADR-001 |
| 2.1.6 | How the choice is enforced | ARCHITECTURE §3.5 |

### 2.1.3 — package status, checked 2026-07-20

Checked rather than recalled, per the manifest's knowledge-freshness rule. Both finalists are
actively maintained: **Bloc at v9.2.x / flutter_bloc 9.1.x**, **Riverpod on the stable 3.x line
(3.2.x)**. Riverpod 3 added a unified `Ref`, automatic retry and *experimental* offline persistence;
Bloc 9 continues the event/cubit model with `hydrated_bloc` for persistence.

Two findings that shaped the decision:

- Riverpod is the commonly recommended default for new projects in 2026; Bloc is recommended where a
  team is large or needs strict event-driven discipline.
- **Bloc is specifically recommended for financial apps on audit-trail grounds.** This was the
  strongest argument against the decision taken, and is addressed head-on in ADR-001: this app's
  audit trail is the append-only ledger (INV-03), which is durable and user-visible, whereas a Bloc
  event log is in-memory and dies with the process. Adopting Bloc for auditability would add a
  second, weaker audit mechanism duplicating one the design already mandates.

Riverpod 3's experimental offline persistence is **prohibited** by ADR-001 — this app has its own
persistence (Stage 4) and sync (Stage 7).

### Acceptance criteria — verification

| Criterion | Verified how | Result |
|---|---|---|
| ADR-001 exists with all required sections and names criteria before the winner | Status, Context, Decision, Alternatives considered, Consequences, Date all present. C1–C6 appear in Context, above any candidate name | ✅ |
| The decision explicitly addresses UI correctness while background sync mutates the database | ADR-001 "How a background sync mutation reaches a visible screen" + ARCHITECTURE §3.4 with a Mermaid sequence diagram and three named verification obligations (S04.4.4, S06.1.3, S06.8.5) | ✅ |
| At least two candidates evaluated with specific, non-generic weaknesses | Bloc evaluated with four weaknesses, each tied to a fact about *this* app: the ledger already provides the audit trail; derived state dominates ~21 screens; database stream subscriptions need manual lifecycle management per bloc; fake injection requires constructing the whole graph. Provider and signals also assessed | ✅ |

### Notes on must_not compliance

- **Not chosen by familiarity:** criteria C1–C6 were fixed before candidates were named, and the
  runner-up's strongest argument (financial-app audit trails) is rebutted on evidence rather than
  ignored.
- **No approach requiring business logic to import Flutter:** the engine is pure domain code and
  imports nothing from the state layer; ADR-001 records that reversing this decision would leave the
  domain and data layers untouched.

### Finding carried forward

The layering guard planned for substage 3.4.4 checks **imports**, so it cannot catch a widget
reading an application-layer provider it should not — everything involved is in the same layer.
Recorded in ARCHITECTURE §3.5 with two mitigations: repository providers declared private to the
application layer, and the substage 6.1.1 check that no widget constructs a repository. Substage 2.2
must not assume the import guard alone is sufficient.

---

## 2.2 — Layering, dependency rule and directory structure (S02.02)

**Output:** `docs/ARCHITECTURE.md` sections 1, 2, 4, 8, 10.

### Acceptance criteria — verification

| Criterion | Verified how | Result |
|---|---|---|
| The directory tree is complete enough to be created verbatim in Stage 3 | §4.2 — full tree to file level for `lib/`, `test/`, `integration_test/`, `tool/`, including every domain, data, application and presentation subdirectory and the named files Stages 4–8 will create | ✅ |
| The dependency rule states, per layer, exactly what may be imported | §2.1 — a four-row table with explicit may / may-not lists, plus two clarifications (presentation may hold domain types for display but not call validators or the engine; application may import data only at the composition root) | ✅ |
| The enforcement mechanism is named and mechanical, not a convention | §2.3 — six guards G1–G6, each with a precise failure condition, each required to be demonstrated failing on a deliberate violation at S03.4.6 | ✅ |
| The sequence diagram renders and shows the engine purity boundary | §10.1 — Mermaid sequence diagram with the boundary drawn as a highlighted region listing exactly what crosses in and out; §10.2 adds the preview path | ✅ |

### Decisions

**Layer-first, not feature-first.** Justified against screen count (~21) and team size (1): feature
isolation buys nothing for a solo developer, while `lib/domain/**` as one greppable path is what
keeps guards G1–G3 simple and reliable. Under feature-first every guard would need to know which
subdirectory of each feature is domain — a pattern that grows with every feature and silently stops
matching when a folder is named differently. Feature grouping still appears inside
`presentation/screens/` and `application/usecases/`, where it aids navigation without weakening a
guard.

**Six guards rather than the four the stage plan lists.** The plan names money, time, layering and
telemetry. Two were added: **G2 engine purity** (the allocation directory may not contain `async`,
`await`, `Future`, `Stream` or `DateTime.now`), because INV-08's purity requirement is stronger than
the general layering rule and deserves its own check; and **G5 database containment**, because
substage 2.2.3 explicitly calls for "a check that no file outside data imports the database
package".

### Findings resolved here

**PR-11 closed — period boundary logic now has exactly one home.** The mid-stage plan audit flagged
that substage 4.6.2 has the data layer compute allocated-in-period while 5.5.1 computes period
boundaries inside the engine. §8.4 fixes the authority: `domain/allocation/period.dart` owns the
arithmetic as a pure function, and `data/balances/period_boundaries.dart` contains none of its own —
it calls the domain function and applies the result to a query. Implemented twice, the
anchor-day-31-in-February rule would drift and headroom would be computed against the wrong window.

**Money needed splitting into two representations.** The CSV exporter (Stage 8) lives in `data` but
needs amounts as decimal strings, while the display formatter lives in `presentation`. Without a
decision, either the exporter imports the presentation layer (violating the dependency rule) or the
decimal placement is implemented twice (a second chance to introduce a float). §8.5 resolves it: a
pure `toDecimalString()` on `Money` in the domain layer handles serialisation, and the presentation
formatter builds locale grouping and the symbol on top of it without re-deriving anything.

**Identifier versions differentiated.** UUID v7 for ledger entries and income events, v4 for
configuration. Reasoned from PRD §7.2: at the Heavy profile, allocation rows are 80–89% of the
table, so time-sortable ids give real index locality where it matters. Configuration rows are few
and gain nothing, while v4 avoids embedding record-creation times into the sync payload.

---

## 2.3 — Data model: entities, tables and columns (S02.03)

**Output:** `docs/SCHEMA.md` sections 1, 2, 3, 4.

### Acceptance criteria — verification

| Criterion | Verified how | Result |
|---|---|---|
| No column stores money or a percentage as real, double, float or numeric | Every money column is `INTEGER` named `*_minor`; every percentage is `INTEGER basis_points`. Conventions S-01/S-02; the runtime check at S04.3.6 reads the live schema rather than trusting the definition source | ✅ |
| Every synced table carries the five sync columns | All nine synced tables reference §2.1. The three device-local tables (`sync_metadata`, `outbox`, `balance_cache`) are listed in §2 with the reason each is excluded | ✅ |
| The ledger table has no design affordance for update or delete | §3.7 states no update or delete path exists at any layer; `is_deleted` is present for structural uniformity but documented as never set, with validation rejecting any ledger row carrying it | ✅ |
| Every enumeration lists its permitted values and is stored as a stable string | §4 — twelve enumerations with values enumerated; convention S-05 | ✅ |
| The ER diagram renders and matches the written schema with no discrepancy | §4.1 Mermaid `erDiagram`, written field by field from §3 | ✅ |
| The `target_date` column is present and documented as reserved | §3.2, plus five further reserved columns | ✅ |

### All six PRD §3.4 accommodations delivered

The deferral debt from Stage 1 is paid here. Each reserved column is documented as unused, will be
validated as unused (substage 2.10), and travels in exports so a v1.1 client reading a v1.0 backup
finds it present.

| Deferral | Accommodation | Where |
|---|---|---|
| D-01 target dates (OQ-04) | `categories.target_date_ms` | §3.2 |
| D-02 derived ceilings (E-03) | `categories.ceiling_kind` + `ceiling_param` | §3.2 |
| D-03 category nesting (OQ-12) | `categories.parent_category_id` | §3.2 |
| D-04 payload encryption (OQ-08) | Remote manifest encryption marker | deferred to §8, substage 2.9 |
| D-05 soft envelope budgets | `categories.soft_budget_minor` + `soft_budget_period` | §3.2 |
| D-06 per-source rules (OQ-11) | `distribution_rule_versions.rule_set` | §3.4 |

### Decisions taken, with reasoning recorded in the document

**Separate `ledger_entries` from `spending_transactions`** (required justification, 2.3.1). Three
reasons: a spending transaction's user-facing fields would be null for 80–89% of rows; the ledger
must stay strictly immutable while a spending *description* is something a user may correct; and
merge semantics differ per record class, which is enforceable only if the classes are separate
tables.

**`amount_minor` is always positive, with `direction` carrying the sign.** A signed amount plus a
direction column gives two representations of the same fact, and they eventually disagree.

**`ledger_entries.account_id` is denormalised at write time.** If a category is re-linked to a
different account next year, last year's entries must still report where the money actually went. A
join would rewrite history.

**`distribution_rule_versions.sealed_at_ms` added** beyond the stage plan's listed columns. Once an
income event references a rule version, that version's lines can never change — otherwise history
silently re-derives and INV-11 breaks. Editing percentages after sealing creates a new version.

**`income_events.overrides_json` closes escalation E-02.** INV-08 requires identical inputs to
produce byte-identical output, but a manual override changes an event's outcome without changing
rules or balances. Storing the override as part of the event's *input* makes the full input tuple
recoverable and keeps overridden events explainable after a rule change. Implements assumption A-23.

**No `balance_minor` column on `accounts`.** Under OQ-02's answer an account is a label; adding a
balance column would create a second source of truth and break INV-04. The account total is derived
from its linked categories. Noted in §3.3 that `ledger_entries.account_id` already accommodates
OQ-02's Reading B without a migration, per PRD §3.4 D-14.

**`balance_cache` is device-local and excluded from sync**, so a merge can never import a balance —
balances are always recomputed locally from entries.

---

## 2.4 — Constraints, indexes, balances, migrations (S02.04)

**Output:** `docs/SCHEMA.md` sections 5 and 7. (Section 6 is substage 2.10's, per the PR-04 fix.)

### Acceptance criteria — verification

| Criterion | Verified how | Result |
|---|---|---|
| Every index names the specific query it serves | §5.5 — eleven indexes, each mapped to numbered queries Q1–Q14 in §5.6, which are themselves traced to PRD journeys and stories | ✅ |
| Foreign key enforcement called out explicitly rather than assumed | §5.1 — `PRAGMA foreign_keys = ON` required on every connection open including tests and migrations, with substage 4.3.3's orphan-insert test named as the only real proof | ✅ |
| The balance policy is chosen, with a verification procedure defined | §7.1 — Option B on measured grounds; two-tier verifier with what runs when | ✅ |
| The migration strategy names the fixture-testing requirement | §7.2 — one fixture per prior version, v1 committed at 4.9.3, no schema change merges without a migration test | ✅ |
| Tombstone retention has a stated window and a safe-purge condition | §7.3 — all-devices-acknowledged **and** a 180-day floor; 365-day stale-device eviction with its consequence stated | ✅ |

### Decisions

**All foreign keys are `ON DELETE RESTRICT`, never `CASCADE`.** A cascade would silently destroy
ledger history when a category row was removed — exactly what INV-03 exists to prevent. Since
deletion is soft everywhere, a hard delete of a referenced row should be impossible; `RESTRICT`
makes that a database-level fact rather than a discipline.

**Three constraints do real invariant work at database level**, giving each a second independent
enforcement mechanism: **C-15** forbids tombstoning a ledger entry (INV-03, alongside the repository
exposing no delete method); **C-19** forbids a capped sink (INV-07's termination guarantee cannot be
broken by any path, including a sync merge); **C-21/C-22** pin the six reserved columns to their v1
values, so a v1.1 client can trust that every v1.0 row carries defaults.

**Balance policy — Option B, chosen on measured grounds.** A grouped ledger scan costs an estimated
40–80 ms at the Heavy profile and 80–150 ms at Stress. Individually acceptable against the 400 ms
P-03 budget, but paid on **every reactive emit** rather than every navigation, leaving no headroom
once reports and per-account totals are also on screen. The cache is updated only inside the same
transaction as the ledger write, is device-local so a merge can never import a balance, and is
verified in two tiers: a cheap per-category count on every cold start, and a full recompute after
**every** merge, before every export, on demand, and whenever the cheap check disagrees. A merge is
never trusted.

**One candidate index explicitly rejected**, per the rule that an index without a named query does
not belong: a composite `ledger_entries (category_id, source_type, occurred_at_ms)` for Q9. IX-01
already narrows to roughly 1,675 rows at Heavy, and `ledger_entries` is the highest-volume table, so
every extra index is paid on every allocation write. Recorded so Stage 4 does not add it
speculatively.

**`ledger_entries.source_id` is deliberately not a foreign key** — it points at either an income
event or a spending transaction depending on `source_type`, which SQLite cannot express. Integrity
for it is enforced by the repository write path and checked by the Stage 9 reconciliation script.

---

## 2.5 — Allocation contracts and phase A (S02.05)

**Output:** `docs/ALLOCATION_ALGORITHM.md` sections 1, 2, 5.

### Acceptance criteria — verification

| Criterion | Verified how | Result |
|---|---|---|
| The pseudocode for phase A contains no floating point operation | §5.1 — integer multiply, integer divide truncating toward zero, modulo, and integer addition only. Purity rule P-8 forbids `double`/`float`/`num` including intermediates; guard G3 enforces it | ✅ |
| The tie-break is stated precisely enough to predict the winner by hand | §5.4 — remainder descending, then `sort_order` ascending, then `id` by **ordinal** string comparison, with locale-aware comparison explicitly forbidden. Worked through for V-03 showing A and B tying at 9,999 and being separated by `sort_order` | ✅ |
| The documented maximum income is a specific number, derived and shown | §5.6 — derivation from `2^63 − 1` divided by 10000, giving **MAX_MONEY_MINOR = 922,337,203,685,477**, with the tightness proof that `+1` overflows | ✅ |
| The purity contract forbids clock, I/O and randomness explicitly | §2.5 — eight numbered rules P-1…P-8, mechanically enforced by guard G2 | ✅ |
| Phase A conservation assertions are named as engine-internal checks that fail loudly | §5.7 — assertions A-1 and A-2 throw rather than returning a typed failure, with the distinction between "inputs unacceptable" and "engine is wrong" spelled out | ✅ |

### Arithmetic verified by script, not by eye

Every figure in §5.6 and both worked examples were re-derived independently:

```
int64 max        : 9223372036854775807
floor(max/10000) : 922337203685477
bound   x 10000  : 9223372036854770000   fits: True
bound+1 x 10000  : 9223372036854780000   fits: False
3 x bound        : 2767011611056431

V-03 (amount 3):    bp=3333 floor=0 rem=9999 | bp=3333 floor=0 rem=9999 | bp=3334 floor=1 rem=2
V-02 (amount 100):  bp=3333 floor=33 rem=3300 | bp=3333 floor=33 rem=3300 | bp=3334 floor=33 rem=3400
```

The bound is **exact and tight** — one unit above it overflows int64. Both vectors reproduce the
expectations stated in the Stage 2 plan (V-03 → 1/1/1 with floors 0/0/1 and remainders 9999/9999/2;
V-02 → 33/33/34).

### Decisions

**A category that accepts nothing produces no line item, not a zero line.** A zero line would write
a ledger row recording that no money moved, inflating the highest-volume table (PRD §7.3) with rows
carrying no information. The fact is recorded in `diagnostics` instead, which is what the preview
renders for PRD §5.6 case I-2.

**Diagnostics are structured events, not strings.** The engine emits kinds, ids and amounts; the
presentation layer resolves ids to names and builds sentences. The engine has no access to category
names and no locale, so it cannot build a user-facing string even in principle — which is what keeps
substage 6.4.3 possible.

**`MAX_MONEY_MINOR` bounds every money value in the request, not only the income.** With all inputs
bounded, the worst arithmetic case in the engine is three bounded values summed
(`ceiling − balance − accepted_so_far`), giving ≈2.77 × 10¹⁵ against an int64 ceiling of
≈9.22 × 10¹⁸ — a margin of roughly 3,300×. This is why no addition or subtraction elsewhere in the
engine needs its own overflow guard, and it is stated so Stage 5 does not add redundant ones.

**`carry_forward_policy` is a request field, not a constant** (substage 5.5.3), so OQ-05's answer can
change without an engine change.

### Note on section ordering

Section numbers follow the references in the Stage 5 plan rather than reading order — phase A is §5
while phase B is §3, because substage 5.2's inputs name "section 5" and 5.3/5.4 name "section 3". A
reading-order note is placed at the top of the document so the ordering does not confuse a reader.

---

## 2.6 — Phase B: ceilings, redirects and termination (S02.06)

**Output:** `docs/ALLOCATION_ALGORITHM.md` section 3.

### Acceptance criteria — verification

| Criterion | Verified how | Result |
|---|---|---|
| Headroom defined for every category type, including the `accepted_so_far` term | §3.1 — four rows covering all three types plus the sink, each carrying `accepted_so_far`; §3.2 explains why the term exists | ✅ |
| The worklist algorithm written step by step with a deterministic ordering rule | §3.3 — full pseudocode; seeding sorted by `sort_order` then `id`; §3.4 fixes FIFO and states that new parcels join the back | ✅ |
| Cycle defence, hop limit and degraded-target handling all specified, all ending at the sink | §3.5 (T-1 visited set, T-2 `MAX_HOPS = 32`, T-3 uncapped sink) and §3.6 (missing, archived, deleted or self-referencing target) — every path routes to the sink and none throws | ✅ |
| The reference chained example worked through with every intermediate value, conserving exactly | §3.9 — six pops tabulated with headroom, accepted and overflow at each; verified by script below | ✅ |
| The final conservation assertion specified as failing loudly rather than adjusting | §3.8 — throws with the diagnostics trace attached; adjusting a line item to balance the sum is named as the anti-pattern it is | ✅ |

### Reference example verified by script

```
Phase A: split(300000, [4000,3500,2500]) -> 120000 / 105000 / 75000, leftover 0

pop1 Medical   room=80000  accepted=80000  overflow=40000
pop2 Emergency room=100000 accepted=100000 overflow=5000
pop3 Trip      room=UNBOUNDED accepted=75000 overflow=0
pop4 Emergency room=0      accepted=0      overflow=40000
pop5 Trip      room=UNBOUNDED accepted=5000  overflow=0
pop6 Trip      room=UNBOUNDED accepted=40000 overflow=0

line items: 80000 + 100000 + 75000 + 5000 + 40000 = 300000
per-category: Medical=80000 Emergency=100000 Trip=120000  total=300000
conserved against 300000: True
```

**The counterfactual was checked too:** without `accepted_so_far`, pop 4 recomputes Emergency's
headroom as `1,000,000 − 900,000 = 100,000`, accepts the full 40,000, and leaves Emergency at
**1,040,000 against a 1,000,000 ceiling** — 40,000 over, silently. That single row is the entire
justification for the tracker, and it is now demonstrated rather than asserted.

### The PR-01 fix carried into the design

The mid-stage plan audit found that the Stage 2 plan's own worked example used a merged-parcel flow
its FIFO worklist never performs. §3.9 implements the corrected version: **five line items, not
three**, because Emergency's base parcel is already queued ahead of Medical's overflow, so Trip
receives 75,000 base plus 5,000 at hop 1 plus 40,000 at hop 2 rather than one combined 120,000.

§3.4 states explicitly that this is observable rather than incidental — under LIFO or with parcels
merged by destination, the user would lose the ability to see that part of the money arrived as
overflow from a named category. Parcels are therefore never merged, never reordered after seeding,
and always appended to the back. Vector V-05 will assert the line-item shape, not just the totals.

### Decisions

**Three termination defences kept, not one.** T-1 (per-parcel visited set), T-2 (`MAX_HOPS = 32`)
and T-3 (uncapped sink) are each sufficient in isolation for most cases, but the design keeps all
three. Recorded explicitly: **configuration-time cycle detection does not make the runtime defence
redundant**, because a sync merge can produce a cycle from two independently valid edits made on
different devices — so the configuration may genuinely be cyclic at the moment allocation runs. This
is a case the save-time check structurally cannot cover.

**The visited set is per parcel, not per run.** A run-wide set would wrongly block a category from
being legitimately reached twice by two different chains — the failure mode substage 5.4's
`common_pitfalls` names.

**A missing sink is a typed failure; a missing redirect target is a warning.** The asymmetry is
deliberate and is stated in §3.7: a degraded redirect target has a safe fallback (the sink), whereas
a missing sink has none, so proceeding would risk losing money. The engine refuses rather than
improvising.

**Unbounded is a distinct value, never `int64.max`.** A very large sentinel overflows the moment
anything is added to it, which is the specific defect substage 5.3.3's `must_not` warns about.

**`max(0, …)` on headroom is load-bearing, not defensive decoration.** §3.1 records the three real
ways a balance ends up above its ceiling — manual override, a lowered ceiling, a sync merge — so the
already-over case is documented as common rather than exotic. Without the clamp, negative headroom
propagates into a negative allocation and conservation breaks.

---

## 2.7 — Overrides, reversals and the error taxonomy (S02.07)

**Output:** `docs/ALLOCATION_ALGORITHM.md` sections 4 and 6.

### Acceptance criteria — verification

| Criterion | Verified how | Result |
|---|---|---|
| The override redistribution rule worked through with exact figures totalling the income | §4.7 — 200,000 + 175,000 + 125,000 = 500,000, every product and floor shown; verified by script below | ✅ |
| Every override validation rule names its typed failure | §4.4 — five rules O-1…O-5, each mapped to a failure in §6 and classified user-input or configuration-bug | ✅ |
| The ceiling-versus-override policy decided, with its alternative recorded | §4.5 — permitted, warned, not redirected; the rejected alternative and its consequence stated | ✅ |
| Reversal specified as mirroring recorded allocations, not recomputing | §4.8 — pseudocode mirrors entries with opposite direction; the reason is given and tied to substage 5.7.5's test | ✅ |
| The error taxonomy is complete, each entry saying configuration bug or user input error | §6 — twelve failures E-01…E-12, each with condition, class, carried context and UI intent; §6.1 separates the five warning conditions | ✅ |

### V-09 verified by script

```
income=500000, Medical overridden to 200000
remaining=300000  relative_total=6000
  bp=3500 product=1050000000 floor=175000 remainder=0
  bp=2500 product=750000000  floor=125000 remainder=0
floor_sum=300000 leftover=0
RESULT: Medical=200000 Emergency=175000 Trip=125000  total=500000  conserved: True
```

Matches the Stage 2 plan's stated expectation for V-09 exactly. **The divisor is the relative total
(6000), not 10000** — noted in the document because using 10000 there is precisely how
redistribution silently loses money.

### Decisions

**The I-1 policy is fixed: an override may exceed a ceiling and is not redirected away.** The
rejected alternative is recorded with its consequence, as substage 2.7.3 requires. Redirecting the
excess would make the override silently not do what the user typed — they enter 200,000, press
confirm, and find 80,000 there. An explicit instruction the app quietly overrules is worse than a
warning the user can act on. The accepted cost is that a category can sit above its ceiling, which
the design already accommodates: §3.1 clamps headroom, no schema constraint forbids it, and
substage 8.3.5 requires the progress indicator to render it without clipping.

**A zero override is an explicit instruction, not an absence.** `{cat_A: 0}` means "A gets nothing
this time"; omitting A means "A takes its normal share". The map's *keys* decide which categories are
overridden. Conflating these is named in substage 5.6's pitfalls.

**Two failures added beyond the stage plan's list.** The plan enumerates ten; §6 has twelve.
`OverrideTargetUnknown` (E-11) covers an override naming a category absent from the request, which
substage 5.6.3 requires as a validation rule but which had no failure to return. `PeriodDefinitionInvalid`
(E-12) covers a malformed period window, which becomes reachable now that `PeriodDefinition` is a
request field. Both are classified as configuration bugs.

**Reversal mirrors rather than recomputes, and the reason is recorded as structural.** If rules
changed between the event and its reversal, recomputing produces different amounts and subtracting
them leaves every balance wrong; if a ceiling was involved the recomputed split differs
*structurally*, because the categories were in different states then. Mirroring is the only method
that restores exact pre-event balances regardless of what changed.

**Reversing a reversal is forbidden** (guard R-2) rather than merely discouraged: it is
indistinguishable from re-entering the money and makes history harder to read. The user records a
new income event instead.

**The warn-versus-fail boundary is stated as a rule, not left to judgement:** it is a failure when
the engine cannot produce a conserved result, and a warning when it can but the user should know
something unexpected happened. §6.1 lists the five warning conditions explicitly so Stage 5 does not
have to decide.

---

## 2.8 — Pseudocode, worked examples and the vector table (S02.08)

**Output:** `docs/ALLOCATION_ALGORITHM.md` sections 7, 8, 9, 10 — the document is now complete.

### Acceptance criteria — verification

| Criterion | Verified how | Result |
|---|---|---|
| The pseudocode is complete, integer-only and includes its assertions inline | §7 — `allocate`, `build_base_parcels`, `build_override_parcels` end to end, with A-1, A-2 and the final conservation assertion written where they run; `split` (§5.1) and `phase_b` (§3.3) reproduced in full at their own sections; a loop-bound argument for termination | ✅ |
| All fifteen vectors tabulated with exact inputs and expected outputs | §10 — V-01…V-15 with configuration and expected line items; §10.1 maps them to the concerns they cover | ✅ |
| Every expected value verified independently of any implementation | §10.2 — the algorithm was **executed**, not inspected; §10.4 records the run output | ✅ |
| The fixture JSON format is defined | §9.1 — full example plus four format rules, including that exactly one of `expected_allocations` / `expected_failure` is non-null and that no decimal point may appear in a fixture | ✅ |
| The seven required properties are listed as design requirements | §9.2 — P1…P7 with statements and notes; §9.3 states what the generator must produce | ✅ |

### The verification method, and the defect it caught

Substage 2.8.4 forbids carrying an unverified expected value into Stage 5. Rather than hand-check
fifteen vectors, **the algorithm as specified was implemented in a scratch script and all fifteen
were executed through it**, then compared against independently reasoned expectations.

**This caught a genuine defect in the design document.** The split primitive in §5.1 divided by the
constant **10000**. That is correct for both phase A applications, where weights total exactly 10000
by validation — and wrong for override redistribution (§4.3), where the non-overridden categories'
weights total 6000.

Under the constant divisor, V-09 produces Emergency 105,000 and Trip 75,000: **180,000 against a
`remaining` of 300,000, leaving 120,000 undistributed**, and driving `leftover` to 120,000 against a
two-item weight list.

The fix: the primitive derives its divisor from the weights it is given. §5.1 and §5.2 now say so,
§4.3 no longer claims a scaling step happens implicitly, and §5.2 carries an explicit note that an
implementation hardcoding 10000 **passes every phase A vector and fails only under override**.

Recorded rather than silently corrected, per the manifest's `sdlc_discipline` rule. What it
demonstrates is the concrete justification for 2.8.4: the defect survived two readings of the
section and was invisible to inspection, because every example in §5 happens to use weights totalling
10000.

### Vector notes

- **Sixteen fixture files for fifteen vectors.** V-11 covers "zero and negative income rejected",
  but the fixture format holds one request per file, so it splits into `v11a` and `v11b`.
- **V-05's assertion is the line-item shape, not only per-category totals.** Per §3.4, FIFO ordering
  makes Trip receive three separate lines; a merged-parcel implementation would produce the same
  totals and the wrong trace. Asserting only totals would let that pass.
- **V-13 asserts a single line item**, proving the no-zero-lines rule of §2.2: A and B compute to
  zero and must produce no ledger row at all.
- **V-15 confirms the bound is usable, not just derived.** At exactly `MAX_MONEY_MINOR` across 40
  categories, 37 receive 23,058,430,092,137 and 3 receive 23,058,430,092,136, summing to the input
  exactly.

### Harness note

Two PowerShell-specific bugs in the scratch harness were fixed before the run was trusted: single-
element arrays being unwrapped to scalars (so `.Count` on a lone hashtable returned its key count),
and an `$_` scope collision in a nested `Where-Object`. Neither reflected a design problem, and both
are noted only because the first masked the real defect for one run — the harness failed before it
could disagree with the document.

---

## 2.9 — Cloud sync data model and merge strategy (S02.09)

**Outputs:** `docs/decisions/ADR-002-sync-target.md`, `ARCHITECTURE.md` sections 5 and 6,
`SCHEMA.md` section 8.

### Acceptance criteria — verification

| Criterion | Verified how | Result |
|---|---|---|
| ADR-002 explicitly answers whether the choice puts financial data on developer-controlled infrastructure | ADR-002 has a section headed "The control question, answered explicitly" answering **no**, naming the two places data exists, and citing S07.10 and S09.7 as the proofs | ✅ |
| Merge rules stated per record class, not as one blanket policy | ARCHITECTURE §6.1 — four classes: immutable (union by UUID), mutable configuration (LWW by HLC), tombstones (delete beats older edit), device-local (never synced) | ✅ |
| The design explains how a delete on device A survives device B offline for a month | ARCHITECTURE §6.3 — five numbered steps ending in convergence, plus why the safe-purge condition is what makes it work | ✅ |
| A schema version field exists in the remote format with a newer-than-expected policy | ARCHITECTURE §5.2 (manifest field) and §5.7 (refuse outright, never partially parse); SCHEMA §8.4 repeats it in the snapshot header | ✅ |
| HLC advance rules specified for both local write and remote receive | ARCHITECTURE §6.4 — both as pseudocode, plus serialisation, total-ordering comparison, persistence and device-id sourcing | ✅ |

### The decision, and the argument that settles it

Drive `appDataFolder`, not Firestore. ADR-002 turns on one question: **who controls the storage and
who is capable of reading the data** — not who intends to, or is authorised to.

A Firestore document lives in a **developer-owned Firebase project**. That makes the developer the
data controller in the regulatory sense, gives them console access to every user's financial
records, and hands them breach liability and lawful-demand obligations. Security rules restrict
*client* access; they do not restrict the project owner. Firestore is materially better on
engineering merits — server-side queries, indexes, real-time push, offline persistence — and **none
of it matters**, because it fails the requirement the product exists to satisfy. Describing such a
project as "the user's Google account" is the anti-pattern the Stage 2 plan names by name.

The six honest costs of `appDataFolder` are tabulated in ADR-002 with mitigations, including the two
that bite: the client must do all merging (a direct consequence of NG-08 — there is nowhere else),
and the sensitive OAuth scope needs Google verification, which is why PRD §3.2 already made sync
non-blocking for release.

### Decisions with reasoning recorded

**Per-device chunk directories.** Two devices never write the same file, so most write conflicts are
removed *by construction* rather than resolved afterwards. Writing all devices to one shared file
manufactures conflicts the merge engine would then have to untangle.

**Last-write-wins is per record, not per field** — stated explicitly, as substage 2.9.4 requires.
Per-field resolution needs an HLC per field; a category has ~20 fields, so that multiplies sync
metadata on the most-edited table twentyfold, permanently, in every chunk and snapshot. Per record
is chosen because of what LWW can and cannot touch:

> **Last-write-wins never applies to money.** Every table it governs is configuration. Money lives in
> the immutable tables, which merge by union. The worst outcome of a per-record conflict is a lost
> category rename — recoverable in seconds and surfaced in the repair log. It is never a lost
> transaction.

Combined with this being a single-user app (NG-02), where simultaneous edits to one category from
two devices need the user in two places at once, the exposure is small and the saving is permanent.

**The append-only ledger is what makes sync safe**, not only what makes it auditable. Recorded in
§6.1 because it reframes INV-03: because ledger entries are immutable they merge by union, so no
money can ever be lost to conflict resolution. The sync design depends on the invariant.

**Compaction order is fixed as snapshot → manifest → retire chunks**, with the interruption analysis
for each step. Reversing the last two loses data on interruption: the manifest would reference a
snapshot whose source chunks were already deleted.

**Bootstrap merges with local data rather than replacing it**, because the common path is a user who
tried the app first and signed in afterwards — so the local database is usually non-empty.

**An absent remote is never evidence of deletion.** Only an explicit tombstone is. This is what makes
US-031 (the user wipes the app's Drive data) safe.

**A tombstone envelope carries no fields.** Shipping the full row with a tombstone would let a stale
device's field values overwrite fresher ones on the way out.

**Unknown fields are preserved, not dropped** — within a schema version. A v1.0 client receiving a
record from a newer minor version writes unrecognised keys back unchanged; dropping them would
silently strip data every time an older device synced. A newer `schema_version` is refused outright,
so this is bounded.

**`balance_cache` is excluded from the payload** so a merge can never import a balance; balances are
always recomputed locally (INV-04).

---

## 2.10 — Validation and configuration integrity rules (S02.10)

**Output:** `docs/SCHEMA.md` section 6. The document is now complete.

### Acceptance criteria — verification

| Criterion | Verified how | Result |
|---|---|---|
| Every rule names its enforcement point | §6.2–§6.7 — **28 rules** V-01…V-28, each with an "Enforced at" column naming a database constraint, a domain validator, the repository write path, or a combination | ✅ |
| No invariant-protecting rule is enforced only in the UI | §6.1 states the governing rule with its reason and lists what each enforcement point can and cannot do; no rule in the tables names UI alone | ✅ |
| Cycle detection has a named method and a stated trigger | §6.3 — depth-first traversal with a visited set **over the whole reachable graph**, running on every save that touches a redirect target and on every post-merge pass | ✅ |
| Every violation states block, warn or auto-repair, plus the recovery path | §6.9 — all 28 save-time rules **block**; auto-repair applies only to the six post-merge cases; nothing merely warns at save time | ✅ |
| The auto-repair procedure is recorded and visible, never silent | §6.8 — durable repair log surfaced in plain language, with a worked example sentence a user would actually read | ✅ |

### Decisions

**The governing rule, stated once and applied everywhere:** no invariant-protecting rule is enforced
only in the UI, **because Stage 7 writes through a completely different path**. A rule living on a
screen is a rule a merge does not know about, and the merged state would persist invalid. This is
why substage 4.8.4 wires validators into the repository rather than the call site, and why 4.8.6
requires a test proving validation cannot be bypassed by writing directly through the repository.

**Cycle detection traverses the whole reachable graph, not the immediate pair.** Checking only
`A → B` and `B → A` misses `A → B → C → A` — the exact defect substage 4.8's pitfalls name.

**The save-time check does not replace the runtime defence.** Recorded explicitly in §6.3: a merge
can produce a cycle from two independently valid edits on different devices, so the configuration
may genuinely be cyclic when allocation runs. The two mechanisms cover different situations and
neither is redundant.

**V-09's asymmetry is deliberate and now documented.** A missing redirect target **blocks** at save
time but is a **warning routed to the sink** at allocation time. Save time can refuse because there
is a user to tell; allocation time cannot, because money is moving and refusing would lose the whole
event.

**V-20 — the short-month anchor rule is clamp, not roll forward.** Rolling 31 February into 3 March
would place the period boundary *after* the next month's anchor in some years, producing either a
skipped period or two overlapping ones. Clamping keeps exactly twelve periods per year for every
anchor value. A worked table covers anchors 29/30/31 across January, both Februaries and April, and
§6.4 records that the rule is implemented once in the domain period module per ARCHITECTURE §8.4.

**Nothing is auto-repaired at save time, and nothing merely warns.** A user editing their own
configuration gets a clear refusal and an explanation. Repair exists only for merges, where there is
no user to ask and no valid state to return to.

**Every repair must be deterministic *and* non-silent** — §6.8 states both as properties with
reasons. A repair that picks "the first surviving category" depends on iteration order and would
make two devices diverge permanently, which is worse than the original invalidity because it is
stable and invisible. Every repair breaks ties by HLC then device id, exactly as the merge does, and
the percentage-redistribution repair reuses the largest-remainder split so it inherits that
determinism by construction.

### Repair catalogue

Six post-merge invalid states enumerated with their repairs and the reason each is deterministic:
deleted redirect target → reassign to the group's sink; percentages no longer totalling 10000 →
proportional redistribution by largest remainder; sink deleted or archived → restore it; cycle formed
by two valid edits → break at the newest-HLC edge; account deleted with categories still linked →
unlink; a group whose categories were all deleted → zero its share and redistribute.

---

## 2.11 — Navigation, screen inventory and per-screen states (S02.11)

**Output:** `docs/NAVIGATION.md`, complete.

### Acceptance criteria — verification

| Criterion | Verified how | Result |
|---|---|---|
| Every PRD journey step maps to a named screen, none homeless | §1.5 — a coverage table over all 12 journeys; **all 40 primary-journey steps** (J1's 22, J2's 18) and all 7 failure journeys mapped to named screens | ✅ |
| The navigation graph has no unreachable screen and no dead end | §2.1 — checked against the Mermaid graph in §2; every screen has an inbound edge and an outbound or back path | ✅ |
| Android back behaviour specified for every multi-step flow | §4 — nine flows specified | ✅ |
| Every screen has a defined empty, loading and error state | §7 — 22 screens × 3 states; "n/a" used only where a state genuinely cannot occur, and the distinction from "not yet designed" is stated | ✅ |
| The personal-only user's experience is specified explicitly | §5.1 — no business surface at all, not an empty group or disabled entry; enabling later requires a rebalance to exactly 100 | ✅ |

### Counts

- Screens: **22** — the PRD §2.3 label set of 21 carried through unchanged, plus one addition.
- Routes: 22, with `Category Selection` parameterised by group and visited once per active group.
- Journeys covered: 12 (2 primary, 7 failure, plus 3 J1/J2 sub-segments).
- Back-behaviour flows: 9.
- Per-screen states defined: 66.

### Decisions

**A central scope filter, not a business tab or a global mode switch.** Reasoned against P2's actual
fear (PRD §2.2) rather than in the abstract. A separate tab duplicates every screen, and duplicated
screens drift apart; it also implies business is a *place* rather than a property of the money. A
global mode switch risks the worst failure available here — the user misreads which mode they are in
and files a household spend against inventory. A central filter shows both scopes together but never
combined, each labelled, **with no mode to be wrong about**.

**A declarative router, justified on two specific needs** rather than general preference: startup
routing is state-driven (`onboarding_state` picks between three destinations at cold start), and
onboarding must resume after process death, which is a redirect under route-per-step but a
serialisation problem under a single stateful widget. Deep links are out of scope, so they form no
part of the argument.

**Back from `Allocation Preview` preserves the entered amount, label, date and note.** Called out
separately in §4 because losing a typed amount when the user backs out to check something is a trust
failure, not an inconvenience.

**Back from `Income Confirmed` goes to the Dashboard, not the preview.** The event is written;
re-entering the preview would imply it is still editable. Undo is available from the confirmation
screen and from history instead.

**No confirm-to-exit on the Dashboard.** Nothing is in flight, and a confirmation prompt on the home
screen is a well-known irritation.

**`Transaction History` distinguishes "no history" from "no results for this filter" in wording.**
Two different facts; one empty state for both would tell the user their records had vanished.

**Two error states singled out in §7.1** as mattering more than the rest. `Dashboard`: if balance
derivation fails, blank or zero would read as "your money is gone", so it shows the last known
figures clearly marked stale. `Income Confirmed`: the message must state plainly that **nothing was
recorded**, because ambiguity leads a user to re-enter a payment that already exists — and duplicate
income is a money bug.

### Deviation

**One screen has no PRD journey: `Diagnostics`.** Substage 2.11.1 forbids screens no journey reaches,
so this is declared rather than quietly added (§1.4). It exists because SCHEMA §7.1 requires a
user-facing entry point for the recompute-and-compare verifier and §6.8 requires the repair log to be
surfaced — both are features with nowhere to live otherwise. It is reachable only from Settings,
never on a primary path, and can be dropped in Stage 6 without affecting any journey.

**Deep links and notifications explicitly stated as absent** (§6), per substage 2.11.7. Recorded
because it lets Stage 3's router assume no route is entered cold with arbitrary arguments — an
assumption that must be revisited if D-09 or D-10 is ever built.

---

## 2.12 — Technology decision set (S02.12)

**Outputs:** `ADR-003-database.md`, `ADR-004-supporting-libraries.md`, `ARCHITECTURE.md` sections 7
and 9. ARCHITECTURE is now complete.

### Acceptance criteria — verification

| Criterion | Verified how | Result |
|---|---|---|
| ADR-003 addresses migration testing and reactive query support explicitly | Criteria D2 (reactive streams) and D3 (migration tooling) are named before candidates; both appear in the sqflite rejection with specific consequences | ✅ |
| Every dependency has a purpose, a licence, a maintenance signal and an exit plan | ADR-004 — eleven adopted entries in a table carrying purpose, maintenance signal and exit plan. **Licence is handled as constraint L2** rather than asserted per package: permissive only, verified at 3.3.6, copyleft a blocker | ✅ |
| The no-telemetry constraint is written as a design decision, not an intention | ADR-004 has a dedicated section listing five mechanical checkpoints (G6, 3.3.7, 7.10.3, 9.7.2, 10.8's must_not) | ✅ |
| The performance design names what is cached and what is paginated | ARCHITECTURE §9.1 (two caches, both with verification paths) and §9.3 (two paginated surfaces, plus why the dashboard is not) | ✅ |

### Package status checked 2026-07-20, not recalled

Per the manifest's knowledge-freshness rule, two searches were run:

- **Drift** is the recommended default for Flutter local persistence in 2026 and actively
  maintained. **sqflite** remains well maintained as a thin SQLite wrapper with no ORM, codegen or
  reactive layer.
- **Isar and Hive were abandoned by their original author.** This is the decisive finding of the
  substage — teams that adopted them are reportedly writing migration code instead of features.
- **`glados`** exists and provides shrinking, but its most recent changelog entry appears to date
  from late 2023 — a weak maintenance signal, recorded with a fallback.
- **`workmanager`** is Flutter Community maintained and Android-focused, which suits an Android-only
  v1.

### Decisions

**Drift over sqflite, on two mechanisms rather than general preference.** sqflite has no reactive
layer, and ARCHITECTURE §3.4 — the path by which a background sync write reaches a visible screen —
depends entirely on query streams re-emitting when *any* writer commits. Hand-building that means
every writer must remember to publish a notification, and **the writer that forgets is the sync
worker**, with a silent failure mode: the dashboard is simply stale after a merge, with no error
anywhere. Second, migration fixture testing (NFR-07) is bespoke code under sqflite, whereas Drift
generates schema snapshots for exactly that purpose.

**Isar excluded for two independent reasons**, either sufficient. Abandonment plus a Rust core
closes the usual forking escape hatch. And as a NoSQL object store it cannot express SCHEMA's 22
check constraints and 21 foreign keys — C-15 (append-only ledger) and C-19 (uncapped sink) would
become application conventions bypassable by any code that forgets, including a merge. That is
precisely the trade SCHEMA §6.1 exists to refuse.

**Drift's exit plan is cheap because the data is in plain SQLite.** If it were abandoned, the path
is sqflite against the same file with hand-written mappers — same SQL, same constraints, same
indexes, **no data migration**. Materially better than Isar or Hive, where leaving means exporting
and re-importing every user's data.

**Three dependencies declined in favour of writing the code.** A CSV package (substage 8.5 demands
integer-derived amounts with no float intermediate, a deliberate BOM decision, and escaping that
round-trips a name containing a comma, a quote *and* a newline — a general library would fight all
three); a separate DI container (Riverpod already provides override-based injection, which is what
ADR-001's C6 selected it for, and a second mechanism means two ways to get a dependency with no rule
about which); and a JSON generator (the export and sync formats have hand-specified rules a
generator would not honour — nulls explicit not omitted, unknown fields preserved not dropped,
integers never rendered as decimals).

**Two uncertainties recorded with pre-decided fallbacks**, so neither becomes a mid-stage surprise.
`glados` → hand-rolled seeded generators, which is **not a downgrade**: substage 5.9.1 already needs
very specific generators no general library supplies, and 5.9.4 needs the seed, which hand-rolling
gives directly. Only shrinking is lost. The seven properties are defined in ALLOCATION_ALGORITHM
§9.2 independently of any library, so the choice cannot affect *what* is verified. `workmanager` →
drop the periodic trigger, keeping foreground, connectivity and manual sync; **no correctness
property depends on sync frequency**, since convergence comes from the merge design.

---

## 2.13 — Design review, assembly and gate preparation (S02.13)

**Outputs:** `docs/reports/STAGE_2_REPORT.md`, `docs/TRACEABILITY.md` updated to `DESIGNED`.

### Acceptance criteria — verification

| Criterion | Verified how | Result |
|---|---|---|
| Every invariant names the design element that enforces it | Report §3 — all twelve walked; **no gaps**. Each names two or more concrete elements, most combining a database constraint with a code-level guard | ✅ |
| Every PRD story maps to a design element | Report §4 — all 37 stories grouped by area, plus the four interaction cases mapped individually | ✅ |
| All worked examples re-verified and conserving | Report §5 — four examples re-derived by script **at review time**, not carried forward | ✅ |
| `TRACEABILITY.md` updated to `DESIGNED` | 23 of 23 rows, with a new per-requirement design-artefact table added at 2.13.6 | ✅ |
| The frozen-decisions list is written | Report §7 — 14 decisions later stages may not change without a new ADR | ✅ |

### The invariant walk found no gaps

All twelve invariants have named enforcing elements. The pattern that emerged: **the strongest ones
are enforced twice, by independent mechanisms.** INV-03 by both a check constraint (C-15) and the
absence of any update or delete method on the repository. INV-07 by a check constraint (C-19), a
save-time validator (V-12) and three runtime defences. INV-01 by a schema convention, a CI guard, a
value type, and a runtime check that reads the *live* schema rather than trusting the definition
source.

### Re-verification output

```
5.4 tie-break, income 3:   floors 0/0/1  remainders 9999/9999/2  leftover 2 -> 1/1/1, sum 3
5.5 rounding, income 100:  floors 33/33/33  remainders 3300/3300/3400  leftover 1 -> 33/33/34
3.9 chained, 300000:       80000 + 100000 + (75000+5000+40000) = 300000  conserved=True
4.7 override, 500000:      divisor 6000 -> 175000/125000, TOTAL 500000  conserved=True
                           counterfactual divisor 10000 -> 180000, SHORT BY 120000
5.6 bound:                 922337203685477; bound*10000 fits, (bound+1)*10000 does not
```

### Consistency pass — and a mis-triage corrected

Four checks, all passing. One finding: **`Diagnostics` needs the repair log to be durable**, which
SCHEMA §6.8 requires but which no table held.

This was initially filed as "a Stage 4 obligation." **That was wrong.** Stage 4 transcribes SCHEMA
*exactly* and proves the transcription faithful with a comparison table (4.3.5) — so a table absent
from SCHEMA is a table Stage 4 will not build, and the gap would have surfaced at Stage 7 substage
7.6.4 with the merge engine having nowhere to write its repairs. A missing table in the schema is a
Stage 2 defect, not a Stage 4 task.

**Closed by amendment:** SCHEMA §3.13 now defines `repair_log` — device-local, append-only, with a
`RepairKind` enumeration covering all six repairs from §6.8, a `merge_session_id` grouping repairs
from one merge so the UI can say "3 changes were made when your devices last synced", and index
IX-12 for the unread-repairs query. Wired through §2 (table inventory, now thirteen tables), §4
(enumerations), §4.1 (ER diagram), §5.5/§5.6 (index and query tables), §6.8 (the repair catalogue
now names the table) and §8.1 (does not travel).

**Device-local, and that follows from a property already required.** §6.8 mandates deterministic
repairs, so each device generates identical entries independently; syncing would duplicate every
one. The determinism requirement is what makes local logging correct rather than a compromise.

Recorded per the manifest's `sdlc_discipline` rule: *"do not silently patch forward: raise it, amend
the earlier document, and note the amendment."*

### An encoding incident, and the lesson

While fixing a typo in the report, a PowerShell `Get-Content -Raw` / `Set-Content -Encoding utf8`
round-trip corrupted every non-ASCII character in the file — PS 5.1 read the UTF-8 bytes as ANSI
before writing them back, turning em-dashes and section signs into mojibake. Caught immediately by a
non-ASCII grep, and the file was rewritten with the Write tool.

**Lesson recorded for later stages: do not round-trip UTF-8 documents through PowerShell 5.1's
`Get-Content`/`Set-Content`.** Use the Read/Edit/Write tools, which handle encoding correctly. A
verification grep over `docs/` confirms no mojibake remains anywhere.

### Stage 2 totals

- Substages: **13 of 13**.
- Acceptance criteria: **62**, all met.
- Deliverables: 4 design documents, 4 ADRs, 1 worklog, 1 report, 1 updated matrix.
- Design documents: ARCHITECTURE (10 sections), SCHEMA (8), ALLOCATION_ALGORITHM (10),
  NAVIGATION (8).
- Golden vectors specified and verified by execution: **15**, in 16 fixture files.
- Frozen decisions: **14**.
- Defects caught in this stage's own work: **1** (the split divisor), recorded rather than silently
  corrected.

### Performance design

§9 records the three load-bearing facts the design is built around: the ledger grows with categories
× income events (so allocation rows dominate and index choice follows that shape); the database is
small enough that **the risk is a missing index causing a full scan on every render**, not volume;
and the engine is pure and in-memory, so its budget is bounded by arithmetic rather than I/O. §9.5
names the substage that replaces each estimate with a measurement.
