# PookieBudget — open questions and ambiguity register

Built in substage 1.7. Every question carries: the question in plain language, why it matters, the
stage it blocks, the options with their consequences, and a **recommended default**. Answering
"go with your defaults" in one message is a complete answer to this document.

**OQ-01 to OQ-10** are carried from `00_project_manifest.json` unchanged in substance.
**OQ-11 to OQ-18** were raised during Stage 1.

**No question below requires any knowledge of Flutter, databases, sync or programming to answer.**

---

## Part 1 — BLOCKING: five questions needed before design starts

A question is blocking **only if the design genuinely cannot proceed without it**. Each of the five
below changes the shape of the stored data, which is the one thing that is expensive to change after
release. Everything else has been pushed to Part 2 and given a working default.

### B-1 (OQ-02) — Bank accounts: a note, or real bookkeeping?

**The question.** When you record that your Emergency fund's money "lives in" your savings account,
what do you want that to mean?

**Why it matters.** It is the difference between a small feature and roughly doubling the app.

| Option | What you get | What it costs |
|---|---|---|
| **A — a label (recommended)** | You tag categories with an account name. The app shows each account's expected total so you can eyeball it against your bank app. If they differ, that is information, not an error. | Nothing. Answers "which account holds what?" directly. |
| B — real balances | Accounts become a second set of books: money recorded per account, transfers between accounts, and reconciliation against statements. | Every income entry must ask which account it arrived in. Roughly twice the bookkeeping, and a second place for figures to disagree. |

**Recommended default: A.** B can be layered on later without undoing anything (§3.4 D-14).

### B-2 (OQ-03) — Is there a third kind of category?

**The question.** Two kinds are described in the brief: **goals** that fill up to a target (Emergency
fund), and **bills** that need a set amount each period (Internet). But Groceries is neither — no
target, no fixed bill, you just spend from it. Should there be a third kind, an **open envelope**,
for those?

**Why it matters.** Most spending categories are neither of the first two. Also, **six of the
nineteen suggested categories are already written as this third kind** — Groceries, Eating out,
Transport, Advertising, Shipping, Business miscellaneous. Saying no means giving all six a different
kind, and deciding what "full" means for Groceries.

- **Yes (recommended).** Open envelopes have no target and never overflow. Money flows in, you spend
  from it, and that is all.
- No. Every category must be a goal or a bill. Groceries needs an invented target.

**Recommended default: yes.**

### B-3 (OQ-07) — The catch-all category

**The question.** When a goal is full, its overflow goes to the category you named. But what if that
one is full too, and so is the next? Should the app keep one permanent catch-all — call it
*Unallocated buffer* — that you can rename and spend from, but cannot delete? And if you run a
business, a second one so overflowing business money stays in the business?

**Why it matters.** Without a category that can always accept money, overflow can have nowhere to
go, and the app's central promise — every unit lands somewhere — cannot be kept. This is the one
place where the app needs something you did not create yourself.

- **Yes to both (recommended).** One personal catch-all, always present, renameable, not deletable.
  A second for business when business is enabled.
- One only. Business overflow can land in a personal category — which breaks the separation P2 needs.
- None. Not available: the promise cannot be kept without it.

**Recommended default: yes to both.**

### B-4 (OQ-11) — What counts as income, and does it all split the same way?

**The question.** Two halves, one answer.
*(a)* Is "income" only your salary, or anything arriving — business sales, refunds, gifts, a loan
repaid to you?
*(b)* If you make a business sale, should it follow the same Spending / Savings / Business split as
your salary, or go entirely into business categories?

**Why it matters.** If different kinds of income split differently, the app must hold more than one
set of percentages at once and ask which applies every time you record money. That is a permanent
change to how the data is stored, not a setting.

- **Recommended: anything arriving is income, and all of it follows the same split.** You can still
  override any single payment by hand, so a sale that should go wholly to the business is one
  adjustment away.
- Separate rules per kind of income. More faithful for a business, but you maintain two or more sets
  of percentages and answer "what kind is this?" on every entry.

**Recommended default: one set of rules for all income, with per-payment override.**

### B-5 (OQ-12) — Do categories nest?

