# Plan review — all stage files audited

**Date:** 2026-07-19. **Scope:** `00_project_manifest.json`, `stage_01` through `stage_10`,
`prompts/README.md` — every file read end to end. Requested by the user before continuing past
substage 1.2: *"analyze all stage files and see if there is any issue, any problems, any
ambiguities, and fix what is needed."*

The manifest's own rule is that changes to the stage plan require raising them; this document is
that record. Every edit below was made under the user's explicit instruction and is listed with its
rationale. Nothing else in the prompt files was altered.

**Mechanical verification:** all 11 JSON files parse after editing. README totals re-counted by
script and confirmed exact: 98 substages, 703 work steps, 465 acceptance criteria.

---

## 1. Defects found and FIXED in the prompt files

### PR-01 — stage_02: worked example contradicted its own algorithm *(the one that mattered)*

2.6.3 specifies phase B as a **FIFO worklist**: the queue is seeded with the phase A allocations in
deterministic order, and overflow parcels are pushed to the back. Under that algorithm, Emergency's
base parcel (105,000) is processed **before** Medical's overflow (40,000) reaches it. The worked
example in 2.6.9 instead combined them ("pending 105,000 + 40,000 = 145,000, accepts 100,000,
overflows 45,000") — a merged-parcel flow the algorithm never performs.

Per-category totals are identical either way (80,000 / 100,000 / 120,000 — conservation holds), but
**line items, hop counts and the diagnostics trace differ**: under FIFO, Trip receives three line
items (75,000 base + 5,000 redirected hop 1 + 40,000 redirected hop 2), not base + one 45,000
redirect. Stage 5 implements the example verbatim and its tests assert on line items; Stage 6's
preview renders the trace. Left unfixed, the designer in 2.6/2.8 would have had to guess which side
was authoritative — precisely the class of ambiguity this plan exists to prevent.

**Fix:** 2.6.9 rewritten as an explicit pop-by-pop walkthrough consistent with 2.6.3, ending with a
note that the vector table asserts per-category totals and the line-item shape must follow the FIFO
flow. V-05's aggregate expectations were already correct and unchanged.

### PR-02 — stage_07 vs stage_10: release fingerprint required before the keystore exists

7.1.1 required registering **both** debug and release SHA-1 fingerprints with the OAuth client
during Stage 7 — but the upload keystore is not generated until 10.5.1, and with Play App Signing
(10.5.3) the Play-assigned signing key's fingerprint only exists after enrolment. The 7.1
acceptance criterion was unsatisfiable as written.

**Fix:** 7.1.1 now offers two valid paths — generate the upload keystore early and register it, or
record release registration as a named pending item that 10.5.4 completes — and notes the Play App
Signing fingerprint explicitly. The acceptance criterion matches. 10.5.4 already said "prepared in
Stage 7; confirm here", which now has a coherent referent.

### PR-03 — stage_03: dark-mode check on screens that don't exist yet

3.6.6 required verifying "every stub screen renders legibly in dark mode", with a matching
acceptance criterion — but stubs are created in 3.7, one substage later.

**Fix:** 3.6.6 rescoped to the theme and shared primitives (which do exist at 3.6); the per-stub
dark-mode walk moved into 3.7.6, whose route walk already visits every stub, with the acceptance
criterion moved accordingly.

### PR-04 — stage_02: SCHEMA.md section 6 claimed by two substages

2.4's outputs were "SCHEMA.md sections 5, 6, 7" and 2.10's were "SCHEMA.md section 6". Stage 4
(4.8) consumes "SCHEMA.md section 6 validation rules", so §6 must belong to 2.10.

**Fix:** 2.4's outputs are now sections 5 and 7, with §6 reserved for 2.10. No stage_04 change
needed — its reference was already consistent with the fix.

### PR-05 — stage_02: design review omitted the tech-decision artefacts

2.13's inputs were "all artefacts from substages 2.1 to **2.11**" — excluding 2.12's ADR-003/004
from the whole-design consistency review. **Fix:** now 2.1 to 2.12, ADRs named.

### PR-06 — stage_02 DoD omitted OQ-08

`open_questions_to_resolve` listed OQ-08 and step 2.13.7 records its resolution, but the stage's
definition-of-done omitted it from the resolved list. **Fix:** added. (Resolving OQ-08 at S02 is
correct even though its blocking stage is S07 — payload encryption changes the remote format
designed in 2.9.)

### PR-07 — stage-level traceability lists inconsistent with their own substages

Four stage files declared a stage-level FR/NFR list narrower than the union of what their own
substages claim to cover:

| File | Missing at stage level | Claimed by |
|---|---|---|
| stage_01 | NFR-05…NFR-08 | 1.5 covers NFR-01 through NFR-08 |
| stage_02 | FR-01, FR-12 | 2.3 (FR-01), 2.7 (FR-12) |
| stage_04 | FR-13 | 4.6 balance derivation |
| stage_06 | FR-02, FR-11 | 6.6 category management |
| stage_08 | FR-10 | 8.3 ceiling progress |

**Fix:** each stage-level list extended to the union of its substage claims.

---

## 2. Findings NOT fixed — recorded for resolution at the right point

### PR-08 — manifest FR "stages" lists are primary-stage lists, not exhaustive (convention, not a defect)

The manifest's per-FR `stages` arrays disagree with substage-level coverage in several places (e.g.
FR-10 lists S02, S05 but stage_06 and stage_08 substages also cover it; FR-12 lists S05, S06 but
2.7 designs its semantics). Rewriting the manifest's registries would churn the user's source
document for no build benefit. **Convention adopted instead:** the manifest lists are the *primary*
implementing stages; the 1.8 traceability matrix will record the union of manifest lists and
stage-file claims, so nothing is lost. Not edited.

