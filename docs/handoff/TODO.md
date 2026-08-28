# TODO — outstanding obligations

Every item carries the stage or substage that **owns** it. Nothing here is optional; each was
raised by a specific acceptance criterion, `must_not`, or design document.

---

## P0 — blocking, do before writing more code

- [ ] **Run the verification sequence** in [`ENVIRONMENT_BLOCKER.md`](ENVIRONMENT_BLOCKER.md) on a
      machine with the Flutter SDK. Substages 4.4–4.7 have never been compiled, analysed, formatted
      or tested. *Owner: immediate.*
- [ ] **Run `dart format .` and commit the result.** All formatting was done by hand; CI fails on
      any difference. *Owner: immediate.*
- [ ] **Fix whatever the build reports**, then flip 4.4–4.7 from 🟡 to ✅ in
      `docs/reports/STAGE_4_WORKLOG.md`, replacing every *"not run"* with real evidence.
      *Owner: immediate.*
- [ ] **Update `docs/ENVIRONMENT.md` §2** with the SDK path on the machine that actually builds.
      It currently records `C:\Users\Chichum\flutter`, which does not exist here. *Owner: immediate.*

---

## P1 — carried obligations from completed substages

- [ ] **Record the 4.6.6 benchmark figure.** `test/data/balances/balance_benchmark_test.dart` builds
      67,000 entries across 100 categories and prints `recomputeAll` + `verify` timings. Paste the
      real number into the 4.6 worklog entry. **Do not substitute SCHEMA §7.1's 40–80 ms estimate** —
      that estimate is what 4.6.6 exists to replace. Budget is P-13 ≤ 2 s. *Owner: 4.6, unfinished.*
- [ ] **Confirm the query plan uses IX-01.** Same test file asserts `EXPLAIN QUERY PLAN` names
      `ix_01_ledger_category_time`. This is substage 4.6.1's *"verify by inspecting the query plan"*.
      *Owner: 4.6, unfinished.*
- [ ] **Re-assert the seed through the real validators.** Substage 4.7's first acceptance criterion
      requires that seeding produce a configuration passing *"every validator from substage 4.8"*.
      4.8 did not exist, so `test/data/seed/seeder_test.dart` asserts V-01, V-02 and INV-07
      directly. **4.8 must add a test that runs the seeded configuration through the real validator.**
      *Owner: 4.8.*

---

## P2 — owned by a specific future substage

### Substage 4.8 — validators and cycle detection

- [ ] **The cycle walk is over a branching graph, not a chain.** ADR-006 replaced the single
      `redirect_target_category_id` column with a `redirect_targets` table, so a category can have
      many targets. A check that follows only the first target would miss a cycle reachable through
      the second. `CategoryRepository.redirectGraph()` already returns the whole graph in one read
      for exactly this.
