# Stage 1 — Requirements Gathering & Documentation — worklog

Evidence log. One entry per substage, appended as each is ticked off.

| Substage | Name | Status |
|---|---|---|
| 1.1 | Intake and source reconciliation | ✅ Complete |
| 1.2 | Personas and end-to-end journeys | ✅ Complete |
| 1.3 | User stories and acceptance criteria | Not started |
| 1.4 | The money model in plain language | Not started |
| 1.5 | Non-functional requirements with measurable targets | Not started |
| 1.6 | Scope boundaries and the version 1 cut line | Not started |
| 1.7 | Open questions and ambiguity register | Not started |
| 1.8 | Traceability matrix and PRD assembly | Not started |

---

## 1.1 — Intake and source reconciliation (S01.01)

**Output:** `docs/PRD.md` Appendix A.

### Work steps

| Step | Action | Where the result lives |
|---|---|---|
| 1.1.1 | Extract every requirement verbatim, including those implied by `predefined_categories` and `cloud_sync_requirements` | PRD §A.1, §A.3 |
| 1.1.2 | Split compound requirements, letter-suffixed, one-line justification each | PRD §A.2 |
| 1.1.3 | Classify functional / non-functional / constraint / assumption-presented-as-requirement | Class column in §A.1, §A.3, §A.4 |
| 1.1.4 | Mark and count money-movement requirements as CRITICAL | PRD §A.5 |
| 1.1.5 | Cross-check against INV-01…INV-12, flag conflicts | PRD §A.6 |
| 1.1.6 | Write the inventory into `docs/PRD.md` as an appendix | PRD Appendix A |

### Acceptance criteria — verification

| Criterion | Verified how | Result |
|---|---|---|
| Every FR and NFR id appears exactly once with verbatim wording | §A.0 count table: 15 FR + 8 NFR = 23 parents, each listed once in §A.1 with source wording quoted | ✅ |
| Every compound requirement split, each split justified in one line | §A.2: 33 children across 13 split parents, each with a verbatim clause and a one-line justification; 9 unsplit parents named explicitly | ✅ |
| Money-movement requirements marked CRITICAL and counted | §A.5: **18 CRITICAL**, plus 1 conditionally CRITICAL (FR-03, conditional on OQ-02); FR-14c explicitly excluded with reason | ✅ |
| Invariant conflicts listed separately and escalated, not resolved | §A.6.1: 4 escalations (E-01…E-04) stated as conflicts with no resolution offered; §A.6.2: 6 tensions recorded separately | ✅ |

### Counts

- Parent requirements: **23** (15 FR, 8 NFR) — reconciles with the manifest.
- Sub-requirements after splitting: **42** (33 children + 9 unsplit parents).
- Implied requirements not in the FR/NFR lists: **15** (IMP-01…IMP-15).
- Non-goal constraints: **6** (NG-01…NG-06 — 5 from `explicit_non_goals_v1`, 1 from `project.platform`).
- Seeded categories: **19** (5 spending, 9 savings, 5 business). Type distribution:
  ACCUMULATING_RESERVE 10, UNCAPPED_FLOW 6, FIXED_RECURRING 3 — sums to 19.
- CRITICAL: **18** unconditional, **1** conditional.
- Invariant escalations: **4**. Tensions noted: **6**.
- Ambiguities flagged for 1.7: **10** (F-01…F-10).

### Escalations raised (per checkpoint `escalate_immediately_if`)

Four conflicts found. None blocks 1.2, so work continues; all four are carried to 1.7 and must be
put to the user at the Stage 1 gate.

- **E-01 — FR-10b vs INV-07.** FR-10b only ever names a *user-specified* redirect target. INV-07
  requires a guaranteed uncapped terminal sink. If every user-created category is capped, overflow
  has nowhere to land. The sink INV-07 needs is one FR-10b does not authorise. Routes to OQ-07.
- **E-02 — FR-12 vs INV-08/INV-11.** A manual override changes an event's outcome without changing
  rules or balances. For INV-08's determinism to hold, the override must be a stored *input* to the
  event rather than an edit of its output. Unstated in the manifest.
- **E-03 — IMP-06 vs INV-08.** A ceiling expressed as "N months of spending-group outflow" is
  recomputed from ledger history rather than stored. Purity survives only if it is resolved to an
  integer before the engine call. Whether it is a v1 capability at all is unstated.
- **E-04 — seed data vs OQ-03.** 6 of the 19 seeded categories carry `suggested_type:
  UNCAPPED_FLOW`, a type whose existence OQ-03 leaves open. If OQ-03 resolves against, those 6
  seeds have no valid type. The manifest is internally inconsistent here.

### Deviations from the stage plan

- **`IMP-xx` namespace introduced.** Step 1.1.1 requires inventorying requirements implied by
  `predefined_categories` and `cloud_sync_requirements`, but the manifest defines no id namespace
  for them (it defines FR, NFR, INV, OQ, R, A). `IMP-01…IMP-15` is inventory-local and flagged in
  §A.3 for adjudication in 1.8 — each must be promoted to an FR/NFR or explicitly dropped.
