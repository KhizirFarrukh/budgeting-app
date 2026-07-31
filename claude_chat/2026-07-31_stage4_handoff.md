# PookieBudget — session handoff (Stage 4 in progress)

**Written:** 2026-07-31 · **Branch:** `v1.0` · **Head:** `7d645a0`
**For:** a fresh agent picking this up cold. Read this top to bottom, then continue at
[§10 "What to do next"](#10-what-to-do-next). You do **not** need the old chat transcript to continue;
everything operative is here. If you want the raw transcript it is at
`C:\Users\Chichum\.claude\projects\c--Users-Chichum-Personal-Projects-budgeting-app\01c726a9-9b0e-42d9-bc92-75e41000ca16.jsonl`.

---

## 1. What this project is

**PookieBudget** — an Android/Flutter budgeting app, built by following a **pre-written 10-stage SDLC
plan** stored in `prompts/`. The plan is the source of truth for *what* to build and *in what order*;
it is not to be improvised around.

- **Stack:** Flutter 3.44.7 / Dart 3.12.2, Android-only, app id `com.khizirfarrukh.pookiebudget`.
- **Key deps:** Riverpod 3.3.2 (ADR-001), Drift 2.34.2 (ADR-003), Google Drive `appDataFolder` for
  sync (ADR-002), `uuid` 4.x (v7 for ledger/income rows, v4 for config — ARCHITECTURE §8.6).
- **Architecture:** four layers, `domain ← data ← application ← presentation`, layer-first directory
  structure. The dependency rule points inward only.

### The plan files (`prompts/`)
`00_project_manifest.json` + `stage_01…stage_10_*.json`. 98 substages, ~703 work steps, 465
acceptance criteria. Each substage JSON has: `goal`, `why_it_matters`, `entry_criteria`, `work`
(numbered steps), `acceptance_criteria`, `must_not`, `common_pitfalls`, `traceability`,
`definition_of_done`, `checkpoint`. **Read the substage JSON before working it** — the `must_not` and
`common_pitfalls` lists are where the real traps are named.

---

## 2. How the user works (operating rules — follow these)

These are established preferences. They also live in the auto-memory at
`C:\Users\Chichum\.claude\projects\c--Users-Chichum-Personal-Projects-budgeting-app\memory\`.

1. **Commit after each substage automatically — do not ask.** (memory: `commit-after-each-substage`)
2. **Git flow is `master → develop → v1.0`.** Work happens on `v1.0`. This **overrides** the
   manifest's `stage/<n>-<slug>` branch convention. (memory: `pookiebudget-git-flow`)
3. **Work autonomously within a stage; gate between stages.** The user says "continue" and expects
   steady progress. Stop for approval only at a **stage boundary** (or when a `checkpoint` in the JSON
   sets `requires_user_approval: true`, or an escalation trigger fires).
4. **The user sends short messages.** "continue", "conitnue", etc. Don't re-litigate settled
   decisions; act.
5. **Commit message style:** conventional-commit subject (`feat(scope): … (substage X.Y)`), a body
   explaining the *why* and any defect found, ending with:
   `Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>`.
   Write the message to a scratchpad file and `git commit -F <file>` — **PowerShell here-strings
   break on embedded quotes**, so never inline a multi-line `-m`.

### Verification discipline (hard-won — see §8)
- **The full check is one command:** `pwsh`-less invocation `& .\tool\check.ps1 -SkipBuild -SkipCoverage`
  (from PowerShell). It runs: pub get → codegen → format → analyze → guards G1–G6 → domain purity →
  tests. **Run this immediately before every commit, not before the last edit.**
- A **passing guard/check proves nothing until you've seen it fail** on a deliberate probe. Stage 3
  found guards G1 & G5 passing while matching *nothing*. New guards get negative-tested.
- **Never claim a state you didn't just verify.** (I once committed 4.2 with 48 analyzer issues
  because I ran `analyze` before adding a file, not after. Don't repeat that.)

---

## 3. Current repo state

```
Branch:  v1.0   (origin/v1.0 in sync at 7d645a0 — nothing to push)
master, develop exist; work is on v1.0.

Recent commits (newest first):
  7d645a0  feat(design): FR-16 ceiling-triggered cascade redirect (ADR-006)
  3fef4db  feat(data): thirteen-table schema transcribed from SCHEMA.md (substage 4.3)
  374b696  feat(domain): entities, enums and invalid-state prevention (substage 4.2)
  d2d17fd  feat(domain): Money, BasisPoints and real Clock/IdGenerator (substage 4.1)
  33d8d47  feat(scaffold): scaffold verification, reach Stage 3 gate (substage 3.9)
  … (3.1–3.8 below that)

Working tree: clean.
Tests: 206 passing (176 test() calls across files; groups add up to 206 cases).
Full check: ALL CHECKS PASSED (7 steps).
```

Note: I did not run `git push` this session, yet `origin/v1.0` shows `7d645a0`. The environment
appears to push (or mirror) automatically. **Verify with `git status` / `git rev-list --left-right
--count origin/v1.0...v1.0` before assuming a push is or isn't needed.**

---

## 4. Stages: where we are

| Stage | Status |
|---|---|
| 1 — Requirements & PRD | ✅ Complete, gate approved. Deliverables in `docs/` (PRD.md, etc.) |
| 2 — System Design & Architecture | ✅ Complete, gate approved. (ARCHITECTURE.md, SCHEMA.md, ALLOCATION_ALGORITHM.md, NAVIGATION.md, ADRs 001–005) |
| 3 — Project Scaffolding | ✅ Complete, gate reached & approved (9 substages) |
| **4 — Core Data Layer** | **🔶 IN PROGRESS — 4.1, 4.2, 4.3 done; 4.4 next** |
| 5–10 | Not started |

### Stage 4 substages (11 total)
| # | Name | Status |
|---|---|---|
| 4.1 | The Money type and core value types | ✅ done — `d2d17fd` |
| 4.2 | Domain entities, enums, invalid-state prevention | ✅ done — `374b696` (later amended by ADR-006) |
| 4.3 | Database schema definition and code generation | ✅ done — `3fef4db` (later amended by ADR-006) |
| — | **ADR-006 amendment** (FR-16 cascade redirect) | ✅ done — `7d645a0` |
| **4.4** | **Repository interfaces and CRUD** | **⬜ NEXT** |
| 4.5 | The append-only ledger and transactional writes | ⬜ |
| 4.6 | Balance derivation and cache verification | ⬜ |
| 4.7 | Seed data, suggested categories and the sink | ⬜ |
| 4.8 | Validators and cycle detection | ⬜ |
| 4.9 | Migrations, export and backup | ⬜ |
| 4.10 | Test suite and performance smoke test | ⬜ (domain+data coverage target 90%) |
| 4.11 | Documentation and gate preparation | ⬜ |

**Full evidence log:** `docs/reports/STAGE_4_WORKLOG.md` — one section per substage with acceptance
criteria mapped to evidence. Keep appending to it.

---

## 5. Architecture & invariants — the quick card

**12 global invariants (INV-01..INV-12)** — the ones that bite constantly:
- **INV-01** integer money only; **no `double`/`float`/`num`** anywhere on the money path. Guard G3
  bans those three words across `lib/domain` and `lib/data`.
- **INV-02** conservation — allocated units sum exactly to the income.
- **INV-03** append-only ledger; no update/delete path at any layer. Enforced twice: repo exposes no
  mutator, and DB check `C-15` (`is_deleted = 0` on `ledger_entries`).
- **INV-04** balances are derived, never a stored source of truth; `balance_cache` is disposable and
  device-local.
- **INV-07** every unit lands somewhere — terminates at the sink (uncapped catch-all).
- **INV-08** engine is pure/deterministic — no clock, byte-identical output for identical input.
- **INV-09** UTC epoch ms everywhere; **INV-10** soft delete; **INV-11** versioned rules
  (sealed rule versions); **INV-12** client-generated UUID primary keys, never auto-increment.

**Six mechanical guards** `tool/guards/guards.dart` (G1–G6):
- G1 layering (no Flutter/presentation import in `lib/domain`), G2 …, **G3 no double/float/num** in
  domain+data, **G4 `DateTime.now()` only in `lib/data/clock_impl.dart`**, G5 …, G6 …
- Guards use a `stripStrings` flag (off for import guards — an import path *is* a string literal, and
  the naive stripper once blanked them, making G1/G5 inert).

**Domain purity check** `tool/domain_purity_check.dart` — runs on the **bare Dart VM** (`dart`, not
`flutter`), imports & exercises *every* `lib/domain` file. Catches transitive Flutter reach that G1
(direct-import-only) misses. **It fails the build if a new `lib/domain/*.dart` file is not imported by
it** — so when you add a domain file, add it to both the imports and the `_importedLibraries` list.
Wired into `tool/check.ps1` and CI.

**Key money/algorithm facts:**
- `MAX_MONEY_MINOR = 922,337,203,685,477` = `floor((2^63-1)/10000)`. `Money.tryFrom` rejects beyond it.
- **Largest-remainder integer split**, tie-break: remainder DESC → `sort_order` ASC → `id` string cmp.
- **`Money.multiplyByBasisPoints(bp, {divisor})`** — divisor is the **sum of participating weights**,
  NOT a constant 10000. (Substage 2.8 defect: constant loses money under override/partial splits.)
- **FIFO worklist** for phase-B redirects; parcels join the back. Chosen over recursion for
  termination + hop visibility; also gives sibling-before-descendant ordering for free (see ADR-006).
- Money has **two representations**: serialisation string in domain (`toDecimalString`), locale
  display in presentation. No `toDouble()` exists, deliberately.

---

## 6. What was built this session (Stage 4.1 → ADR-006)

### 4.1 — Money & core value types (`d2d17fd`)
- `lib/domain/money/money.dart` — `final class Money implements Comparable<Money>`. int64 minor
  units + `Currency`. `tryFrom`, `parse`, `plus`/`minus` (typed overflow failures, not wrapping),
  `negated`/`abs`, `multiplyByBasisPoints` → `BasisPointSplit{floor, remainder, divisor}`, `compareTo`
  (throws on currency mismatch — `Comparable` can't return a failure), `toDecimalString`. **No double.**
- `lib/domain/money/money_failure.dart` — sealed `MoneyFailure`: `MoneyOverflow`, `CurrencyMismatch`,
  `MoneyUnparseable(ParseFailureReason)`; `const int maxMoneyMinor = 922337203685477`.
- `lib/domain/money/basis_points.dart` — `final class BasisPoints`, integer-only percent formatting
  (`asPercentString` assembles a string, never `raw/100` which returns double), `sum`, `sumsToFull`.
- `lib/data/clock_impl.dart` (`SystemClock`, the ONLY `DateTime.now()` site) and
  `id_generator_impl.dart` (`UuidIdGenerator` — v7 time-sortable / v4 random).
- Tests `test/domain/money/money_test.dart` — boundaries, all three exponents (JPY 0, USD 2, KWD 3).
- G3 & G4 negative-tested (probe files made them fail, then removed).

### 4.2 — Domain entities & enums (`374b696`)
`lib/domain/entities/` — **every entity is immutable, private ctor, only entry is a `create` factory
returning `Result<T, EntityFailure>`; `copyWith` ALSO returns `Result`** (routes through `create`, so
a valid entity can't be copied into an invalid one).
- Entities: `category_group`, `category`, `account`, `distribution_rule_version`, `rule_line`,
  `income_event`, `allocation` (AllocationLine — engine output, not stored), `ledger_entry`
  (append-only, no copyWith), `spending_transaction`, `app_settings`. Plus `sync_fields.dart`
  (the 5 sync columns as a value object), `headroom.dart`, `enums.dart`, `entity_failure.dart`.
- **`enums.dart`** — 13 enums, each `implements WireEnum` with an explicit `wireName` string and
  `fromWire` returning null on unknown (never a default fallback). **Never ordinal.**
- **`headroom.dart`** — sealed `Headroom { bounded(int), unbounded() }`. `bounded` clamps at 0 in its
  ctor (the `max(0,…)` of ALLOCATION §3.1). Represents "unbounded" explicitly, never as int64.max.
  `Category.headroom(...)` is the single implementation (substage 4.2.2 — "engine asks the category").
- Entities store **bare `int` minor units, not `Money`** — one currency for the whole app lives once
  on `AppSettings.currency`; a `Currency` per entity would be N copies that can disagree.
- Added `tool/domain_purity_check.dart` here (see §5).

### 4.3 — Database schema (`3fef4db`)
`lib/data/database/` — Drift. Replaced the Stage-3 codegen probe wholesale.
- `tables/sync_columns.dart` (mixin + `kSyncedTableNames`, `kSyncColumnNames`, `kSyncCheckConstraint`
  — note: constraint is **inlined as a literal** at each table because Drift only verifies literal
  `customConstraints`; a named const silently disables its verification).
- `tables/configuration_tables.dart`, `movement_tables.dart`, `local_tables.dart` — 13→14 tables.
- `database.dart` — `PookieDatabase`, `kSchemaVersion = 1`, all unique/perf indexes as **named
  constants**, `PRAGMA foreign_keys = ON` in `beforeOpen` **with the result read back and asserted**
  (SQLite defaults FK enforcement OFF; per-connection).
- **`@ReferenceName(...)` on 15+ FKs** to stop Drift silently omitting colliding manager accessors.
- Tests `test/data/database/schema_test.dart` — read the **live schema** (`PRAGMA table_info`,
  `foreign_key_list`, `EXPLAIN QUERY PLAN`), not the Dart source: no float storage class (allowlist
  TEXT/INTEGER), FK enforcement (orphan insert fails), all 5 sync cols on synced tables & none on
  local, every check/unique constraint that protects an invariant, IX-01 used by query plan.
- **4.3 found a real 4.2 defect:** `IncomeEvent` allowed zero income; SCHEMA C-02 + vector V-11a
  require `> 0` (`IncomeNotPositive`). Fixed. Deleted the now-unused `NegativeAmount` failure.
- **Amended SCHEMA.md** with C-23…C-28 (six constraints the design required but §5.4 hadn't listed) —
  recorded, not silently added, per 4.3 `must_not`.
- Evidence: `docs/reports/STAGE_4_SCHEMA_COMPARISON.md` (generated from a live DB dump).

### ADR-006 — FR-16 ceiling-triggered cascade redirect (`7d645a0`) ← NEW REQUIREMENT
The user added a requirement **after** the Stage 1 & 2 gates: when an Accumulating Reserve hits its
ceiling, its allocation redirects to **explicitly user-configured** fallback categories (priority
order OR split), cascading onward if those are full, terminating in a flagged surplus bucket.

**Most of it was already designed/built** (live check via `accepted_so_far`, cascade via FIFO
worklist + vector V-05, sink terminal via INV-07/V-06, reserve-vs-bill via headroom table). ADR-006
maps that clause-by-clause to avoid duplicating mechanisms. **Two things were genuinely new:**

1. **Multiple redirect targets.** New table `redirect_targets` **replaces** the single
   `categories.redirect_target_category_id` column (removed, not kept alongside). New entity
   `lib/domain/entities/redirect_target.dart` with `RedirectTargetList` extension (`inOfferOrder`,
   `shareDivisor`, `sharesSumToFull`) and free function `validateRedirectMode`. New enum
   `RedirectMode { priority, split }`. New failures: `NegativeRedirectPriority`, `RedirectModeMismatch`,
   `RedirectSharesDoNotSum`, `ReferenceAmountTypeMismatch`. `SPLIT` divides by the **live** weight sum.
2. **Reference Monthly Amount** — new nullable `categories.reference_monthly_amount_minor`. **Stored
   but does NOT drive allocation yet** — the requirement implies absolute amounts, FR-02 (a MUST) says
   percentages. Raised as **OQ-19** (see §9). C-33 keeps it reserve-only + positive so no row exists
   that either answer would invalidate.

**Ripple applied:** PRD FR-16 + US-038/US-039; SCHEMA §3.14 + C-29…C-33 + V-28…V-31 + U-11/U-12 +
IX-13 + RedirectMode; ALLOCATION_ALGORITHM §3.10 (4 subsections) + vectors **V-16…V-19**;
OPEN_QUESTIONS OQ-19; TRACEABILITY FR-16 row; reworked `Category` entity + drift table; tests
`test/domain/entities/redirect_target_test.dart` (walks each vector's arithmetic by hand, asserts
conservation).

**Resolved ambiguity you should know about (§9 item 2):** the requirement's "priority order" vs
"cascade down that target's own target" are two different behaviours. I chose **source's own list
first, then descend** (ALLOCATION §3.10.1). Vector V-18 pins it. A parcel therefore carries `origin_id`
+ `next_target_index` separately from `redirected_from`.

---

## 7. Repo map (the parts that matter now)

```
docs/
  PRD.md  ARCHITECTURE.md  SCHEMA.md  ALLOCATION_ALGORITHM.md  NAVIGATION.md
  OPEN_QUESTIONS.md  ASSUMPTIONS.md  TRACEABILITY.md
  decisions/ADR-001..ADR-006
  reports/STAGE_{1,2,3}_{REPORT,WORKLOG}.md
          STAGE_4_WORKLOG.md            ← append per substage
          STAGE_4_SCHEMA_COMPARISON.md  ← regenerate if schema changes
lib/
  domain/
    result.dart                         Result<T,F> = Success | Failure
    money/{money,money_failure,basis_points,currency,money_format,clock,id_generator}.dart
    entities/{category_group,category,account,distribution_rule_version,rule_line,
              income_event,allocation,ledger_entry,spending_transaction,app_settings,
              redirect_target,sync_fields,headroom,enums,entity_failure}.dart
  data/
    clock_impl.dart  id_generator_impl.dart      (the ONLY DateTime.now() is here)
    database/database.dart  database.g.dart(gen)  tables/*.dart
    repositories/ mappers/ balances/ seed/ migrations/ backup/ sync/  ← mostly empty, 4.4+ fills them
tool/
  guards/guards.dart   domain_purity_check.dart   check.ps1
test/
  domain/money/money_test.dart
  domain/entities/{entities_test,redirect_target_test}.dart
  data/database/schema_test.dart
  support/…  fixtures/allocation/{v01…,v11a…}.json
prompts/  ← the 10-stage plan (source of truth)
```

**Toolchain paths (this machine):** Flutter isn't on PATH. Use
`& "$env:USERPROFILE\flutter\bin\flutter.bat"` and `…\dart.bat`. `tool/check.ps1` resolves them.
Scratchpad for temp files:
`C:\Users\Chichum\AppData\Local\Temp\claude\c--Users-Chichum-Personal-Projects-budgeting-app\01c726a9-9b0e-42d9-bc92-75e41000ca16\scratchpad`.
**PowerShell is 5.1** — `&&`/ternary/`pwsh` don't exist; `python` maps to a store stub in Bash tool
(use the `Bash` tool's `python` heredocs, which DO work, or `python -` with a heredoc).

---

## 8. Hard-won lessons (don't relearn these)

1. **A passing check is not evidence.** Negative-test guards. Stage 3: G1 & G5 matched nothing for
   weeks. This session: the purity check + G3/G4 were each made to fail on a probe before trusting.
2. **Verify against the spec document, not your own memory of it.** 4.3 caught a 4.2 defect (zero
   income) only because transcription re-read SCHEMA. Re-reading my own code wouldn't have.
3. **Run `tool/check.ps1` immediately before the commit.** I committed 4.2 with 48 analyzer issues by
   running `analyze` before adding a file. The check is the *last* action.
4. **PowerShell 5.1 UTF-8 round-trips corrupt files** (`Get-Content`/`Set-Content` read UTF-8 as ANSI
   → mojibake). Use the `Write` tool, or `[System.IO.File]::ReadAllText/AppendAllText` with explicit
   `UTF8Encoding($false)`. Committing multi-line messages: write to a file, `git commit -F`.
5. **Drift gotchas:** `customConstraints` must be **literal strings** (a named const disables Drift's
   verification silently); colliding FKs need `@ReferenceName` or accessors are silently omitted.
   Both emit *warnings*, and 4.3.4 requires resolving warnings, not ignoring them.
6. **Requirements after a gate → amend + ADR + trace the ripple.** Don't absorb them into the open
   stage silently. That's the manifest's `sdlc_discipline` rule and it's how ADR-005/006 were handled.
7. When Bash-tool `python` heredocs contain Dart string interpolation (`$id`), the shell may eat `$`.
   Watch for `\$` landing in generated Dart; unescape after.

---

## 9. OPEN ITEMS NEEDING THE USER (surface these; don't silently decide)

1. **OQ-19 — does `reference_monthly_amount_minor` drive allocation, or just describe intent?**
   The FR-16 requirement implies absolute monthly amounts; FR-02 (MUST) specifies percentages. They
   diverge visibly when income varies (700k month, 550k reference → bike gets 193k or 245k?).
   My **recommendation: percentages allocate, the reference amount is for projections** (keeps FR-02,
   conservation, and all golden vectors intact). Documented in `docs/OPEN_QUESTIONS.md` (OQ-19). The
   cascade behaves identically either way, so it isn't blocking — but Stage 5 needs the answer.
2. **V-18 ordering — confirm the ambiguity resolution.** "priority order" vs "cascade down that
   target's own target" were both in the requirement. I chose **exhaust the source's own target list
   first, then descend**. If the user meant descend-immediately, ALLOCATION §3.10.1, vector V-18, and
   the `origin_id`/`next_target_index` parcel fields change. I flagged this in chat; **no reply yet.**
3. **Push:** not needed as of this writing (`origin/v1.0` == `v1.0` == `7d645a0`). Re-check before
   assuming. The user handles credentials; you cannot push non-interactively.

---

## 10. What to do next

**Substage 4.4 — Repository interfaces and CRUD.** First:

```
Read prompts/stage_04_core_data_layer.json  → the substage with "substage": "4.4"
```

Then implement per its `work` steps. Known shape from the plan and ADR-006:
- Repository **interfaces in `lib/domain`** (pure, no Drift), **implementations in `lib/data`**.
- One repository per aggregate. **Add a `RedirectTargetRepository`** (ADR-006 added the table) — it
  loads a source category's targets (used on the allocation hot path via IX-13).
- Mappers `lib/data/mappers/` translate Drift rows ↔ domain entities. **Every enum crosses via
  `wireName`/`fromWire`; reject unknown strings at the mapper boundary** (don't default).
- Respect INV-03: **no update/delete on the ledger repository** (that's 4.5's transactional writes,
  but the interface must not expose mutators).
- V-24 (currency immutable once a ledger entry exists) is a **repository** check — it needs to count
  rows, which an entity can't. AppSettings deliberately left it for here (see `app_settings.dart`).

**Then, every substage:** append evidence to `docs/reports/STAGE_4_WORKLOG.md` → run
`& .\tool\check.ps1 -SkipBuild -SkipCoverage` → commit with `-F` (conventional message, Co-Authored-By
line) → move to the next substage. Don't stop between substages; the next stop is the **Stage 4 gate**
(after 4.11), where you commit, (confirm) push, and wait for approval.

**Watch for at later substages:**
- **4.7** seed: name the personal sink **"Unallocated Surplus"** (matches FR-16 wording).
- **4.8** cycle detection now walks a **branching** graph (`redirect_targets` has many successors per
  node). A check following only the first target misses a cycle through the second — SCHEMA V-12 was
  amended to say so. Test 2-node, 3-node, longer cycles, and self-reference.
- **4.10** coverage target is **90%** for `lib/domain` + `lib/data`.

**Verification commands (copy-paste):**
```powershell
& .\tool\check.ps1 -SkipBuild -SkipCoverage      # the one-command gate (7 steps)
# individual pieces if needed:
& "$env:USERPROFILE\flutter\bin\dart.bat" format .
& "$env:USERPROFILE\flutter\bin\flutter.bat" analyze
& "$env:USERPROFILE\flutter\bin\flutter.bat" test
& "$env:USERPROFILE\flutter\bin\dart.bat" run tool/guards/guards.dart
& "$env:USERPROFILE\flutter\bin\dart.bat" run tool/domain_purity_check.dart
& "$env:USERPROFILE\flutter\bin\flutter.bat" pub run build_runner build   # after any table change
```

---

## 11. Golden-vector cheat sheet (ALLOCATION_ALGORITHM.md §… , for Stage 5 mostly, but referenced now)

V-01 plain split · V-02/V-03 largest-remainder + tie-break · V-04 single ceiling redirect ·
V-05 chained multi-hop (5 line items) · V-06 everything full → sink · V-07 cycle defended at runtime ·
V-08 fixed-recurring overflow · V-09 override w/ redistribution (divisor 6000!) · V-10 override exceeds
income → fail · V-11a/b zero/negative income → `IncomeNotPositive` · V-12 empty group w/ share → fail ·
V-13 smallest indivisible (income=1) · V-14 simultaneous ceiling hits · V-15 near-max income ·
**V-16 simple redirect (PRIORITY)** · **V-17 split redirect (tie-break leftover)** ·
**V-18 chained cascade: sibling-then-descend-then-sink** (pins the §3.10.1 ordering) ·
**V-19 no valid target → surplus + `SURPLUS_UNALLOCATED` diagnostic**.
Fixture files exist only for V-01 and V-11a so far; Stage 5 writes the rest.

---

*End of handoff. If anything here contradicts a file in the repo, the repo wins — verify before
acting on a claim, especially anything naming a specific file, constant, or line.*
