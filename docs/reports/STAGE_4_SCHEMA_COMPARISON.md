# Schema versus design — the substage 4.3.5 comparison table

**Purpose.** Substage 4.3's goal is *"transcribe SCHEMA.md into table definitions exactly, and prove
the transcription is faithful"*, and its `why_it_matters` states the stakes plainly: *"Any divergence
here invalidates the Stage 2 design review, silently."*

> **Regenerated after [ADR-006](../decisions/ADR-006-ceiling-triggered-cascade-redirect.md).** The
> cascade-redirect requirement added `redirect_targets`, added two columns to `categories` and
> removed one, one substage after this document was first written. Regenerated from the live schema
> rather than hand-patched — the whole point of a dump is that it cannot drift from what the code
> builds.

**How this document was produced.** The column tables below are **dumped from a running database**
(`tool/_dump_schema.dart` reading `PRAGMA table_info`), not transcribed by hand from the Dart
definitions. A hand-written comparison table is evidence that someone read the code; a dump is
evidence of what the code actually builds. The same principle drives substage 4.3.6's requirement to
*"read the schema at runtime rather than trusting the definition source, so a generator change cannot
slip past."*

**Totals: 14 tables, 180 columns.** Every column is `TEXT` or `INTEGER`; there is no `REAL`,
`NUMERIC` or `DECIMAL` anywhere, asserted by test rather than by inspection.

---

## 1. Summary — designed versus implemented

| SCHEMA § | Table | Designed columns | Implemented | Difference |
|---|---|---|---|---|
| 3.1 | `category_groups` | 5 + 5 sync | 10 | none |
| 3.2 | `categories` | 21 + 5 sync | 26 | none — **+2 −1 by ADR-006**: gains `reference_monthly_amount_minor` and `redirect_mode`, loses `redirect_target_category_id` |
| 3.3 | `accounts` | 7 + 5 sync | 12 | none |
| 3.4 | `distribution_rule_versions` | 6 + 5 sync | 11 | none |
| 3.5 | `rule_lines` | 6 + 5 sync | 11 | none |
| **3.14** | **`redirect_targets`** | 5 + 5 sync | 10 | none — **added by ADR-006** |
| 3.6 | `income_events` | 13 + 5 sync | 18 | none |
| 3.7 | `ledger_entries` | 14 + 5 sync | 19 | none |
| 3.8 | `spending_transactions` | 11 + 5 sync | 16 | none |
| 3.9 | `app_settings` | 11 + 5 sync | 16 | none |
| 3.10 | `sync_metadata` | 9, device-local | 9 | none |
| 3.11 | `outbox` | 9, device-local | 9 | none |
| 3.12 | `balance_cache` | 5, device-local | 5 | none |
| 3.13 | `repair_log` | 8, device-local | 8 | none |

**Ten synced tables carry all five sync columns; the four device-local tables carry none of them.**
Both halves are asserted by test. The second half matters as much as the first: `balance_cache`
carrying sync columns would let a merge import a balance, which is precisely what INV-04 forbids.

## 2. Constraints

| Group | Designed | Implemented | Difference |
|---|---|---|---|
| Foreign keys (§5.2) | 22, all `ON DELETE RESTRICT` | 22, all `RESTRICT` | none — verified by reading `PRAGMA foreign_key_list` on every table, not by reading the Dart |
| Unique constraints (§5.3) | U-01…U-12 | U-01…U-08 and U-11…U-12 as partial unique indexes, U-09 as a check, U-10 as a primary key | none — the expression differs by kind because Drift cannot express a partial unique index, so those eight are raw SQL |
| Check constraints (§5.4) | C-01…C-33 | C-01…C-33 | none — **C-23…C-28** were added at 4.3 (below), **C-29…C-33** by ADR-006 |
| Indexes (§5.5) | IX-01…IX-13 | IX-01…IX-13, with IX-11 expanded to ten | none. The deliberately-omitted Q9 composite is asserted **absent**, so a later hand cannot add it without failing a test |

### The six added constraints

Recorded as an amendment to `SCHEMA.md` §5.4 rather than absorbed silently, per 4.3's `must_not`:
*"Do not silently deviate from SCHEMA.md — amend the document and note it."*

