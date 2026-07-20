# Stage 1 — Requirements Gathering & Documentation — worklog

Evidence log. One entry per substage, appended as each is ticked off.

| Substage | Name | Status |
|---|---|---|
| 1.1 | Intake and source reconciliation | ✅ Complete |
| 1.2 | Personas and end-to-end journeys | ✅ Complete |
| 1.3 | User stories and acceptance criteria | ✅ Complete |
| 1.4 | The money model in plain language | ✅ Complete |
| 1.5 | Non-functional requirements with measurable targets | ✅ Complete |
| 1.6 | Scope boundaries and the version 1 cut line | ✅ Complete |
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

---

## 1.3 — User stories and acceptance criteria (S01.03)

**Output:** `docs/PRD.md` sections 5.1–5.9.

### Work steps

| Step | Action | Where the result lives |
|---|---|---|
| 1.3.1 | One or more stories per inventoried requirement, US-001 onward, persona-split where personas differ | PRD §5.1–§5.5, §5.8 |
| 1.3.2 | Given/When/Then criteria, observable from outside the app | every story |
| 1.3.3 | Negative/failure criterion for every CRITICAL story | bolded **Failure** bullets |
| 1.3.4 | The four FR-10 × FR-11 × FR-12 interaction cases, explicit | PRD §5.6 (I-1…I-4) |
| 1.3.5 | MoSCoW per story, inherited unless reasoned | story headers; deviations stated inline |
| 1.3.6 | Flag stories whose criteria required guessing | PRD §5.9 |
| 1.3.7 | FR-to-story coverage table | PRD §5.7 |

### Acceptance criteria — verification

| Criterion | Verified how | Result |
|---|---|---|
| Every FR covered by at least one story, coverage table no gaps | §5.7: 15 rows, every row lists stories, none empty; non-FR CRITICAL items mapped below the table | ✅ |
| No story contains "etc", "and so on", "appropriate", "as needed" | `grep -i "\betc\b|and so on|appropriate|as needed"` over PRD.md → **no matches** | ✅ |
| Every story has at least one Given/When/Then criterion | 37 stories, each with ≥1 GWT bullet, most with 2–5 | ✅ |
| Every CRITICAL story has at least one negative/failure criterion | 17 CRITICAL-marked stories covering all 18 §A.5 register entries (US-014 covers FR-04b + NFR-05); each carries ≥1 **Failure** bullet | ✅ |
| The four interaction cases each have explicit expected behaviour | §5.6: I-1 override-past-ceiling (permitted, warned, not redirected), I-2 funded bill (accepts zero, reason shown), I-3 full target (chain continues, every hop visible), I-4 sink terminal (named, explained) | ✅ |

### Counts

- Stories: **37** (US-001…US-037).
- CRITICAL stories: **17**, covering all **18** CRITICAL register entries from §A.5.
- Persona-differentiated pairs: FR-03 (US-011 P1 / US-012 P2), FR-04b (US-014 P1 / US-015 P2),
  FR-14d (US-036 P1 / US-037 P2); FR-07 written P2-first (US-009/US-010).
- Priority deviations from inheritance: **2** — US-017 (undo) assigned MUST with no parent FR,
  reason stated (mis-entry is certain; FJ-3 depends on it); US-037 inherits FR-14's SHOULD.
- Flags carried to 1.7: **10** story-level dependencies (§5.9), of which **1 is new: F-13**.

### New finding — F-13

The inventory contains no FR that authorises recording a spending transaction. FR-04 covers income
only; spending entry is implied by FR-05's word "track" and required by FR-13, FR-14 and both
primary journeys. US-024 treats it as MUST via FR-05; 1.7 must confirm that reading rather than let
it pass as an unexamined assumption. Running ambiguity count: **13** (F-01…F-13).

### Deviations from the stage plan

- Interaction cases written as a dedicated subsection (§5.6) with story anchors, rather than as four
  standalone stories — each is a behaviour of existing stories, and a standalone story would have
  duplicated criteria the anchored stories already carry.
- §5.8 (reports stories) placed after the coverage table so the table sits with the main story body;
  ordering only, no content effect.

### Notes

No criterion references an internal component, stored structure or code concept — checked by
reading every criterion against the 1.3.2 rule. Product language kept to whole percentages
throughout, anticipating 1.4's must_not.

---

## 1.4 — The money model in plain language (S01.04)

**Output:** `docs/PRD.md` section 4 (§4.1–§4.9).

