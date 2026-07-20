# PookieBudget — traceability matrix

Seeded in substage 1.8. **Every later stage updates this file rather than creating its own.** A
matrix built once and never updated is worse than none, because it looks authoritative.

**Status values:** `NOT_STARTED` → `DESIGNED` (S02) → `IMPLEMENTED` → `VERIFIED` (S09).
All rows are seeded `NOT_STARTED`; Stage 1 produces specification, not implementation.

**Implementing stages** are the union of the manifest's per-requirement stage list and the stages
whose substages claim coverage — the convention adopted in `PLAN_REVIEW.md` PR-08.

---

## Feature requirements

| FR | Statement (abbreviated) | Stories | Implementing stages | Verifying artefact | Status |
|---|---|---|---|---|---|
| FR-01 | Add multiple user-definable categories | US-006 | S02, S04, S06 | Category management widget tests; S09.2 journey | NOT_STARTED |
| FR-02 | Fixed percentage of income per category | US-007 | S02, S04, S05, S06 | Split primitive unit tests; golden vectors V-01…V-03 | NOT_STARTED |
| FR-03 | Assign which account stores which category's funds | US-011, US-012 | S02, S04, S06 | Per-account total reconciliation test (S06.7.6) | NOT_STARTED |
| FR-04 | Log an income event and auto-split it | US-013, US-014, US-015 | S05, S06 | Golden vectors; preview-equals-confirmed test (S06.4.6) | NOT_STARTED |
| FR-05 | Track spending categories separately from savings | US-008, US-024, US-026 | S02, S04, S06 | Group separation in model; scope isolation tests (S06.9.8) | NOT_STARTED |
| FR-06 | User selects top-level Spending / Savings / Business ratios | US-001, US-015 | S02, S05, S06 | Exact-100 constraint widget tests (S06.2.7) | NOT_STARTED |
| FR-07 | Business group has its own categories, kept distinct | US-009, US-010 | S04, S06 | Cross-screen scope test (S06.10.6) | NOT_STARTED |
| FR-08 | Suggested categories, all editable, plus custom | US-003, US-004, US-005 | S04, S06 | Seed idempotency and non-destructiveness tests (S04.7) | NOT_STARTED |
| FR-09 | Cloud sync to the user's own Google account | US-028, US-029 | S02, S07 | Two-device convergence suite; traffic capture (S07.10) | NOT_STARTED |
| FR-10 | Ceilings, with overflow redirecting to a fallback | US-018, US-019 | S02, S05, S06, S08 | Golden vectors V-04…V-07, V-14; ceiling journey (S09.2.2) | NOT_STARTED |
| FR-11 | Fixed-recurring distinguished from accumulating reserve | US-020, US-021 | S02, S04, S05, S06 | Golden vector V-08; period edge-case tests (S05.5.5) | NOT_STARTED |
| FR-12 | Manual override of a single event's split | US-016 | S02, S05, S06 | Golden vectors V-09, V-10; override journey (S09.2.4) | NOT_STARTED |
| FR-13 | Dashboard showing balance against ceiling | US-023 | S04, S06, S08 | Displayed-versus-derived assertion (S09.1.4) | NOT_STARTED |
| FR-14 | Monthly/yearly summaries, trends, CSV export | US-033, US-034, US-035, US-036, US-037 | S08 | Reconciliation suite (S08.7); export round-trip | NOT_STARTED |
| FR-15 | Offline-first; syncs when connectivity returns | US-027, US-029, US-030 | S04, S06, S07 | Offline flow run (S06.12.6); long-offline catch-up (S07.11) | NOT_STARTED |

## Non-functional requirements

| NFR | Statement (abbreviated) | Target | Implementing stages | Verifying artefact | Status |
|---|---|---|---|---|---|
| NFR-01 | No financial data leaves the user's own Google account | Binary — zero non-Google hosts from the app process; zero telemetry packages | S02, S07, S09 | Traffic capture (S07.10, S09.7); CI telemetry guard | NOT_STARTED |
| NFR-02 | Fully functional offline | Binary — the 11 core flows of §6.2, no network, no account | S04, S06, S07, S09 | Offline test run; manual checklist; S10.8.5 clean device | NOT_STARTED |
| NFR-03 | Personal and business separation | Binary — personal totals unchanged by business activity | S06, S08 | Cross-screen scope test (S06.10.6) | NOT_STARTED |
| NFR-04 | Usable by someone who has never budgeted | ≤ 120 s setup; ≤ 300 s to first split | S06, S09 | Timed path (S06.3.7, S06.12.9) — **evidence strength depends on A-12** | NOT_STARTED |
| NFR-05 | Financial correctness over convenience | Zero discrepancy; ≥ 3,000 property cases per run | S05, S09 | `tool/reconcile.dart`; property seed record | NOT_STARTED |
| NFR-06 | Responsive on mid-tier hardware | 14 budgets, P-01…P-14 (§6.6) | S05, S08, S09 | Benchmark table naming the device (S09.6) | NOT_STARTED |
| NFR-07 | Durability and recoverability | Byte-identical round-trip; framework plus v1 fixture | S04, S08 | Round-trip test (S04.9.7); committed v1 fixture | NOT_STARTED |
| NFR-08 | Accessibility | TalkBack journey completable; 48dp / 4.5:1 / 200% | S06, S09 | Accessibility log (S09.5); goldens in four variants | NOT_STARTED |

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
| Every status seeded | 23 of 23 `NOT_STARTED` ✅ |

## Update obligations by stage

| Stage | Obligation |
|---|---|
| S02.13.6 | Every row → `DESIGNED`, naming the design artefact |
| S03.9.7 | Update rows whose implementing artefact now exists |
| S04.11.4, S05.10.6, S06.12, S07, S08.8.4 | Update rows this stage advances |
| S09.8.5 | Every row shows a verifying artefact and a final status; **no row may lack one** |
| S10.7.7 | Finalise |
