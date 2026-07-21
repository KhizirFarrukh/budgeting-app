# Stage 2 report — System Design & Architecture

**Stage:** S02 · **Substages:** 13 of 13 complete · **Status:** awaiting approval gate
**Branch:** `v1.0` · **Date:** 2026-07-20

---

## 1. What was produced

| File | Description |
|---|---|
| `docs/ARCHITECTURE.md` | Ten sections: four layers with per-layer import allow-lists, six mechanical guards, the verbatim directory tree, state management, sync architecture, merge semantics and the HLC, technology decisions, cross-cutting concerns, performance design, and two sequence diagrams |
| `docs/SCHEMA.md` | Eight sections: conventions, twelve tables, every column, twelve enumerations, an ER diagram, 22 check constraints, 10 unique constraints, 21 foreign keys, 11 indexes, 28 validation rules, the balance policy, migrations, retention, and the remote payload format |
| `docs/ALLOCATION_ALGORITHM.md` | Ten sections: request and result contracts, an eight-rule purity contract, phase A with its derived overflow bound, phase B with three termination defences, overrides and reversals, a twelve-entry error taxonomy, complete pseudocode, the fixture format, seven required properties, and fifteen verified golden vectors |
| `docs/NAVIGATION.md` | 22 screens, the navigation graph, per-flow Android back behaviour, business scope separation, and 66 per-screen states |
| `docs/decisions/ADR-001` … `ADR-004` | State management, sync target, database, supporting libraries |
| `docs/reports/STAGE_2_WORKLOG.md` | Per-substage evidence with acceptance-criterion verification |

**Entry condition.** Stage 2 requires the five Stage 1 blocking questions answered or explicit
permission to proceed on the recommendations. The user reviewed them at the gate and instructed work
to continue; that was recorded as authorisation for all five, with OQ-02 and OQ-12 flagged as the two
most expensive to reverse. **All five recommendations are now baked into SCHEMA section 3.**

## 2. How each acceptance criterion was verified

All 62 acceptance criteria across the 13 substages were verified and recorded in the worklog. The
five stage-level criteria:

| Criterion | Verification | Result |
|---|---|---|
| Every invariant names the design element that enforces it | Section 3 below — all twelve, no gaps | ✅ |
| Every PRD story maps to a design element | Section 4 below — all 37 | ✅ |
| All worked examples re-verified and conserving | Section 5 below — four examples re-derived independently by script | ✅ |
| `TRACEABILITY.md` updated to `DESIGNED` for every requirement | 23 of 23 rows | ✅ |
| The frozen-decisions list is written | Section 7 below — 14 decisions | ✅ |

## 3. The invariant walk (substage 2.13.3)

An invariant with no named enforcing element is a gap that must be closed before the gate. **There
are none.**

