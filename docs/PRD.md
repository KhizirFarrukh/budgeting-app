# PookieBudget — Product Requirements Document

| | |
|---|---|
| **Status** | In progress — Stage 1 |
| **Source** | `prompts/00_project_manifest.json` (schema 4.0.0) |
| **Sections assembled** | 2 (1.2), 3 (1.6), 4 (1.4), 5 (1.3), 6 and 7 (1.5), Appendix A (1.1) |
| **Sections pending** | 1, 8, 9, assembled across substages 1.7–1.8 |

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

## 3. Scope, deferrals and the version 1 cut line

Written in substage 1.6. Three distinct things are separated here, because conflating them is how
scope decisions go wrong:

- **Non-goals** — never built, at any version.
- **Deferred** — will be built later, and the only question that matters is whether deferring costs
  a migration.
- **In scope but not release-blocking** — built for v1, but its absence would not stop a release.

### 3.1 Non-goals

Restated from the manifest, plus those discovered during substages 1.1 to 1.5.

| ID | Non-goal | Source |
|---|---|---|
| NG-01 | No bank API or open-banking integration. Income and spending are entered manually. | Manifest |
| NG-02 | No multi-user or shared household accounts. | Manifest |
| NG-03 | No investment tracking, loans, debt payoff planning or net-worth calculation. | Manifest |
| NG-04 | No third-party analytics, no crash reporting containing financial data, no ad SDKs. | Manifest |
| NG-05 | No currency conversion or multi-currency portfolios. One currency per install. | Manifest |
| NG-06 | No iOS in v1 — but no Android-only abstraction may enter the domain layer and block a later port. | Manifest platform block |
| **NG-07** | **No forecasting, projection, advice or scoring.** The app shows what happened, never what will happen or what the user ought to do. | **New — discovered 1.5; a predictive feature would need its own requirement and changes the product's liability posture** |
| **NG-08** | **No developer-operated backend, proxy, relay or metrics endpoint, at any version.** | **New — implicit in INV-05 and NFR-01, named here as permanent rather than merely absent** |
| **NG-09** | **No web version.** | **Manifest platform block, not previously listed as a non-goal** |

### 3.2 Story disposition

**All 37 stories (US-001…US-037) are in scope for version 1. None is deferred.**

That is not the result of generous scoping — it is a property of the brief. Fourteen of the
manifest's fifteen feature requirements are marked MUST; only FR-14 (reports) is SHOULD. There is
almost nothing the brief itself permits cutting. **See ESC-1.6-A** — this is a schedule risk that
should be visible now rather than discovered in Stage 6.

The real distinction available is therefore between in-scope-and-blocking and
in-scope-but-not-blocking:

| Disposition | Stories | Count |
|---|---|---|
| In scope, release-blocking | US-001…US-032 except US-028…US-031 | 28 |
| In scope, **not** release-blocking — cloud sync | US-028, US-029, US-030, US-031 | 4 |
| In scope, **not** release-blocking — reports and export | US-033…US-037 | 5 |

**Why sync is in scope but not release-blocking.** FR-09 is a MUST and will be built. But the app
delivers its daily value with no account linked at all (NFR-02 guarantees this), and R-04 warns that
Google's OAuth verification for the app-data scope can take weeks of calendar time that the team
does not control. Making sync a release blocker would hand a third party a veto over the release
date. The manifest's own R-04 mitigation says the same thing: *"keep the app fully functional
without sign-in so an unverified build is still shippable to testers."* Sync ships when verification
clears; the app does not wait for it.

### 3.3 The version 1 cut line

The shortest set of capabilities that makes this app worth opening daily. **Anything not on this
list does not block release.**

- [ ] **1.** A first-time user completes setup by accepting defaults, in under two minutes, and lands on a dashboard
- [ ] **2.** Every suggested category can be renamed, retyped, re-targeted or removed, and custom categories can be added
- [ ] **3.** Group and within-group percentages can be set, and cannot be saved unless each totals exactly 100
- [ ] **4.** An income event can be recorded, and its split previewed before confirming
- [ ] **5.** The previewed amounts total the entered amount exactly, at one minor unit, at typical values, and at the documented maximum
- [ ] **6.** A full category's overflow reaches the category the user named, and every hop is explained in the preview
- [ ] **7.** A chain where everything is full terminates at the catch-all, by name
- [ ] **8.** A fixed bill stops collecting once funded for its period, and its surplus visibly moves on
- [ ] **9.** The split for a single payment can be adjusted by hand, and cannot be confirmed unless it totals exactly
- [ ] **10.** A confirmed income event can be undone, restoring every balance exactly, with both entries visible in history
- [ ] **11.** A spend can be recorded in seconds, and the category balance falls by exactly that amount
- [ ] **12.** The dashboard shows every category's balance and ceiling progress, and updates without a manual refresh
- [ ] **13.** History is filterable and its totals agree with the dashboard
- [ ] **14.** Business and personal figures never mix, and a personal-only user sees no business surface
- [ ] **15.** All fourteen of the above work with no network and no Google account, on a device that has never been online
- [ ] **16.** A complete backup can be exported and restored, reproducing every balance exactly

Sixteen items. Every one is verifiable by a person holding a phone, and each maps to stories already
written in §5.

### 3.4 Deferrals, classified — the load-bearing output

Every deferred feature is labelled **schema-safe** (can be added later without migrating existing
data) or **requires accommodation now** (adding it later would force a migration unless something is
put in the schema at v1.0). Where accommodation is required, it is named explicitly, because an
unnamed accommodation is an unpaid debt.

#### Requires accommodation now — six items

| ID | Deferred feature | Why deferred | **Accommodation required at v1.0** |
|---|---|---|---|
| D-01 | Target dates on accumulating categories, with a suggested monthly contribution (OQ-04) | Several seeded categories are deadline-driven, but "on track" calculations are a feature in their own right | A nullable **target date** on every category, present and documented as reserved but unused. *(Already required by the design plan at 2.3.3.)* |
| D-02 | Ceilings expressed as a formula rather than an amount — "six months of spending" (IMP-06, escalation E-03) | A derived ceiling is recomputed from history, not stored; it changes what a ceiling *is* | A **ceiling kind discriminator** plus a **parameter field** on every category. Without it, every category row must be migrated when the second kind of ceiling appears. |
| D-03 | True category hierarchy — categories nested inside categories (ambiguity F-04) | FR-07's word "sub-categories" may mean only "categories within the business group". If it means a tree, that is materially more scope | A nullable **parent category reference** (self-referencing) on every category. **Conditional on F-04** — if F-04 resolves to "a tree is wanted in v1", this is not a deferral at all. |
| D-04 | Passphrase encryption of the cloud payload (OQ-08) | Manifest default is no encryption in v1; a forgotten passphrase is an unrecoverable failure mode | An **encryption-scheme field in the remote manifest file**, written from v1.0 with the value "none". Without it, a later client cannot distinguish an unencrypted payload from a corrupt one, and cannot safely mix encrypted and unencrypted devices during rollout. *(Remote format only — the local database is unaffected.)* |
| D-05 | A soft monthly budget on envelope categories that warns but never redirects (part of the OQ-03 default) | It adds warning states and a period concept to a category type whose whole point is having no cap; no FR requires it | A nullable **soft budget amount** and its **period** on every category. |
| D-06 | Different distribution rules per income source — salary split one way, business revenue another (ambiguity F-10) | The brief describes one rule set applying to all income | A **discriminator on the rule-version record** identifying which rule set it belongs to, so more than one can exist concurrently. **Conditional on F-10** — if F-10 resolves to "business revenue uses a business-only split", this is v1 scope, not a deferral. |

**D-03 and D-06 are conditional and both depend on unresolved ambiguities.** If either resolves the
other way, it moves from "deferred with accommodation" to "in scope", which changes Stage 2's data
design materially. Both must be answered before Stage 2 begins.

#### Schema-safe to defer — eight items

