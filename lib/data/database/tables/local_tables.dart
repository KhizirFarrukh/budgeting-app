import 'package:drift/drift.dart';
import 'package:pookiebudget/data/database/tables/configuration_tables.dart';
import 'package:pookiebudget/data/database/tables/sync_columns.dart';

/// `app_settings` (synced) and the four **device-local** tables.
///
/// Transcribed from `SCHEMA.md` §3.9–3.13. The device-local four carry **none**
/// of the five sync columns, deliberately — each is excluded from the payload
/// for a stated reason, recorded on the table.

/// SCHEMA §3.9 — the single settings row. `id` is fixed so a merge cannot
/// produce two.
@DataClassName('AppSettingsRow')
class AppSettingsTable extends Table with SyncColumns {
  @override
  String get tableName => 'app_settings';

  TextColumn get id =>
      text().named('id').withDefault(const Constant('singleton'))();

  /// ISO 4217, e.g. `PKR`, `USD`, `JPY`, `KWD`.
  TextColumn get currencyCode => text().named('currency_code')();

  /// 0, 2 or 3. Drives all parsing and formatting. **Immutable once any ledger
  /// entry exists** (V-24) — enforced at the repository, which can count rows.
  IntColumn get currencyMinorExponent =>
      integer().named('currency_minor_exponent')();

  /// For display formatting.
  TextColumn get locale => text().named('locale')();

  BoolColumn get businessScopeEnabled => boolean()
      .named('business_scope_enabled')
      .withDefault(const Constant(false))();