| INV | Rule | Enforcing design elements |
|---|---|---|
| **INV-01** | Integer money only | SCHEMA S-01 (no real/float/numeric column exists anywhere); guard **G3**; a runtime check reading the *live* schema (S04.3.6); the `Money` value type with no double-accepting API; purity rule **P-8**; ARCHITECTURE 8.5's serialisation/display split so neither path can introduce a float |
| **INV-02** | Conservation of money | ALLOCATION 5.7 assertions **A-1/A-2** after each split; 3.8 final assertion before returning; both **throw** rather than adjust; property **P1** over thousands of cases; the running total shown in the preview (US-014) |
| **INV-03** | Append-only ledger | SCHEMA 3.7 — no update or delete path at any layer; check constraint **C-15** forbidding a tombstoned ledger row; the repository exposes no update or delete method (S04.5.1); corrections are compensating entries (4.8); foreign keys are `RESTRICT`, never `CASCADE` |
| **INV-04** | Balances are derived | SCHEMA 7.1 — cache updated only inside the ledger write transaction, **device-local and excluded from sync** so a merge can never import one; two-tier verifier (cheap count every cold start, full recompute after every merge); ARCHITECTURE 3.2 forbids holding a balance in the state layer |
| **INV-05** | No third-party infrastructure | **ADR-002** — the control question answered explicitly; **NG-08** makes it permanent; guard **G6** over the resolved dependency tree; provider SDK confined to one directory; traffic capture at S07.10 and S09.7 |
| **INV-06** | Never block on the network | ARCHITECTURE 5.5 — no sync state blocks the UI, no modal, no blocking spinner; 3.4's path never awaits; NFR-02's eleven named flows verified with the network *stalled*, not merely off |
| **INV-07** | Redirect chains terminate | ALLOCATION 3.5 — three independent defences (per-parcel visited set, `MAX_HOPS` = 32, uncapped sink); check constraint **C-19** makes a capped sink impossible; validation V-12 (cycle detection), V-13/V-15 (sink protected); 3.7 makes a missing sink a **typed failure** |
| **INV-08** | Deterministic, pure engine | ALLOCATION 2.5 rules **P-1 to P-8**; guard **G2**; 5.4's ordinal tie-break with locale comparison forbidden; properties **P4** and **P6**; `overrides_json` stored as an event **input** (A-23) so overridden events stay reproducible |
| **INV-09** | UTC epoch milliseconds | SCHEMA S-03 for every timestamp column; ARCHITECTURE 8.3; guard **G4** bans `DateTime.now()` outside the `Clock`; timezone applied only at presentation and in reporting, which receives it as an **input** |
| **INV-10** | Soft delete with tombstones | SCHEMA S-06 and the five sync columns on all nine synced tables; 7.3's safe-purge condition (all devices acknowledged **and** a 180-day floor); ARCHITECTURE 6.1's tombstone rule and 6.3's worked month-offline scenario |
| **INV-11** | Versioned, effective-dated rules | SCHEMA 3.4 `sealed_at_ms` — a version referenced by an income event can never change; `income_events.rule_version_id` records what was applied; `overrides_json` preserves the rest of the input tuple; reversal mirrors rather than recomputes (4.8) |
| **INV-12** | Client-generated UUIDs | SCHEMA S-04 — TEXT UUID primary keys, no auto-increment anywhere; ARCHITECTURE 8.6 (v7 for ledger rows, v4 for configuration) via an injected `IdGenerator`; idempotent inserts keyed by UUID (S04.5.4) |

## 4. The requirement check (substage 2.13.4)

Every PRD user story maps to a design element. Grouped by area; all 37 covered.

| Stories | Design elements |
|---|---|
| US-001, US-007 (percentages) | SCHEMA 3.5 `rule_lines` two-level split; V-01/V-02 totalling exactly 10000; ALLOCATION 5.3 |
| US-002 (personal-only) | SCHEMA `category_groups.is_active`; NAVIGATION 5.1; assumption A-20 |
| US-003 to US-005 (suggestions) | SCHEMA `is_suggested_seed`, `seed_version`; NAVIGATION `Category Selection` |
| US-006 (categories) | SCHEMA 3.2; NAVIGATION `Category List` / `Category Edit`; V-14 archive guard |
| US-008 to US-010, US-012 (scope) | SCHEMA `scope` columns; NAVIGATION 5 central filter; ARCHITECTURE 3.2 scope state |
| US-011 (accounts) | SCHEMA 3.3 — a label with a derived total, no balance column |
| US-013 to US-015 (income) | SCHEMA 3.6; ALLOCATION 1, 5 and 3; ARCHITECTURE 10.1 |
| US-016 (override) | ALLOCATION 4.1 to 4.7; `overrides_json`; NAVIGATION `Adjust Split` |
| US-017 (undo) | ALLOCATION 4.8; SCHEMA `reverses_entry_id`, `reversed_by_event_id` |
| US-018, US-019, US-022 (ceilings) | SCHEMA `ceiling_minor`, `redirect_target_category_id`; ALLOCATION 3.1 to 3.9 |
| US-020, US-021 (bills) | SCHEMA `bill_amount_minor`, `period_anchor_day`; ALLOCATION 3.1; V-20 clamp rule |
| US-023 (dashboard) | SCHEMA 7.1 balance policy; ARCHITECTURE 3.4; NAVIGATION 7 |
| US-024 to US-026 (spending, history) | SCHEMA 3.8; NAVIGATION `Add Spending`, `Transaction History`; ARCHITECTURE 9.3 pagination |
| US-027 (offline) | ARCHITECTURE 5.5 and 3.4; INV-06 enforcement |
| US-028 to US-031 (sync) | ADR-002; ARCHITECTURE 5 and 6; SCHEMA 8 |
| US-032 (backup) | SCHEMA 7.2, and 7.4's version refusal |
| US-033 to US-037 (reports, export) | SCHEMA 5.6 Q4; ARCHITECTURE 9.1 to 9.3; NAVIGATION `Reports` |

