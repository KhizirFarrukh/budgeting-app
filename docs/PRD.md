# PookieBudget — Product Requirements Document

| | |
|---|---|
| **Status** | In progress — Stage 1 |
| **Source** | `prompts/00_project_manifest.json` (schema 4.0.0) |
| **Sections assembled** | 2 (substage 1.2), Appendix A (substage 1.1) |
| **Sections pending** | 1, 3–9, assembled across substages 1.3–1.8 |

> Sections are written across substages 1.2 to 1.8 and assembled in order in 1.8.
> Appendix A was written first, in 1.1, so the finished document carries its own provenance.

---

## 2. Personas and journeys

Written in substage 1.2. Journeys name a screen at every step; **screen names here are labels for
Stage 2 to build a navigation graph from, not screen designs.** Nothing in this section describes
layout, colour or component choice.

### 2.1 Persona P1 — the personal saver

| | |
|---|---|
| **Who** | Salaried individual with irregular side income. |
| **Prior budgeting experience** | **None.** They have never used a budgeting app. NFR-04 is written against this assumption and every design decision in onboarding inherits it. |
| **Financial context** | One predictable monthly salary plus occasional irregular side income. Money arrives, sits in one account, and is spent down before any of it is deliberately saved. They are not in debt distress; they are leaking money to the absence of a system. |
| **Technical confidence** | Comfortable with everyday phone apps. Not comfortable with spreadsheets, percentages expressed as decimals, or any word that sounds like accounting. |
| **Device assumptions** | Mid-tier Android phone, roughly 4GB RAM (per NFR-06). Portrait, one-handed. Frequently on mobile data or no data at all. |
| **What makes them open the app** | Money just landed. This is the single most common trigger and it is time-pressured — they are often standing somewhere, distracted, with a notification still on screen. Secondary trigger: they just spent something and want to record it before they forget. Tertiary: idle curiosity about how close a goal is. |
| **What they want** | Money split the moment it arrives, without deciding anything. Visible progress on each goal. Certainty about which real-world account holds what. |
| **What makes them abandon it** | Being asked to enter numbers they do not know before they can see anything work. Any screen that requires arithmetic. Any figure that looks wrong, once — a single unexplained number destroys trust permanently (R-01). |

### 2.2 Persona P2 — the owner-operator

P2 is P1 plus a small retail/reselling business. Everything in §2.1 still applies.

| | |
|---|---|
| **Additional financial context** | Business revenue arrives irregularly and in larger, lumpier amounts than salary. A portion of every sale is not profit — it is next month's stock. |
| **The business pressure** | Inventory money spent on groceries is not an accounting error; it is a business that cannot restock next month. The gap between "there is money in the account" and "that money is already committed" is where the business dies. |
| **Why separation matters emotionally, not only structurally** | P2 does not fear a wrong report. They fear the specific moment of going to restock and finding the float gone, with no memory of where it went. Separation exists to make that moment impossible, so the design must make business money feel like it belongs to someone else. |
| **What they want** | Inventory restock money ring-fenced. Ad spend tracked apart from personal discretionary spend. Business figures that never contaminate household figures (NFR-03). |
| **What makes them abandon it** | Seeing a business figure inside a personal total, once. Being made to feel they need an accountant to use it (R-05). |

**No third persona is proposed.** The manifest defines P1 and P2 and NG-02 rules out multi-user or
shared household accounts, so no second-user persona is admissible in v1.

---

### 2.3 Screen inventory used by these journeys

Stage 2 (substage 2.11) owns the definitive screen list. These are the labels the journeys below
reference.

`Welcome` · `Currency Confirmation` · `Scope Selection` · `Top-Level Split` · `Category Selection`
· `Category Percentages` · `Ceilings Setup` · `Accounts Setup` · `Setup Summary` · `Dashboard` ·
`Add Income` · `Allocation Preview` · `Adjust Split` · `Income Confirmed` · `Add Spending` ·
`Category Detail` · `Transaction History` · `Reports` · `Settings` · `Sync & Account` ·
`Restore From Cloud`

---

### 2.4 Journey J1 — P1 primary: setup, first income, first spend

**J1-A — First launch to dashboard** (all defaults accepted)

| # | Screen | What the user does |
|---|---|---|
| 1 | `Welcome` | Reads one sentence on what the app does. Taps Start. |
| 2 | `Currency Confirmation` | Sees their currency already filled in from the device locale. Confirms. Told they can change it only while no money has been recorded (OQ-01). |
| 3 | `Scope Selection` | Chooses "Personal only" or "Personal and business". P1 chooses personal only, which removes the Business group from every later step. |
| 4 | `Top-Level Split` | Sees Spending and Savings pre-filled with default whole percentages totalling 100. Accepts. |
| 5 | `Category Selection` (Spending) | Sees the 5 suggested spending categories pre-ticked. Accepts all. |
| 6 | `Category Selection` (Savings) | Sees the 9 suggested savings categories pre-ticked. Accepts all. |
| 7 | `Category Percentages` | Sees within-group percentages pre-filled and totalling 100 per group. Accepts. |
| 8 | `Ceilings Setup` | Offered the chance to set targets on savings categories. Taps Skip — ceilings are optional at setup and editable later. |
| 9 | `Accounts Setup` | Offered the chance to name real-world accounts. Taps Skip. |
| 10 | `Setup Summary` | Sees the configuration in one view. Confirms. |
| 11 | `Dashboard` | Lands on an empty dashboard showing every category at zero, with a single obvious next action: add income. |