### PR-09 — E-04 stands: seed data presupposes UNCAPPED_FLOW while OQ-03 leaves it open

6 of 19 seeded categories carry `suggested_type: UNCAPPED_FLOW`; OQ-03 still asks whether that type
should exist. Already escalated in PRD §A.6.1. This is a **user decision**, not an editorial fix —
resolving it by editing the manifest would violate "do not resolve a blocking question by
assumption". Goes to the Stage 1 gate with OQ-03 (default: yes, the type exists).

### PR-10 — overlapping `open_questions_to_resolve` across stages (interpretation note)

OQ-05 appears in S02, S04 and S05; OQ-06 in S01, S02 and S06; OQ-09 in S01, S02 and S05.
**Interpretation adopted:** the earliest listing stage (never later than the manifest's
`blocking_stage`) resolves the question; later listings *consume and confirm* the resolution. No
edits — the lists are harmless under this reading and pruning them risks losing the confirm step.

### PR-11 — period-boundary logic must have exactly one home (guidance for S02)

4.6.2 has the data layer compute `allocated_in_current_period` "taking the period definition as an
input", while 5.5.1 computes period boundaries from the anchor day inside the engine. Both are
correct individually, but Stage 2 must place the boundary calculation in **one** pure domain module
that both consume, or the two will drift (the anchor-31-in-February rule implemented twice is the
known failure mode). Recorded here so 2.3/2.5 design it that way; nothing to edit in the prompts.

### PR-12 — physical-device and human-in-the-loop steps (execution note)

Several steps require a physical Android device or human senses: 3.1.7/3.9.3 (build & walk on
device), 6.3.7 (timing a real user path), 9.3 (interruption/call tests), 9.5 (TalkBack with the
screen covered), 10.6.3 (clean-device release smoke). As an agent I can drive emulators and
automated checks, but these specific verifications will need Khizir's hands at those stages. Flagged
now so it isn't a surprise mid-stage-9.

### PR-13 — trivia noted, deliberately untouched

- 3.6.5 says "widget tests" for the money formatter, which is not a widget — the intent (unit
  tests at 3.6) is unambiguous.
- 5.7's inputs name the Stage 4 ledger repository while the engine is pure — reversal *generation*
  is pure (mirrors recorded allocations); its verification tests compose with the repository.
  Coherent as written.
- Stage 6's handoff references a "sync status surface, stubbed" — the stub exists from 3.7 (the
  2.11.1 inventory includes the sync/sign-in status screen). Coherent.
- 9.3's input "release-configuration build if available" vs 9.7's hard requirement — intentional
  escalation, not a contradiction.

### PR-14 — arithmetic spot-checks all pass

Verified by hand during review: V-02 (33/33/34), V-03 (floors 0/0/1, remainders 9999/9999/2 →
1/1/1), V-08 (headroom 50,000, redirect 70,000), the 2.6.9 chain (conserves 300,000 under both
parcel granularities), and the 2.7.1 override redistribution (200,000/175,000/125,000 = 500,000).
No numeric errors found anywhere in the plan.

---

## 3. Net effect

Five files edited (`stage_01`, `stage_02`, `stage_03`, `stage_04`, `stage_06`, `stage_07`,
`stage_08` — seven, counting the traceability-only edits), zero behavioural scope changed, no
requirement added or removed, no open question resolved by assumption. The two fixes that would
have caused real downstream damage are PR-01 (Stage 5 would have implemented a worked example its
own algorithm contradicts) and PR-02 (Stage 7's gate was unsatisfiable as written).