**The four interaction cases (PRD 5.6)** each have a design element: I-1 to ALLOCATION 4.5;
I-2 to 3.1's fixed-recurring headroom; I-3 to 3.3's worklist chaining; I-4 to 3.5's T-3 plus C-19.

## 5. Worked examples re-verified (substage 2.13.5)

Re-derived independently by script at review time, not carried forward from when they were written:

```
5.4 tie-break, income 3:   floors 0/0/1  remainders 9999/9999/2  leftover 2 -> 1/1/1, sum 3
5.5 rounding, income 100:  floors 33/33/33  remainders 3300/3300/3400  leftover 1 -> 33/33/34, sum 100
3.9 chained, 300000:       phase A 120000/105000/75000
                           medical accepts 80000 ovf 40000 | emergency accepts 100000 ovf 5000
                           emergency 2nd parcel accepts 0 ovf 40000 | trip = 75000+5000+40000 = 120000
                           TOTAL 300000  conserved=True
4.7 override, 500000:      remaining 300000, divisor 6000 -> 175000/125000, TOTAL 500000 conserved=True
                           counterfactual with divisor 10000: 105000/75000 = 180000 -- SHORT BY 120000
5.6 bound:                 MAX_MONEY_MINOR=922337203685477
                           bound*10000 fits=True   (bound+1)*10000 fits=False
```

**All conserve exactly.** The counterfactual line confirms the defect caught at 2.8 (section 11).

## 6. Consistency checks (substage 2.13.2)

| Check | Result |
|---|---|
| Every SCHEMA entity used somewhere, or justified as reserved | ✅ All twelve tables are referenced by ALLOCATION or NAVIGATION. The six reserved columns are justified as PRD 3.4 accommodations and pinned unused by C-21/C-22 |
| Every NAVIGATION screen has the data it needs in SCHEMA | ✅ Checked screen by screen. `Diagnostics` needs the repair log, which SCHEMA 6.8 required as durable but no table held — **gap closed by amendment**, see below |
| Terminology matches the PRD glossary across all four documents | ✅ Design documents use PRD 9's right-hand column exclusively; product language stays in the PRD and the UI, per 9.1's binding mapping |
| Numbers stated in one document match the same numbers elsewhere | ✅ `MAX_MONEY_MINOR`, `MAX_HOPS` = 32, 10000 basis points, the 19 seeded categories, the five-year row counts and the NFR-06 budgets all cross-checked |

### 6.1 Amendment after the gate was drafted — the repair log had no table

The consistency pass found that SCHEMA 6.8 requires every post-merge repair to be "written to a
durable repair log and surfaced to the user", and NAVIGATION's `Diagnostics` screen displays it —
**but no table held it.** This report originally filed that as "a Stage 4 obligation."

**That triage was wrong, and is corrected here.** Stage 4 transcribes SCHEMA *exactly* (substage
4.3.5 proves the transcription faithful with a comparison table). A table absent from SCHEMA is a
table Stage 4 will not build, so the gap would have survived to Stage 7 substage 7.6.4 and been
discovered mid-implementation, with the merge engine having nowhere to write.

