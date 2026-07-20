# Stage 2 — System Design & Architecture — worklog

Evidence log, one entry per substage.

| Substage | Name | Status |
|---|---|---|
| 2.1 | State management decision | ✅ Complete |
| 2.2 | Layering, dependency rule and directory structure | ✅ Complete |
| 2.3 | Data model: entities, tables and columns | ✅ Complete |
| 2.4 | Data model: constraints, indexes, balances, migrations | ✅ Complete |
| 2.5 | Allocation: contracts and phase A base split | Not started |
| 2.6 | Allocation: phase B ceilings, redirects, termination | Not started |
| 2.7 | Allocation: overrides, reversals, error taxonomy | Not started |
| 2.8 | Allocation: pseudocode, worked examples, vector table | Not started |
| 2.9 | Cloud sync data model and merge strategy | Not started |
| 2.10 | Validation and configuration integrity rules | Not started |
| 2.11 | Navigation, screen inventory, per-screen states | Not started |
| 2.12 | Technology decision set | Not started |
| 2.13 | Design review, assembly and gate preparation | Not started |

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
