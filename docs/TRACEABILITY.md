# PookieBudget — traceability matrix

Seeded in substage 1.8. **Every later stage updates this file rather than creating its own.** A
matrix built once and never updated is worse than none, because it looks authoritative.

**Status values:** `NOT_STARTED` → `DESIGNED` (S02) → `IMPLEMENTED` → `VERIFIED` (S09).

**Current state: all 23 rows at `DESIGNED`**, updated at substage 2.13.6. Every requirement now has
a design artefact that will satisfy it; none has implementing code yet.

**Implementing stages** are the union of the manifest's per-requirement stage list and the stages
whose substages claim coverage — the convention adopted in `PLAN_REVIEW.md` PR-08.

---

## Feature requirements

| FR | Statement (abbreviated) | Stories | Implementing stages | Verifying artefact | Status |
|---|---|---|---|---|---|
| FR-01 | Add multiple user-definable categories | US-006 | S02, S04, S06 | Category management widget tests; S09.2 journey | DESIGNED |
| FR-02 | Fixed percentage of income per category | US-007 | S02, S04, S05, S06 | Split primitive unit tests; golden vectors V-01…V-03 | DESIGNED |
| FR-03 | Assign which account stores which category's funds | US-011, US-012 | S02, S04, S06 | Per-account total reconciliation test (S06.7.6) | DESIGNED |
| FR-04 | Log an income event and auto-split it | US-013, US-014, US-015 | S05, S06 | Golden vectors; preview-equals-confirmed test (S06.4.6) | DESIGNED |
| FR-05 | Track spending categories separately from savings | US-008, US-024, US-026 | S02, S04, S06 | Group separation in model; scope isolation tests (S06.9.8) | DESIGNED |
| FR-06 | User selects top-level Spending / Savings / Business ratios | US-001, US-015 | S02, S05, S06 | Exact-100 constraint widget tests (S06.2.7) | DESIGNED |
| FR-07 | Business group has its own categories, kept distinct | US-009, US-010 | S04, S06 | Cross-screen scope test (S06.10.6) | DESIGNED |
| FR-08 | Suggested categories, all editable, plus custom | US-003, US-004, US-005 | S04, S06 | Seed idempotency and non-destructiveness tests (S04.7) | DESIGNED |
| FR-09 | Cloud sync to the user's own Google account | US-028, US-029 | S02, S07 | Two-device convergence suite; traffic capture (S07.10) | DESIGNED |
| FR-10 | Ceilings, with overflow redirecting to a fallback | US-018, US-019 | S02, S05, S06, S08 | Golden vectors V-04…V-07, V-14; ceiling journey (S09.2.2) | DESIGNED |
| FR-11 | Fixed-recurring distinguished from accumulating reserve | US-020, US-021 | S02, S04, S05, S06 | Golden vector V-08; period edge-case tests (S05.5.5) | DESIGNED |
| FR-12 | Manual override of a single event's split | US-016 | S02, S05, S06 | Golden vectors V-09, V-10; override journey (S09.2.4) | DESIGNED |
| FR-13 | Dashboard showing balance against ceiling | US-023 | S04, S06, S08 | Displayed-versus-derived assertion (S09.1.4) | DESIGNED |
| FR-14 | Monthly/yearly summaries, trends, CSV export | US-033, US-034, US-035, US-036, US-037 | S08 | Reconciliation suite (S08.7); export round-trip | DESIGNED |
| FR-15 | Offline-first; syncs when connectivity returns | US-027, US-029, US-030 | S04, S06, S07 | Offline flow run (S06.12.6); long-offline catch-up (S07.11) | DESIGNED |

## Non-functional requirements