**J1-B — Logging the first salary**

| # | Screen | What the user does |
|---|---|---|
| 12 | `Dashboard` | Taps Add income. |
| 13 | `Add Income` | Enters the amount and a source label. Date defaults to today. |
| 14 | `Allocation Preview` | Sees every category and the amount it will receive, with the total stated and equal to what they typed. Sees, in words, why each amount is what it is. |
| 15 | `Allocation Preview` | Taps Confirm. |
| 16 | `Income Confirmed` | Sees confirmation that the money has been split, and that it can be undone. |
| 17 | `Dashboard` | Sees every category now holding money. |

**J1-C — Logging a grocery spend, and checking back the next day**

| # | Screen | What the user does |
|---|---|---|
| 18 | `Dashboard` | Taps Add spending. |
| 19 | `Add Spending` | Enters the amount, picks Groceries, adds an optional note. Confirms. |
| 20 | `Dashboard` | Sees the Groceries balance reduced by exactly that amount. |
| 21 | `Dashboard` (next day) | Opens the app cold. Sees the same figures — nothing has drifted overnight. |
| 22 | `Category Detail` | Taps a savings category to see its balance against its target and the entries that produced it. |

**Highest abandonment risk: step 7, `Category Percentages`.** This is the first screen that asks
P1 — who has never budgeted — to have an opinion about numbers across up to 14 categories.
**Design response:** the screen must arrive already valid and totalling 100 per group, so that
accepting it requires one tap and no arithmetic, and any edit must rebalance the remainder
automatically rather than leaving the user to make it total 100 themselves.

---

### 2.5 Journey J2 — P2 primary: business setup and a ceiling overflow

**J2-A — Setup with business scope**

| # | Screen | What the user does |
|---|---|---|
| 1–2 | `Welcome`, `Currency Confirmation` | As J1. |
| 3 | `Scope Selection` | Chooses "Personal and business". The Business group becomes visible everywhere. |
| 4 | `Top-Level Split` | Sets three-way ratios across Spending, Savings and Business in whole percentages totalling 100. |
| 5 | `Category Selection` (Spending, Savings) | Accepts or edits suggestions, as J1. |
| 6 | `Category Selection` (Business) | Sees the 5 suggested business categories, including Inventory/stock purchases and Advertising/marketing. Accepts. |
| 7 | `Category Percentages` | Sets within-group percentages, including within Business. |
| 8 | `Ceilings Setup` | **Does not skip.** Sets a ceiling on Inventory/stock purchases — the amount of stock float the business needs — and names where its overflow should go. |
| 9 | `Accounts Setup` | Names the separate business account and links the business categories to it. |
| 10 | `Setup Summary` | Confirms. |
| 11 | `Dashboard` | Lands with business and personal figures visibly distinct and never summed together (NFR-03). |

**J2-B — A business income event that overflows the inventory ceiling**

| # | Screen | What the user does / sees |
|---|---|---|
| 12 | `Dashboard` | Taps Add income. |
| 13 | `Add Income` | Enters a large sale amount. |
| 14 | `Allocation Preview` | Sees the three-way split, then within Business sees that Inventory/stock purchases would receive more than it can hold. |
| 15 | `Allocation Preview` | **The overflow moment.** Sees stated plainly: the amount Inventory would have received, the amount it actually accepts (its remaining headroom), the surplus, and the named category the surplus goes to instead. Sees the running total still equal to the amount entered. |
| 16 | `Allocation Preview` | Taps Confirm. |
| 17 | `Income Confirmed` | Sees that Inventory is now full and that the surplus went elsewhere, by name. |
| 18 | `Dashboard` | Sees Inventory at its ceiling and the redirect target increased. |

**What the user must understand at step 15 — this is the most important sentence in the design:**
the money was not lost, it was not held back, and it was not decided arbitrarily — it went to a
place *they* named, *because* the place they wanted it was already full. Overflow must read as the
system doing what they asked, not as the system overruling them.

**Highest abandonment risk: step 15, the overflow moment.** If the user cannot immediately see
where the surplus went and why, they conclude the app has lost their money and never trust it
again. **Design response:** the preview must show the redirect as a named, traceable movement from
one category to another with the arithmetic visible, never as an unexplained smaller number.

---