SCHEMA now defines **`repair_log`** (section 3.13) as a thirteenth table: device-local, append-only,
with `RepairKind` covering all six repairs from 6.8, a `merge_session_id` grouping repairs from one
merge, and index IX-12 serving the unread-repairs query. Wired through the table inventory, the
enumerations, the ER diagram, the index and query tables, and the sync payload's travels/does-not-
travel list.

**It is device-local, and that follows from a property already required.** Section 6.8 mandates that
repairs be *deterministic* — two devices performing the same merge produce identical repairs. Each
device therefore generates the same log entries independently, so syncing the log would duplicate
every one.

Recorded here rather than silently patched, per the manifest's `sdlc_discipline` rule.

## 7. Frozen decisions (substage 2.13.8)

Later stages may not change these without a new ADR.

| # | Decision | Source |
|---|---|---|
| 1 | Riverpod for state management; no Riverpod persistence feature at any stage | ADR-001 |
| 2 | Drive `appDataFolder`; **no developer backend, ever** | ADR-002, NG-08 |
| 3 | Drift over SQLite | ADR-003 |
| 4 | Layer-first directory structure; the six guards G1 to G6 | ARCHITECTURE 2, 4 |
| 5 | Money is int64 minor units everywhere, including exports and fixtures | SCHEMA S-01 |
| 6 | The ledger has no update or delete path at any layer | SCHEMA 3.7, C-15 |
| 7 | Balances are derived; the cache is device-local and never synced | SCHEMA 7.1 |
| 8 | `MAX_MONEY_MINOR` = 922,337,203,685,477 | ALLOCATION 5.6 |
| 9 | The split primitive divides by the **sum of the weights**, never a constant | ALLOCATION 5.2 |
| 10 | Phase B is a **FIFO** worklist; parcels are never merged or reordered | ALLOCATION 3.4 |
| 11 | `MAX_HOPS` = 32; all three termination defences retained | ALLOCATION 3.5 |
| 12 | An override may exceed a ceiling and is **not** redirected away | ALLOCATION 4.5 |
| 13 | Reversal mirrors recorded allocations; it never recomputes | ALLOCATION 4.8 |
| 14 | Last-write-wins is per record and applies only to configuration, never to money | ARCHITECTURE 6.2 |

## 8. Decisions and ADRs

Four ADRs, all with the six required sections.

| ADR | Decision | The argument that settled it |
|---|---|---|
| **001** | Riverpod over Bloc | Bloc is commonly recommended for financial apps on audit-trail grounds — rebutted directly: this app's audit trail is the append-only ledger, durable and user-visible, whereas a Bloc event log is in-memory and dies with the process |
| **002** | Drive `appDataFolder` over Firestore | Who *can* read the data, not who intends to. A Firestore document lives in a developer-owned project, making the developer the data controller with console access. Firestore is better on engineering merits and none of it matters |
| **003** | Drift over sqflite and Isar | sqflite has no reactive layer, and that is the mechanism ARCHITECTURE 3.4 runs on — the writer that would forget to notify is the sync worker, failing silently. Isar is abandoned *and* cannot express the 22 check constraints and 21 foreign keys the design relies on |
| **004** | Eleven libraries adopted, three declined | CSV, dependency injection and JSON codegen declined because the design has specific requirements a general library would fight |

## 9. Open questions

**None blocking Stage 3.** The five Stage 1 blocking questions were authorised and are now
implemented in the schema. Two Stage 3 verifications carry pre-decided fallbacks (ADR-004): `glados`
maintenance leads to hand-rolled seeded generators; `workmanager` leads to dropping the periodic
trigger. Neither can affect correctness.

**OQ-08 resolved** as part of this stage's `open_questions_to_resolve`: no payload encryption in
v1.0, with the encryption-scheme marker present in the remote manifest from day one (deferral D-04).

## 10. Deviations from the stage plan

