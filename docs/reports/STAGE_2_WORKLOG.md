# Stage 2 — System Design & Architecture — worklog

Evidence log, one entry per substage.

| Substage | Name | Status |
|---|---|---|
| 2.1 | State management decision | ✅ Complete |
| 2.2 | Layering, dependency rule and directory structure | ✅ Complete |
| 2.3 | Data model: entities, tables and columns | Not started |
| 2.4 | Data model: constraints, indexes, balances, migrations | Not started |
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