| ID | Deferred feature | Why it is safe |
|---|---|---|
| D-07 | Transfers between categories | A future transfers table plus a new movement-source value. Ledger entries already carry a source kind and a source reference, so nothing existing changes. Enumerations are stored as stable strings, so a new value is additive. |
| D-08 | Scheduled or recurring income — auto-logging a salary monthly | A new schedule table that writes ordinary income events. No existing table changes. |
| D-09 | Reminders and notifications | New table plus platform integration; no financial record is touched. |
| D-10 | Home screen widgets | Read-only projection of existing data. |
| D-11 | Receipt or photo attachments | A new table referencing an existing ledger entry. |
| D-12 | Localisation into other languages | No schema at all. The accommodation is behavioural and **already required**: seeded strings externalised (design plan 4.7.7) and all user-facing strings in one place (6.11.6). |
| D-13 | An iOS version | No schema. The accommodation is NG-06, already a binding constraint on the domain layer. |
| D-14 | Account-level balances, transfers and statement reconciliation — OQ-02 Reading B | **Already accommodated by accident, and worth stating so it is not re-litigated:** ledger entries carry an account reference, so per-account movement is recordable from v1.0. Reading B additionally needs a nullable arrival-account reference on income events, which is an additive nullable column, not a migration of existing rows. |

**Total: fourteen deferrals — six needing accommodation, eight safe.** Every accommodation is named.
None is left as "we'll deal with it later".

### 3.5 The boundary against accounting software

R-05 warns that the business feature set could turn this into accounting software. The line, in one
sentence:

> **PookieBudget records where money was *allocated*; the moment a feature requires recording what
> is *owed to or by* the user — invoices, receivables, payables, tax liability, profit-and-loss or a
> chart of accounts — it belongs in accounting software and not in this app.**

Practically, that rules out: invoicing and quotes; customer and supplier records; VAT/GST or
income-tax computation; cost of goods sold and margin analysis; payroll; depreciation; double-entry
journals and trial balances; anything producing a document for a tax authority.

It permits, and v1 delivers: ring-fencing business money as it arrives, keeping business balances
visually and structurally separate from household money, and exporting business-scoped records so an
accountant can do the accounting elsewhere. **The export is the boundary** — this app hands the data
to accounting software rather than becoming it.

Any proposed business feature that crosses this line is raised as an open question, never
implemented inline.

### 3.6 Journey sanity check

Every step of both primary journeys must be supported by an in-scope capability — nothing a primary
journey depends on may be deferred.

| Journey segment | Steps | Supporting capabilities | Cut-line items |
|---|---|---|---|
| J1-A first launch to dashboard | 1–11 | Onboarding, currency, scope choice, suggested categories, percentages, optional ceilings, optional accounts | 1, 2, 3 |
| J1-B first salary | 12–17 | Income entry, live preview, conservation, confirm, result | 4, 5, 12 |
| J1-C spend and return next day | 18–22 | Spending entry, dashboard, category detail, ceiling progress | 11, 12 |
| J2-A business setup | 1–11 | Scope with business, business categories, ceilings with redirect target, accounts, scope separation | 1, 2, 3, 14 |
| J2-B business income overflowing a ceiling | 12–18 | Preview, headroom, redirect with named destination, hop explanation, confirm | 5, 6, 7 |

**Result: every one of J1's 22 steps and J2's 18 steps is supported by an in-scope, release-blocking
capability.** No primary journey touches any deferred feature — checked against all fourteen
deferrals in §3.4; none of target dates, derived ceilings, hierarchy, payload encryption, soft
budgets, per-source rules, transfers, scheduling, notifications, widgets, attachments, localisation,
iOS or account reconciliation appears in either journey.

The failure journeys FJ-4 and FJ-5(a) depend on sync, which is in scope but not release-blocking
(§3.2). Those two journeys are therefore unavailable in a pre-verification release — stated here so
the limitation is deliberate rather than discovered.

### 3.7 Escalation from this substage

**ESC-1.6-A — the brief leaves almost nothing to cut, and that is a schedule risk.**
Fourteen of fifteen feature requirements are MUST. After a genuine attempt at scoping, all 37
stories are in scope and only nine are non-blocking. The plan's own warning about "a cut line so
generous that Stage 6 never ends" applies directly, and the honest response is not to pretend
otherwise but to name it: **either the schedule accommodates a fourteen-MUST v1, or one or more FRs
must be renegotiated to SHOULD before Stage 2 begins.** The most plausible candidates, if
renegotiation is wanted, are FR-03 (accounts — informational only under OQ-02's default, and the
least load-bearing MUST) and FR-14 (already SHOULD, and could be reduced to CSV export alone).
Recorded, not resolved — this is the user's call at the gate.

---

## 4. The money model

Written in substage 1.4, in words a non-developer can act on. Stage 2 derives the data design from
this section, so every sentence here is a commitment. Percentages appear as whole percentages;
amounts appear as plain figures with no currency named, because the model is the same in every
currency.

### 4.1 What a balance is — and is not

A category's balance is **money you have set aside and not yet spent, as recorded in this app**.

It is the running total of everything that ever happened to that category: each income share that
landed in it, each spend recorded against it, each correction. The app always arrives at the number
by adding up that history — a balance is never a number anyone typed in, and there is no way to
"set" a balance directly. If you doubt a figure, you can open the category and add its entries
yourself; the total will match, or the app is wrong.

A balance is **not** what any bank shows. The app never connects to a bank. If you spend cash and
don't record it, the app doesn't know. The app's promise is exact bookkeeping of what you told it —
not mind-reading of what you didn't.

### 4.2 The three kinds of category

Every category is one of three kinds. The kind decides what "full" means and what happens to money
the category doesn't need. *(The third kind exists as this document's recommendation under open
question OQ-03; the suggested categories assume it.)*

**A reserve you are building — like Emergency fund, Trip savings, Medical reserve.**
It grows toward a target amount you set (its *ceiling* — §4.3). It is **full** when its balance
reaches that target. Money arriving beyond that point is not lost and not crammed in — it moves on
to the category you named as next in line (§4.5). **Spending from it makes room again**: pay a
medical bill from Medical reserve and the reserve is below its target, so future income tops it
back up — using a reserve for its purpose is never punished.

**A bill you pay every period — like Mobile/Internet, Subscriptions.**
You tell the app the bill amount and the day of the month it's due. Each period, the category
collects **only up to the bill amount** — it is "funded" for the period once this period's
allocations reach that amount, and further income passes it by until the next period starts. It
does not hoard three months of internet money. **Spending from it does not reopen collection in
the same period**: the cap is on how much goes *in* per period, so paying the bill doesn't make the
category collect twice. If a period ends with money unspent, the recommendation (open question
OQ-05) is that the surplus stays and the next period collects only the difference — the category
never holds more than one bill's worth.

**An open envelope — like Groceries, Transport, Eating out.**
No target and no cap. It is never "full"; whatever share you assign flows in, every time, and
overflow from other categories can always land here. The only question an envelope answers is "how
much is left this month?" — and that is spending discipline, not a rule the app enforces.

### 4.3 A ceiling is a finish line, not a fence

A **ceiling** is the amount at which a reserve counts as complete. It answers "when am I done
saving for this?"

It is **not a spending limit**. The app never stops you spending from any category, and a ceiling
says nothing about spending at all. Other budgeting apps use "limit" to mean "stop me spending" —
this app's ceiling means "stop *filling* this and send the money onward". If a category is at its
ceiling, that is a success state, not a warning state.

Two consequences worth stating plainly:

- A balance can sit **above** its ceiling. That happens only when you put it there yourself — by a
  manual override on one payment (§4.7), or by raising and then lowering the ceiling. The app never
  moves money out of a category to "fix" this; it simply stops adding more until you've spent back
  under the line.
- Lowering a ceiling below the current balance is allowed and moves no money; it just means the
  category is now over-complete and will receive nothing further.

### 4.4 Where each unit of income goes

When you record income, the app splits it in two visible steps:

1. **Across the groups** — Spending, Savings, and Business if enabled — by the whole-number
   percentages you chose. A 50 / 30 / 20 split of 30,000 is 15,000 / 9,000 / 6,000.
2. **Within each group** — each category takes its percentage of its group's share.

Then the ceilings have their say: any category that can't take its full share passes the excess on
(§4.5).

**The conservation rule — the app's core promise:** every single unit of an income amount lands in
exactly one category, always. Record 30,000 and the amounts landing across all categories total
exactly 30,000 — not 29,999, not 30,001, no matter how awkward the percentages divide. Nothing is
ever rounded away, absorbed, or held in limbo. The app can always show you where every unit went,
and the preview shows the running total equalling your entry before you confirm anything.

### 4.5 Overflow and the chain — a worked example

When a category is full, its excess goes to the category **you** named as its next-in-line. That
category may itself be full — then the excess follows *that* category's next-in-line, and so on,
hop by hop, until it lands somewhere with room. Every hop is shown to you; money never silently
skips from one place to another.