### Work steps

| Step | Action | Where the result lives |
|---|---|---|
| 1.4.1 | Balance: what it means and does not mean; always derived, never typed | §4.1 |
| 1.4.2 | Each category type: full condition, overflow, spending-reopens-headroom | §4.2 |
| 1.4.3 | Ceiling as a finish line, explicitly not a spending limit | §4.3 |
| 1.4.4 | Categories vs accounts: both OQ-02 readings with consequences, A recommended | §4.9 |
| 1.4.5 | Conservation rule in user terms | §4.4 |
| 1.4.6 | Worked redirect chain, ≥3 categories, seeded names, hand-checkable | §4.5 |
| 1.4.7 | The catch-all (sink) in user language, non-deletable, per OQ-07 | §4.6 |
| 1.4.8 | Reversal per OQ-09: ink not pencil, opposing entry stays visible | §4.8 |

*(§4.7 — per-payment override rules — added beyond the listed steps so the section states the I-1
policy from §5.6 in user language; without it the money model would be silent on the one case where
a balance can legitimately exceed a ceiling, which §4.3 references.)*

### Acceptance criteria — verification

| Criterion | Verified how | Result |
|---|---|---|
| A non-developer can predict where money goes in a ceiling-overflow scenario | §4.5 walks the chain step by step; the "check yourself" question at its end has exactly one answer derivable from the text (the catch-all, §4.6) | ✅ |
| At least one worked numeric example, arithmetic conserves exactly | §4.5: split 12,000+10,500+7,500 = 30,000; landings 8,000+10,000+12,000 = 30,000; every intermediate value shown; re-verified by hand at write time | ✅ |
| Nothing contradicts INV-01 through INV-12 | Walked: §4.1↔INV-04, §4.4↔INV-01/02, §4.5/§4.6↔INV-07, §4.7↔INV-11 (per-event override, standing rules untouched), §4.8↔INV-03. The §4.5 hop order matches the FIFO worklist fixed in PR-01 | ✅ |
| Each type states full condition, overflow behaviour, and whether spending reopens headroom | §4.2: reserve (full at ceiling / redirects / reopens), bill (funded at period amount / passes by / does **not** reopen within period), envelope (never full / n.a. / n.a.) | ✅ |

### must_not compliance

- No schema or column names anywhere in §4 — checked by reading.
- No decimal percentages: 40% / 35% / 25% and 50 / 30 / 20 throughout; the design-level unit is not
  mentioned in the section.

### Positions taken (all labelled as recommendations pending the gate)

- OQ-03: the third type (open envelope) presented as the recommendation the seed set assumes.
- OQ-05: bill surplus carries forward; next period collects only the difference.
- F-09: spending from a reserve reopens headroom; bills do not reopen within a period.
- OQ-02: Reading A (accounts as labels) recommended, Reading B stated with its cost.
- OQ-07: catch-all non-deletable, renameable; separate business catch-all.
- OQ-09: undo unlimited in time, always a visible pair.
- I-1 restated in user language: override may exceed a ceiling, warned, never redirected away.

### Notes

Amounts in §4 are written as plain figures with no currency, since the model is currency-neutral;
the example uses the same category shape as the design reference chain so Stage 2's §2.6.9 and the
PRD tell one story.

---

## 1.5 — Non-functional requirements with measurable targets (S01.05)

**Outputs:** `docs/PRD.md` section 6 (NFRs) and section 7 (data volume and growth).

### Work steps

| Step | Action | Where the result lives |
|---|---|---|
| 1.5.1 | Restate NFR-01…08, sharpen every target | §6.1–§6.8, sharpenings marked ↑ |
| 1.5.2 | Offline behaviour in detail | §6.2, including the 11-flow enumeration and the three no-network UI states |
| 1.5.3 | Sync expectations from the user's point of view | §6.9 |
| 1.5.4 | Privacy in language reusable for the Stage 10 policy | §6.10 |
| 1.5.5 | Performance budgets with numbers | §6.6 table P-01…P-14 |
| 1.5.6 | Accessibility targets concretely | §6.8 |
| 1.5.7 | Data volume assumptions and five-year ledger size | §7.1–§7.4 |
| 1.5.8 | Verifying stage and artefact per NFR | stated per NFR, summarised §6.11 |

### Acceptance criteria — verification