### 2.6 Failure journeys

Seven, against a required minimum of five. Each is written to end with the user still in control of
their data. **FJ-5 branch (b) is the exception and is escalated in §2.8.**

#### FJ-1 — No internet at all, from first launch through the first income event

1. `Welcome` — app opens with no network. Nothing is blocked and no error is shown.
2. Onboarding proceeds exactly as J1-A. No step requires a network call.
3. `Sync & Account` is never forced. If sign-in is offered, it is skippable and labelled optional.
4. `Add Income` → `Allocation Preview` → `Income Confirmed` all complete offline. The allocation is computed on-device.
5. `Dashboard` shows the result. A quiet, non-alarming indicator states the data is on this device only.
6. **Outcome:** full core flow completed with no network and no account (NFR-02, FR-15a).

**Highest risk: step 5** — telling the user their data is device-only can read as a warning that
something is broken. **Design response:** state it as a fact with an action attached ("On this
device only — back up"), never as an error state or a red indicator.

#### FJ-2 — Google permission revoked, discovered on the next sync attempt

1. User previously signed in; sync has been working.
2. They revoke the app's access in their Google account settings, outside the app.
3. `Dashboard` — the app continues to work completely. Nothing is blocked, no modal appears.
4. A background sync attempt fails with an authorisation error. The failure is recorded, not surfaced as a crash or a dialog.
5. `Dashboard` shows sync as needing attention. Local data is untouched and fully usable.
6. `Sync & Account` — the user sees plainly that access was withdrawn and what that means: local data is intact, cloud copy is stale, nothing has been deleted. One action offered: sign in again.
7. On re-authorisation, the outbox drains and the two sides converge.
8. **Outcome:** no data loss, no blocked app, user in control.

**Highest risk: step 4** — surfacing an auth failure as a blocking dialog would violate INV-06.
**Design response:** sync failures are never modal and never block a user action; they change a
status surface the user may choose to visit.

#### FJ-3 — A mistaken income entry, undone

1. `Dashboard` — the user realises the salary they logged an hour ago was the wrong amount.
2. `Transaction History` — they find the income event.
3. They select Undo on that event.
4. A confirmation states what will happen in plain terms: the split will be reversed, the entry will remain visible as a reversal, and history is not erased (INV-03, OQ-09).
5. They confirm. Every category returns to its prior balance exactly.
6. `Transaction History` shows both the original event and its reversal — the original does not disappear.
7. They re-enter the correct amount via `Add Income`.
8. **Outcome:** corrected, with an audit trail, and no history edited.

**Highest risk: step 6** — a user who expects the mistake to vanish may read the retained entry as
the undo having failed. **Design response:** the reversal must be visually paired with the entry it
cancels and the pair must read as settled, not as two competing entries.

#### FJ-4 — A second device added months later

1. New phone, app installed, `Welcome`.
2. `Sync & Account` — the user signs in with the same Google account during onboarding.
3. The app detects existing data in the account and offers `Restore From Cloud` rather than continuing setup.
4. Restore runs. The user is not asked to re-enter categories, percentages, ceilings or accounts.
5. `Dashboard` — figures match the original device.
6. Both devices continue to work independently, including offline, and converge afterwards.
7. **Outcome:** history received in full; the user never re-does setup.

**Highest risk: step 3** — a new install that walks the user through onboarding *before* checking
for existing data creates a conflicting second configuration. **Design response:** the check for
existing cloud data must happen before any configuration is written locally, and restore must be
offered as the default path when data is found.

#### FJ-5 — Phone lost, replaced

**Branch (a) — the user had signed in.** Identical to FJ-4. Install, sign in, restore, continue.
Outcome: complete recovery.

**Branch (b) — the user never signed in.** The data existed only on the lost device. Unless they
had exported a backup (NFR-07a), it is unrecoverable. There is no path in the app that recovers it.
**This branch ends in data loss and is escalated in §2.8.**

**Highest risk: it is not a step in this journey at all — it is step 3 of FJ-1**, months earlier,
where a user declined sign-in and was not made to understand the consequence. **Design response:**
the device-only state must carry a standing, non-nagging offer to back up, and the consequence must
be stated once in plain language during onboarding rather than buried in settings.

#### FJ-6 — The cloud copy vanishes

Covers IMP-12: the user can wipe the app's hidden data from their own Drive settings.

1. The user clears the app's hidden app data in their Google account, not knowing what it was.
2. Next sync finds no remote store.
3. The app does **not** interpret an empty remote as "everything was deleted" and does not mirror that emptiness onto the device.
4. `Dashboard` — local data is fully intact and the app works normally.
5. `Sync & Account` explains that the cloud copy is gone, local data is safe, and offers to re-upload.
6. On confirmation, the remote store is recreated from local data.
7. **Outcome:** no data loss; the destructive interpretation is never taken automatically.

**Highest risk: step 3.** A merge that treats "remote is empty" as "records were deleted" destroys
the user's entire history from a single external action. **Design response:** absence of a remote
store is never evidence of deletion — only an explicit tombstone is (INV-10).

#### FJ-7 — Percentages changed, then an old event re-examined

Covers INV-11.

1. The user has been running for six months and changes their savings percentage upward.
2. `Dashboard` and all future allocations use the new rule.
3. `Transaction History` — they open an income event from four months ago and wonder why its split does not match their current percentages.
4. The event explains itself against the rule that was in force when it was applied, not the current one.
5. Past figures do not retroactively change.
6. **Outcome:** history stays explainable and stable across rule changes.

**Highest risk: step 5.** Retroactively re-deriving history against current rules would silently
alter past balances. **Design response:** every income event carries the rule version it was
evaluated under, and historical explanation reads from that version.

---

### 2.7 Setup time estimate against NFR-04 and R-06

NFR-04 requires onboarding **and** the first income split under 5 minutes (300s) unaided. R-06
separately requires that setup alone be completable in under 2 minutes (120s) by accepting defaults.
Both are estimated here against the J1 default-accepting path.

| Steps | Segment | Estimate |
|---|---|---|
| 1 | `Welcome` | 5s |
| 2 | `Currency Confirmation` — pre-filled from locale, confirm | 8s |
| 3 | `Scope Selection` — one tap | 8s |
| 4 | `Top-Level Split` — pre-filled and valid, accept | 15s |
| 5–6 | `Category Selection` ×2 groups — pre-ticked, accept each | 30s |
| 7 | `Category Percentages` — pre-filled and valid, accept | 20s |
| 8 | `Ceilings Setup` — skip | 5s |
| 9 | `Accounts Setup` — skip | 5s |
| 10 | `Setup Summary` — confirm | 10s |
| | **Onboarding subtotal (11 steps to `Dashboard`)** | **106s ≈ 1m 46s** — under R-06's 120s ✅ |
| 13 | `Add Income` — type amount and label | 30s |
| 14 | `Allocation Preview` — read the split | 20s |
| 15–17 | Confirm and land on `Dashboard` | 10s |
| | **Total to first completed income split** | **166s ≈ 2m 46s** — under NFR-04's 300s ✅, 134s margin |

**What the step count has to support this claim.** Eleven screens in under two minutes averages
under 10 seconds per screen. That is only achievable if **every screen on the default path arrives
already valid and requires exactly one tap to accept.** This is a constraint on Stage 6, derived
here rather than assumed: if any default-path screen requires the user to make numbers total 100
themselves, R-06's target fails.

These are estimates. NFR-04 is verified by observed first-time users in Stage 9, not by this table.

---

### 2.8 Escalations from this substage

**ESC-1.2-A — FJ-5(b) ends in data loss, and no design response fully prevents it.**
Substage 1.2's acceptance criteria require that no failure journey end in a dead end or in data
loss. FJ-5 branch (b) does. This is not a design defect that can be written away: NFR-02 and FR-15a
guarantee the app is fully usable with no account ever linked, and NG-01 rules out any other
recovery channel, so a user who never signs in and never exports has no recovery path when the
device is lost. The tension is between NFR-02 (sign-in never required) and NFR-07 (recoverability).
Recorded, not resolved. Carried to 1.7 as a question about how insistently the app should prompt
for a backup, and what it must say at onboarding about the device-only state.

**F-11 (new ambiguity, to 1.7)** — `Scope Selection` is introduced by these journeys but is not in
any FR. FR-06 assumes a three-way Spending/Savings/Business split; a personal-only user has no
Business group. Whether the Business group is hidden, or present at 0%, changes how group
percentages must total 100 and is a real data-model question for Stage 2.

**F-12 (new ambiguity, to 1.7)** — FJ-4 step 3 requires that a new install detect existing cloud
data *before* writing local configuration. No requirement states this ordering, and getting it
wrong produces two divergent configurations that then have to be merged.

---

## Appendix A — Source requirement inventory

Built in substage 1.1 from `00_project_manifest.json`. Wording in the "verbatim source" columns is
copied exactly from the manifest and must not be paraphrased. Where this appendix records a
judgement (a split, a classification, a flag) that judgement is labelled as such.

### A.0 Reconciliation of counts

| Source block | Expected | Inventoried | Reconciled |
|---|---|---|---|
| `feature_requirements` | 15 (FR-01…FR-15) | 15 | ✅ |
| `non_functional_requirements` | 8 (NFR-01…NFR-08) | 8 | ✅ |
| `predefined_categories` | 19 seeded categories (5 spending, 9 savings, 5 business) | 19 | ✅ |
| `cloud_sync_requirements` | 4 keyed requirements + 4 known trade-offs | 8 | ✅ |
| `explicit_non_goals_v1` | 5 | 5 | ✅ |

Parent requirement total: **23**. After splitting compound requirements: **42** sub-requirements
(§A.2). Implied requirements not present in the FR/NFR lists: **15** (§A.3). Non-goal constraints:
**5** (§A.4).

---

### A.1 Parent requirements — verbatim

#### A.1.1 Feature requirements

| ID | Verbatim source statement | Priority | Class |
|---|---|---|---|
| FR-01 | "Add multiple savings categories, each user-definable." | MUST | Functional |
| FR-02 | "Set a fixed percentage of income allocated to each category." | MUST | Functional |
| FR-03 | "Assign which bank account stores which category's funds." | MUST | Functional |
| FR-04 | "Log an income event and auto-split it into spending, savings and business-purpose buckets based on user-defined rules." | MUST | Functional |
| FR-05 | "Track spending categories separately from savings categories." | MUST | Functional |
| FR-06 | "User selects top-level split ratios: Spending / Savings / Business Purposes." | MUST | Functional |
| FR-07 | "Business Purposes group includes sub-categories such as inventory/stock and advertising/marketing, kept distinct from personal categories." | MUST | Functional |
| FR-08 | "Each category group ships with predefined suggested categories; the user can accept, edit, remove or add fully custom categories." | MUST | Functional |
| FR-09 | "Cloud sync to the user's own Google account, not a third-party server, so data is not locked to one device." | MUST | Functional + Constraint |
| FR-10 | "Category ceiling system: accumulating categories have a target ceiling; once reached, further contributions redirect to a user-specified fallback category." | MUST | Functional |
| FR-11 | "Fixed-recurring categories are distinguished from accumulating reserve categories, since they do not need to grow past their bill amount." | MUST | Functional (contains embedded rationale — see F-06) |
| FR-12 | "Manual override: the user can adjust the auto-suggested split for any individual income event before confirming." | MUST | Functional |
| FR-13 | "Dashboard showing real-time balance per category against its ceiling/target." | MUST | Functional |
| FR-14 | "Reports: monthly/yearly summaries, category trends, CSV export." | SHOULD | Functional |
| FR-15 | "Offline-first: app fully usable without internet, syncs when connectivity returns." | MUST | Non-functional (registered as FR — see F-01) |

#### A.1.2 Non-functional requirements

| ID | Verbatim source statement | Verbatim measurable target | Class |
|---|---|---|---|
| NFR-01 | "No user financial data leaves the user's own Google account infrastructure." | "Zero outbound requests to any host not owned by Google as the user's storage provider; verified by network capture during QA." | Constraint |
| NFR-02 | "The app must function fully offline; sync is an enhancement, not a dependency." | "100% of core flows completable with no network and with no Google account linked." | Non-functional |
| NFR-03 | "Clear separation in UI/UX between personal and business financial data." | "Business data never appears in personal totals; distinct visual treatment; separate report scopes." | Non-functional |
| NFR-04 | "Accessible to users with no prior budgeting-app experience." | "A first-time user completes onboarding and their first income split unaided in under 5 minutes." | Non-functional |
| NFR-05 | "Financial correctness over convenience." | "No rounding drift: for every income event, the sum of allocations equals the input amount exactly, proven by property-based tests over randomised inputs." | Non-functional |
| NFR-06 | "Responsive on mid-tier Android hardware." | "Cold start under 2.5s and dashboard scroll without dropped frames on a device roughly equivalent to a 4GB-RAM mid-range phone; allocation of one income event across 100 categories under 50ms." | Non-functional |
| NFR-07 | "Data durability and recoverability." | "User can export a full JSON/CSV backup at any time; database migrations are tested against fixtures from every prior schema version." | Non-functional |
| NFR-08 | "Accessibility compliance." | "TalkBack labels on all interactive elements, minimum 48dp touch targets, 4.5:1 text contrast, layout intact at 200% font scale." | Non-functional |

---

### A.2 Compound requirements, split

A requirement is split when its verbatim statement contains more than one independently testable
claim. Each child carries the parent id plus a letter suffix and quotes the exact clause it derives
from. Parents not listed here carry exactly one testable claim and are not split.

| ID | Verbatim clause | Split justification (one line) |
|---|---|---|
| FR-01a | "Add multiple savings categories" | Creating more than one category is verifiable independently of whether its fields are editable. |
| FR-01b | "each user-definable" | Editability of a category's definition is a separate observable behaviour from its creation. |
| FR-04a | "Log an income event" | Recording the inbound amount is verifiable even if no split rules exist. |
| FR-04b | "auto-split it into spending, savings and business-purpose buckets based on user-defined rules" | The split is a distinct behaviour with its own correctness condition (conservation). |
| FR-07a | "Business Purposes group includes sub-categories such as inventory/stock and advertising/marketing" | Presence of business categories is verifiable separately from their isolation. |
| FR-07b | "kept distinct from personal categories" | Isolation is a negative property requiring its own test (a business category must not appear in personal flows). |
| FR-08a | "Each category group ships with predefined suggested categories" | Shipping the seed set is verifiable before any user edit occurs. |
| FR-08b | "the user can accept, edit, remove" | Mutability of a *seeded* category is distinct from creating a new one. |
| FR-08c | "or add fully custom categories" | Creating a category with no seed provenance is a separate path. |
| FR-09a | "Cloud sync to the user's own Google account" | The positive capability: data reaches the user's own storage. |
| FR-09b | "not a third-party server" | A prohibition, verifiable only by network capture — a constraint, not a feature. |
| FR-09c | "so data is not locked to one device" | Multi-device availability is the outcome and is verifiable independently of the storage target. |
| FR-10a | "accumulating categories have a target ceiling" | Configuring and storing a ceiling is verifiable with no income event. |
| FR-10b | "once reached, further contributions redirect to a user-specified fallback category" | Redirect-on-overflow is the behaviour; the ceiling is the configuration. |
| FR-11a | "Fixed-recurring categories are distinguished from accumulating reserve categories" | The existence of the type distinction is verifiable in configuration. |
| FR-11b | "they do not need to grow past their bill amount" | Per-period capping is a runtime allocation behaviour with its own failure mode. |
| FR-14a | "monthly … summaries" | Named as a distinct capability in the stage plan (1.1.2). |
| FR-14b | "yearly summaries" | Distinct period boundary and distinct output. |
| FR-14c | "category trends" | A different computation (change over time) from a period summary. |
| FR-14d | "CSV export" | An artefact leaving the app, with its own reconciliation requirement. |
| FR-15a | "app fully usable without internet" | Offline capability is verifiable with no account ever linked. |
| FR-15b | "syncs when connectivity returns" | Reconciliation on reconnect is a separate behaviour with its own failure modes. |
| NFR-02a | "The app must function fully offline" | Duplicates FR-15a — see F-01. |
| NFR-02b | "sync is an enhancement, not a dependency" | Prohibits sync being on any blocking path; a distinct negative property. |
| NFR-06a | "Cold start under 2.5s" | Independent measurement. |
| NFR-06b | "dashboard scroll without dropped frames" | Independent measurement. |
| NFR-06c | "allocation of one income event across 100 categories under 50ms" | Independent measurement, and the only one measurable without a device. |
| NFR-07a | "User can export a full JSON/CSV backup at any time" | A user-facing capability. |
| NFR-07b | "database migrations are tested against fixtures from every prior schema version" | An engineering practice, verifiable in CI, not by a user. |
| NFR-08a | "TalkBack labels on all interactive elements" | Independent check. |
| NFR-08b | "minimum 48dp touch targets" | Independent check. |
| NFR-08c | "4.5:1 text contrast" | Independent check. |
| NFR-08d | "layout intact at 200% font scale" | Independent check. |

Unsplit parents (one testable claim each): FR-02, FR-03, FR-05, FR-06, FR-12, FR-13, NFR-01,
NFR-03, NFR-04, NFR-05.

Sub-requirement total: 33 children + 9 unsplit FR/NFR parents = **42**.

---

### A.3 Implied requirements

Requirements carried by `predefined_categories`, `cloud_sync_requirements` and `project.platform`
that do not appear in the FR or NFR lists. **`IMP-xx` is an inventory-local namespace**, not a
manifest registry. Substage 1.8 must either promote each row to an FR/NFR or record an explicit
decision to drop it; none may be left un-adjudicated.

| ID | Implied requirement | Verbatim source | Class |
|---|---|---|---|
| IMP-01 | Seeded categories are presented as editable proposals, never as fixed structure | "The onboarding UI must present them as pre-ticked-but-editable proposals, never as fixed structure." | Constraint |
| IMP-02 | Every seeded category ships with a suggested category type | `suggested_type` present on all 19 seed entries | Functional |
| IMP-03 | The seed set is exactly 19 named categories: 5 spending, 9 savings, 5 business | `predefined_categories` lists | Functional (content) |
| IMP-04 | The business group has a designated default sink candidate | "Suitable default sink for the business group." (Business miscellaneous) | Functional |
| IMP-05 | At least one seeded category is anchored to a moving lunar-calendar date | "the target date moves ~11 days earlier each Gregorian year" (Eid/Qurbani savings) | Assumption presented as requirement |
| IMP-06 | A ceiling may be expressed as a multiple of another figure rather than an absolute amount | "Ceiling commonly expressed as N months of spending-group outflow." (Emergency fund) | Assumption presented as requirement |
| IMP-07 | Spending from an accumulating reserve reopens its headroom so it refills | "refills after a claim is spent" (Medical reserve); "Drains to near zero on purchase, then refills" (Vehicle/PC upgrade reserve) | Functional |
| IMP-08 | The remote store is the user's own Google account; Drive `appDataFolder` is recommended and the final choice is justified in an ADR | "Google Drive appDataFolder is the recommended target; see ADR requirement in S07" | Constraint |
| IMP-09 | No third-party server exists | `no_third_party_server: true` | Constraint |
| IMP-10 | The app is offline-first | `offline_first: true` | Non-functional |
| IMP-11 | Multi-device conflict handling is required | `multi_device_conflict_handling_required: true` | Functional |
| IMP-12 | The app handles the remote store having vanished, gracefully | "The user can wipe the app's hidden data from Drive settings, so the app must handle 'remote store vanished' gracefully." | Functional |
| IMP-13 | Remote payload size is the app's responsibility, because it consumes the user's own quota | "Files count against the user's own Drive storage quota." | Non-functional |
| IMP-14 | The app-data OAuth scope requires Google verification before public release, and calendar time is budgeted for it | "typically requires app verification before public release - budget calendar time for this in S10" | Constraint (schedule) |
| IMP-15 | All merging happens on the client | "No server-side query, indexing, merge, or realtime push - the client does all merging." | Constraint |

---

### A.4 Non-goal constraints

| ID | Verbatim source | Class |
|---|---|---|
| NG-01 | "No bank API / open-banking integration. Income and spending are entered manually." | Constraint |
| NG-02 | "No multi-user or shared household accounts." | Constraint |
| NG-03 | "No investment tracking, loans, debt payoff planning, or net-worth calculation." | Constraint |
| NG-04 | "No third-party analytics, crash reporting containing financial data, or ad SDKs." | Constraint |
| NG-05 | "No currency conversion or multi-currency portfolios (single currency per install)." | Constraint |
| NG-06 | "do not introduce Android-only abstractions in the domain layer that would block a later iOS port" | Constraint (from `project.platform.ios_support`) |

Six rows, of which five are the manifest's `explicit_non_goals_v1`; NG-06 is drawn from the platform
block and is a constraint of the same kind.

---

### A.5 CRITICAL register

**Definition used:** a requirement is CRITICAL if incorrect behaviour would cause money to be lost,
invented, or attributed to the wrong category, **or** would cause a displayed or exported figure to
disagree with the ledger. Both classes need failure-case acceptance criteria in substage 1.3.

| # | ID | Why it is CRITICAL |
|---|---|---|
| 1 | FR-02 | Percentages are the input to every split; a wrong value misallocates every future event. |
| 2 | FR-04a | The recorded income amount is the conservation target for the whole event. |
| 3 | FR-04b | The split itself — the primary money-movement operation. |
| 4 | FR-06 | Top-level ratios gate all downstream allocation. |
| 5 | FR-10a | A wrong ceiling changes headroom and therefore where overflow lands. |
| 6 | FR-10b | Redirect is money movement between categories. |
| 7 | FR-11a | Category type determines the headroom formula. |
| 8 | FR-11b | Per-period capping decides how much money leaves the category. |
| 9 | FR-12 | User-entered amounts must still total the income exactly. |
| 10 | FR-13 | Displayed balances must equal ledger-derived balances. |
| 11 | FR-14a | A monthly summary must reconcile with the ledger. |
| 12 | FR-14b | A yearly summary must reconcile with the ledger. |
| 13 | FR-14d | Exported CSV totals must reconcile with in-app totals. |
| 14 | FR-15b | A merge must neither drop nor duplicate a ledger entry. |
| 15 | NFR-05 | The rounding-drift prohibition itself. |
| 16 | NFR-07a | An incomplete backup silently loses money on restore. |
| 17 | IMP-07 | Whether spending reopens headroom changes every subsequent allocation. |
| 18 | IMP-11 | Conflict resolution decides which device's money records survive. |

**Count: 18 CRITICAL.**

**Conditionally CRITICAL: 1.** FR-03 is not CRITICAL under OQ-02's default reading (accounts are
informational labels). If OQ-02 resolves to Option B — accounts holding real balances with transfers
and reconciliation — FR-03 becomes CRITICAL and needs failure criteria. Recorded so that answering
OQ-02 mechanically updates this register.