**Worked example** — three savings categories, real suggested names, arithmetic you can check by
hand. Setup:

| Category | Share of Savings | Target (ceiling) | Balance before | Next in line |
|---|---|---|---|---|
| Medical reserve | 40% | 50,000 | 42,000 | Emergency fund |
| Emergency fund | 35% | 100,000 | 90,000 | Trip savings |
| Trip savings | 25% | none — open | 12,500 | — |

Salary arrives and the Savings group's share is **30,000**. Step by step:

1. The percentage split assigns: Medical 40% = **12,000**, Emergency 35% = **10,500**, Trip 25% = **7,500**. (Check: 12,000 + 10,500 + 7,500 = 30,000.)
2. **Medical reserve** has room for only 50,000 − 42,000 = **8,000**. It accepts 8,000 and is now full. The remaining **4,000** heads to its next-in-line, Emergency fund.
3. **Emergency fund** deals with its own share first: room is 100,000 − 90,000 = **10,000**, so of its 10,500 it accepts **10,000** and is now full; the leftover **500** heads to its next-in-line, Trip savings.
4. The **4,000** from Medical now arrives at Emergency fund — which is already full, so all 4,000 continues down the line to Trip savings.
5. **Trip savings** has no ceiling. It accepts its own 7,500, the 500, and the 4,000: **12,000** in total.

Where the money ended up: Medical **8,000** + Emergency **10,000** + Trip **12,000** = **30,000**.
Every unit accounted for; both full categories stopped exactly at their targets; the app shows each
of these hops in the preview before you confirm.

*Check yourself:* if Trip savings had also had a ceiling with only 9,000 of room, where would the
last 3,000 go? — To the catch-all category described next. That is the answer the app would show
you, by name.

### 4.6 The catch-all at the end of every chain

One category is the **always-open catch-all** (suggested name: *Unallocated buffer*). It has no
ceiling, so it can always accept money, and every chain of next-in-lines ends there if everything
else is full. It is the reason overflow can never be homeless.

You can rename it and spend from it like any category. The one thing you cannot do is delete it —
the app's promise that every unit lands somewhere depends on it existing. If you run a business, a
separate business catch-all keeps overflowing business money inside the business (recommendation
under OQ-07).

### 4.7 Bending the rules for one payment

Before confirming any income event you can adjust its split by hand. The rules that make this safe:

- The adjusted amounts must still total the payment **exactly** — the app will not confirm
  otherwise.
- Your adjustment applies to **that payment only**. Your standing percentages are untouched, and
  the next payment previews by the standing rules.
- You may deliberately push a category past its ceiling this way. The app warns you and then obeys
  you — your explicit instruction outranks the standing rule for that one event. The overfilled
  category then receives nothing further from later income until spending brings it back under its
  ceiling.

### 4.8 Mistakes: undone, never erased

The app's history is written in ink. Nothing recorded is ever edited or deleted — a mistake is
corrected by an **equal and opposite entry** that cancels it, with both entries staying visible as
a pair.

Undo a mis-entered salary and every category returns to exactly the balance it had before — and
your history shows the salary *and* its reversal, so the record honestly reflects both the mistake
and the correction. A corrected spend works the same way: the original, its cancellation, and the
corrected entry all remain readable. This is why a balance can always be re-derived from history:
the history is never rewritten to flatter the present. *(Recommendation under OQ-09: undo is
available for any event, however old, and always leaves this visible pair.)*

### 4.9 Categories and bank accounts — two readings, one recommendation

Open question OQ-02 admits two readings of what a "bank account" is in this app. They differ in
scope so materially that the choice is put here rather than made silently:

**Reading A — accounts are labels (recommended).** An account is a name you attach to categories:
"Emergency fund and Trip savings live in my HBL savings account." The app shows each account's
expected total — the sum of its categories' balances — so you can eyeball it against what the bank
app shows. Nothing more. If they differ, the app changes nothing by itself; the difference is
information ("you have unrecorded activity"), not an error the app tries to fix.

**Reading B — accounts hold real balances.** Accounts become a second, parallel set of books:
recording money in an account, transfers between accounts, and reconciling each against bank
statements. This roughly doubles the bookkeeping surface of the app and makes every income event
ask "which account did this arrive in?" before it can be recorded.

The recommendation is Reading A for version 1: it answers persona P1's actual question ("which
account holds what?") with a fraction of the machinery, and Reading B can be layered on later
without undoing anything. The consequence to accept: the app's per-account totals are expectations,
not statements of record.



Written in substage 1.3. Every story: stable id, persona, MoSCoW priority, the inventory ids it
satisfies, and Given/When/Then criteria **observable by a person holding a phone** — no criterion
references an internal component, stored structure or code concept. Product language uses whole
percentages; the design-level unit is reserved for Stage 2. Stories marked **CRITICAL** carry at
least one failure criterion, per the §A.5 register.