| Deviation | Why |
|---|---|
| **Six guards rather than four** | Added G2 (engine purity — INV-08 is stronger than general layering) and G5 (database containment), the latter explicitly required by substage 2.2.3's wording |
| **Two failures beyond the plan's ten** | `OverrideTargetUnknown` (5.6.3 requires the validation rule but the plan listed no failure for it) and `PeriodDefinitionInvalid` (reachable once `PeriodDefinition` became a request field) |
| **`sealed_at_ms` added to rule versions** | Without it, editing a rule version referenced by a past event would silently re-derive history and break INV-11 |
| **`Diagnostics` screen has no PRD journey** | Declared in NAVIGATION 1.4. SCHEMA 7.1 and 6.8 both require a user-facing surface; droppable in Stage 6 without affecting any journey |
| **Sixteen fixture files for fifteen vectors** | V-11 covers zero *and* negative income; the fixture format holds one request per file |
| **The reference example produces five line items, not three** | Implements the PR-01 plan fix: under the FIFO worklist, Emergency's base parcel is resolved before Medical's overflow arrives |

## 11. The defect this stage caught in its own work

Substage 2.8.4 forbids carrying an unverified expected value into Stage 5. Rather than hand-check,
**the algorithm as specified was implemented and all fifteen vectors executed through it.**

That caught a real defect: **the split primitive divided by the constant 10000.** Correct for both
phase A applications, where validation guarantees weights total 10000 — and wrong for override
redistribution, where the non-overridden weights total 6000. V-09 would have produced 105,000 and
75,000: **180,000 against a `remaining` of 300,000, leaving 120,000 undistributed**, re-confirmed in
section 5 above.

Fixed in ALLOCATION 5.1 and 5.2, with the reasoning recorded rather than silently corrected. Section
5.2 now carries an explicit warning that an implementation hardcoding 10000 **passes every phase A
vector and fails only under override.**

It survived two readings of the section, because every example in section 5 happens to use weights
totalling 10000. That is the concrete justification for the rule that produced it.

## 12. What Stage 3 will consume

| From | Drives |
|---|---|
| ARCHITECTURE 4 | The directory tree, created verbatim at 3.2 |
| ARCHITECTURE 2.3 | Guards G1 to G6, implemented at 3.4 and each demonstrated failing |
| ARCHITECTURE 7 | The dependency list for 3.3; versions resolved from pub.dev, not from here |
| ARCHITECTURE 8.5 | The money formatter's two-representation split, built at 3.6 |
| NAVIGATION 1 and 2 | One stub per route at 3.7; the router at 3.7.1 |
| NAVIGATION 4 | Android back behaviour at 3.7.4 |
| ALLOCATION 9.1 | The fixture loader at 3.8.5 — adding a vector must need no code change |
| SCHEMA (all) | Stage 4's transcription, proven faithful by a comparison table |

**Constraints Stage 3 must honour:** the tree is created verbatim, with any wanted-but-absent folder
raised as a design gap rather than invented (3.2.1); every guard must be demonstrated **failing** on
a deliberate violation, with output captured; no business logic, persistence or network code exists
at the end of Stage 3; and versions are resolved at implementation time, never pasted from memory.

---

## 13. Gate

Stage 2 (System Design & Architecture) is complete. Deliverables: `ARCHITECTURE.md`, `SCHEMA.md`,
`ALLOCATION_ALGORITHM.md`, `NAVIGATION.md`, and ADR-001 through ADR-004.

**Key decisions to confirm:**

1. **Sync target — Drive `appDataFolder`, not Firestore** (ADR-002). The developer operates no
   server and has no technical means of reading your data. The costs: it uses your own Drive quota,
   all merging happens on-device, and the OAuth scope needs Google verification before public
   release.
2. **Ceiling and redirect behaviour.** A full category passes its surplus to the category you named,
   hop by hop, with every hop shown. Chains end at a non-deletable catch-all. **A manual override may
   deliberately exceed a ceiling** — you are warned, and the money stays where you put it rather than
   being redirected away.
3. **Bank accounts are labels with a derived total** (OQ-02's answer), so there is no account balance
   column and no transfers.
4. **Categories are flat** (OQ-12's answer), with a reserved column so nesting remains possible later.

**No open questions block Stage 3.**

Do you approve moving to Stage 3, project scaffolding?