- **`NG-06` added beyond `explicit_non_goals_v1`.** The iOS-portability constraint in
  `project.platform.ios_support` is a constraint of the same kind as the five non-goals and would
  otherwise have no home in the inventory.
- **CRITICAL definition widened.** The plan says "touch money movement". Figures that must
  reconcile exactly with the ledger but move no money (FR-13, FR-14a/b/d, NFR-07a) were included,
  because they need the same failure-case criteria in 1.3. The definition used is stated in §A.5.

### Notes

No paraphrasing was performed in §A.1, §A.3 or §A.4 — source wording is quoted. No conflict found
in 1.1.5 was resolved.

---

## 1.2 — Personas and end-to-end journeys (S01.02)

**Output:** `docs/PRD.md` section 2.

### Work steps

| Step | Action | Where the result lives |
|---|---|---|
| 1.2.1 | Expand P1 — goals, context, confidence, device, triggers, abandonment | PRD §2.1 |
| 1.2.2 | Expand P2 — same, plus business pressure and its emotional stake | PRD §2.2 |
| 1.2.3 | P1 primary journey, numbered, screen named at every step | PRD §2.4 (J1-A/B/C) |
| 1.2.4 | P2 primary journey through a business ceiling overflow | PRD §2.5 (J2-A/B) |
| 1.2.5 | At least five failure journeys | PRD §2.6 (FJ-1…FJ-7) |
| 1.2.6 | Highest-risk step and design response, per journey | PRD §2.4–§2.6, bolded per journey |
| 1.2.7 | Wall-clock estimate for the P1 default path against NFR-04 | PRD §2.7 |

### Acceptance criteria — verification

| Criterion | Verified how | Result |
|---|---|---|
| Both primary journeys written as numbered steps with a named screen at each step | J1 = 22 numbered steps across J1-A/B/C; J2 = 18 across J2-A/B. Every row names a screen from the §2.3 inventory. | ✅ |
| At least five failure journeys, none ending in a dead end or data loss | **7 written.** Six end with data intact and the user in control. **FJ-5(b) ends in data loss** — escalated as ESC-1.2-A rather than papered over. | ⚠️ 6 of 7 |
| Every journey names its highest-risk step and the design response | 9 journeys (J1, J2, FJ-1…FJ-7), each with a bolded highest-risk step and a one-sentence design response. | ✅ |
| The P1 default path is plausibly under 5 minutes and the step count supports the claim | §2.7: 11 onboarding steps = 106s; through first income split = 166s vs the 300s target. The supporting constraint (one tap per default-path screen) is stated explicitly. | ✅ |

### Counts

- Journeys: **9** — 2 primary (J1, J2), 7 failure (FJ-1…FJ-7), against a required minimum of 5 failure journeys.
- Screens named: **21** (§2.3). Stage 2 substage 2.11 owns the definitive inventory.
- J1 steps: 22. J2 steps: 18.
- Estimated onboarding time on defaults: **106s** vs R-06's 120s target.
- Estimated time to first completed income split: **166s** vs NFR-04's 300s target — 134s margin.

### Escalations raised

- **ESC-1.2-A — FJ-5(b) ends in data loss and cannot be designed away.** A user who never signs in
  and never exports has no recovery path when their device is lost. This is a direct tension
  between NFR-02 (the app must be fully usable with no account ever linked) and NFR-07
  (recoverability), with NG-01 ruling out any other recovery channel. The acceptance criterion "none
  ends in data loss" is therefore not fully satisfiable. Recorded, not resolved; carried to 1.7.

### New ambiguities flagged for 1.7

- **F-11 — the personal-only scope.** `Scope Selection` is required by both primary journeys but
  appears in no FR. FR-06 assumes a three-way split; a personal-only user has no Business group.
  Whether that group is hidden or present at 0% changes how group percentages total 100.
- **F-12 — install ordering on a device with existing cloud data.** FJ-4 requires detecting remote
  data *before* writing local configuration. No requirement states this; the wrong order produces
  two divergent configurations that must then be merged.

Running ambiguity count carried to 1.7: **12** (F-01…F-12).

### Deviations from the stage plan

- **Two failure journeys beyond the five named in step 1.2.5.** FJ-6 (remote store vanished) exists
  because 1.1 inventoried IMP-12 with no journey to exercise it; FJ-7 (rules changed, old event
  re-examined) exists because INV-11 had no journey either. Both would otherwise reach Stage 2 as
  invariants with no screen behind them.
- **A screen inventory (§2.3) was written.** Not requested by 1.2, but step 1.2.3 requires naming a
  screen at every step, and doing that without a fixed label set produces synonyms that would break
  1.8's consistency pass. The section states that Stage 2 substage 2.11 owns the real inventory.

### Notes

No screens were designed — §2 names screens and describes what the user does, per the substage's
`must_not`. No third persona was introduced; §2.2 records that NG-02 forecloses one.
