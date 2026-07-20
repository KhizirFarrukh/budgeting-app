# PookieBudget — assumptions register

Every non-blocking default the project is proceeding on, per the manifest's assumption policy: an
id, the assumption, why it was made, **what breaks if it is wrong**, and when it is reviewed.

Assumptions are cheap to change **before** the stage named in "Review at" completes, and expensive
afterwards. Nothing here resolves a question from Part 1 of `OPEN_QUESTIONS.md` — blocking questions
are never answered by assumption.

Opened in substage 1.7. Later stages append; they do not renumber.

---

## Part A — Defaults taken on non-blocking open questions

| ID | Assumption | Reason | If it is wrong | Review at |
|---|---|---|---|---|
| **A-01** | Currency and its decimal places are read from the device region at setup and can be changed only while no money has been recorded. | OQ-01 default. Every stored amount is interpreted through this setting, so changing it later reinterprets history. | A user in the wrong region silently gets the wrong currency and must wipe and restart to fix it. Recoverable only before the first income event. | S02.10 (validation rules) |
| **A-02** | Goals have a target amount but no target date in v1. | OQ-04 default. Deadline tracking is a feature in its own right. | Deadline-driven goals (Eid, annual tax) cannot show whether the user is on track — a visible gap for at least four suggested categories. Mitigated: the place is reserved (§3.4 D-01), so adding it later is not a migration. | S02.03 (data model) |
| **A-03** | A bill category's unspent surplus carries forward; the next period tops up only to the bill amount. | OQ-05 default. Keeps a bill category from ever holding more than one bill's worth. | If the user expected the surplus to redirect out, bill categories hold more than expected and other categories receive less. Behaviour is parameterised (S05 5.5.3), so this is a configuration change, not a rewrite. | S05.05 |
| **A-04** | Spending that takes a category negative is allowed, with a prominent warning, and shown as negative. | OQ-06 default. The app must never prevent recording something that actually happened. | If blocking were wanted instead, users could record impossible states. Judged the lesser harm: a blocked entry means the app's records diverge from reality permanently. | S06.09 |
| **A-05** | The cloud copy is not passphrase-encrypted in v1; Google account security is relied on. An encryption marker is written into the remote format from v1.0. | OQ-08 default. A forgotten passphrase is an unrecoverable data-loss mode. | If a user's Google account is compromised, their financial data is readable by the attacker. The marker (§3.4 D-04) means encryption can be added later without a rollout hazard. | S07.03 |
| **A-06** | Any income event can be undone at any time, and the reversal is always visible beside the original. | OQ-09 default. INV-03 already forbids editing history, so undo must work this way. | If a time limit were wanted, none exists; users can undo very old events, which may surprise them. No data risk — balances always return exactly. | S05.07 |
| **A-07** | A business-scoped CSV export exists, with date, category, amount, note and running balance. | OQ-10 default. | If an accountant needs different columns, the export needs revision. Low cost — the export format is not stored data. | S08.05 |
| **A-08** | A category links to at most one account; an account holds many categories. | OQ-13 default; the design plan already models a single account reference per category. | A user splitting one goal across two real accounts cannot represent that. They can split the goal into two categories as a workaround. | S02.03 |
| **A-09** | Taking money out of a savings goal is recorded as spending, identical to any other category, and appears in spending totals. | OQ-14 default. Keeps one movement concept rather than two. | Spending totals include money spent from reserves, which may overstate "spending" for a user who thinks of it as moving savings out. Reports can separate by category, so the information is not lost. | S08.02 |
| **A-10** | No direct category-to-category transfers in v1. | OQ-15 default; not in the brief. | A user wanting to reshuffle money between goals must record a spend and an income, which is clumsy and distorts both totals. Schema-safe to add later (§3.4 D-07). | S08.08 (v1.1 backlog) |
| **A-11** | The device-only state is explained once during setup, then shown as a permanent quiet indicator with a backup action attached. No repeated prompts. | OQ-16 default. Balances the FJ-5(b) data-loss risk against nagging a user who has deliberately declined sign-in. | A user who never signs in and never exports loses everything if the device is lost. **This is the residual risk of ESC-1.2-A and it cannot be fully designed away** — NFR-02 guarantees the app works with no account, and no other recovery channel exists. | S06.11, S10.02 |
| **A-12** | If no first-time observer can be found, NFR-04's evidence is the developer-timed path, labelled in the test report as weaker evidence. | OQ-17 default; ESC-1.5-A. | NFR-04 would be reported as met on evidence that cannot detect confusion, hesitation or abandonment. The requirement could be failing in reality while passing on paper. | S09.03 |
| **A-13** | The schedule accommodates all fourteen MUST requirements; no requirement is renegotiated to SHOULD. | OQ-18 default; ESC-1.6-A. | Stage 6 runs long, since it carries twelve substages against a brief with almost no cut line. The named fallback is to reduce FR-03 or FR-14 (§3.7). | S02.13 gate |

## Part B — Ambiguities resolved from existing material

These were flagged during substages 1.1 to 1.6 and turned out to be answerable from the manifest or
the design plan. They are recorded here rather than in the open-questions register, to keep that
register short enough that the five blocking questions are not buried.

