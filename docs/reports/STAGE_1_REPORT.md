# Stage 1 report — Requirements Gathering & Documentation

**Stage:** S01 · **Substages:** 8 of 8 complete · **Status:** awaiting approval gate
**Branch:** `v1.0` · **Date:** 2026-07-19

---

## 1. What was produced

| File | Description |
|---|---|
| `docs/PRD.md` | The complete product requirements document: purpose, personas and journeys, scope and cut line, money model, 37 user stories with acceptance criteria, measurable NFRs, data volume, open questions, glossary, traceability reference, and the source requirement inventory appendix. |
| `docs/OPEN_QUESTIONS.md` | 18 questions — 10 carried from the manifest, 8 raised during this stage — each with options, consequences and a recommended default. Five are blocking. |
| `docs/ASSUMPTIONS.md` | 26 assumptions, each with its reason, its impact if wrong, and the substage that reviews it. |
| `docs/TRACEABILITY.md` | The living matrix: 23 rows, one per manifest requirement, each naming stories, implementing stages, verifying artefact and status. |
| `docs/PLAN_REVIEW.md` | Audit of all ten stage files and the manifest, performed at the user's request mid-stage. Seven defects fixed, four findings recorded. |
| `docs/reports/STAGE_1_WORKLOG.md` | Per-substage evidence log with acceptance-criterion verification. |

**Counts:** 37 user stories · 18 CRITICAL requirements identified · 4 interaction cases specified ·
18 open questions (5 blocking) · 26 assumptions · 14 deferrals classified · 9 non-goals ·
16-item release cut line.

## 2. How each acceptance criterion was verified

### Stage-level definition of done

| Criterion | Verification | Result |
|---|---|---|
| PRD contains all required sections with no placeholder text | Sections 1–10 plus Appendix A present in the required order. `grep -i "TODO\|TBD\|placeholder\|lorem"` over `docs/` returns one hit: the header line asserting no placeholder text exists. | ✅ |
| Every manifest FR and NFR traceable to at least one user story | §5.7 coverage table: 15 of 15 FRs covered, no gaps. NFRs covered via §6 and the matrix. | ✅ |
| All open questions registered, prioritised, carrying a recommended default | 18 of 18 carry a default; split 5 blocking / 13 non-blocking. | ✅ |
| No section contains implementation detail | Read end to end. One bounded exception, declared in the PRD header: §3.4 names deferred features' schema accommodations as field *concepts*, which substage 1.6.4 explicitly requires. | ✅ |
| Blocking questions put to the user in plain language | `OPEN_QUESTIONS.md` Part 3 — five questions, no jargon, each with a recommendation. | ✅ |

### Mechanical checks

Completeness pass (1.8.5) — every inventoried id present in the PRD:

```
COMPLETENESS PASS: all 15 FR, 8 NFR, 15 IMP, 9 NG and 37 US ids present in PRD.md
```

Register continuity:

```
REGISTER PASS: OQ-01..OQ-18 and A-01..A-26 all present
```

Banned-vagueness check over the PRD (substage 1.3):

```
grep -i "\betc\b|and so on|appropriate|as needed"  ->  No matches found
```

Prompt-file integrity after the mid-stage audit:

```
All 11 JSON files parse OK
stage_01..stage_10: substages=98 work_steps=703 acceptance_criteria=465
```

### Per-substage criteria

All 33 acceptance criteria across the eight substages were verified and recorded in
`STAGE_1_WORKLOG.md`. **32 passed; one is partial:**

- **Substage 1.2, "at least five failure journeys, none ending in a dead end or data loss"** — seven
  written, six clean. FJ-5(b) ends in data loss and cannot be designed away (see §5, ESC-1.2-A).
  Recorded as ⚠️ 6-of-7 rather than ticked.

## 3. Decisions made, and their ADR numbers

**No ADRs were written in this stage, and none should have been.** The decision log begins at
substage 2.1 with ADR-001 (state management); Stage 1's output is specification, not technical
choice. The manifest's `stage_must_not` forbids choosing packages, state management or database in
this stage, and none was chosen.

Product-level decisions recorded in the PRD rather than as ADRs:

