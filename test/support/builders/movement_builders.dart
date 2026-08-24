/// Builders for the three money-movement entities.
///
/// Separate from `config_builders.dart` because the defaults differ in kind:
/// a configuration builder produces something *valid*, while a movement builder
/// must produce something valid **and internally consistent with its
/// siblings** — a ledger entry's `source_id` has to name its event, its
/// amounts have to conserve, and a reversal's magnitudes have to mirror an
/// original's exactly.
///
/// [allocationEntriesFor] and [reversalEntriesFor] exist for that reason. Every
/// test that writes an income event needs entries that satisfy INV-02, and a
/// test that hand-rolls them gets the conservation check it was not trying to
/// exercise. Building them from the event means the arithmetic is right once.
library;

import 'package:pookiebudget/domain/entities/entity_failure.dart';
import 'package:pookiebudget/domain/entities/enums.dart';
import 'package:pookiebudget/domain/entities/income_event.dart';
import 'package:pookiebudget/domain/entities/ledger_entry.dart';
import 'package:pookiebudget/domain/entities/spending_transaction.dart';
import 'package:pookiebudget/domain/entities/sync_fields.dart';
import 'package:pookiebudget/domain/result.dart';

import 'config_builders.dart';

T _require<T>(Result<T, EntityFailure> result, String what) =>
    switch (result) {
      Success<T, EntityFailure>(:final T value) => value,
      Failure<T, EntityFailure>(:final EntityFailure failure) =>
        throw StateError(
          'The $what builder produced an invalid entity: $failure.',
        ),
    };

IncomeEvent buildIncomeEvent({
  String id = 'income-1',
  int amountMinor = 30000000,
  int occurredAtMs = 1767225600000,
  int recordedAtMs = 1767225600000,
  int evaluatedAtMs = 1767225600000,
  String ruleVersionId = 'rule-v1',
  String? sourceLabel = 'Salary',
  MoneyScope scope = MoneyScope.personal,
  String? overridesJson,
  String? reversedByEventId,
  bool isReversal = false,
  String? reversesEventId,
  String? note,
  SyncFields? sync,
}) => _require<IncomeEvent>(
  IncomeEvent.create(
    id: id,
    amountMinor: amountMinor,
    occurredAtMs: occurredAtMs,
    recordedAtMs: recordedAtMs,
    evaluatedAtMs: evaluatedAtMs,
    ruleVersionId: ruleVersionId,
    sourceLabel: sourceLabel,
    scope: scope,
    overridesJson: overridesJson,
    reversedByEventId: reversedByEventId,
    isReversal: isReversal,
    reversesEventId: reversesEventId,
    note: note,
    sync: sync ?? syncFields(),
  ),
  'income event',
);

LedgerEntry buildLedgerEntry({
  String id = 'entry-1',
  String categoryId = 'category-groceries',
  LedgerDirection direction = LedgerDirection.inbound,
  int amountMinor = 30000000,
  int occurredAtMs = 1767225600000,
  int recordedAtMs = 1767225600000,
  LedgerSourceType sourceType = LedgerSourceType.allocation,
  String sourceId = 'income-1',
  String? accountId,
  AllocationReason? reason = AllocationReason.base,
  String? redirectedFromCategoryId,
  int? hopCount = 0,
  String? reversesEntryId,
  String? note,
  SyncFields? sync,
}) => _require<LedgerEntry>(
  LedgerEntry.create(
    id: id,
    categoryId: categoryId,
    direction: direction,
    amountMinor: amountMinor,
    occurredAtMs: occurredAtMs,
    recordedAtMs: recordedAtMs,
    sourceType: sourceType,
    sourceId: sourceId,
    accountId: accountId,
    reason: reason,
    redirectedFromCategoryId: redirectedFromCategoryId,
    hopCount: hopCount,
    reversesEntryId: reversesEntryId,
    note: note,
    sync: sync ?? syncFields(),
  ),
  'ledger entry',
);

/// Allocation entries for [event] that conserve exactly.
///
/// Splits the event's amount across [categoryIds], giving any remainder to the
/// **first** category. Deterministic and, more importantly, exact: the sum is
/// the event amount by construction, so a test asserting something else cannot
/// fail on arithmetic it did not intend to test.
List<LedgerEntry> allocationEntriesFor(
  IncomeEvent event,
  List<String> categoryIds,
) {
  final int share = event.amountMinor ~/ categoryIds.length;
  final int remainder = event.amountMinor - share * categoryIds.length;
  return <LedgerEntry>[
    for (int i = 0; i < categoryIds.length; i++)
      buildLedgerEntry(
        id: '${event.id}-entry-$i',
        categoryId: categoryIds[i],
        amountMinor: i == 0 ? share + remainder : share,
        occurredAtMs: event.occurredAtMs,
        recordedAtMs: event.recordedAtMs,
        sourceId: event.id,
      ),
  ];
}

/// Compensating entries mirroring [originals]: same magnitudes, opposite
/// directions, each pointing at the entry it undoes.
///
/// **Mirrors, never recomputes** — ALLOCATION_ALGORITHM §4.8. If the user
/// changed their percentages between the event and the undo, a recomputed split
/// would return every affected balance to the wrong value.
List<LedgerEntry> reversalEntriesFor(
  IncomeEvent reversalEvent,
  List<LedgerEntry> originals,
) => <LedgerEntry>[
  for (int i = 0; i < originals.length; i++)
    buildLedgerEntry(
      id: '${reversalEvent.id}-entry-$i',
      categoryId: originals[i].categoryId,
      accountId: originals[i].accountId,
      direction: originals[i].direction == LedgerDirection.inbound
          ? LedgerDirection.outbound
          : LedgerDirection.inbound,
      amountMinor: originals[i].amountMinor,
      occurredAtMs: reversalEvent.occurredAtMs,
      recordedAtMs: reversalEvent.recordedAtMs,
      sourceType: LedgerSourceType.reversal,
      sourceId: reversalEvent.id,
      reason: originals[i].reason,
      hopCount: originals[i].hopCount,
      reversesEntryId: originals[i].id,
    ),
];

SpendingTransaction buildSpending({
  String id = 'spend-1',
  int amountMinor = 250000,
  String categoryId = 'category-groceries',
  int occurredAtMs = 1767225600000,
  int recordedAtMs = 1767225600000,
  String? accountId,
  String? payee = 'Imtiaz',
  String? note,
  MoneyScope scope = MoneyScope.personal,
  bool isCorrection = false,
  String? correctsTransactionId,
  SyncFields? sync,
}) => _require<SpendingTransaction>(
  SpendingTransaction.create(
    id: id,
    amountMinor: amountMinor,
    categoryId: categoryId,
    occurredAtMs: occurredAtMs,
    recordedAtMs: recordedAtMs,
    accountId: accountId,
    payee: payee,
    note: note,
    scope: scope,
    isCorrection: isCorrection,
    correctsTransactionId: correctsTransactionId,
    sync: sync ?? syncFields(),
  ),
  'spending transaction',
);

/// The single `OUT` entry that [transaction] produces (SCHEMA §3.8).
LedgerEntry spendingEntryFor(
  SpendingTransaction transaction, {
  String? id,
}) => buildLedgerEntry(
  id: id ?? '${transaction.id}-entry',
  categoryId: transaction.categoryId,
  accountId: transaction.accountId,
  direction: LedgerDirection.outbound,
  amountMinor: transaction.amountMinor,
  occurredAtMs: transaction.occurredAtMs,
  recordedAtMs: transaction.recordedAtMs,
  sourceType: LedgerSourceType.spending,
  sourceId: transaction.id,
  reason: null,
  hopCount: null,
);