**The question.** The brief says the Business group has "sub-categories" such as inventory and
advertising. Does that just mean *categories that belong to the Business group*, or do you want real
folders — Advertising containing "Facebook ads" and "printed flyers", each with its own balance?

**Why it matters.** Real folders change how every list, every percentage and every report works, and
cannot be added later without rebuilding how categories are stored.

- **Flat (recommended).** Three groups; categories sit inside them. "Sub-category" in the brief means
  "a category inside the Business group".
- Nested. Categories inside categories, to any depth. Materially more app, and percentages must then
  work at every level.

**Recommended default: flat.** A place is reserved in the design so nesting stays possible later
(§3.4 D-03).

---

## Part 2 — NON-BLOCKING: answered by default, change any of them freely

Each has a working default already applied in the PRD and recorded as a numbered assumption in
`ASSUMPTIONS.md`. Design proceeds without your answer; say so if any default is wrong.

### From the manifest

**OQ-01 — Which currency, and can it change later?**
*Blocks: nothing.* The app stores your currency the same way whatever you choose.
**Default (A-01):** read from your phone's region at setup, changeable only while no money has been
recorded. After that it is fixed, because changing it would mean reinterpreting every past figure.

**OQ-04 — Should goals have a target *date*, not just a target amount?**
*Blocks: nothing — deferred.* Several suggested goals are deadline-driven (Eid savings, annual tax
reserve) and the app cannot currently tell you whether you are on track.
**Default (A-02):** not in version 1; a place is reserved so it can be added without disturbing your
data.

**OQ-05 — A bill category ends the month with money unspent. What happens?**
*Blocks: nothing — the design treats this as a setting.*
**Default (A-03):** it carries forward, and next period only tops up to the bill amount, so the
category never holds more than one bill's worth.

**OQ-06 — You spend more from a category than it holds. Block, warn, or allow?**
*Blocks: nothing.*
**Default (A-04):** allow, with a clear warning and the negative balance shown plainly. The app
should never stop you recording something that actually happened.

**OQ-08 — Should the cloud copy be protected by a passphrase you set?**
*Blocks: nothing — deferred.* It would protect you if your Google account were compromised, at the
cost of losing everything if you forget the passphrase.
**Default (A-05):** not in version 1; rely on your Google account's own security. A marker is
written into the cloud format from day one so this can be added later safely.

**OQ-09 — Can income events be undone, and how far back?**
*Blocks: nothing.*
**Default (A-06):** yes, any event, however old. The undo always appears in your history next to the
original rather than making it disappear.

**OQ-10 — Do you need business records exportable separately, for an accountant?**
*Blocks: nothing (Stage 8).*
**Default (A-07):** yes — a business-only export with date, category, amount, note and running
balance.

### Raised during Stage 1

**OQ-13 — Can one category's money sit in more than one account?**
*Blocks: nothing.*
**Default (A-08):** one category is linked to at most one account; one account can hold many
categories. Splitting a single goal across two accounts is not supported.

**OQ-14 — Is taking money out of a savings goal "spending"?**
*Blocks: nothing.* Paying a medical bill from your Medical reserve — is that an expense, or just
money moving out of a pot?
**Default (A-09):** it is recorded as spending, exactly like any other category, and shows in your
spending totals. The goal then refills from later income.

**OQ-15 — Should you be able to move money directly between categories?**
*Blocks: nothing — deferred.* Not in the brief, but people ask for it.
**Default (A-10):** not in version 1. It can be added later without disturbing existing data.

**OQ-16 — How hard should the app push you to make a backup?**
*Blocks: nothing.* This one has a real consequence, so it is worth your attention despite being
non-blocking: **if you never sign in and never export a backup, and you lose your phone, your data
is gone.** There is no other way to recover it — that is the price of the app having no server.
**Default (A-11):** say it once, plainly, during setup; then keep a permanent, quiet backup action
next to the "on this device only" indicator. No repeated nagging.
*Alternative if you prefer:* a periodic reminder after a set number of recorded events.

