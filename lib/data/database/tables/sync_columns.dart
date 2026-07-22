import 'package:drift/drift.dart';

/// The five sync columns every synced table carries, without exception
/// (SCHEMA §2.1, S-07).
///
/// A mixin rather than five declarations repeated nine times. A table that
/// quietly omitted one would still compile — it would fail to *merge*, much
/// later, on another device. Substage 4.3's acceptance criterion *"every synced
/// table carries all five sync columns"* is checked at runtime against
/// [kSyncColumnNames], reading the live schema rather than trusting this file.
///
/// Every column name is given explicitly with `.named()`. Drift's default
/// Dart-to-SQL naming is a configuration setting, and 4.3's whole job is that
/// the SQL matches `SCHEMA.md` exactly — so nothing here is left to a default
/// that a `build.yaml` edit could change.
mixin SyncColumns on Table {
  /// Wall-clock time of the last write, UTC epoch ms.
  ///
  /// **For display and diagnostics only — never for ordering.** A device with a
  /// wrong clock produces a misleading value here but still orders correctly by
  /// [hlc]. Substage 7.4's rule *"never compare raw wall-clock timestamps in
  /// merge logic"* is why these are two columns and not one.
  IntColumn get updatedAtMs => integer().named('updated_at_ms')();

  /// The device id that last wrote this row.
  TextColumn get updatedByDevice => text().named('updated_by_device')();

  /// Hybrid logical clock, lexicographically sortable.
  ///
  /// **This is what orders concurrent edits** (R-08).
  TextColumn get hlc => text().named('hlc')();

  /// Tombstone flag. Stored as INTEGER 0/1 — Drift maps `boolean()` to an
  /// integer column in SQLite, which is what SCHEMA specifies.
  BoolColumn get isDeleted =>
      boolean().named('is_deleted').withDefault(const Constant(false))();

  /// When the tombstone was set; null when [isDeleted] is 0.
  IntColumn get deletedAtMs => integer().named('deleted_at_ms').nullable()();
}

/// The five column names, for the runtime check that every synced table has
/// them all.
const List<String> kSyncColumnNames = <String>[
  'updated_at_ms',
  'updated_by_device',
  'hlc',
  'is_deleted',
  'deleted_at_ms',
];

/// The nine synced tables (SCHEMA §8.1). The four device-local tables —
/// `sync_metadata`, `outbox`, `balance_cache`, `repair_log` — deliberately have
/// none of these columns and are excluded from the payload.
const List<String> kSyncedTableNames = <String>[
  'category_groups',
  'categories',
  'accounts',
  'distribution_rule_versions',
  'rule_lines',
  'income_events',
  'ledger_entries',
  'spending_transactions',
  'app_settings',
];

/// C-13, applied to every synced table.
///
/// `deleted_at_ms` must be present exactly when `is_deleted` is 1. Without the
/// second half a tombstone could carry no timestamp, and without the third a
/// live row could carry a deletion date — both merge as something the other
/// device cannot interpret.
const String kSyncCheckConstraint =
    'CHECK (is_deleted IN (0,1) AND '
    '(is_deleted = 0 OR deleted_at_ms IS NOT NULL) AND '
    '(is_deleted = 1 OR deleted_at_ms IS NULL))';
