# Session log — substages 4.4 to 4.7

The conversation that produced commits `2c34a1a` … `8a68090`, written down so the reasoning survives
the loss of the chat. Dates 2026-08-23 to 2026-08-28.

---

## How the session started

The instruction was: *"read, analyze and understand the code first, then go through the prompts,
then see which stages have been completed, then start working on it stage by stage continuing from
last completed stage. you may refer to git commits to get hint of stages completed."*

Orientation established that Stages 1–3 were through their gates and Stage 4 was complete through
**4.3**, plus an out-of-band design commit (`7d645a0`, ADR-006). So **4.4 was next**.

Partway through, the user added: *"also commit after each stage."* Every substage since has one
commit.

---

## The blocker, found immediately

Before writing anything, a check for the toolchain found **no Dart or Flutter SDK on the machine**.
`docs/ENVIRONMENT.md` records the SDK under a user profile (`Chichum`) that does not exist here.
There is no `.dart_tool/`, no pub cache, and `database.g.dart` has never been generated.

This was reported to the user before starting, and the user chose to continue. Consequently **every
substage from 4.4 onward is written but unverified**, marked 🟡 rather than ✅, with each acceptance
criterion recorded as *"not run"* rather than ticked. Full detail and the recovery sequence:
[`ENVIRONMENT_BLOCKER.md`](ENVIRONMENT_BLOCKER.md).

Static checks that need no toolchain were run by hand on every file and all pass. They reduce risk;
they are not a build.

---

## 4.4 — Repository interfaces and CRUD · `2c34a1a`

Eight domain interfaces (four in this substage) plus their Drift implementations and row↔entity
mappers. ~5,150 lines.

**Decisions and why they went that way:**

- **Repositories do not invent `SyncFields`.** Callers hand over a complete entity, stamp included.
  The HLC that orders concurrent edits is Stage 7's; a placeholder minted here would be a *second,
  wrong* source of ordering that Stage 7 would then have to detect and undo. The sole exception is
  soft delete — the only write a repository *originates* — which takes an injected `Clock`.
- **Mapper writes are total; the two originated writes are partial.** Every companion sets every
  column including explicit nulls, so switching a savings goal to an open envelope actually *clears*
  the ceiling. The tombstone and archive updates deliberately write only what they change, because
  there the repository knows exactly which fields it is touching.
- **Rejections throw (`RejectedWrite`) rather than return, so the transaction rolls back.** A
  rejection signalled by returning early only unwinds cleanly while nothing has been written — a
  property every future edit would have to preserve unprompted.
- **One `_rejectIfSealed` gate guards all six mutating rule paths** (INV-11). The failure mode is not
  "the check is wrong", it is "the eighth path forgot to call it".
- **Tombstone filtering is structural.** Every list read funnels through one private `_…Select` that
  applies the term unconditionally; `matchAll` exists so an unfiltered read takes the *same* code
  path as a filtered one.

**Judgement call:** `RedirectTarget` CRUD went into `CategoryRepository` rather than a seventh
interface. ADR-006 made a category's overflow behaviour a list of rows rather than a column, so
"edit this category" now spans two tables; splitting them would put two halves of one user action
behind two objects.

---

## 4.5 — Append-only ledger and transactional writes · `86d6f25`

**The core move:** `LedgerRepository` has no `update` and no `delete` — not "shouldn't", *doesn't*.
INV-03 enforced by absence, because absence is the only enforcement that cannot be forgotten under
deadline.

Five further mechanisms close the routes an interface cannot: no `copyWith` on `LedgerEntry`, one
insert-shaped companion, a single `ledger_writer.dart` chokepoint, constraint C-15, and
`insertOrIgnore`. `test/data/repositories/append_only_design_test.dart` asserts each route is shut,
and includes a self-test that its own scan would catch a violation.

**The subtlest decision — `insertOrIgnore`, never `insertOnConflictUpdate`.** An upsert would make a
retry carrying a different amount under the same id silently rewrite history: *an update path
wearing an insert's name*. Both halves are tested — a replay adds no rows, **and** does not change
the stored amount.

**Other decisions:**

- **Conservation is checked inside the write transaction** (INV-02), not trusted from the engine.
  This is the boundary where a computed split becomes rows that can never be edited, so it is the
  last free moment. A short write is not a partial record, it is a *permanently wrong* one.
- **Income writes seal their rule version in the same transaction**, with
  `WHERE ... AND sealed_at_ms IS NULL` — idempotent, and it keeps the *first* instant.
- **Reversal guards R-1/R-2 check stored state**, not what the caller believed; two devices can both
  decide to undo the same event. The link is written with `AND reversed_by_event_id IS NULL`, making
  R-1 atomic rather than merely checked.
- **`record()` throws when handed a reversal.** Routing one through it would skip both guards. This
  settled a rule applied consistently since: **caller-construction bugs throw; data-state conflicts
  return.**

**Judgement calls:** added `SpendingRepository`, a seventh interface `ARCHITECTURE.md` §2.2 does not
name — both alternative homes were worse. Considered and rejected a SQLite trigger on
`ledger_entries`: stronger than all six routes, but `SCHEMA.md` specifies no triggers and 4.3
transcribes it exactly, so it would need an ADR for a goal already met.

---

## 4.6 — Balance derivation and cache verification · `9fb427e`