FR-14c (category trends) is deliberately **not** CRITICAL: it presents direction of change rather
than a figure that must reconcile to the minor unit.

---

### A.6 Invariant cross-check

Per 1.1.5, requirements that appear to conflict with INV-01…INV-12 are recorded and escalated here,
**not resolved**.

#### A.6.1 Escalations — genuine conflicts

| # | Requirements | Invariants | The conflict |
|---|---|---|---|
| E-01 | FR-10b — "redirect to a **user-specified** fallback category" | INV-07 | INV-07 guarantees termination via "a guaranteed uncapped terminal sink category". FR-10b only ever names a *user-specified* target. If the user specifies a fallback that is itself capped, and every category the user created is capped, there is no terminal destination and overflow has nowhere to land. INV-07 therefore requires a sink the user did not specify and cannot delete — which FR-10b does not authorise. Routes to OQ-07. |
| E-02 | FR-12 — manual override of a single event | INV-08, INV-11 | INV-08 requires that "the same inputs, balances and rule version always produce byte-identical output". An override changes the outcome without changing rules or balances, so the override amounts must themselves be a stored *input* to the event, not a post-hoc edit of its output. INV-11 further requires the event be explainable against the rule version active at the time — an overridden event is explainable only if the override is recorded alongside that rule version. Neither FR-12 nor the manifest states this. |
| E-03 | IMP-06 — ceiling "expressed as N months of spending-group outflow" | INV-08 | A ceiling derived from historical outflow is not a stored constant; it is recomputed from ledger history. The engine may remain pure only if that ceiling is resolved to an integer *before* the call and passed in. Whether such a ceiling is a v1 capability at all is unstated. |
| E-04 | IMP-02 / IMP-03 — 6 of 19 seeded categories carry `suggested_type: UNCAPPED_FLOW` | — | The manifest's own seed data presupposes a category type whose existence is still open (OQ-03, "should a third category type UNCAPPED_FLOW exist"). If OQ-03 resolves against, 6 seeded categories have no valid type. Seed data and open register are inconsistent as shipped. |

