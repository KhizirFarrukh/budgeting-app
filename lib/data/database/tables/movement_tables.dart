import 'package:drift/drift.dart';
import 'package:pookiebudget/data/database/tables/configuration_tables.dart';
import 'package:pookiebudget/data/database/tables/sync_columns.dart';

/// The money-movement tables: income events, the ledger, spending.
///
/// Transcribed from `SCHEMA.md` §3.6–3.8.

/// SCHEMA §3.6 — money arriving, and the full record of how it was split.
@DataClassName('IncomeEventRow')
class IncomeEvents extends Table with SyncColumns {
  @override
  String get tableName => 'income_events';

  /// UUID **v7** — time-sortable, for index locality on a high-volume table.
  TextColumn get id => text().named('id')();

  /// **The conservation target**: ledger entries for this event must sum to
  /// exactly this (INV-02).
  IntColumn get amountMinor => integer().named('amount_minor')();

  /// "Salary", "Sale — order 412".
  TextColumn get sourceLabel => text().named('source_label').nullable()();

  /// When the money arrived, per the user.
  IntColumn get occurredAtMs => integer().named('occurred_at_ms')();

  /// When the app was told.
  IntColumn get recordedAtMs => integer().named('recorded_at_ms')();

  /// The timestamp passed into the engine. Stored so the event is exactly
  /// reproducible (INV-08).
  IntColumn get evaluatedAtMs => integer().named('evaluated_at_ms')();

  /// The version actually applied (INV-11).
  TextColumn get ruleVersionId => text()
      .named('rule_version_id')
      .references(
        DistributionRuleVersions,
        #id,
        onDelete: KeyAction.restrict,
      )();

  /// `PERSONAL` | `BUSINESS`, for reporting scope.
  TextColumn get scope =>
      text().named('scope').withDefault(const Constant('PERSONAL'))();

  /// The manual override map as supplied, or null. JSON of
  /// `{category_id: amount_minor}` with integer values.
  ///
  /// **An input to the event, not an edit of its output** (A-23, closes E-02).
  /// Without it the event is unreproducible and INV-11's promise breaks.
  TextColumn get overridesJson => text().named('overrides_json').nullable()();