| NFR | Statement (abbreviated) | Target | Implementing stages | Verifying artefact | Status |
|---|---|---|---|---|---|
| NFR-01 | No financial data leaves the user's own Google account | Binary — zero non-Google hosts from the app process; zero telemetry packages | S02, S07, S09 | Traffic capture (S07.10, S09.7); CI telemetry guard | DESIGNED |
| NFR-02 | Fully functional offline | Binary — the 11 core flows of §6.2, no network, no account | S04, S06, S07, S09 | Offline test run; manual checklist; S10.8.5 clean device | DESIGNED |
| NFR-03 | Personal and business separation | Binary — personal totals unchanged by business activity | S06, S08 | Cross-screen scope test (S06.10.6) | DESIGNED |
| NFR-04 | Usable by someone who has never budgeted | ≤ 120 s setup; ≤ 300 s to first split | S06, S09 | Timed path (S06.3.7, S06.12.9) — **evidence strength depends on A-12** | DESIGNED |
| NFR-05 | Financial correctness over convenience | Zero discrepancy; ≥ 3,000 property cases per run | S05, S09 | `tool/reconcile.dart`; property seed record | DESIGNED |
| NFR-06 | Responsive on mid-tier hardware | 14 budgets, P-01…P-14 (§6.6) | S05, S08, S09 | Benchmark table naming the device (S09.6) | DESIGNED |
| NFR-07 | Durability and recoverability | Byte-identical round-trip; framework plus v1 fixture | S04, S08 | Round-trip test (S04.9.7); committed v1 fixture | DESIGNED |
| NFR-08 | Accessibility | TalkBack journey completable; 48dp / 4.5:1 / 200% | S06, S09 | Accessibility log (S09.5); goldens in four variants | DESIGNED |

---

## Cross-referenced pairs

Three requirements are registered in both registries and state the same claim. Both rows are kept,
because the stage plan references both ids, but **coverage is counted once per pair** — see
assumption A-14.

| Pair | Claim |
|---|---|
| FR-15 ↔ NFR-02 | The app works fully offline |
| FR-09 ↔ NFR-01 | Financial data reaches only the user's own Google account |
| FR-07b ↔ NFR-03 | Business and personal data stay separate |

## Matrix integrity checks — substage 1.8.2

| Check | Result |
|---|---|
| One row per manifest FR | 15 rows, FR-01…FR-15 ✅ |
| One row per manifest NFR | 8 rows, NFR-01…NFR-08 ✅ |
| No empty implementing-stage cell | 23 of 23 populated ✅ |
| No empty verifying-artefact cell | 23 of 23 populated ✅ |
| Every FR has at least one story | 15 of 15 ✅ |
| Every status seeded | 23 of 23 ✅ |

## Design artefacts per requirement — substage 2.13.6

Added at the Stage 2 gate. Each requirement's design artefact, which is what moved it to `DESIGNED`.

| Requirement | Design artefact |
|---|---|
| FR-01, FR-08 | SCHEMA §3.2 `categories`; seed flags; NAVIGATION category screens |
| FR-02, FR-06 | SCHEMA §3.5 `rule_lines` two-level split; ALLOCATION §5 |
| FR-03 | SCHEMA §3.3 `accounts` — label with derived total, no balance column |
| FR-04 | SCHEMA §3.6 `income_events`; ALLOCATION §1, §2, §5, §3; ARCHITECTURE §10.1 |
| FR-05, FR-07 | SCHEMA `scope` columns; NAVIGATION §5 central scope filter |
| FR-09, FR-15 | ADR-002; ARCHITECTURE §5, §6; SCHEMA §8 |
| FR-10 | SCHEMA `ceiling_minor`, `redirect_target_category_id`; ALLOCATION §3 |
| FR-11 | SCHEMA `bill_amount_minor`, `period_anchor_day`; ALLOCATION §3.1; SCHEMA V-20 |
| FR-12 | ALLOCATION §4; SCHEMA `overrides_json` |
| FR-13 | SCHEMA §7.1 balance policy; ARCHITECTURE §3.4 |
| FR-14 | SCHEMA §5.6 Q4; ARCHITECTURE §9; NAVIGATION `Reports` |
| NFR-01 | ADR-002; NG-08; guard G6 |
| NFR-02 | ARCHITECTURE §5.5, §3.4 |
| NFR-03 | NAVIGATION §5; SCHEMA `scope` columns |
| NFR-04 | NAVIGATION §1.1 onboarding chain; PRD §2.7's one-tap-per-screen constraint |
| NFR-05 | ALLOCATION §5.7, §3.8 assertions; §9.2 properties P1–P7 |
| NFR-06 | ARCHITECTURE §9; SCHEMA §5.5 indexes; §7.1 balance cache |
| NFR-07 | SCHEMA §7.2 migrations; §7.4 version refusal |
| NFR-08 | NAVIGATION §7 per-screen states; ARCHITECTURE §8 theming obligations |

## Update obligations by stage

| Stage | Obligation |
|---|---|
| S02.13.6 | Every row → `DESIGNED`, naming the design artefact |
| S03.9.7 | Update rows whose implementing artefact now exists |
| S04.11.4, S05.10.6, S06.12, S07, S08.8.4 | Update rows this stage advances |
| S09.8.5 | Every row shows a verifying artefact and a final status; **no row may lack one** |
| S10.7.7 | Finalise |