| # | Constraint | Table | Why it was missing |
|---|---|---|---|
| C-23 | `scope IN ('GROUP','CATEGORY')` | `rule_lines` | §4 lists the value set; §5.4 had no `CHECK` for it, unlike the six other enum columns |
| C-24 | Scope/target agreement, both directions | `rule_lines` | §3.5 stated it as prose only |
| C-25 | `onboarding_state IN (…)` | `app_settings` | as C-23 |
| C-26 | `operation`, `state`, `attempt_count >= 0` | `outbox` | as C-23 |
| C-27 | `kind IN (…six RepairKind values…)` | `repair_log` | as C-23 — this table itself arrived by amendment (ADR-005) |
| C-28 | `id = 'singleton'` | `sync_metadata` | §3.10 states the table is single-row; only `app_settings` had the constraint (U-09) |

All six are **tightenings**: no row valid under the Stage 2 design is now rejected. C-24 is the one
with teeth — without it a `GROUP` line carrying a `category_id` is counted in neither total, so a
share exists but is summed nowhere, which looks correct on screen while breaking V-01.

## 3. Type mapping

| Design intent | SQLite storage | Where |
|---|---|---|
| Money | `INTEGER` minor units | every `*_minor` column (INV-01) |
| Percentages | `INTEGER` basis points | `rule_lines.basis_points` |
| Timestamps | `INTEGER` UTC epoch ms | every `*_ms` column (INV-09) |
| Ids | `TEXT` UUID | every primary key (INV-12) |
| Enumerations | `TEXT`, stable strings | asserted non-numeric by test (S-05) |
| Booleans | `INTEGER` 0/1 | Drift's `boolean()` maps to `INTEGER` in SQLite |

**`redirect_targets.basis_points` is nullable where every other share column is not.** Under
`PRIORITY` a share is meaningless, and 0 is a *meaningful* share — "this target gets nothing" is a
different statement from "this target is not weighted". Recorded here because a nullable numeric
column normally deserves suspicion.

**Every primary key is `TEXT`.** Asserted across all 13 tables by reading `pk` from
`PRAGMA table_info` — no auto-increment integer anywhere, because two devices creating records
offline must not collide (INV-12, S-04).

---

## 4. Full column dump

Generated from the live schema. Note that the five sync columns appear first on synced tables — an
artefact of Drift's mixin ordering, not a design difference; column order is not part of the design
and no query depends on it.

#### `accounts`

| Column | Implemented type | Null | Default | PK |
|---|---|---|---|---|
| `updated_at_ms` | INTEGER | no | — |  |
| `updated_by_device` | TEXT | no | — |  |
| `hlc` | TEXT | no | — |  |
| `is_deleted` | INTEGER | no | `0` |  |
| `deleted_at_ms` | INTEGER | yes | — |  |
| `id` | TEXT | no | — | ✓ |
| `name` | TEXT | no | — |  |
| `institution` | TEXT | yes | — |  |
| `last_four` | TEXT | yes | — |  |
| `scope` | TEXT | no | `'PERSONAL'` |  |
| `sort_order` | INTEGER | no | — |  |
| `is_archived` | INTEGER | no | `0` |  |

#### `app_settings`

| Column | Implemented type | Null | Default | PK |
|---|---|---|---|---|
| `updated_at_ms` | INTEGER | no | — |  |
| `updated_by_device` | TEXT | no | — |  |
| `hlc` | TEXT | no | — |  |
| `is_deleted` | INTEGER | no | `0` |  |
| `deleted_at_ms` | INTEGER | yes | — |  |
| `id` | TEXT | no | `'singleton'` | ✓ |
| `currency_code` | TEXT | no | — |  |
| `currency_minor_exponent` | INTEGER | no | — |  |
| `locale` | TEXT | no | — |  |
| `business_scope_enabled` | INTEGER | no | `0` |  |
| `personal_sink_category_id` | TEXT | yes | — |  |
| `business_sink_category_id` | TEXT | yes | — |  |
| `onboarding_state` | TEXT | no | `'NOT_STARTED'` |  |
| `onboarding_step` | INTEGER | yes | — |  |
| `schema_version` | INTEGER | no | — |  |
| `active_rule_version_id` | TEXT | yes | — |  |

#### `balance_cache`

| Column | Implemented type | Null | Default | PK |
|---|---|---|---|---|
| `category_id` | TEXT | no | — | ✓ |
| `balance_minor` | INTEGER | no | — |  |
| `last_entry_id` | TEXT | yes | — |  |
| `computed_at_ms` | INTEGER | no | — |  |
| `is_stale` | INTEGER | no | `0` |  |

#### `categories`