Priorities inherit the manifest FR priority (MUST except FR-14's SHOULD) unless a reason to differ
is stated on the story.

### 5.1 Setup and configuration

---

**US-001 — Choose the top-level split** · P1 · MUST · FR-06 · **CRITICAL**

> As P1, I want to choose how each payment divides between Spending and Savings (and Business when
> enabled), so that every future payment follows my plan without me deciding in the moment.

- Given the Top-Level Split step, When I first see it, Then the percentages already total exactly 100 and one tap accepts them.
- Given I edit a group's percentage, When the total is not 100, Then the shortfall or excess is shown next to the figures and I cannot continue until the total is exactly 100.
- Given I change the split later in Settings, When I next log income, Then the preview follows the new split, and every previously recorded event still shows the split it was made with.
- **Failure:** Given any input path (typing, sliders, restoring a backup), When a split not totalling exactly 100 would result, Then it is refused with the difference named — never silently adjusted.

---

**US-002 — Use the app without business features** · P1 · MUST · derived from FR-06/FR-07 and journey J1 · *flag → F-11*

> As P1, I want to run the app personal-only, so that my home budget is not cluttered by a business
> I do not have.

- Given the scope step, When I choose personal only, Then no business group, category, figure or menu entry appears anywhere in the app afterwards.
- Given personal-only was chosen, When I later enable business in Settings, Then the business categories are offered, and I am guided to rebalance the top-level split to include Business so it totals exactly 100 before the change takes effect.

---

**US-003 — See suggested categories** · P1 · MUST · FR-08a, IMP-01, IMP-02, IMP-03

> As P1, I want ready-made category suggestions, so that I do not face an empty app on day one.

- Given a fresh install, When I reach the category step, Then each group shows its suggested categories pre-selected, each with a visible suggested type.
- Given the suggestions, When I simply accept them, Then setup continues with no further category work required.

---

**US-004 — Change or remove any suggestion** · P1 · MUST · FR-08b, IMP-01

> As P1, I want to rename, retype or remove any suggested category, so that the suggestions are a
> starting point and not a constraint.

- Given a suggested category, When I rename it, change its type, or remove it — during onboarding or any time later — Then the change persists and nothing recreates the original.
- Given I remove every category from a group that has a non-zero share of income, When I try to finish setup, Then the app tells me a group that receives money needs at least one category, and offers to add one or set that group's share to zero.

---

**US-005 — Add my own categories** · P1 · MUST · FR-08c

> As P1, I want to add fully custom categories, so that my budget matches my life rather than a
> template.

- Given the category step or category management, When I add a category with my own name and type, Then it appears and behaves identically to a suggested one in every list, split, and report.

---

**US-006 — Create and manage multiple savings categories** · P1 · MUST · FR-01a, FR-01b

> As P1, I want several separate savings categories, so that each goal is visible on its own.

- Given setup is complete, When I add several savings categories, Then each shows its own balance and settings.
- Given an existing category, When I rename it, Then the new name shows everywhere, including next to past entries.
- Given a category I no longer use, When I archive it, Then it leaves the pickers and dashboard but its history remains readable, and the change survives an app restart.

---

**US-007 — Set each category's share** · P1 · MUST · FR-02 · **CRITICAL** · *flag → F-03*

> As P1, I want each category to receive a fixed share of its group's money, so that the split
> happens by rule and not by mood.

- Given the percentage step for a group, When the group's percentages total exactly 100, Then I can save; when they do not, Then the difference is shown and saving is blocked.
- Given saved percentages, When I log income, Then the preview shows each category receiving its share of its group's amount, before any ceiling effects.
- **Failure:** Given I remove or archive a category with a non-zero share, When its share becomes unassigned, Then the app requires the group to be rebalanced to exactly 100 before the removal is final — it never leaves a group silently under-allocated.

---

**US-008 — Keep spending and savings visibly separate** · P1 · MUST · FR-05

> As P1, I want spending money and savings kept apart, so that money set aside never looks
> spendable.

- Given any list, picker, dashboard section or report, When categories are shown, Then spending and savings appear as separate groups, and no total combines them without naming that it does.

---

**US-009 — Business categories exist and stay business** · P2 · MUST · FR-07a

> As P2, I want a business group with its own categories — inventory restock and advertising among
> the suggestions — so that business money has named destinations of its own.

- Given business scope is enabled, When I reach the category step, Then the business group shows its own suggested categories, including inventory purchases and advertising.
- Given the business group, When I add, rename or remove its categories, Then it behaves exactly as the personal groups do.

---

**US-010 — Business and personal can never cross** · P2 · MUST · FR-07b, NFR-03 · **failure-style by nature**

> As P2, I want it to be impossible to file household activity against business categories or the
> reverse, so that a distracted moment cannot mix the two.

- Given a personal spending entry, When I open the category picker, Then no business category is offered through any path.
- Given a business spending entry, When I open the category picker, Then no personal category is offered.
- Given any screen showing personal totals, When business activity exists, Then the personal totals are identical to what they would be with no business activity at all.

---

**US-011 — Say which account holds what** · P1 · MUST · FR-03 · *flag → OQ-02, F-08*

> As P1, I want to record which real account holds each category's money, so that I always know
> where the money physically sits.

- Given account management, When I create an account with a name, Then I can link categories to it.
- Given linked categories, When I view the account, Then it shows the total of its linked categories' balances, and that total equals the sum of those balances as shown on the dashboard.
- Given any account screen, When I read it, Then nothing suggests the app is connected to a real bank.

---

**US-012 — Keep the business float in its own account** · P2 · MUST · FR-03, NFR-03

> As P2, I want business categories linked to my business account, so that the float is visibly not
> household money.

- Given a business account, When I link the business categories to it, Then its displayed total covers exactly those categories, and no personal category can be linked into a mixed total without the account showing both by name.

### 5.2 Income and allocation

---

**US-013 — Log an income event** · P1 · MUST · FR-04a · **CRITICAL**

> As P1, I want to record money the moment it arrives, so that it is captured before life moves on.

- Given the dashboard, When I choose to add income, Then I can enter an amount, a source label and a date (defaulting to today), with nothing else required.
- Given a valid amount, When I proceed, Then I see the full allocation preview before anything is recorded.
- **Failure:** Given an amount of zero, a negative amount, or non-numeric input, When I try to proceed, Then the entry is refused with the reason stated, and nothing is recorded.

---

**US-014 — The split happens by itself, exactly** · P1 · MUST · FR-04b, NFR-05 · **CRITICAL**

> As P1, I want each payment split across my categories by my rules, so that saving happens before
> spending can eat it.

- Given my configured percentages, When I enter an amount, Then the preview lists every receiving category and its amount, and the amounts visibly total exactly the amount I entered.
- Given the preview, When I confirm, Then the dashboard shows every category increased by exactly the previewed amounts.
- **Failure — smallest money:** Given an income of exactly one minor unit (one cent, one paisa), When previewed and confirmed, Then exactly one category receives it and the total still matches.
- **Failure — awkward split:** Given an amount my percentages cannot divide evenly, When previewed, Then the amounts still total exactly what I entered, with no unit lost or invented.
- **Failure — very large:** Given an amount at the app's stated maximum, When previewed and confirmed, Then the total still matches exactly; given an amount above the maximum, Then it is refused with the limit stated.
- **Failure — stale rules:** Given I changed percentages after opening the income form, When I reach the preview, Then the preview reflects the rules that will actually be applied, and confirming records those same figures.

---

**US-015 — Business revenue lands in business buckets** · P2 · MUST · FR-04b, FR-06 · *flag → F-10*

> As P2, I want sale proceeds split so the business share is set aside at the moment of the sale,
> so that restock money exists before I can mistake revenue for profit.

- Given business scope is enabled, When I log income, Then the preview shows the business group receiving its share, split across the business categories by their percentages.
- Given the preview, When a business category is full, Then its overflow follows the same visible redirect rules as any other category.

---

**US-016 — Adjust one payment's split by hand** · P1 · MUST · FR-12 · **CRITICAL**

> As P1, I want to override the suggested split for a single payment, so that a special situation
> does not require changing my standing rules.

- Given the allocation preview, When I change one category's amount, Then the remaining categories adjust so the total still equals the payment exactly, and it is visible which amounts I set and which the app computed.
- Given an override, When I confirm, Then only this event is affected — the next income event previews by my standing rules, unchanged.
- **Failure — does not total:** Given overridden amounts that total more or less than the payment, When I try to confirm, Then confirmation is impossible and the difference is shown in place.
- **Failure — negative:** Given a negative amount for any category, When entered, Then it is refused on the spot.
- **Failure — over-assignment:** Given overrides that alone exceed the payment, When entered, Then the excess is named and confirmation stays blocked until resolved.

---

**US-017 — Undo a mistaken income event** · P1 · MUST · OQ-09 default, INV-03 · *no parent FR — priority MUST because mis-entry is certain in a manual-entry app and journey FJ-3 depends on it* · *flag → OQ-09*

> As P1, I want to undo an income event I got wrong, so that a typo does not poison my balances.

- Given a confirmed income event, When I choose undo and confirm, Then every affected category returns to exactly its prior balance.
- Given the undo completed, When I open history, Then both the original event and its reversal are visible, clearly paired — the original does not vanish.
- **Failure:** Given an event already undone, When I try to undo it again, Then the app refuses and points at the existing reversal.

### 5.3 Ceilings, types and redirects

---

**US-018 — Give a goal a ceiling** · P1 · MUST · FR-10a · **CRITICAL**

> As P1, I want to set a target amount on a savings category, so that the app knows when that goal
> is done.

- Given an accumulating category, When I set a ceiling, Then the dashboard shows progress toward it.
- Given ceiling setup, When I set one, Then I choose (or confirm) where money should go once this category is full.
- **Failure:** Given a ceiling of zero or a negative amount, When I try to save it, Then it is refused with the reason stated.

---

**US-019 — Overflow goes where I said, visibly** · P1 · MUST · FR-10b · **CRITICAL**

> As P1, I want money beyond a full category to flow to the category I named, so that finishing one
> goal automatically accelerates the next.

- Given a category near its ceiling, When income would push it past, Then the preview shows: the amount it would have received, the amount it accepts, the surplus, and the named category the surplus goes to — with the overall total still equal to the payment.
- Given the confirmed event, When I open the receiving category, Then the redirected amount is attributed as coming from the full category by name.
- **Failure — already full:** Given a category already at its ceiling before the income arrives, When previewed, Then it accepts nothing, its entire share moves on visibly, and nothing is silently withheld.
- **Failure — target also full:** see interaction case I-3 in §5.6.

---

**US-020 — Fixed bills are their own kind of category** · P1 · MUST · FR-11a · **CRITICAL**

> As P1, I want bill categories that only need their bill amount each period, so that bill money is
> funded and never over-hoarded.

- Given category setup, When I mark a category as a fixed recurring bill, Then I state its per-period amount and its day of the month, and the category displays as a bill, distinct from savings goals.
- **Failure:** Given a bill category with no amount, or a day outside the month, When I try to save, Then it is refused with the field named.

---

**US-021 — Bills stop collecting once funded** · P1 · MUST · FR-11b · **CRITICAL**

> As P1, I want a funded bill to pass further money along, so that my internet bill never
> accumulates three months of money it does not need.

- Given a bill category partly funded this period, When income arrives, Then it accepts only up to its remaining bill amount and the rest visibly moves on.
- **Failure — already funded:** see interaction case I-2 in §5.6.

---

**US-022 — Spending from a goal reopens room** · P1 · MUST · IMP-07 · **CRITICAL** · *flag → F-09*

> As P1, I want a reserve I have spent from to refill on later income, so that using a reserve for
> its purpose is not punished.

- Given a full category with a ceiling, When I record spending from it, Then its balance drops below the ceiling, and the next income event allocates to it again up to the ceiling.
- **Failure:** Given the same category, When the next income arrives, Then it never refills past the ceiling — the surplus follows its redirect as always.

### 5.4 Seeing and spending the money

---

**US-023 — A dashboard I can trust at a glance** · P1 · MUST · FR-13 · **CRITICAL** · *flag → F-05*

> As P1, I want every category's current balance against its target on one screen, so that opening
> the app answers "where am I?" in seconds.

- Given recorded events, When I open the dashboard, Then every category shows its balance, and each figure equals what its own history adds up to — checkable by opening the category and summing its entries.
- Given I confirm an income event or a spend, When I return to the dashboard, Then the figures already reflect it without restarting or refreshing the app.
- Given a category with a ceiling, When shown, Then its progress toward the ceiling is visible, and it never reads as complete before the balance actually equals the ceiling.
- **Failure:** Given an undo, When completed, Then the dashboard figures return to exactly their prior values.

---

**US-024 — Record spending quickly** · P1 · MUST · implied by FR-05 and journeys J1-C/J2 · *flag → F-13 (no explicit FR authorises spend recording)*

> As P1, I want to log a spend in seconds, so that recording happens at the till and not from
> memory at midnight.

- Given the dashboard, When I add a spend with an amount and a category, Then the category's balance falls by exactly that amount, and the entry appears in history with its date and my note.
- Given the category picker, When it opens, Then my most recently used categories are offered first.

---

**US-025 — Spending more than a category holds** · P1 · MUST · OQ-06 default · *flag → OQ-06*

> As P1, I want to record what I truly spent even when the envelope is short, so that the app
> reflects reality rather than blocking it.

- Given a spend larger than the category's balance, When I record it, Then the app warns me plainly that the category goes negative, records it anyway on my confirmation, and shows the negative balance distinctly on the dashboard.

---

**US-026 — History that never lies** · P1 · MUST · FR-05, INV-03

> As P1, I want every past movement inspectable, so that I can always reconstruct where money went.

- Given history, When I filter by date range, category, group or account, Then the filtered totals match what the dashboard and reports say for the same selection.
- Given a corrected entry, When I view history, Then the original and its correction are both visible and paired — nothing is ever edited in place or disappears.

### 5.5 Sync, offline and data ownership

---

**US-027 — Works entirely without internet** · P1 · MUST · FR-15a, NFR-02

> As P1, I want everything to work with no connection and no account, so that my budget never
> depends on anyone's server.

- Given a phone with no connectivity and no Google account linked, When I complete setup, log income, override, spend and read reports, Then every one of those completes normally.
- Given no account is linked, When I use the app over weeks, Then nothing nags beyond a quiet indication that data lives on this device only, with a backup option attached.

---

**US-028 — My data goes only to my own Google account** · P1 · MUST · FR-09a, FR-09b, NFR-01

> As P1, I want cloud backup that is mine alone, so that no company — including the developer — can
> read my finances.

- Given Settings, When I choose to enable sync, Then the only sign-in offered is my own Google account, and the app states in plain words where the data goes and that the developer cannot read it.
- Given the whole app, When I look for one, Then there is no developer account, no registration, and no service of the developer's to subscribe to.

---

**US-029 — A second device just works** · P1 · MUST · FR-09c, FR-15b · **CRITICAL**

> As P1, I want a new phone to receive everything, so that my history is never captive to one
> device.

- Given a new device and the same Google account, When I sign in during setup, Then the app finds my existing data and offers to restore it before asking me to configure anything.
- Given the restore completes, When I compare devices, Then balances, categories, accounts and history match exactly.
- **Failure:** Given each device recorded different events while offline, When both sync, Then every event from both devices is present on both, none lost and none doubled.

---

**US-030 — Conflicting edits resolve the same way everywhere** · P1 · MUST · IMP-11 · **CRITICAL**

> As P1, I want simultaneous edits from two devices to settle consistently, so that my devices
> never disagree.

- Given the same category renamed differently on two offline devices, When both sync, Then both devices end up showing the same single winner, and no crash, duplicate or loss occurs.
- **Failure:** Given a category deleted on one device and edited on the other, When both sync, Then both devices agree on the outcome and the recorded money movements of that category remain readable in history either way.

---

**US-031 — The cloud copy vanishing is not the end** · P1 · MUST · IMP-12

> As P1, I want the app to survive its cloud data being wiped, so that one action in Google
> settings cannot destroy my phone's records.

- Given the app's cloud data was removed from my Google account, When the app next syncs, Then my local data is untouched, the situation is explained in plain words, and one action re-uploads.

---

**US-032 — A backup I hold in my hand** · P1 · MUST · NFR-07a · **CRITICAL**

> As P1, I want to export a complete backup file and restore from it, so that my data survives even
> with sync switched off.

- Given Settings, When I export a backup, Then I get a single file, saved or shared wherever I choose, with no network needed.
- Given a fresh install, When I restore that file, Then every balance, category, account and history entry matches the original exactly.
- **Failure:** Given a backup made by a newer app version, or made with a different currency, When I try to restore it, Then the restore is refused with a plain explanation — never partially applied.

### 5.6 The four interaction cases — explicit expected behaviour

Required by 1.3.4: the interactions of FR-10, FR-11 and FR-12 are where defects live, so each has a
stated behaviour no implementer may guess at.

**I-1 — A manual override pushes a category past its ceiling.**
Permitted. The preview shows a plain warning that this exceeds the target; the amount stays where
the user put it and is **not** redirected away — the user's explicit instruction outranks the
standing rule for this one event. The category then shows over-target on the dashboard, and at the
next income event it accepts nothing and redirects its whole share until spending brings it back
under. *(Story anchor: US-016, US-022.)*

**I-2 — A fixed-recurring category is already funded when income arrives.**
It accepts exactly zero. The preview lists it with "already funded for this period" as the stated
reason, shows its whole share moving to its redirect target by name, and the total still equals the
payment. It never quietly absorbs a partial amount. *(Story anchor: US-021.)*

**I-3 — A redirect target is itself full.**
The surplus continues along the target's own redirect, hop by hop, and the preview shows every hop:
each category named, the amount it accepted, the amount passed on. The user never sees money leave
category A and simply appear in category D unexplained. *(Story anchor: US-019.)*

**I-4 — A chain ends at the sink.**
When everything along the path is full, the remainder lands in the always-open catch-all category,
and the preview says so in those terms: named category, stated reason ("everything else on the path
was full"), exact amount. The sink is presented as part of the user's own configuration — visible,
renameable, but always present. *(Story anchor: US-019, sink per OQ-07.)*

### 5.7 Coverage table — FR to stories

| FR | Stories | Covered |
|---|---|---|
| FR-01 | US-006 | ✅ |
| FR-02 | US-007 | ✅ |
| FR-03 | US-011, US-012 | ✅ |
| FR-04 | US-013, US-014, US-015 | ✅ |
| FR-05 | US-008, US-024, US-026 | ✅ |
| FR-06 | US-001, US-015 | ✅ |
| FR-07 | US-009, US-010 | ✅ |
| FR-08 | US-003, US-004, US-005 | ✅ |
| FR-09 | US-028, US-029 | ✅ |
| FR-10 | US-018, US-019 (+ I-1, I-3, I-4) | ✅ |
| FR-11 | US-020, US-021 (+ I-2) | ✅ |
| FR-12 | US-016 (+ I-1) | ✅ |
| FR-13 | US-023 | ✅ |
| FR-14 | US-033…US-037 (§5.8) | ✅ |
| FR-15 | US-027, US-029, US-030 | ✅ |

Non-FR CRITICAL items: NFR-05 → US-014; NFR-07a → US-032; IMP-07 → US-022; IMP-11 → US-030.
IMP-12 → US-031. No FR is uncovered.

### 5.8 Reports and export stories

---

**US-033 — Monthly summary** · P1 · SHOULD · FR-14a · **CRITICAL**

> As P1, I want a monthly review, so that I can see whether the plan worked last month.

- Given a month with activity, When I open its summary, Then I see income, per-group allocation, per-category spend, and each category's opening and closing balance — and opening plus the month's movements equals closing, exactly, for every category.
- Given redirects occurred, When I read the summary, Then it shows how much was redirected and where it went.
- **Failure:** Given a month with no activity, When opened, Then it shows zeros plainly — never a hidden month and never an invented figure.

---

**US-034 — Yearly summary** · P1 · SHOULD · FR-14b · **CRITICAL**

- Given a year of data, When I open the yearly summary, Then its totals equal the sum of its twelve monthly summaries, and month-to-month comparison is visible.
- **Failure:** Given my percentages changed mid-year, When I compare months, Then the summary shows that the rules changed between them, and no past month's figures have shifted.

---

**US-035 — Category trends** · P1 · SHOULD · FR-14c

- Given a category and a chosen period, When I view its trend, Then the chart reflects the same figures its history shows, and a readable table of the same numbers is available.

---

**US-036 — CSV export** · P1 · SHOULD · FR-14d · **CRITICAL**

> As P1, I want my records out of the app in a spreadsheet-readable file, so that my data is mine.

- Given any scope and date range, When I export CSV, Then opening it in a spreadsheet shows rows whose totals equal the in-app report for the same scope and range, exactly.
- **Failure:** Given category names containing commas, quotation marks or line breaks, When exported and opened in a spreadsheet, Then every row survives intact with its columns aligned.
- **Failure:** Given no network, When I export, Then it works identically.

---

**US-037 — Business records exportable on their own** · P2 · SHOULD · FR-14d, OQ-10 default · *flag → OQ-10*

- Given business scope, When I export with the business-only scope, Then the file contains only business activity, suitable for handing to an accountant, and its totals match the business report for the same range.

### 5.9 Flags raised while writing criteria (to 1.7)

Stories whose criteria could not be written without leaning on an unresolved question:

| Story | Rests on | Status |
|---|---|---|
| US-002 | F-11 — personal-only scope: hidden group vs zero share | flagged in 1.2 |
| US-007 | F-03 — percentage of income vs percentage of group | flagged in 1.1 |
| US-011 | OQ-02, F-08 — account semantics and cardinality | registered / flagged |
| US-015 | F-10 — does business revenue follow the same three-way split | flagged in 1.1 |
| US-017 | OQ-09 — reversal semantics | registered, default assumed |
| US-022 | F-09 — spending reopens headroom | flagged in 1.1, seed notes imply yes |
| US-023 | F-05 — meaning of "real-time" | flagged in 1.1 |
| US-024 | **F-13 (new)** — no FR explicitly authorises recording a spend; implied by FR-05's "track" and by every journey | new flag |
| US-025 | OQ-06 — negative balances | registered, default assumed |
| US-037 | OQ-10 — business export shape | registered, default assumed |

**F-13 is new from this substage:** the requirement inventory contains no explicit "log a spending
transaction" statement — FR-04 covers income only. Spending entry is load-bearing for FR-05, FR-13
(balances must fall), FR-14 and both primary journeys, so it is treated as MUST via FR-05, and 1.7
must confirm that reading.

---

## 6. Non-functional requirements

Written in substage 1.5. Every requirement below carries either a **number** or a **binary
observable condition**, plus the stage and artefact that verifies it. Where the manifest's target
was directional, it is sharpened here and the sharpening is marked **↑**. No target is stated that
there is no intention of measuring.

### 6.1 NFR-01 — No user financial data leaves the user's own Google account

**Manifest target:** zero outbound requests to any host not owned by Google as the user's storage
provider; verified by network capture during QA.

**↑ Sharpened:**

- Outbound requests **originating from the app process** reach only Google authentication and Drive
  endpoints. Requests made by the operating system, the launcher or the store are out of scope and
  the capture must distinguish them.
- The permitted destination set is enumerated at S07.10 and frozen; any host outside it is a defect,
  not a judgement call.
- The resolved dependency tree contains **zero** analytics, crash-reporting, advertising or
  telemetry packages — checked transitively, not just among direct dependencies.
- A full-session verbose log contains **zero** monetary amounts, category names or account labels.
- **No developer-operated backend, proxy, relay or metrics endpoint exists.** This is binary and
  permanent.

**Verified in:** S07.10 (development build) and S09.7 (release build).
**Artefacts:** traffic capture evidence, `docs/PRIVACY_SOURCE.md`, the CI telemetry guard, the
log-content check.

### 6.2 NFR-02 — Fully functional offline

**Manifest target:** 100% of core flows completable with no network and with no Google account
linked.

**↑ Sharpened — "core flows" is enumerated here so Stage 9 does not get to decide what counts.**
All eleven must complete with the device in airplane mode and no account ever linked:

1. Complete onboarding from first launch to dashboard
2. Add income and see the allocation preview
3. Manually override a preview and confirm it
4. Undo a confirmed income event
5. Record a spend
6. Correct a recorded spend
7. Create, edit, archive a category
8. Change percentages, ceilings and redirect targets
9. Create and edit an account
10. Read the dashboard, history and every report
11. Export CSV and export a full backup

**Additional binary conditions:**

- No user-initiated action anywhere in the app awaits a network call. Verified with the network
  stalled indefinitely, not merely disabled — a stalled connection is the case that exposes a
  blocking await.
- Launch never awaits authentication. A failed silent re-auth starts the app in local-only mode.
- No modal, spinner or dialog related to sync ever blocks the UI.

**Verified in:** S06.12 (offline run of every flow), S09.3 (manual checklist), S10.8.5 (clean device
that has never had network access, on the shipping artefact).
**Artefacts:** `STAGE_6_REPORT.md` offline evidence, `MANUAL_TEST_CHECKLIST.md`, `STAGE_10_REPORT.md`.

#### What the user sees when there is no network or no account

- **Never signed in:** a quiet, permanent indicator that data lives on this device only, with a
  backup action attached to it. Stated as a fact with a remedy, never as an error, never in a
  warning colour, and never as a repeating prompt. It is not a nag: it appears in one place and does
  not interrupt.
- **Signed in, currently offline:** the sync surface shows the last successful sync time and the
  count of changes waiting. Nothing else changes; the app behaves identically.
- **Signed in, sync failing repeatedly:** the surface changes to indicate attention is needed and
  names the reason in plain language. It still does not block anything.

### 6.3 NFR-03 — Personal and business separation

**Manifest target:** business data never appears in personal totals; distinct visual treatment;
separate report scopes.

**↑ Sharpened:**

- **Binary:** for any screen, the personal figures shown when business activity exists are
  identical to the figures that would be shown if no business activity existed at all.
- Any figure combining scopes is labelled as combined, in text, on the same screen.
- The visual distinction survives greyscale and does not rely on colour alone (this is also an
  NFR-08 condition).
- Category pickers are scope-filtered: no business category is reachable from a personal spending
  flow through any path, and the reverse.
- A personal-only user sees zero business surface: no empty group, no disabled menu entry, no dead
  navigation.

**Verified in:** S06.10 (cross-screen scope test that walks every screen asserting no unlabelled
mixed figure), S08.1 (scope separation at the query level), S08.2 (separate report scopes).
**Artefacts:** the cross-screen scope test, `STAGE_6_REPORT.md`, `STAGE_8_REPORT.md`.

### 6.4 NFR-04 — Usable by someone who has never budgeted

**Manifest target:** a first-time user completes onboarding and their first income split unaided in
under 5 minutes.

**↑ Sharpened:**

- Setup accepting every default: **≤ 120 s** (this is R-06's mitigation target).
- Setup plus a first confirmed income event: **≤ 300 s**, the NFR-04 figure.
- Every screen on the default-accepting path arrives already valid and requires **exactly one tap**
  to accept. This is the structural condition that makes the timing achievable — §2.7 derives it.
- No screen on the default path requires the user to perform arithmetic.
- "Unaided" means: no explanation from the observer, no documentation, no prior exposure to the app.

**Measurement, and an honesty problem — see ESC-1.5-A.** The primary evidence is at least three
observed first-time users who have never used a budgeting app, median ≤ 300 s, none exceeding 480 s.
If naive observers cannot be recruited, the fallback is the developer-timed default path (S06.3.7,
S06.12.9), which measures *mechanical* duration only and is explicitly weaker evidence — it cannot
detect hesitation, misreading or abandonment, which are the failure modes NFR-04 exists to catch.
The fallback must be labelled as such in the test report rather than presented as satisfying the NFR.

**Verified in:** S06.3.7 and S06.12.9 (timed path), S09.3 (usability observations during manual
testing).
**Artefacts:** `STAGE_6_REPORT.md` timing record, `TEST_REPORT.md` usability section.

### 6.5 NFR-05 — Financial correctness over convenience

**Manifest target:** no rounding drift; for every income event the sum of allocations equals the
input exactly, proven by property-based tests over randomised inputs.

**↑ Sharpened:**

- **Zero** discrepancy is the only acceptable result. A one-minor-unit difference is a defect, never
  "rounding".
- Property P1 (conservation) holds over **≥ 3,000** generated cases per CI run, with the seed
  recorded so any failure reproduces.
- The global identity holds across an entire generated multi-year history: the sum of all category
  balances equals total income minus total spending, exactly.
- Per-event conservation holds for **every** event in that history, not a sample.
- The audit is performed by a script written independently of the app's own aggregation code —
  reusing it would only prove the code agrees with itself.
- **Zero** unjustified `double`, `float` or `num` on the money path, enforced by a CI guard that has
  been demonstrated failing on a deliberate violation.

**Verified in:** S05.9 (property tests), S09.4 (independent reconciliation audit), S10.6.6 and
S10.8.2 (re-run against release-build data).
**Artefacts:** `tool/reconcile.dart`, property test seed record, the money-path CI guard.

### 6.6 NFR-06 — Responsive on mid-tier Android hardware

**Manifest target:** cold start under 2.5 s, dashboard scroll without dropped frames on roughly a
4 GB-RAM mid-range phone, allocation across 100 categories under 50 ms.

**↑ Sharpened into a full budget table.** Every figure is measured on the reference device with the
five-year heavy dataset (§7) loaded — not on an empty database, and not on a flagship.

| # | Operation | Budget | Measured at |
|---|---|---|---|
| P-01 | Cold start to interactive dashboard | p50 ≤ 1.8 s, **p95 ≤ 2.5 s** | S09.6 |
| P-02 | Warm start (process alive) | ≤ 800 ms | S09.6 |
| P-03 | Dashboard first meaningful paint | ≤ 400 ms | S09.6 |
| P-04 | Dashboard and history scroll | **zero** frames over 16.7 ms across a 5-second scroll | S09.6 |
| P-05 | Allocation engine, 100 categories | **≤ 50 ms** (manifest figure) | S05.10 |
| P-06 | Allocation engine, pathological — 100 categories all at ceiling chaining to sink | ≤ 100 ms | S05.10 |
| P-07 | Keystroke to updated preview, 40 categories | p95 ≤ 100 ms | S06.4, S09.6 |
| P-08 | Monthly report generation | ≤ 1 s | S08.1, S09.6 |
| P-09 | Yearly report generation | ≤ 2 s | S08.1, S09.6 |
| P-10 | Full-history CSV export | ≤ 5 s | S08.5, S09.6 |
| P-11 | Full JSON backup export | ≤ 5 s | S04.9, S09.6 |
| P-12 | New-device sync bootstrap | ≤ 30 s | S07.8, S09.6 |
| P-13 | Balance recompute-and-compare, all categories | ≤ 2 s | S04.6, S09.6 |
| P-14 | Memory across 100 navigation cycles | no upward trend attributable to a leak | S09.6 |

**Reference device class:** a phone with approximately 4 GB RAM and a mid-range SoC (Snapdragon
6-series, Dimensity 700-series, Helio G-series or equivalent), released within roughly three years
of the measurement date. Stage 9 records the exact device used. Measuring on a flagship and
reporting it as representative is prohibited.

**Verified in:** S05.10 (engine benchmarks), S08.1 (aggregation benchmarks), S09.6 (all figures on
device).
**Artefacts:** `STAGE_5_REPORT.md` benchmarks, `TEST_REPORT.md` performance section naming the device.

### 6.7 NFR-07 — Durability and recoverability

**Manifest target:** full JSON/CSV backup at any time; migrations tested against fixtures from every
prior schema version.

**↑ Sharpened:**

- Export is available at any moment, works offline, and requires no account.
- Export → wipe → restore reproduces **byte-identical** balances and ledger contents.
- Export includes tombstones and sync metadata, so a restore does not resurrect deleted records.
- Restore refuses a newer schema version and refuses a mismatched currency, each with a plain
  explanation, and applies **all or nothing** — never partially.
- An automatic pre-migration export is written before any migration runs.
- **Migration fixtures — the v1.0 caveat:** at version 1.0 there are no prior schema versions, so
  "fixtures from every prior version" is unfalsifiable at launch. The binding v1.0 condition is
  therefore: the migration framework exists, and a version-1 fixture database containing a reversal,
  a redirect and an archived category is committed. From v1.1 onward the fixture-per-prior-version
  rule binds absolutely.

**Verified in:** S04.9 (round-trip test, migration harness, v1 fixture), S08.6 (user-facing restore),
S09.3 (restore onto a fresh install as a manual case).
**Artefacts:** round-trip test, committed v1 fixture database, `EXPORT_FORMAT.md`.

### 6.8 NFR-08 — Accessibility

**Manifest target:** TalkBack labels on all interactive elements, minimum 48dp touch targets, 4.5:1
text contrast, layout intact at 200% font scale.

**↑ Sharpened:**

- **Binary:** the full primary journey — onboarding, add income, read the preview, confirm, check a
  balance — is completable with TalkBack and the screen covered. Evidenced by a step-by-step log.
- Every interactive element has a label that reads sensibly aloud. Mechanical labels that produce
  nonsense when spoken ("button button") count as failures.
- Money is announced as an amount, not as a digit sequence.
- Touch targets ≥ **48dp**, explicitly including the inline per-category edit controls in the
  allocation preview, which are the most likely to be undersized.
- Contrast ≥ **4.5:1** for body text and ≥ **3:1** for large text and UI component boundaries, in
  both light and dark themes, **measured** rather than judged by eye.
- Layout intact at **200%** font scale and maximum display size, on the smallest supported screen,
  with no clipped or overlapping text.
- **Zero** information conveyed by colour alone — specifically ceiling progress and the business
  scope distinction, both of which must survive greyscale.
- No focus traps in any dialog or multi-step flow; focus order follows reading order.
- The reduced-motion system setting is respected and nothing becomes unintelligible when it is on.

**Verified in:** S09.5 (accessibility pass on a physical device with TalkBack), S09.1 (golden tests
at 200% font scale in both themes).
**Artefacts:** `TEST_REPORT.md` accessibility section, golden images in four variants.

### 6.9 Sync, from the user's point of view

Not a separate NFR, but the user-facing half of NFR-02 and FR-09. Stated here because Stage 2 owes
the user these guarantees, not merely a converging algorithm.

**What the user should see:**

- **Same category edited on two devices:** one edit wins, both devices show the same winner, and the
  user is not asked to arbitrate. Silent divergence between devices is the failure being prevented.
- **A device offline for a month:** on reconnect everything catches up without intervention. Nothing
  the user recorded offline is lost, and nothing is duplicated.
- **A merge that had to adjust configuration** — a redirect target deleted on the other device, say —
  is recorded and shown in plain language. The user learns *that* their configuration changed and
  *why*.

**What the user must never see:**

- A spinner or dialog blocking the app while sync runs.
- Data changing with no explanation available anywhere.
- A raw provider error, an error code, or a stack trace.
- Any implication that sync is required for the app to work.

**Verified in:** S07.5, S07.6, S07.9, S07.11.
**Artefacts:** `SYNC.md` including the repair catalogue, convergence test results.

### 6.10 Privacy — the source text for the published policy

Written so Stage 10 can draft the published policy from this section without further research
(S07.10 expands it into `PRIVACY_SOURCE.md`; S10.3 publishes from that).

**What the app collects:** nothing beyond what the user types in. There is no account with the
developer, no registration, no profile, no usage data collection of any kind.

**What is stored, and where:**

| Data | Location | Who can read it |
|---|---|---|
| All financial records — income, allocations, spending, categories, accounts, settings | The device | The user |
| The same records, as a sync payload | A hidden application-data folder inside **the user's own Google Drive** | The user's Google account holder. Not the developer — the folder is not visible to or reachable by anyone else |
| Files the user explicitly exports | Wherever the user chose to save or share them | Whoever the user gives them to |

**What leaves the device, and only these:**

1. The sync payload, sent to the user's own Google Drive, only after the user opts in by signing in.
2. Authentication exchanges with Google's sign-in endpoints, needed to obtain permission to write to
   that folder.
3. Files the user deliberately exports, to the destination the user picks.

Nothing else. There is no third destination because there is no developer infrastructure to send
anything to.

**Permissions requested and why:**

- **Internet access** — solely to reach Google's authentication and Drive endpoints for sync. The
  app functions fully with this permission never exercised.
- **The narrowest Google Drive scope that permits app-private storage** — grants access only to the
  app's own hidden folder, not to the user's documents, photos or other Drive contents. The exact
  scope string and its current classification are recorded at S07.1.2.
- No location, contacts, camera, microphone, SMS or general storage permission is requested. Exports
  go through the system share sheet or a user-chosen destination.

**What the developer can see:** nothing. There is no server, no database, no log collection, no
crash reporting and no analytics on the developer's side. The developer cannot read a user's
financial data, cannot enumerate users, and cannot tell whether the app is being used.

**Third-party recipients:** none. Google is the user's chosen storage provider acting on the user's
behalf, not a party the developer shares data with.

**Retention and deletion:**

- Local data persists until the user deletes it or uninstalls the app.
- Remote data persists until the user deletes it. The user can wipe the app's hidden Drive data from
  their own Google account settings without involving the app, and the app handles that gracefully
  rather than treating it as deletion of their local records.
- Revoking the app's access from the Google account page stops all sync; local data is untouched and
  the app continues working.
- The precise deletion behaviour on sign-out and on explicit deletion is verified and documented at
  S09.7.6, because the published policy and the store declaration must both match it exactly.

**The operational consequence of this design, stated honestly:** with no analytics and no crash
reporting, the developer has no visibility into failures after release. The only feedback channel is
users getting in touch. This is a deliberate trade of operational insight for privacy, and S10.8.8
plans around it.

**Verified in:** S07.10, S09.7.
**Artefacts:** `PRIVACY_SOURCE.md`, `PRIVACY_POLICY.md`, traffic captures from both a development
and a release build.

### 6.11 NFR verification summary

| NFR | Target type | Verified in | Verifying artefact |
|---|---|---|---|
| NFR-01 | Binary — zero non-Google hosts, zero telemetry packages | S07.10, S09.7 | Traffic capture, CI telemetry guard, `PRIVACY_SOURCE.md` |
| NFR-02 | Binary — 11 named flows complete offline, unlinked | S06.12, S09.3, S10.8.5 | Offline test run, manual checklist |
| NFR-03 | Binary — personal totals unchanged by business activity | S06.10, S08.1, S08.2 | Cross-screen scope test |
| NFR-04 | ≤ 120 s setup, ≤ 300 s to first split | S06.3.7, S06.12.9, S09.3 | Timing record — see ESC-1.5-A |
| NFR-05 | Zero discrepancy, ≥ 3,000 property cases | S05.9, S09.4, S10.6.6 | `tool/reconcile.dart`, property seed |
| NFR-06 | 14 numeric budgets, P-01…P-14 | S05.10, S08.1, S09.6 | Benchmark table naming the device |
| NFR-07 | Byte-identical round-trip; framework + v1 fixture | S04.9, S08.6, S09.3 | Round-trip test, v1 fixture database |
| NFR-08 | TalkBack journey completable; 48dp / 4.5:1 / 200% | S09.5, S09.1 | Accessibility log, golden images |

Every NFR has a number or a binary condition, and every NFR names a stage and an artefact. No row is
empty.

---

## 7. Data volume and growth assumptions

Written in substage 1.5. Stage 2 sizes its indexes from this section, Stage 4 builds its synthetic
dataset generator from it, and Stages 8 and 9 reuse that generator. The figures are assumptions,
labelled as such — but they are the assumptions the design is entitled to rely on.

### 7.1 Per-user activity assumptions

| Variable | Light | Typical | Heavy | Stress (design headroom) |
|---|---|---|---|---|
| Active categories | 10 | 20 | 40 | 100 |
| Income events per month | 1 | 3 | 20 | 20 |
| Spending transactions per month | 30 | 60 | 200 | 200 |
| Profile | P1, single salary | P1 with side income | P2, business with frequent sales | Beyond any expected real user |

The manifest's ranges are categories 10–40, income events 1–20 per month, spending 30–200 per month.
Light/Typical/Heavy sit inside those ranges; **Stress** deliberately exceeds them, matching the
100-category figure NFR-06 benchmarks against, so the design has headroom above the worst real case.

### 7.2 The multiplier that actually drives growth

One income event does not create one row. It creates **one ledger entry per receiving category**,
plus one more for each redirect hop. A user with 40 categories generates 40-plus ledger rows from a
single salary.

**Ledger rows per income event ≈ N + H**, where N is the number of categories with a non-zero share
and H is the number of redirect hops in that event (assumed 2 for Light/Typical, 5 for Heavy/Stress
in steady state, when several categories sit at their ceilings).

This is the single most important sizing fact in the section: **the ledger grows with categories ×
income events, not with income events alone.** A user who doubles their category count doubles their
future row growth rate. Every index Stage 2 defines on the ledger must be chosen with that in mind,
and the allocation rows — not the spending rows — are the bulk of the table in every profile except
Light.

### 7.3 Five-year row counts

Five years = 60 months. A 2% reversal allowance is added, since a reversal writes a mirroring set of
entries.

| | Light | Typical | Heavy | Stress |
|---|---|---|---|---|
| Income events | 60 | 180 | 1,200 | 1,200 |
| Rows per income event (N + H) | 12 | 22 | 45 | 105 |
| **Allocation ledger rows** | 720 | 3,960 | 54,000 | 126,000 |
| Spending transactions | 1,800 | 3,600 | 12,000 | 12,000 |
| Reversal allowance (~2%) | ~50 | ~150 | ~1,300 | ~2,800 |
| **Total ledger rows at 5 years** | **≈ 2,600** | **≈ 7,700** | **≈ 67,000** | **≈ 141,000** |
| Allocation rows as a share of the ledger | 28% | 51% | 80% | **89%** |
| Configuration rows (categories, accounts, rule versions) | < 100 | < 200 | < 500 | < 1,000 |

**Design headroom target: 250,000 ledger rows.** Stage 4's synthetic generator should be capable of
producing that, and the Stage 9 performance figures should hold at the Heavy profile with the Stress
profile as a documented stretch.

### 7.4 What these counts mean for the design

**This is a small database.** Even the Stress profile is under 150,000 rows — trivial for SQLite
*provided the indexes match the queries*. The performance risk here is not data volume; it is a
missing index turning a 5 ms query into a full scan of 141,000 rows on a mid-tier phone, executed on
every dashboard render. That is why Stage 2 substage 2.4.3 requires every index to name the query it
serves.

**Storage estimates** — at roughly 350 bytes per ledger row including its identifiers, timestamps
and sync columns, plus approximately 35% for indexes:

| Profile | Ledger data | With indexes | Round figure |
|---|---|---|---|
| Typical | ~2.7 MB | ~3.6 MB | **< 5 MB** |
| Heavy | ~23 MB | ~31 MB | **~35 MB** |
| Stress | ~49 MB | ~66 MB | **~70 MB** |

**Remote payload** — the sync payload is more verbose than the stored rows, but compresses well
because identifiers and structure repeat. Estimated compressed size at the Heavy profile: **single-
digit megabytes**. This settles the IMP-13 concern (app data counts against the user's own Drive
quota) quantitatively: against a 15 GB free Drive allowance, the app's footprint is negligible even
for a heavy five-year user. Compaction (S07.8) exists to bound chunk growth, not because total size
is a threat.

**Consequences to carry forward:**

- Balance derivation by full scan is affordable at Typical but not at Heavy on every dashboard
  render — this is the quantitative basis for tension T-01 in §A.6.2 and makes the balance cache a
  Stage 2 decision with real numbers behind it, not a preference.
- Report aggregation over five years touches the whole ledger; the P-08 and P-09 budgets are set
  against the Heavy profile.
- The synthetic generator built at S04.10.7 must produce all four profiles, since S08 and S09 both
  reuse it.

### 7.5 Escalation from this substage

**ESC-1.5-A — NFR-04 is the only requirement that cannot be verified mechanically.**
Every other NFR reduces to a script, a capture, a measurement or a binary inspection. NFR-04's
target — "a first-time user completes onboarding and their first income split unaided in under 5
minutes" — requires a person who has never seen the app and who is not the developer. A
developer-timed run measures mechanical duration and cannot detect hesitation, misreading or
abandonment, which are precisely the failure modes NFR-04 exists to catch. Recorded, not resolved:
either naive observers are recruited before Stage 9, or the test report states plainly that NFR-04
rests on weaker evidence than every other NFR. This is a question for the user at the gate.

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