**Found a real defect in `SCHEMA.md`.** The document describes `balance_cache` twice and the two
disagree: §7.1 defines the cheap verifier tier as comparing against `entry_count`; §3.12 declares no
such column. 4.3 transcribed §3.12 faithfully and the comparison table correctly reported no
divergence — neither section is wrong about itself. Only 4.6 has cause to read both.

Raised and amended rather than patched forward, as **[ADR-007](../decisions/ADR-007-balance-cache-entry-count.md)**.

The zero-schema-change alternative — compare `MAX(id)` against the existing `last_entry_id`, since
ledger ids are UUID v7 — was rejected as **weakest exactly where the risk is highest**: it cannot
detect an entry inserted with an *earlier* id, which is precisely what a sync merge produces, and
§7.1 says merges dominate this failure mode.

**Other decisions:**

- **The cache is folded in by `appendLedgerEntries` itself.** §7.1 demands no code path writes an
  entry without adjusting the cache atomically; the only way to make that true is to make it the
  same path. 4.5's chokepoint turned out to be the right home.
- **A replayed entry must not fold twice.** `insertOrIgnore` silently skips a duplicate, so
  incrementing regardless would let a retried sync push inflate every category it touched —
  corruption caused by the mechanism that exists to make retries safe. The writer asks before
  inserting.
- **`is_stale` is never cleared by an incremental update**, and a stale row is reported *as stale*
  rather than as a mismatch, so a known-bad row does not bury the real signal.
- **Derived and cached are separate methods.** A single "cache if fresh, else recompute" accessor
  would make the verifier unwritable — the comparison would compare the cache against itself.
- **`recomputeAll` takes no number from any caller**, which is what keeps it a recompute rather than
  the setter 4.6's `must_not` forbids.
- **Account totals join through `categories.linked_account_id`**, not `ledger_entries.account_id`.
  The two differ on purpose: the entry column is denormalised at write time so history survives a
  re-link, while an account's total is what it holds *now*.
- **`period.dart` derives `nextPeriod` from the instant after this period ends**, not by adding a
  month — adding a month to a *clamped* 28 Feb gives 28 Mar, and an anchor of 31 is lost permanently
  after one short month.

**Could not meet one criterion.** 4.6.6 requires a *recorded* derivation timing at five-year volume,
which requires running. The benchmark is written and prints its figure; the worklog cell is
deliberately left empty rather than filled with §7.1's estimate — that estimate is what 4.6.6 exists
to replace.

---

## 4.7 — Seed data, suggested categories and the sink · `8a68090`

**No default split is prescribed anywhere** in the PRD, manifest or SCHEMA, so the numbers were
chosen here. The substage names the trap: *"default percentages that total 9999 because of a
hand-computed split, which blocks onboarding"* — nine savings categories at a hand-written 1111
total exactly that.

So nothing is hand-computed. `distributeEvenly` spreads the remainder one basis point at a time
(largest-remainder, the same rule the engine uses), so totals are **exact by construction** and a
twentieth suggestion cannot break them. The test sweeps every part-count from 1 to 40.

**Ten of the nineteen suggestions cannot be stored without amounts the app cannot know** —
`ACCUMULATING_RESERVE` requires a ceiling (V-08), `FIXED_RECURRING` a bill and anchor day (V-18).
Resolution: obviously-provisional round figures, every row flagged `is_suggested_seed` with a
`seed_version`, which is exactly what 4.7.2 asks that flag for. Inventing a figure that *looked*
authoritative would have been worse than one that plainly wants changing. Amounts live in **major
units** and are scaled by the exponent, so the same seed set is correct in JPY and KWD.

**Three bugs found while writing it:**

1. **U-04 violation** — enabling business scope later minted a *second* unsealed rule version while
   the first was still a draft, which the partial unique index rejects, aborting the whole seed. Now
   it joins the existing draft; a new version is minted only when there is none, which is also
   correct when the old one has been sealed.
2. **An invalid settings insert** — the first draft created the `app_settings` row to hold
   `active_rule_version_id`. That row's currency is the one value that must never be guessed (V-24
   freezes it once money exists). The seeder now *requires* settings and refuses with
   `RecordNotFound`, which makes the onboarding ordering explicit rather than accidental.
3. Both settings updates now carry `AND <column> IS NULL`, so a re-run cannot drag a user back to an
   earlier sink or rule version.

**Two things deliberately not done:**

- **Deterministic (UUID v5) seed ids.** Two devices seeding offline produce 38 categories on merge;
  v5 would make it a no-op. Not done, because `ARCHITECTURE.md` §8.6 assigns v4 to configuration and
  this would be a unilateral amendment for a problem **Stage 7.8 already owns**. Recorded in
  [`TODO.md`](TODO.md) so 7.8 inherits it.
- **A reset-to-suggestions path.** 4.7.8 says *"if the design calls for one"*, and nothing does.
  Building a destructive action nobody asked for is inventing scope.

---

## Patterns worth carrying forward

Things that came up repeatedly and are now conventions:

1. **Enforce by absence where possible.** No update method beats a comment asking you not to update.
2. **Check inside the transaction, against stored state.** Not before it, and not against what the
   caller believed.
3. **Caller-construction bugs throw; data-state conflicts return a typed failure.**
4. **Compute rather than write down** anything that must sum exactly.
5. **A guard that has never failed has never been tested** — every scanning test carries a self-test.
6. **Read past the abstraction when testing the abstraction** — `rawRow`/`rawCount` exist for this.
7. **When two design documents disagree, that is a finding, not an inconvenience.** ADR it.