| ID | Assumption | Reason | If it is wrong | Review at |
|---|---|---|---|---|
| **A-14** | FR-15 and NFR-02, FR-09 and NFR-01, and FR-07b and NFR-03 are each **one** requirement stated twice, not two. Traceability counts each once and cross-references the pair. | F-01. The wording of each pair is materially the same claim. | The traceability matrix double-counts coverage and reports a stronger position than reality. Detected during the 1.8 completeness pass. | S01.08 |
| **A-15** | FR-01's phrase "savings categories" means categories generally, not savings-group categories only. | F-02. FR-05, FR-06 and FR-07 establish three groups; reading FR-01 narrowly would leave spending and business categories unauthorised. | Category creation would be authorised only for the savings group, contradicting FR-07 and FR-08. Judged an obvious wording slip. | S01.08 |
| **A-16** | Percentages apply at two levels: across the three groups, then within each group across its categories. Each level totals exactly 100. | F-03. The manifest's own conventions state both levels explicitly, and FR-02's verification text does too. | The whole allocation model changes shape. Confidence is high — the manifest is explicit. | S02.05 |
| **A-17** | "Real-time" in FR-13 means the dashboard reflects a change without a manual refresh, within the same interaction — not sub-second guaranteed latency. | F-05. The measurable performance targets live in NFR-06 (§6.6); FR-13 is about correctness and immediacy, not a latency figure. | If a stricter reading was intended, the P-03 budget (400 ms first paint) is the ceiling anyway. Low risk. | S06.08 |
| **A-18** | "Monthly" and "yearly" mean calendar month and calendar year in the user's local timezone. | F-07. The Stage 8 plan already specifies exactly this. | Rolling or user-anchored periods would change every report boundary. The Stage 8 plan is explicit, so confidence is high. | S08.01 |
| **A-19** | Spending from a goal reopens its room automatically; spending from a bill category does **not** reopen that period's collection. | F-09. This falls out of the two headroom formulas rather than being a separate rule: a goal's room is target minus balance (so spending raises it), while a bill's is bill amount minus what was already collected this period (which spending does not touch). | If bills were meant to reopen on spending, a bill category could collect twice in one period — which contradicts FR-11's purpose. Derivation is sound. | S05.03 |
| **A-20** | A personal-only user has no Business group at all, rather than a Business group set to zero. Enabling business later requires rebalancing the split to 100. | F-11. Avoids an empty visible group, satisfying NFR-03's "no dead navigation". | If a zero-share group were expected to persist invisibly, enabling business later would not require a rebalance. The rebalance is already designed (US-002, S06 6.10.5). | S02.11 |
| **A-21** | A new install checks for existing cloud data **before** writing any local configuration. | F-12. The reverse order produces two divergent configurations that must then be merged. | A new device that onboards first and signs in second creates a competing configuration. The Stage 7 plan already covers merging pre-sign-in local data, so the failure is recoverable but avoidable. | S07.08 |
| **A-22** | Recording a spending transaction is in scope for v1, authorised by FR-05's requirement to "track" spending categories. | F-13. **No requirement states it explicitly** — FR-04 covers income only. But FR-13 (balances against ceilings), FR-14 (reports) and both primary journeys are impossible without it. | If spending were genuinely out of scope, balances would only ever increase and the product would not function. Treated as an obvious omission from the brief rather than a deliberate exclusion. Worth a one-word confirmation at the gate. | S01.08 gate |
| **A-23** | A manual override is stored as part of the income event's **input**, not as an edit of its computed output. | E-02. INV-08 requires identical inputs to produce identical output; an override that modifies results after the fact would make the event unreproducible, and INV-11 requires historical events to stay explainable. | Overridden events become unexplainable after a rule change, breaking the audit trail that FR-12 and INV-11 jointly require. This is a design conclusion, not a user preference. | S02.07 |
| **A-24** | Ceilings are fixed amounts in v1. Ceilings expressed as a formula ("six months of spending") are deferred, with a kind discriminator reserved. | E-03. A derived ceiling is recomputed from history rather than stored, which changes what a ceiling is. | The Emergency fund suggestion note ("commonly expressed as N months of spending") cannot be honoured literally in v1; users set an absolute amount instead. Reserved discriminator (§3.4 D-02) prevents a migration later. | S02.03 |
| **A-25** | FR-11's clause "since they do not need to grow past their bill amount" is rationale, not an additional requirement. | F-06. It explains why the category type exists rather than adding a testable claim. | Nothing — the behavioural requirement (per-period capping) is captured separately as FR-11b. | S01.08 |
| **A-26** | A group with a non-zero share must have at least one active category; this is rejected at save time rather than handled at allocation time. | Manifest candidate question, already answered by the design plan's validation rules and by the engine's typed failure for an empty group with a non-zero share. | Income would be allocated to a group with nowhere to put it, and the engine would fail at the worst possible moment — while the user is entering money — instead of at configuration time. | S02.10 |

---

## Summary

| | Count |
|---|---|
| Part A — non-blocking open-question defaults | 13 (A-01…A-13) |
| Part B — ambiguities resolved from existing material | 13 (A-14…A-26) |
| **Total** | **26** |

Every assumption states its impact if wrong and names the substage at which it is reviewed. The
three carrying the most residual risk, in order:

1. **A-11** — a user who never signs in and never exports loses everything with the device. The
   residual of ESC-1.2-A; cannot be fully designed away while NFR-02 holds.
2. **A-12** — NFR-04 may be reported as met on evidence that cannot detect the failure it exists to
   catch.
3. **A-13** — a fourteen-MUST v1 with almost no cut line; Stage 6 is where that pressure lands.
