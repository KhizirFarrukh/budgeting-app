/// Row ↔ entity for the three money-movement tables.
///
/// ## The ledger direction that does not exist
///
/// There is a `ledgerEntryToCompanion` here because rows have to be written
/// once. There is deliberately **no** helper for building a companion that
/// updates one — no "patch", no partial companion, nothing that produces a
/// `LedgerEntriesCompanion` with some fields absent. A partial companion is the
/// shape an update takes, and offering one here would put the tool for
/// violating INV-03 one import away from every file in the data layer.
///
/// `append_only_design_test.dart` asserts that absence by scanning this file.
library;

import 'package:drift/drift.dart';
import 'package:pookiebudget/data/database/database.dart';
import 'package:pookiebudget/data/mappers/mapping_error.dart';
import 'package:pookiebudget/data/mappers/sync_field_mapper.dart';
import 'package:pookiebudget/domain/entities/entity_failure.dart';
import 'package:pookiebudget/domain/entities/enums.dart';
import 'package:pookiebudget/domain/entities/income_event.dart';
import 'package:pookiebudget/domain/entities/ledger_entry.dart';
import 'package:pookiebudget/domain/entities/spending_transaction.dart';
import 'package:pookiebudget/domain/result.dart';

// ---------------------------------------------------------------------------
// LedgerEntry
// ---------------------------------------------------------------------------

LedgerEntry ledgerEntryFromRow(LedgerEntryRow row) {
  final LedgerDirection? direction = LedgerDirection.fromWire(row.direction);
  if (direction == null) {
    throw MappingError.unknownEnum(
      table: 'ledger_entries',
      recordId: row.id,
      column: 'direction',
      value: row.direction,
      permitted: LedgerDirection.values
          .map((LedgerDirection v) => v.wireName)
          .toList(),
    );
  }

  final LedgerSourceType? sourceType = LedgerSourceType.fromWire(
    row.sourceType,
  );
  if (sourceType == null) {
    throw MappingError.unknownEnum(
      table: 'ledger_entries',
      recordId: row.id,
      column: 'source_type',
      value: row.sourceType,
      permitted: LedgerSourceType.values
          .map((LedgerSourceType v) => v.wireName)
          .toList(),
    );
  }

  // Nullable: an allocation carries a reason, a spending entry does not. So a
  // null column is valid and only a *present but unrecognised* value is a
  // mapping error — the distinction a blanket `fromWire` call would lose.
  AllocationReason? reason;
  if (row.reason != null) {
    reason = AllocationReason.fromWire(row.reason!);
    if (reason == null) {
      throw MappingError.unknownEnum(
        table: 'ledger_entries',
        recordId: row.id,
        column: 'reason',
        value: row.reason!,
        permitted: AllocationReason.values
            .map((AllocationReason v) => v.wireName)
            .toList(),
      );
    }
  }

  final Result<LedgerEntry, EntityFailure> result = LedgerEntry.create(
    id: row.id,
    categoryId: row.categoryId,
    direction: direction,
    amountMinor: row.amountMinor,
    occurredAtMs: row.occurredAtMs,
    recordedAtMs: row.recordedAtMs,
    sourceType: sourceType,
    sourceId: row.sourceId,
    accountId: row.accountId,
    reason: reason,
    redirectedFromCategoryId: row.redirectedFromCategoryId,
    hopCount: row.hopCount,
    reversesEntryId: row.reversesEntryId,
    note: row.note,
    sync: readSyncFields(
      updatedAtMs: row.updatedAtMs,
      updatedByDevice: row.updatedByDevice,
      hlc: row.hlc,
      isDeleted: row.isDeleted,
      deletedAtMs: row.deletedAtMs,
    ),
  );

  return switch (result) {
    Success<LedgerEntry, EntityFailure>(:final LedgerEntry value) => value,
    Failure<LedgerEntry, EntityFailure>(:final EntityFailure failure) =>
      throw MappingError.rejectedByEntity(
        table: 'ledger_entries',
        recordId: row.id,
        failure: failure,
      ),
  };
}

/// Builds the companion for an **insert**. There is no update counterpart.
LedgerEntriesCompanion ledgerEntryToCompanion(LedgerEntry entry) =>
    LedgerEntriesCompanion(
      id: Value<String>(entry.id),
      categoryId: Value<String>(entry.categoryId),
      accountId: Value<String?>(entry.accountId),
      direction: Value<String>(entry.direction.wireName),
      amountMinor: Value<int>(entry.amountMinor),
      occurredAtMs: Value<int>(entry.occurredAtMs),
      recordedAtMs: Value<int>(entry.recordedAtMs),
      sourceType: Value<String>(entry.sourceType.wireName),
      sourceId: Value<String>(entry.sourceId),
      reason: Value<String?>(entry.reason?.wireName),
      redirectedFromCategoryId: Value<String?>(entry.redirectedFromCategoryId),
      hopCount: Value<int?>(entry.hopCount),
      reversesEntryId: Value<String?>(entry.reversesEntryId),
      note: Value<String?>(entry.note),
      updatedAtMs: Value<int>(entry.sync.updatedAtMs),
      updatedByDevice: Value<String>(entry.sync.updatedByDevice),
      hlc: Value<String>(entry.sync.hlc),
      // Never anything else. C-15 pins the column at 0 and `LedgerEntry.create`
      // refuses a tombstoned entry, so this is the third mechanism saying the
      // same thing — deleting a money movement is what INV-03 forbids.
      isDeleted: const Value<bool>(false),
      deletedAtMs: const Value<int?>(null),
    );

// ---------------------------------------------------------------------------
// IncomeEvent
// ---------------------------------------------------------------------------