**OQ-17 — Can anyone who has never seen the app try the setup?**
*Blocks: nothing — but it decides how strong one piece of evidence is.* One requirement (setup plus
a first split in under five minutes, unaided) can only be truly tested by someone who has never used
the app and is not the person who built it. A self-timed run measures speed but cannot detect
confusion.
**Default (A-12):** if nobody is available, the self-timed figure is used and the test report states
plainly that this requirement rests on weaker evidence than the others.

**OQ-18 — Fourteen of fifteen features are marked "must have". Is that the plan?**
*Blocks: nothing — but it sets the schedule.* After a genuine attempt to cut scope, almost nothing
could be cut, because the brief itself marks nearly everything as required.
**Default (A-13):** proceed with all fourteen.
*If you would rather shorten the first release,* the two most cuttable are **bank account labels**
(the least load-bearing requirement, especially under B-1 option A) and **reports** (already marked
"should have"; could be reduced to CSV export alone for version 1).

---

## Part 3 — The blocking list, as five plain questions

For putting in front of the user at the gate. No jargon, answerable in a few minutes.

1. **Bank accounts** — should the app just *remember* which account holds which category and show
   you a total to compare against your bank app? Or should it properly track each account's balance,
   transfers between them, and reconcile against statements? *(Recommend: just remember and total.)*

2. **A third kind of category** — should there be an "open envelope" kind for things like Groceries,
   which have no target and no fixed bill? *(Recommend: yes. Six of the nineteen suggested
   categories already assume it exists.)*

3. **A catch-all** — should the app keep one permanent category that can always accept overflow,
   which you can rename and spend from but not delete, plus a second one for business?
   *(Recommend: yes to both. Without it, overflow can have nowhere to go.)*

4. **Income** — does everything arriving count as income (salary, business sales, refunds, gifts),
   and should it all follow the same split? *(Recommend: yes to both, with per-payment override
   available. Separate rules per income type is a permanent change to how data is stored.)*

5. **Nested categories** — does "sub-categories" in the brief mean real folders inside categories, or
   just categories that belong to the Business group? *(Recommend: no folders in version 1; a place
   is reserved so they remain possible later.)*

---

## Register summary

| | Count |
|---|---|
| Carried from the manifest | 10 (OQ-01…OQ-10) |
| Raised during Stage 1 | 8 (OQ-11…OQ-18) |
| **Total** | **18** |
| **Blocking Stage 2** | **5** — OQ-02, OQ-03, OQ-07, OQ-11, OQ-12 |
| Non-blocking, defaulted | 13 |
| Recommended default stated | 18 of 18 |

### Why some manifest questions are not on the blocking list

The manifest marks OQ-01, OQ-04, OQ-05, OQ-06 and OQ-09 as blocking Stage 1 or Stage 2. Substage
1.7 requires ruthlessness: a question blocks only if design cannot proceed. Each of those five was
re-examined and found not to block, with a specific reason:

| Question | Why design proceeds without the answer |
|---|---|
| OQ-01 currency | The data is stored identically under either answer; only a policy on changing it later differs. |
| OQ-04 target dates | Deferred with the accommodation already named (§3.4 D-01). |
| OQ-05 bill surplus | The design plan already requires this to be an input rather than a fixed rule (S05 substage 5.5.3), so both answers are accommodated. |
| OQ-06 negative balances | A display and warning policy; nothing stored changes. |
| OQ-09 reversibility | Reversal by opposing entry is already mandatory (INV-03). The question is only whether a time limit applies, and "no limit" is the simpler design. |

Each is defaulted and recorded as an assumption. If any default is wrong, say so — none is expensive
to change **before** Stage 2 completes.

### Ambiguities resolved without becoming questions

Six items flagged during substages 1.1 to 1.6 turned out to be answerable from the manifest or the
design itself, and were recorded as assumptions rather than padding this register: F-01
(double-registered requirements), F-02 (FR-01's loose use of "savings"), F-03 (percentages are
two-level — the manifest's own conventions say so), F-06 (FR-11's embedded rationale), F-09
(spending reopening headroom falls out of the headroom formulas), and E-02 (overrides must be stored
as event inputs — a design conclusion, not a user choice). See `ASSUMPTIONS.md` A-14 to A-25.