| Column | Implemented type | Null | Default | PK |
|---|---|---|---|---|
| `updated_at_ms` | INTEGER | no | — |  |
| `updated_by_device` | TEXT | no | — |  |
| `hlc` | TEXT | no | — |  |
| `is_deleted` | INTEGER | no | `0` |  |
| `deleted_at_ms` | INTEGER | yes | — |  |
| `id` | TEXT | no | — | ✓ |
| `group_id` | TEXT | no | — |  |
| `name` | TEXT | no | — |  |
| `type` | TEXT | no | — |  |
| `sort_order` | INTEGER | no | — |  |
| `is_archived` | INTEGER | no | `0` |  |
| `is_sink` | INTEGER | no | `0` |  |
| `is_suggested_seed` | INTEGER | no | `0` |  |
| `seed_version` | INTEGER | yes | — |  |
| `ceiling_minor` | INTEGER | yes | — |  |
| `bill_amount_minor` | INTEGER | yes | — |  |
| `period_anchor_day` | INTEGER | yes | — |  |
| `redirect_mode` | TEXT | no | `'PRIORITY'` |  |
| `reference_monthly_amount_minor` | INTEGER | yes | — |  |
| `linked_account_id` | TEXT | yes | — |  |
| `target_date_ms` | INTEGER | yes | — |  |
| `ceiling_kind` | TEXT | no | `'ABSOLUTE'` |  |
| `ceiling_param` | TEXT | yes | — |  |
| `parent_category_id` | TEXT | yes | — |  |
| `soft_budget_minor` | INTEGER | yes | — |  |
| `soft_budget_period` | TEXT | yes | — |  |

#### `category_groups`

| Column | Implemented type | Null | Default | PK |
|---|---|---|---|---|
| `updated_at_ms` | INTEGER | no | — |  |
| `updated_by_device` | TEXT | no | — |  |
| `hlc` | TEXT | no | — |  |
| `is_deleted` | INTEGER | no | `0` |  |
| `deleted_at_ms` | INTEGER | yes | — |  |
| `id` | TEXT | no | — | ✓ |
| `kind` | TEXT | no | — |  |
| `name` | TEXT | no | — |  |
| `sort_order` | INTEGER | no | — |  |
| `is_active` | INTEGER | no | `1` |  |

#### `distribution_rule_versions`

| Column | Implemented type | Null | Default | PK |
|---|---|---|---|---|
| `updated_at_ms` | INTEGER | no | — |  |
| `updated_by_device` | TEXT | no | — |  |
| `hlc` | TEXT | no | — |  |
| `is_deleted` | INTEGER | no | `0` |  |
| `deleted_at_ms` | INTEGER | yes | — |  |
| `id` | TEXT | no | — | ✓ |
| `effective_from_ms` | INTEGER | no | — |  |
| `created_at_ms` | INTEGER | no | — |  |
| `sealed_at_ms` | INTEGER | yes | — |  |
| `note` | TEXT | yes | — |  |
| `rule_set` | TEXT | no | `'DEFAULT'` |  |

#### `income_events`

| Column | Implemented type | Null | Default | PK |
|---|---|---|---|---|
| `updated_at_ms` | INTEGER | no | — |  |
| `updated_by_device` | TEXT | no | — |  |
| `hlc` | TEXT | no | — |  |
| `is_deleted` | INTEGER | no | `0` |  |
| `deleted_at_ms` | INTEGER | yes | — |  |
| `id` | TEXT | no | — | ✓ |
| `amount_minor` | INTEGER | no | — |  |
| `source_label` | TEXT | yes | — |  |
| `occurred_at_ms` | INTEGER | no | — |  |
| `recorded_at_ms` | INTEGER | no | — |  |
| `evaluated_at_ms` | INTEGER | no | — |  |
| `rule_version_id` | TEXT | no | — |  |
| `scope` | TEXT | no | `'PERSONAL'` |  |
| `overrides_json` | TEXT | yes | — |  |
| `reversed_by_event_id` | TEXT | yes | — |  |
| `is_reversal` | INTEGER | no | `0` |  |
| `reverses_event_id` | TEXT | yes | — |  |
| `note` | TEXT | yes | — |  |

#### `ledger_entries`

| Column | Implemented type | Null | Default | PK |
|---|---|---|---|---|
| `updated_at_ms` | INTEGER | no | — |  |
| `updated_by_device` | TEXT | no | — |  |
| `hlc` | TEXT | no | — |  |
| `is_deleted` | INTEGER | no | `0` |  |
| `deleted_at_ms` | INTEGER | yes | — |  |
| `id` | TEXT | no | — | ✓ |
| `category_id` | TEXT | no | — |  |
| `account_id` | TEXT | yes | — |  |
| `direction` | TEXT | no | — |  |
| `amount_minor` | INTEGER | no | — |  |
| `occurred_at_ms` | INTEGER | no | — |  |
| `recorded_at_ms` | INTEGER | no | — |  |
| `source_type` | TEXT | no | — |  |
| `source_id` | TEXT | no | — |  |
| `reason` | TEXT | yes | — |  |
| `redirected_from_category_id` | TEXT | yes | — |  |
| `hop_count` | INTEGER | yes | — |  |
| `reverses_entry_id` | TEXT | yes | — |  |
| `note` | TEXT | yes | — |  |