IncomeEvent incomeEventFromRow(IncomeEventRow row) {
  final MoneyScope? scope = MoneyScope.fromWire(row.scope);
  if (scope == null) {
    throw MappingError.unknownEnum(
      table: 'income_events',
      recordId: row.id,
      column: 'scope',
      value: row.scope,
      permitted: MoneyScope.values.map((MoneyScope v) => v.wireName).toList(),
    );
  }

  final Result<IncomeEvent, EntityFailure> result = IncomeEvent.create(
    id: row.id,
    amountMinor: row.amountMinor,
    occurredAtMs: row.occurredAtMs,
    recordedAtMs: row.recordedAtMs,
    evaluatedAtMs: row.evaluatedAtMs,
    ruleVersionId: row.ruleVersionId,
    sourceLabel: row.sourceLabel,
    scope: scope,
    overridesJson: row.overridesJson,
    reversedByEventId: row.reversedByEventId,
    isReversal: row.isReversal,
    reversesEventId: row.reversesEventId,
    note: row.note,
    sync: readSyncFields(
      updatedAtMs: row.updatedAtMs,
      updatedByDevice: row.updatedByDevice,
      hlc: row.hlc,
      isDeleted: row.isDeleted,
      deletedAtMs: row.deletedAtMs,
    ),
  );

  return switch (result) {
    Success<IncomeEvent, EntityFailure>(:final IncomeEvent value) => value,
    Failure<IncomeEvent, EntityFailure>(:final EntityFailure failure) =>
      throw MappingError.rejectedByEntity(
        table: 'income_events',
        recordId: row.id,
        failure: failure,
      ),
  };
}

IncomeEventsCompanion incomeEventToCompanion(IncomeEvent event) =>
    IncomeEventsCompanion(
      id: Value<String>(event.id),
      amountMinor: Value<int>(event.amountMinor),
      sourceLabel: Value<String?>(event.sourceLabel),
      occurredAtMs: Value<int>(event.occurredAtMs),
      recordedAtMs: Value<int>(event.recordedAtMs),
      evaluatedAtMs: Value<int>(event.evaluatedAtMs),
      ruleVersionId: Value<String>(event.ruleVersionId),
      scope: Value<String>(event.scope.wireName),
      // A verbatim record of user input, never a computed result. Without it
      // the event is unreproducible and INV-11's promise breaks.
      overridesJson: Value<String?>(event.overridesJson),
      reversedByEventId: Value<String?>(event.reversedByEventId),
      isReversal: Value<bool>(event.isReversal),
      reversesEventId: Value<String?>(event.reversesEventId),
      note: Value<String?>(event.note),
      updatedAtMs: Value<int>(event.sync.updatedAtMs),
      updatedByDevice: Value<String>(event.sync.updatedByDevice),
      hlc: Value<String>(event.sync.hlc),
      isDeleted: Value<bool>(event.sync.isDeleted),
      deletedAtMs: Value<int?>(event.sync.deletedAtMs),
    );

// ---------------------------------------------------------------------------
// SpendingTransaction
// ---------------------------------------------------------------------------

SpendingTransaction spendingTransactionFromRow(SpendingTransactionRow row) {
  final MoneyScope? scope = MoneyScope.fromWire(row.scope);
  if (scope == null) {
    throw MappingError.unknownEnum(
      table: 'spending_transactions',
      recordId: row.id,
      column: 'scope',
      value: row.scope,
      permitted: MoneyScope.values.map((MoneyScope v) => v.wireName).toList(),
    );
  }

  final Result<SpendingTransaction, EntityFailure> result =
      SpendingTransaction.create(
        id: row.id,
        amountMinor: row.amountMinor,
        categoryId: row.categoryId,
        occurredAtMs: row.occurredAtMs,
        recordedAtMs: row.recordedAtMs,
        accountId: row.accountId,
        payee: row.payee,
        note: row.note,
        scope: scope,
        isCorrection: row.isCorrection,
        correctsTransactionId: row.correctsTransactionId,
        sync: readSyncFields(
          updatedAtMs: row.updatedAtMs,
          updatedByDevice: row.updatedByDevice,
          hlc: row.hlc,
          isDeleted: row.isDeleted,
          deletedAtMs: row.deletedAtMs,
        ),
      );

  return switch (result) {
    Success<SpendingTransaction, EntityFailure>(
      :final SpendingTransaction value,
    ) =>
      value,
    Failure<SpendingTransaction, EntityFailure>(:final EntityFailure failure) =>
      throw MappingError.rejectedByEntity(
        table: 'spending_transactions',
        recordId: row.id,
        failure: failure,
      ),
  };
}

SpendingTransactionsCompanion spendingTransactionToCompanion(
  SpendingTransaction transaction,
) => SpendingTransactionsCompanion(
  id: Value<String>(transaction.id),
  amountMinor: Value<int>(transaction.amountMinor),
  categoryId: Value<String>(transaction.categoryId),
  accountId: Value<String?>(transaction.accountId),
  occurredAtMs: Value<int>(transaction.occurredAtMs),
  recordedAtMs: Value<int>(transaction.recordedAtMs),
  payee: Value<String?>(transaction.payee),
  note: Value<String?>(transaction.note),
  scope: Value<String>(transaction.scope.wireName),
  isCorrection: Value<bool>(transaction.isCorrection),
  correctsTransactionId: Value<String?>(transaction.correctsTransactionId),
  updatedAtMs: Value<int>(transaction.sync.updatedAtMs),
  updatedByDevice: Value<String>(transaction.sync.updatedByDevice),
  hlc: Value<String>(transaction.sync.hlc),
  isDeleted: Value<bool>(transaction.sync.isDeleted),
  deletedAtMs: Value<int?>(transaction.sync.deletedAtMs),
);