  /// The reversal event that undid this one, if any.
  @ReferenceName('eventsReversedByThis')
  TextColumn get reversedByEventId => text()
      .named('reversed_by_event_id')
      .nullable()
      .references(IncomeEvents, #id, onDelete: KeyAction.restrict)();

  /// 1 when this event *is* a reversal of another.
  BoolColumn get isReversal =>
      boolean().named('is_reversal').withDefault(const Constant(false))();

  @ReferenceName('eventsThisReverses')
  TextColumn get reversesEventId => text()
      .named('reverses_event_id')
      .nullable()
      .references(IncomeEvents, #id, onDelete: KeyAction.restrict)();

  TextColumn get note => text().named('note').nullable()();

  @override
  Set<Column<Object>> get primaryKey => <Column<Object>>{id};

  @override
  List<String> get customConstraints => <String>[
    // C-02 — amount_minor > 0. Zero is rejected, not merely empty: vector
    // V-11a expects `IncomeNotPositive`.
    'CHECK (amount_minor > 0)',
    // C-11
    "CHECK (scope IN ('PERSONAL','BUSINESS'))",
    'CHECK (is_deleted IN (0,1) AND (is_deleted = 0 OR deleted_at_ms IS NOT NULL) AND (is_deleted = 1 OR deleted_at_ms IS NULL))',
  ];
}

/// SCHEMA §3.7 — the immutable record of every movement. **Append-only.**
///
/// This table has no update path and no delete path at any layer (INV-03).
/// Corrections are new compensating rows.
@DataClassName('LedgerEntryRow')
class LedgerEntries extends Table with SyncColumns {
  @override
  String get tableName => 'ledger_entries';

  /// UUID **v7**, and the **idempotency key**: inserting the same id twice is a
  /// no-op. That is what makes a retried sync safe.
  TextColumn get id => text().named('id')();

  @ReferenceName('ledgerEntriesForCategory')
  TextColumn get categoryId => text()
      .named('category_id')
      .references(Categories, #id, onDelete: KeyAction.restrict)();

  /// **Denormalised from the category at write time**, so history survives a
  /// later re-link. A join would rewrite history.
  @ReferenceName('ledgerEntriesForAccount')
  TextColumn get accountId => text()
      .named('account_id')
      .nullable()
      .references(Accounts, #id, onDelete: KeyAction.restrict)();

  /// `IN` | `OUT`.
  TextColumn get direction => text().named('direction')();

  /// Always **positive**; `direction` carries the sign. A signed amount plus a
  /// direction gives two ways to express the same thing and eventually they
  /// disagree.
  IntColumn get amountMinor => integer().named('amount_minor')();

  IntColumn get occurredAtMs => integer().named('occurred_at_ms')();
  IntColumn get recordedAtMs => integer().named('recorded_at_ms')();

  /// `ALLOCATION` | `SPENDING` | `REVERSAL` | `ADJUSTMENT`.
  TextColumn get sourceType => text().named('source_type')();

  /// The income event or spending transaction that produced it.
  ///
  /// **Deliberately not a foreign key**: it points at either table depending on
  /// `source_type`, and SQLite cannot express a polymorphic reference.
  /// Referential integrity is enforced by the repository write path and checked
  /// by the Stage 9 reconciliation script.
  TextColumn get sourceId => text().named('source_id')();

  /// `BASE` | `REDIRECT` | `MANUAL_OVERRIDE` | `SINK_TERMINAL`. Set for
  /// allocations.
  TextColumn get reason => text().named('reason').nullable()();

  /// Set when `reason = REDIRECT`. **This is what lets the UI say where
  /// overflow came from.**
  @ReferenceName('ledgerEntriesRedirectedFrom')
  TextColumn get redirectedFromCategoryId => text()
      .named('redirected_from_category_id')
      .nullable()
      .references(Categories, #id, onDelete: KeyAction.restrict)();

  /// How many redirects this parcel travelled. 0 for a base allocation.
  IntColumn get hopCount => integer().named('hop_count').nullable()();

  @ReferenceName('entriesThisReverses')
  TextColumn get reversesEntryId => text()
      .named('reverses_entry_id')
      .nullable()
      .references(LedgerEntries, #id, onDelete: KeyAction.restrict)();

  TextColumn get note => text().named('note').nullable()();

  @override
  Set<Column<Object>> get primaryKey => <Column<Object>>{id};

  @override
  List<String> get customConstraints => <String>[
    // C-02
    'CHECK (amount_minor > 0)',
    // C-06
    "CHECK (direction IN ('IN','OUT'))",
    // C-07
    "CHECK (source_type IN ('ALLOCATION','SPENDING','REVERSAL','ADJUSTMENT'))",
    // C-08
    "CHECK (reason IS NULL OR reason IN ('BASE','REDIRECT','MANUAL_OVERRIDE','SINK_TERMINAL'))",
    // C-14
    'CHECK (hop_count IS NULL OR hop_count >= 0)',
    // C-15 — THE APPEND-ONLY GUARANTEE AT DATABASE LEVEL. A ledger entry may
    // never be tombstoned. Combined with the repository exposing no update or
    // delete method, INV-03 is protected by two independent mechanisms.
    'CHECK (is_deleted = 0)',
    // C-16
    "CHECK (redirected_from_category_id IS NULL OR reason = 'REDIRECT')",
    // C-13's tombstone-date half still applies; the is_deleted half is
    // subsumed by C-15 above but kept so the constraint set is uniform.
    'CHECK (is_deleted IN (0,1) AND (is_deleted = 0 OR deleted_at_ms IS NOT NULL) AND (is_deleted = 1 OR deleted_at_ms IS NULL))',
  ];
}

/// SCHEMA §3.8 — the user-facing record behind an outgoing movement.
///
/// One row produces exactly one `OUT` ledger entry. Kept separate because a
/// transaction is editable and a ledger entry is not: a correction writes three
/// rows, and the original stays visible (US-026).
@DataClassName('SpendingTransactionRow')
class SpendingTransactions extends Table with SyncColumns {
  @override
  String get tableName => 'spending_transactions';

  /// UUID v7.
  TextColumn get id => text().named('id')();

  /// Positive.
  IntColumn get amountMinor => integer().named('amount_minor')();

  @ReferenceName('spendingForCategory')
  TextColumn get categoryId => text()
      .named('category_id')
      .references(Categories, #id, onDelete: KeyAction.restrict)();

  /// Defaulted from the category's link, overridable.
  @ReferenceName('spendingForAccount')
  TextColumn get accountId => text()
      .named('account_id')
      .nullable()
      .references(Accounts, #id, onDelete: KeyAction.restrict)();

  IntColumn get occurredAtMs => integer().named('occurred_at_ms')();
  IntColumn get recordedAtMs => integer().named('recorded_at_ms')();

  TextColumn get payee => text().named('payee').nullable()();
  TextColumn get note => text().named('note').nullable()();

  /// `PERSONAL` | `BUSINESS`.
  TextColumn get scope =>
      text().named('scope').withDefault(const Constant('PERSONAL'))();

  /// 1 when this replaces a corrected entry.
  BoolColumn get isCorrection =>
      boolean().named('is_correction').withDefault(const Constant(false))();

  @ReferenceName('transactionsThisCorrects')
  TextColumn get correctsTransactionId => text()
      .named('corrects_transaction_id')
      .nullable()
      .references(SpendingTransactions, #id, onDelete: KeyAction.restrict)();

  @override
  Set<Column<Object>> get primaryKey => <Column<Object>>{id};

  @override
  List<String> get customConstraints => <String>[
    // C-02
    'CHECK (amount_minor > 0)',
    // C-11
    "CHECK (scope IN ('PERSONAL','BUSINESS'))",
    'CHECK (is_deleted IN (0,1) AND (is_deleted = 0 OR deleted_at_ms IS NOT NULL) AND (is_deleted = 1 OR deleted_at_ms IS NULL))',
  ];
}