  /// Required once onboarding completes.
  @ReferenceName('settingsUsingAsPersonalSink')
  TextColumn get personalSinkCategoryId => text()
      .named('personal_sink_category_id')
      .nullable()
      .references(Categories, #id, onDelete: KeyAction.restrict)();

  /// Required when business scope is enabled.
  @ReferenceName('settingsUsingAsBusinessSink')
  TextColumn get businessSinkCategoryId => text()
      .named('business_sink_category_id')
      .nullable()
      .references(Categories, #id, onDelete: KeyAction.restrict)();

  /// `NOT_STARTED` | `IN_PROGRESS` | `COMPLETE`. Enables
  /// resume-where-you-left-off.
  TextColumn get onboardingState => text()
      .named('onboarding_state')
      .withDefault(const Constant('NOT_STARTED'))();

  /// Which step, when in progress.
  IntColumn get onboardingStep =>
      integer().named('onboarding_step').nullable()();

  /// The database schema version.
  IntColumn get schemaVersion => integer().named('schema_version')();

  /// The currently effective rule version.
  TextColumn get activeRuleVersionId => text()
      .named('active_rule_version_id')
      .nullable()
      .references(
        DistributionRuleVersions,
        #id,
        onDelete: KeyAction.restrict,
      )();

  @override
  Set<Column<Object>> get primaryKey => <Column<Object>>{id};

  @override
  List<String> get customConstraints => <String>[
    // U-09 — settings is a single row.
    "CHECK (id = 'singleton')",
    // C-12 — every stored amount is interpreted through this exponent, so an
    // unsupported value would misread every balance in the database.
    'CHECK (currency_minor_exponent IN (0,2,3))',
    "CHECK (onboarding_state IN ('NOT_STARTED','IN_PROGRESS','COMPLETE'))",
    'CHECK (is_deleted IN (0,1) AND (is_deleted = 0 OR deleted_at_ms IS NOT NULL) AND (is_deleted = 1 OR deleted_at_ms IS NULL))',
  ];
}

/// SCHEMA §3.10 — **device-local, never synced.**
///
/// Syncing a device's own clock state to other devices would be meaningless at
/// best and corrupting at worst.
@DataClassName('SyncMetadataRow')
class SyncMetadata extends Table {
  @override
  String get tableName => 'sync_metadata';

  TextColumn get id =>
      text().named('id').withDefault(const Constant('singleton'))();

  /// Generated once at install. **Never derived from a hardware identifier**
  /// (S07.4.4).
  TextColumn get deviceId => text().named('device_id')();

  /// Persisted HLC state, so it never goes backwards across a restart.
  IntColumn get hlcPhysicalMs => integer().named('hlc_physical_ms')();
  IntColumn get hlcCounter => integer().named('hlc_counter')();

  IntColumn get lastSyncAtMs => integer().named('last_sync_at_ms').nullable()();
  TextColumn get lastSnapshotId =>
      text().named('last_snapshot_id').nullable()();
  TextColumn get lastAppliedChunk =>
      text().named('last_applied_chunk').nullable()();
  IntColumn get remoteSchemaVersion =>
      integer().named('remote_schema_version').nullable()();

  /// A hash, **not the address** — used only to detect an account switch.
  TextColumn get accountEmailHash =>
      text().named('account_email_hash').nullable()();

  @override
  Set<Column<Object>> get primaryKey => <Column<Object>>{id};

  @override
  List<String> get customConstraints => <String>["CHECK (id = 'singleton')"];
}

/// SCHEMA §3.11 — **device-local.**
///
/// Written in the **same transaction** as the mutation it describes (S07.7.1);
/// otherwise a crash between the two loses the change silently.
@DataClassName('OutboxRow')
class Outbox extends Table {
  @override
  String get tableName => 'outbox';

  /// UUID v7.
  TextColumn get id => text().named('id')();

  /// Which table the change touched.
  TextColumn get tableName0 => text().named('table_name')();

  /// Which row.
  TextColumn get recordId => text().named('record_id')();

  /// `UPSERT` | `TOMBSTONE`.
  TextColumn get operation => text().named('operation')();

  /// The HLC of the change.
  TextColumn get hlc => text().named('hlc')();

  IntColumn get createdAtMs => integer().named('created_at_ms')();

  /// `PENDING` | `IN_FLIGHT` | `FAILED`.
  TextColumn get state => text().named('state')();

  /// Drives backoff.
  IntColumn get attemptCount => integer().named('attempt_count')();

  /// Error **type**, never a payload (ARCHITECTURE §8.2). A payload here would
  /// put user money data into a diagnostic record.
  TextColumn get lastError => text().named('last_error').nullable()();

  @override
  Set<Column<Object>> get primaryKey => <Column<Object>>{id};

  @override
  List<String> get customConstraints => <String>[
    "CHECK (operation IN ('UPSERT','TOMBSTONE'))",
    "CHECK (state IN ('PENDING','IN_FLIGHT','FAILED'))",
    'CHECK (attempt_count >= 0)',
  ];
}

/// SCHEMA §3.12 — **device-local, derived, disposable.**
///
/// **This is a cache and never a source of truth** (INV-04). It is excluded
/// from sync precisely so a merge can never import a balance — balances are
/// always recomputed locally from entries.
@DataClassName('BalanceCacheRow')
class BalanceCache extends Table {
  @override
  String get tableName => 'balance_cache';

  TextColumn get categoryId => text()
      .named('category_id')
      .references(Categories, #id, onDelete: KeyAction.restrict)();

  /// Cached sum of the category's ledger entries.
  ///
  /// **May legitimately be negative** — a category can be overspent — so there
  /// is no positivity check here, unlike every amount column on a movement
  /// table.
  IntColumn get balanceMinor => integer().named('balance_minor')();

  /// How many entries are folded into [balanceMinor].
  ///
  /// **Added by ADR-007.** §7.1's cheap verifier tier — one grouped `COUNT(*)`
  /// per category, run at every cold start — compares against this, and §3.12
  /// did not declare it. Substage 4.3 transcribed the declaration faithfully,
  /// so the gap only surfaced at 4.6 where both sections are read together.
  ///
  /// It also makes one more discrepancy nameable: a cache whose *total* matches
  /// while its *composition* does not, which two cancelling errors produce and
  /// a balance comparison alone reports as healthy.
  IntColumn get entryCount =>
      integer().named('entry_count').withDefault(const Constant(0))();

  /// The most recent entry folded in.
  TextColumn get lastEntryId => text().named('last_entry_id').nullable()();

  IntColumn get computedAtMs => integer().named('computed_at_ms')();

  /// Set on any write to that category's entries.
  BoolColumn get isStale =>
      boolean().named('is_stale').withDefault(const Constant(false))();

  /// U-10 — one cache row per category.
  @override
  Set<Column<Object>> get primaryKey => <Column<Object>>{categoryId};
}

/// SCHEMA §3.13 — **device-local, append-only.** Added by ADR-005.
///
/// Device-local because §6.8 requires every repair to be **deterministic**: two
/// devices performing the same merge produce identical repairs, so each logs the
/// same repair independently and syncing the log would duplicate every entry.
/// The determinism requirement is precisely what makes local logging correct.
@DataClassName('RepairLogRow')
class RepairLog extends Table {
  @override
  String get tableName => 'repair_log';

  /// UUID v7 — time-sortable, as this is an append-only log.
  TextColumn get id => text().named('id')();

  IntColumn get occurredAtMs => integer().named('occurred_at_ms')();

  /// Groups every repair from one merge, so the UI can say "3 changes were made
  /// when your devices last synced".
  TextColumn get mergeSessionId => text().named('merge_session_id')();

  /// Which of the six §6.8 repairs this was.
  TextColumn get kind => text().named('kind')();

  TextColumn get tableName0 => text().named('table_name')();

  /// Which row. **Not a foreign key** — the repair may concern a record that
  /// was deleted, which is often the reason a repair was needed.
  TextColumn get recordId => text().named('record_id')();

  /// Structured context: the ids involved and any amounts, as integers.
  ///
  /// Holds **ids rather than names**, for the same reason the engine's
  /// diagnostics do: the data layer has no locale and should not build
  /// user-facing sentences. The Diagnostics screen resolves ids at display
  /// time, so a later rename is reflected in old entries.
  TextColumn get detailJson => text().named('detail_json')();

  /// Set when the user has seen it; null means unread.
  IntColumn get acknowledgedAtMs =>
      integer().named('acknowledged_at_ms').nullable()();

  @override
  Set<Column<Object>> get primaryKey => <Column<Object>>{id};

  @override
  List<String> get customConstraints => <String>[
    "CHECK (kind IN ('REDIRECT_TARGET_REASSIGNED','PERCENTAGES_REDISTRIBUTED','SINK_RESTORED','CYCLE_BROKEN','ACCOUNT_UNLINKED','GROUP_SHARE_ZEROED'))",
  ];
}