- [ ] **Wire validators into the repository write path**, so a caller who forgets still cannot
      persist invalid state (SCHEMA §6.1: *"no invariant-protecting rule is enforced only in the
      UI"*).
- [ ] **Category deletion must consult rule lines.** `DriftCategoryRepository.deleteCategory`
      deliberately does *not* check them — a sealed version's lines must survive the deletion
      (INV-11) while a draft's must be redistributed to keep V-02's total at 10000. That is a
      judgement over the whole set, not a referential check over one row. There is a comment at the
      call site marking the spot.

### Substage 4.9 — migrations, export and backup

- [ ] The v1 fixture database goes in `test/fixtures/databases/`, populated with a reversal, a
      redirect and an archived category (SCHEMA §7.2).
- [ ] Export must carry the **five reserved columns** on `categories` so a v1.1 client reading a
      v1.0 backup finds them present (SCHEMA §6.7).

### Substage 4.11 — documentation and gate

- [ ] **Regenerate `docs/reports/STAGE_4_SCHEMA_COMPARISON.md`.** ADR-007 added
      `balance_cache.entry_count`, so the comparison must be rebuilt against the amended §3.12
      rather than the original five-column table.
- [ ] **Fold three stale rows back into `ARCHITECTURE.md` §2.2's repository table.** It lists six
      interfaces; there are now eight, and one moved:
      - `SpendingRepository` — added at 4.5
      - `BalanceRepository` — added at 4.6
      - `RedirectTarget` CRUD lives in `CategoryRepository`, not its own interface (ADR-006 changed
        the model after §2.2 was written)
- [ ] Reach the Stage 4 gate and **stop for user approval** before opening `stage_05`.

### Stage 5 — allocation engine

- [ ] Implement `ALLOCATION_ALGORITHM.md` §3.10 (multi-target redirect) and pass golden vectors
      **V-16…V-19**, added by ADR-006. Their fixture files are **not yet written** — the vector table
      in the design document is the contract.
- [ ] `BasisPoints.sum` exists specifically to be passed as `multiplyByBasisPoints`'s divisor when
      wiring override redistribution. **Do not pass a literal 10000** — substage 2.8 found that
      defect by executing the algorithm, and vector V-09 would lose 120,000 minor units.
- [ ] Substage 5.5.5 needs its own anchor-31-through-February test. The authority is already built
      and tested (`lib/domain/allocation/period.dart`, `test/domain/allocation/period_test.dart`) —
      call it, do not reimplement it.

### Stage 6 — UI

- [ ] A **redirect-target editor** (list, reorder, mode, shares), not a single-target dropdown
      (ADR-006). Named there so this stage sizes it rather than discovering it.
- [ ] Surface `SURPLUS_UNALLOCATED`.
- [ ] Onboarding must **write the settings row before calling the seeder** — the seeder requires it
      and refuses with `RecordNotFound` otherwise. The currency exponent is chosen at step one.
- [ ] Onboarding must walk the user through confirming the **placeholder ceilings and bill amounts**
      on the ten seeded categories that require them. They are flagged `is_suggested_seed` with a
      `seed_version` precisely so an untouched suggestion is detectable.
- [ ] Substage 6.1.1 must add an explicit check that no widget constructs a repository or touches
      the database — the import guards cannot catch it.

### Stage 7 — sync

- [ ] **New-device bootstrap must not seed before checking for a remote.** Two devices seeding
      independently while offline produce two full sets of categories, which merge into 38. Seed ids
      are UUID v4 per ARCHITECTURE §8.6, so they do not converge on their own. Deterministic UUID v5
      seed ids were considered at 4.7 and rejected as a unilateral amendment to §8.6 — **this stage
      owns the problem.** *Raised at 4.7.*
- [ ] The HLC (7.4) replaces the empty-string `hlc` that repositories currently write via
      `SyncFields.local`. Repositories deliberately do not invent one.
- [ ] `updated_by_device` is left untouched by soft deletes because device identity lives in
      `sync_metadata` and does not exist until 7.4.
- [ ] After **every** merge, run the **full** balance verifier tier and recompute locally
      (SCHEMA §7.1: *"a merge is never trusted"*). `BalanceVerifier.markStale` exists for this.
- [ ] Post-merge repair writes to `repair_log` (ADR-005); the `ACCOUNT_UNLINKED` repair is the
      sanctioned resolution for deleting an account with linked categories, which
      `DriftAccountRepository.deleteAccount` currently refuses.

---

## P3 — open questions still unresolved

| ID | Question | Status |
|---|---|---|
| **OQ-19** | Should `reference_monthly_amount_minor` drive allocation, or do percentages? | Raised by ADR-006, answered by default (percentages). The column is stored so the data exists either way. Revisit if Stage 6 shows the absolute figure is what users mean. |
| OQ-04 | Deadline-driven goals (`target_date_ms`) | Deferred to v1.1 (D-01). Column reserved, pinned null by C-21. |

---

## Housekeeping

- [ ] Keep `tool/domain_purity_check.dart` in step. Its completeness assertion **fails the build**
      if a file exists under `lib/domain` that it does not import. It was extended three times this
      session; it will need extending again at 4.8 (`lib/domain/validation/`).
- [ ] This handoff pack is a map, not a source of truth. When it disagrees with `docs/SCHEMA.md`,
      `docs/ARCHITECTURE.md` or the worklogs, **those win** — fix the map.
