import 'package:pookiebudget/domain/entities/entity_failure.dart';
import 'package:pookiebudget/domain/entities/enums.dart';
import 'package:pookiebudget/domain/entities/sync_fields.dart';
import 'package:pookiebudget/domain/result.dart';

/// The user-facing record behind an outgoing movement.
///
/// One row produces exactly one `OUT` ledger entry. Kept separate from
/// `LedgerEntry` because a transaction is editable and a ledger entry is not
/// (SCHEMA §2.2) — a correction writes three rows: a compensating ledger entry
/// cancelling the original, a new transaction, and its ledger entry. The
/// original stays visible (US-026).
final class SpendingTransaction {
  const SpendingTransaction._({
    required this.id,
    required this.amountMinor,
    required this.categoryId,
    required this.accountId,
    required this.occurredAtMs,
    required this.recordedAtMs,
    required this.payee,
    required this.note,
    required this.scope,
    required this.isCorrection,
    required this.correctsTransactionId,
    required this.sync,
  });

  static Result<SpendingTransaction, EntityFailure> create({
    required String id,
    required int amountMinor,
    required String categoryId,
    required int occurredAtMs,
    required int recordedAtMs,
    required SyncFields sync,
    String? accountId,
    String? payee,
    String? note,
    MoneyScope scope = MoneyScope.personal,
    bool isCorrection = false,
    String? correctsTransactionId,
  }) {
    if (amountMinor <= 0) {
      return Failure<SpendingTransaction, EntityFailure>(
        NonPositiveAmount(field: 'amount_minor', value: amountMinor),
      );
    }
    return Success<SpendingTransaction, EntityFailure>(
      SpendingTransaction._(
        id: id,
        amountMinor: amountMinor,
        categoryId: categoryId,
        accountId: accountId,
        occurredAtMs: occurredAtMs,
        recordedAtMs: recordedAtMs,
        payee: payee,
        note: note,
        scope: scope,
        isCorrection: isCorrection,
        correctsTransactionId: correctsTransactionId,
        sync: sync,
      ),
    );
  }

  /// UUID v7.
  final String id;

  /// Positive.
  final int amountMinor;

  final String categoryId;

  /// Defaulted from the category's link, overridable.
  final String? accountId;

  final int occurredAtMs;
  final int recordedAtMs;
  final String? payee;
  final String? note;
  final MoneyScope scope;

  /// True when this replaces a corrected entry.
  final bool isCorrection;

  final String? correctsTransactionId;
  final SyncFields sync;

  Result<SpendingTransaction, EntityFailure> copyWith({
    int? amountMinor,
    String? categoryId,
    String? accountId,
    int? occurredAtMs,
    int? recordedAtMs,
    String? payee,
    String? note,
    MoneyScope? scope,
    bool? isCorrection,
    String? correctsTransactionId,
    SyncFields? sync,
    bool clearAccount = false,
    bool clearPayee = false,
    bool clearNote = false,
  }) => SpendingTransaction.create(
    id: id,
    amountMinor: amountMinor ?? this.amountMinor,
    categoryId: categoryId ?? this.categoryId,
    accountId: clearAccount ? null : (accountId ?? this.accountId),
    occurredAtMs: occurredAtMs ?? this.occurredAtMs,
    recordedAtMs: recordedAtMs ?? this.recordedAtMs,
    payee: clearPayee ? null : (payee ?? this.payee),
    note: clearNote ? null : (note ?? this.note),
    scope: scope ?? this.scope,
    isCorrection: isCorrection ?? this.isCorrection,
    correctsTransactionId: correctsTransactionId ?? this.correctsTransactionId,
    sync: sync ?? this.sync,
  );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SpendingTransaction &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          amountMinor == other.amountMinor &&
          categoryId == other.categoryId &&
          accountId == other.accountId &&
          occurredAtMs == other.occurredAtMs &&
          recordedAtMs == other.recordedAtMs &&
          payee == other.payee &&
          note == other.note &&
          scope == other.scope &&
          isCorrection == other.isCorrection &&
          correctsTransactionId == other.correctsTransactionId &&
          sync == other.sync;

  @override
  int get hashCode => Object.hashAll(<Object?>[
    id,
    amountMinor,
    categoryId,
    accountId,
    occurredAtMs,
    recordedAtMs,
    payee,
    note,
    scope,
    isCorrection,
    correctsTransactionId,
    sync,
  ]);

  @override
  String toString() =>
      'SpendingTransaction($id, $amountMinor, $categoryId, '
      '${scope.wireName})';
}