Type distribution across the 19 seeds, for E-04: ACCUMULATING_RESERVE 10, UNCAPPED_FLOW 6,
FIXED_RECURRING 3.

#### A.6.2 Tensions noted — not conflicts, but constraints later stages must honour

| # | Requirements | Invariants | Note |
|---|---|---|---|
| T-01 | FR-13 "real-time balance" | INV-04, NFR-06a | INV-04 makes balances derived. Deriving from a full ledger scan on every dashboard render is in tension with the 2.5s cold start at five-year volume, so the cache INV-04 permits is likely mandatory rather than optional. A Stage 2 decision, not a Stage 1 one. |
| T-02 | FR-09, NFR-01 | INV-05 | The manifest's own `analysis_note` already records that Firestore would conflict with INV-05 and steers to `appDataFolder`. Not an open conflict; S07 must still record the ADR. |
| T-03 | FR-14d CSV export | INV-01 | CSV is text. Amounts must be rendered from int64 minor units by integer formatting; no float may appear in the export path, including in the writer. |
| T-04 | FR-15b sync | INV-03, INV-10 | A merge may never delete a ledger entry. Union-by-UUID on immutable entries plus tombstones for configuration satisfies both; recorded so no merge design regresses it. |
| T-05 | NFR-07a "export at any time" | INV-05, NFR-01 | A user-initiated export deliberately moves financial data off-device. This is user egress, not developer egress, and must not be flagged as an NFR-01 violation during Stage 9 network capture. |
| T-06 | FR-12 override | INV-02 | Conservation still binds an overridden event; FR-12's own `verified_by` already requires exact totalling. |