| Decision | Where | Character |
|---|---|---|
| Version 1 cut line — 16 release-blocking capabilities | §3.3 | Scope |
| Sync is in scope but **not** release-blocking | §3.2 | Scope + schedule; mirrors R-04's own mitigation |
| 14 deferrals classified; 6 need schema accommodation now | §3.4 | Constrains Stage 2's data design |
| Ceiling is a finish line, never a spending limit | §4.3 | Product language |
| Manual override may exceed a ceiling; warned, obeyed, never redirected away | §4.7, §5.6 I-1 | Behaviour |
| Spending reopens a goal's room; a bill's period cap is unaffected | §4.2, A-19 | Emergent from headroom definitions, not chosen |
| Three new permanent non-goals: no forecasting, no developer backend at any version, no web | §3.1 | Scope |

## 4. Assumptions recorded

26, in `docs/ASSUMPTIONS.md`: A-01…A-13 are defaults taken on non-blocking questions; A-14…A-26 are
ambiguities resolved from the manifest or the design plan rather than escalated.

**The three carrying real residual risk:**

- **A-11** — a user who never signs in and never exports loses everything with the device. No
  recovery path exists, and none can while NFR-02 guarantees the app works with no account.
- **A-12** — NFR-04 may be reported as met on evidence that cannot detect the failure it exists to
  catch, if no first-time observer is available.
- **A-13** — a fourteen-MUST v1 with almost no cut line; the pressure lands in Stage 6.

## 5. Open questions still blocking

**Five. Stage 2 may not begin until these are answered, or until the recommendations are explicitly
authorised.** Full text with options and consequences in `OPEN_QUESTIONS.md` Part 3.

| # | Id | Question | Recommendation |
|---|---|---|---|
| 1 | OQ-02 | Bank accounts — a label with a total, or real balances with transfers and reconciliation? | A label with a total |
| 2 | OQ-03 | Is there a third kind of category, an open envelope with no target and no bill? | Yes — six of the nineteen suggestions already assume it |
| 3 | OQ-07 | A permanent catch-all that always accepts overflow, renameable but not deletable, plus a business one? | Yes to both |
| 4 | OQ-11 | Does everything arriving count as income, and does it all split the same way? | Yes to both, with per-payment override |
| 5 | OQ-12 | Do categories nest into real folders? | Flat; nesting reserved for later |

Each changes the shape of stored data, which is the one thing expensive to change after release.
Five of the manifest's eight nominally-blocking questions were demoted after the 1.7.4 ruthlessness
pass, each with a specific reason recorded in the register.

### Escalations for the user's attention (non-blocking)

- **ESC-1.2-A** — the no-sign-in, no-backup, lost-phone path ends in unrecoverable data loss. Related
  question: OQ-16, how insistently should the app prompt for a backup?
- **ESC-1.5-A** — NFR-04 is the only requirement that cannot be verified mechanically; it needs a
  person who has never seen the app and did not build it. Related question: OQ-17.
- **ESC-1.6-A** — 14 of 15 requirements are MUST, so scoping produced almost no cuts. Related
  question: OQ-18. If a shorter first release is wanted, FR-03 and FR-14 are the candidates.

## 6. Deviations from the stage plan

| Deviation | Why |
|---|---|
| `IMP-xx` namespace introduced in 1.1 | Step 1.1.1 requires inventorying implied requirements, but the manifest defines no namespace for them. Each was adjudicated in §10 — promoted, deferred or folded — so none is left dangling. |
| CRITICAL widened beyond "moves money" | Figures that must reconcile exactly with the ledger (dashboard, summaries, export, backup) need the same failure criteria. Definition stated in §A.5. |
| Two extra failure journeys in 1.2 | IMP-12 and INV-11 had no journey exercising them and would have reached Stage 2 as invariants with no screen behind them. |
| A screen-label set fixed in 1.2 | Naming screens ad-hoc across nine journeys would have seeded synonyms that break 1.8's consistency pass. Stage 2 substage 2.11 still owns the definitive inventory. |
| Interaction cases written as a subsection, not four stories | Each is a behaviour of existing stories; standalone stories would have duplicated criteria. |
| A third scope disposition — "in scope but not release-blocking" | The plan's binary in/deferred split yields no information against a brief that is 14/15 MUST. |
| NFR-02's "core flows" enumerated as 11 named flows | The manifest left the set undefined, which would have let Stage 9 choose its own scope. |
| NFR-07's v1.0 caveat recorded | "Fixtures from every prior version" is unfalsifiable at v1.0. The binding v1.0 condition is stated instead. |
| A fourth data-volume profile (Stress) added | Gives design headroom above the worst real case and matches the 100-category figure NFR-06 benchmarks against. |
| A product-language ↔ glossary mapping table added (§9.1) | 1.4 required plain language; 1.8.4 forbids introduced synonyms. The mapping makes both true at once and binds Stage 2 to the glossary column. |
| **Mid-stage: all ten stage files audited and seven defects fixed** | Requested by the user between 1.2 and 1.3. Recorded in `PLAN_REVIEW.md`. Two would have caused real damage: a Stage 2 worked example contradicting its own algorithm, and a Stage 7 gate that was unsatisfiable as written. |