| Criterion | Verified how | Result |
|---|---|---|
| Every NFR has a number or a binary observable condition | §6.11 table, "Target type" column: 4 binary, 4 numeric; no NFR left directional | ✅ |
| Every NFR names its verifying stage and artefact | §6.11, "Verified in" and "Verifying artefact" columns — no empty cell across 8 rows | ✅ |
| The data volume section produces concrete five-year row counts | §7.3: 2,600 / 7,700 / 67,000 / 141,000 ledger rows across four profiles, derived from stated inputs | ✅ |
| The privacy section is complete enough to draft a policy from without further research | §6.10 covers collection, storage locations with who-can-read, the three egress paths, permissions with justification, developer visibility, third parties, retention, deletion, and the operational trade-off | ✅ |

### Arithmetic check on §7.3

Re-derived independently after writing:

- Light: 60 events × 12 rows = 720 allocation; 30 × 60 = 1,800 spending; +2% ≈ 2,570 → **2,600**. Allocation share 720/2,570 = 28%.
- Typical: 180 × 22 = 3,960; 3,600 spending; +2% ≈ 7,710 → **7,700**. Share 51%.
- Heavy: 1,200 × 45 = 54,000; 12,000 spending; +2% ≈ 67,300 → **67,000**. Share 80%.
- Stress: 1,200 × 105 = 126,000; 12,000 spending; +2% ≈ 140,800 → **141,000**. Share 89%.
- Storage at 350 B/row × 1.35 for indexes: Typical 3.6 MB, Heavy 31 MB, Stress 66 MB.

One correction applied during the check: the Heavy allocation share was first written as 81%; the
true figure is 80.2%, corrected to 80%.

### Findings

**The N + H multiplier (§7.2).** One income event writes one ledger row per receiving category plus
one per redirect hop — so the ledger grows with **categories × income events**, not income events
alone. At the Heavy profile, allocation rows are 80% of the table and at Stress 89%. Stage 2's
ledger indexes must be chosen against that shape, and a user who doubles their category count
doubles their future row-growth rate. This was not obvious from the manifest's ranges and is the
most consequential number produced by this substage.

**IMP-13 quantified.** Estimated compressed remote payload at the Heavy profile is single-digit
megabytes against a 15 GB free Drive allowance. The "app data counts against the user's quota"
concern is real but negligible in magnitude; compaction exists to bound chunk count, not total size.

**T-01 now has numbers.** Full-scan balance derivation is affordable at Typical (7,700 rows) but not
on every dashboard render at Heavy (67,000). The balance cache is therefore a Stage 2 decision with
quantitative backing rather than a preference.

### Escalation raised

**ESC-1.5-A — NFR-04 cannot be verified mechanically.** Every other NFR reduces to a script,
capture, measurement or inspection. NFR-04 requires a person who has never seen the app and is not
the developer; a developer-timed run measures mechanical duration only and cannot detect hesitation,
misreading or abandonment — the exact failure modes NFR-04 exists to catch. Recorded in §7.5, not
resolved: either naive observers are recruited before Stage 9, or the test report states plainly
that NFR-04 rests on weaker evidence than every other NFR. Goes to the user at the Stage 1 gate.

### Deviations from the stage plan

- **NFR-02's "core flows" enumerated as 11 named flows.** The manifest says "100% of core flows"
  without defining the set, which would have let Stage 9 choose its own scope. Enumerating here is a
  sharpening, not a scope change — every flow listed is already required by an approved story.
- **NFR-07's v1.0 caveat recorded.** "Fixtures from every prior schema version" is unfalsifiable at
  version 1.0, where no prior version exists. The binding v1.0 condition is stated instead
  (framework plus a committed v1 fixture), with the full rule binding from v1.1.
- **A fourth data-volume profile (Stress) added** beyond the manifest's ranges, to give the design
  headroom above the worst real case and to match the 100-category figure NFR-06 benchmarks against.

### Notes

No target was written that there is no intention of measuring — each of P-01…P-14 names the substage
that measures it. The reference device is specified as a **class** with the exact model recorded at
Stage 9, rather than a model named from memory, per the manifest's knowledge-freshness rule.

---

## 1.6 — Scope boundaries and the version 1 cut line (S01.06)

**Output:** `docs/PRD.md` section 3 (§3.1–§3.7).

### Work steps