---

### A.7 Ambiguities flagged for substage 1.7

Recorded, not resolved. Each is a candidate OQ-11 onward.

| # | Requirement | The ambiguity |
|---|---|---|
| F-01 | FR-15 vs NFR-02, FR-09 vs NFR-01, FR-07b vs NFR-03 | Three requirements are registered in both the FR and NFR lists in near-identical terms. Traceability needs to know whether these are one requirement or two, or 1.8's matrix will double-count coverage. |
| F-02 | FR-01 | Says "savings categories", but FR-05, FR-06 and FR-07 establish three groups. Either FR-01 is scoped to savings only, or "savings" is being used loosely for "category". Terminology must be settled before the glossary is final. |
| F-03 | FR-02 | "a fixed percentage of income" — of the gross income amount, or of the group's share of it? `verified_by` implies two-level (group shares to 10000, within-group shares to 10000), but the statement reads as one level. |
| F-04 | FR-07 | "sub-categories" — does this imply a nested category hierarchy, or simply categories belonging to the business group? The first reading is materially more scope and a different data model. |
| F-05 | FR-13 | "real-time" is undefined. Within the same frame, on next open, within N seconds of a write? |
| F-06 | FR-11 | Contains embedded rationale ("since they do not need to grow past their bill amount") — an assumption presented as a requirement. Routed here per step 1.1.3. |
| F-07 | FR-14a, FR-14b | "monthly/yearly" — calendar month and calendar year, or rolling windows, or user-configurable period start? Report boundaries are undefined. |
| F-08 | FR-03 | Cardinality unstated: may one account hold several categories, and may one category span several accounts? |
| F-09 | IMP-07 | Whether spending reopens headroom is implied only by two seed-category notes, never stated as a rule. Two incompatible reasonable implementations exist. |
| F-10 | FR-04a | "income event" — salary only, or any inbound money including business revenue, refunds and gifts? The glossary says "salary, sale proceeds, gift", the FR says only "income event". |

Ten flags. All carry forward to substage 1.7 for options, consequences and a recommended default.