## 7. What Stage 2 will consume

| From | Drives |
|---|---|
| §4 the money model | The data model — entity definitions, category types, ceiling and headroom semantics, the conservation rule |
| §4.5 the worked chain | The reference example for substage 2.6.9, already aligned to the FIFO worklist |
| §2 journeys, §2.3 screen labels | The navigation graph and screen inventory (2.11); every journey step must map to a named screen |
| §5 stories and criteria | The design elements that must exist; 2.13.4 checks every story maps to one |
| §5.6 interaction cases | Override, ceiling and period semantics for substages 2.6 and 2.7 |
| §6 NFR targets | Architecture trade-offs, particularly the balance-cache decision (2.4.5) |
| §7 data volume | Index sizing (2.4.3) — the N + H multiplier means allocation rows are 80–89% of the ledger |
| §3.4 accommodations | Six fields the schema must carry at v1.0 even though their features are deferred |
| §8 answered questions | Unblocks 2.3 (data model), 2.6 (ceilings and sink) and 2.9 (sync) |
| `TRACEABILITY.md` | Updated to `DESIGNED` at 2.13.6 |

**Design constraints Stage 2 must honour, derived from this stage:**

1. The five blocking answers, once given, are binding on the data model.
2. Six accommodations must be present at v1.0: reserved target date, ceiling kind discriminator plus
   parameter, parent category reference, remote encryption marker, soft budget plus period, rule-set
   discriminator (§3.4).
3. A manual override must be stored as an **input** to the income event, never as an edit of its
   output — otherwise INV-08 determinism and INV-11 explainability both break (A-23).
4. Period-boundary logic must live in exactly **one** place shared by the data layer and the engine;
   implemented twice, the anchor-day-31-in-February rule will drift (`PLAN_REVIEW.md` PR-11).
5. The balance cache is effectively mandatory at the Heavy profile, not a preference (§7.4).
6. Stage 2 vocabulary is the right-hand column of §9.1. Product language is for the UI, not the
   design documents.

---

## 8. Consistency pass findings (substage 1.8.4)

Read end to end in one sitting. Four findings, all resolved:

1. **Terminology conflict between substages.** 1.4 required plain language for a non-developer; 1.8.4
   forbids introduced synonyms. Both are right. Resolved by adding §9.1, an explicit binding mapping
   — plain words for the product, glossary terms for the design, with the left column declared a
   defect in any Stage 2+ document.
2. **A completeness gap in my own 1.1 inventory.** The manifest's platform block declares web support
   out of scope; Appendix A recorded the iOS constraint but missed the web one. Caught by the 1.8
   completeness pass, added as NG-09, and **recorded as a visible correction rather than silently
   repaired** — an inventory's value depends on its errors being visible.
3. **Appendix A and §3.1 hold different non-goal counts** (7 versus 9). Not a contradiction: Appendix
   A is the *source* inventory of what the manifest said; §3.1 is the *current* list including NG-07
   and NG-08, derived in 1.5 and 1.6. A note in §A.4 makes the relationship explicit.
4. **Numbers cross-checked across sections and found consistent:** setup timings (106 s / 166 s in
   §2.7 against ≤120 s / ≤300 s in §6.4 and "under two minutes" in §3.3); the 19 seeded categories and
   their 10 / 6 / 3 type split (§A.0, §A.6.1, OQ-03); journey step counts (J1 = 11+6+5 = 22, J2 =
   11+7 = 18, cited identically in §2 and §3.6); the §4.5 worked example, re-verified by hand
   (12,000 + 10,500 + 7,500 = 30,000 in; 8,000 + 10,000 + 12,000 = 30,000 out); and the five-year row
   counts (§7.3 against §7.4's storage table).

---

## 9. Gate

Stage 1 (Requirements) is complete. Deliverables: `PRD.md`, `OPEN_QUESTIONS.md`, `ASSUMPTIONS.md`,
`TRACEABILITY.md`, plus the mid-stage `PLAN_REVIEW.md`.

**Five blocking questions need answers before design begins** — §5 above, full text in
`OPEN_QUESTIONS.md` Part 3. Answering "go with your recommendations" is a complete answer.

Do you approve moving to Stage 2, system design and architecture?