#### `outbox`

| Column | Implemented type | Null | Default | PK |
|---|---|---|---|---|
| `id` | TEXT | no | — | ✓ |
| `table_name` | TEXT | no | — |  |
| `record_id` | TEXT | no | — |  |
| `operation` | TEXT | no | — |  |
| `hlc` | TEXT | no | — |  |
| `created_at_ms` | INTEGER | no | — |  |
| `state` | TEXT | no | — |  |
| `attempt_count` | INTEGER | no | — |  |
| `last_error` | TEXT | yes | — |  |

#### `redirect_targets`

| Column | Implemented type | Null | Default | PK |
|---|---|---|---|---|
| `updated_at_ms` | INTEGER | no | — |  |
| `updated_by_device` | TEXT | no | — |  |
| `hlc` | TEXT | no | — |  |
| `is_deleted` | INTEGER | no | `0` |  |
| `deleted_at_ms` | INTEGER | yes | — |  |
| `id` | TEXT | no | — | ✓ |
| `source_category_id` | TEXT | no | — |  |
| `target_category_id` | TEXT | no | — |  |
| `priority` | INTEGER | no | — |  |
| `basis_points` | INTEGER | yes | — |  |

#### `repair_log`

| Column | Implemented type | Null | Default | PK |
|---|---|---|---|---|
| `id` | TEXT | no | — | ✓ |
| `occurred_at_ms` | INTEGER | no | — |  |
| `merge_session_id` | TEXT | no | — |  |
| `kind` | TEXT | no | — |  |
| `table_name` | TEXT | no | — |  |
| `record_id` | TEXT | no | — |  |
| `detail_json` | TEXT | no | — |  |
| `acknowledged_at_ms` | INTEGER | yes | — |  |

#### `rule_lines`

| Column | Implemented type | Null | Default | PK |
|---|---|---|---|---|
| `updated_at_ms` | INTEGER | no | — |  |
| `updated_by_device` | TEXT | no | — |  |
| `hlc` | TEXT | no | — |  |
| `is_deleted` | INTEGER | no | `0` |  |
| `deleted_at_ms` | INTEGER | yes | — |  |
| `id` | TEXT | no | — | ✓ |
| `rule_version_id` | TEXT | no | — |  |
| `scope` | TEXT | no | — |  |
| `group_id` | TEXT | yes | — |  |
| `category_id` | TEXT | yes | — |  |
| `basis_points` | INTEGER | no | — |  |

#### `spending_transactions`

| Column | Implemented type | Null | Default | PK |
|---|---|---|---|---|
| `updated_at_ms` | INTEGER | no | — |  |
| `updated_by_device` | TEXT | no | — |  |
| `hlc` | TEXT | no | — |  |
| `is_deleted` | INTEGER | no | `0` |  |
| `deleted_at_ms` | INTEGER | yes | — |  |
| `id` | TEXT | no | — | ✓ |
| `amount_minor` | INTEGER | no | — |  |
| `category_id` | TEXT | no | — |  |
| `account_id` | TEXT | yes | — |  |
| `occurred_at_ms` | INTEGER | no | — |  |
| `recorded_at_ms` | INTEGER | no | — |  |
| `payee` | TEXT | yes | — |  |
| `note` | TEXT | yes | — |  |
| `scope` | TEXT | no | `'PERSONAL'` |  |
| `is_correction` | INTEGER | no | `0` |  |
| `corrects_transaction_id` | TEXT | yes | — |  |

#### `sync_metadata`

| Column | Implemented type | Null | Default | PK |
|---|---|---|---|---|
| `id` | TEXT | no | `'singleton'` | ✓ |
| `device_id` | TEXT | no | — |  |
| `hlc_physical_ms` | INTEGER | no | — |  |
| `hlc_counter` | INTEGER | no | — |  |
| `last_sync_at_ms` | INTEGER | yes | — |  |
| `last_snapshot_id` | TEXT | yes | — |  |
| `last_applied_chunk` | TEXT | yes | — |  |
| `remote_schema_version` | INTEGER | yes | — |  |
| `account_email_hash` | TEXT | yes | — |  |