| Step | Action | Where the result lives |
|---|---|---|
| 1.6.1 | Restate manifest non-goals, add those discovered in 1.1–1.5 | §3.1 — 6 restated, **3 new** (NG-07…NG-09) |
| 1.6.2 | Per-story in-scope or deferred, one-line justification per deferral | §3.2 — all 37 in scope, none deferred; justification given for the nine non-blocking |
| 1.6.3 | The v1 acceptance definition as a tick-list | §3.3 — 16 tick boxes |
| 1.6.4 | Classify every deferral schema-safe or requires-accommodation, naming the accommodation | §3.4 — 14 deferrals: **6 requiring accommodation, 8 safe** |
| 1.6.5 | The R-05 boundary against accounting software, one sentence | §3.5 |
| 1.6.6 | Sanity-check the cut line against both primary journeys | §3.6 |

### Acceptance criteria — verification

| Criterion | Verified how | Result |
|---|---|---|
| The cut line is a tick-list, not a paragraph | §3.3: 16 checkbox items, each verifiable by a person holding a phone | ✅ |
| Every deferral labelled schema-safe or requires-accommodation, with the accommodation named | §3.4: 14 deferrals in two tables; each of the 6 accommodation cases names the specific field or record change needed at v1.0 | ✅ |
| Every step of both primary journeys supported by an in-scope capability | §3.6: J1's 22 steps and J2's 18 steps mapped to capabilities and cut-line item numbers; all 14 deferrals checked against both journeys, zero appearances | ✅ |
| The accounting-software boundary stated in one sentence | §3.5: allocation versus obligation — the line falls where a feature must record what is owed to or by the user | ✅ |

### must_not compliance

- **Nothing a primary journey depends on was deferred** — verified by checking all 14 deferrals
  against all 40 primary-journey steps in §3.6.
- **No deferral needing accommodation was left unnamed** — all six name the specific field or record
  change: reserved target date, ceiling kind plus parameter, parent reference, remote encryption
  marker, soft budget plus period, rule-set discriminator.

### Findings

**Two deferrals are conditional on unresolved ambiguities, and both change Stage 2's data design.**
D-03 (category hierarchy) depends on F-04 — whether FR-07's "sub-categories" means a tree or merely
categories inside the business group. D-06 (per-source rules) depends on F-10 — whether business
revenue follows the same three-way split. If either resolves the other way, it stops being a
deferral and becomes v1 scope. Both must be answered before Stage 2 opens, and both are carried to
1.7 accordingly.

**D-14 is already accommodated by accident.** OQ-02's Reading B (accounts holding real balances)
would normally be an expensive later addition, but ledger entries already carry an account
reference, so per-account movement is recordable from v1.0. Reading B needs only an additive
nullable arrival-account reference on income events. Recorded so this is not re-litigated in Stage 2
as though it were a migration risk.

**Three new non-goals.** NG-07 (no forecasting, projection, advice or scoring) surfaced from the
Stage 8 plan's explicit exclusion and deserves to be a stated non-goal rather than a buried
instruction, because a predictive feature changes the product's liability posture. NG-08 (no
developer backend at any version) was implicit in INV-05 and NFR-01 but never stated as permanent.
NG-09 (no web version) appears in the manifest's platform block but was not in the non-goals list.

### Escalation raised

**ESC-1.6-A — the brief leaves almost nothing to cut.** Fourteen of fifteen FRs are MUST, so after a
genuine scoping attempt all 37 stories are in scope and only nine are non-blocking. The stage plan's
own warning — "a cut line so generous that Stage 6 never ends" — applies directly. Rather than
manufacture cuts the brief does not permit, the finding is named: either the schedule accommodates a
fourteen-MUST v1, or an FR is renegotiated to SHOULD before Stage 2. Candidates named if wanted:
FR-03 (accounts, informational-only under OQ-02's default, the least load-bearing MUST) and FR-14
(already SHOULD, reducible to CSV export alone). User's call at the gate.

### Deviations from the stage plan

- **Sync classified in-scope-but-not-release-blocking**, rather than in scope with no further
  qualification. FR-09 is a MUST and will be built, but making it a release blocker hands Google's
  OAuth verification timeline a veto over the release date. This mirrors the manifest's own R-04
  mitigation and is recorded so the choice is deliberate. The consequence is stated in §3.6: failure
  journeys FJ-4 and FJ-5(a) are unavailable in a pre-verification release.
- **A third disposition category introduced** — "in scope but not release-blocking" — because the
  binary in/deferred split the plan assumes produces no useful information against a brief that is
  14/15 MUST.
