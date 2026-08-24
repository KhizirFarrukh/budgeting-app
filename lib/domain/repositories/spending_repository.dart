import 'package:pookiebudget/domain/entities/ledger_entry.dart';
import 'package:pookiebudget/domain/entities/spending_transaction.dart';
import 'package:pookiebudget/domain/repositories/repository_failure.dart';
import 'package:pookiebudget/domain/repositories/repository_queries.dart';
import 'package:pookiebudget/domain/result.dart';

/// Recording money leaving, and correcting a record of it.
///
/// # Why this is a third interface and not part of the other two
///
/// `ARCHITECTURE.md` §2.2 lists six repositories and does not name this one.
/// The two candidate homes are both worse:
///
/// - **`LedgerRepository`** exists to expose no mutation at all. Spending
///   transactions are correctable records, and putting a correctable record
///   behind the interface whose defining property is immutability blurs exactly
///   the line substage 4.5 is drawing.
/// - **`IncomeEventRepository`** is money arriving. Money leaving is not a
///   variant of that; sharing an interface would only mean sharing a
///   transaction helper, which they already do at the data layer.
///
/// `SpendingTransaction` is a distinct record class with its own reads (Q14)
/// and its own correction semantics, so it gets its own contract. Recorded in
/// the worklog and flagged for substage 4.11 to fold back into
/// `ARCHITECTURE.md`, which is now two rows out of date — this and
/// `RedirectTarget` from ADR-006.
///
/// # Correction supersedes; it does not edit
///
/// SCHEMA §2.2 calls a spending transaction *editable* and a ledger entry not.
/// "Editable" here means **correctable**, and the correction is three rows
/// written together (US-026):
///
/// 1. a compensating `IN` ledger entry cancelling the original's `OUT`;
/// 2. a new transaction, flagged `is_correction` and pointing at the original;
/// 3. that transaction's own `OUT` entry.
///
/// The original transaction and its entry both stay exactly as written and stay
/// visible. So this interface has no `updateTransaction` either — the shape of
/// a correction is a new record, at every level of the design.
abstract interface class SpendingRepository {
  /// Records spending and its single `OUT` ledger entry atomically.
  ///
  /// SCHEMA §3.8: one transaction row produces exactly one entry. The pairing
  /// is checked, not assumed — an entry naming a different category or a
  /// different amount than its transaction would make the history screen and
  /// the balance disagree, each correct about a different number.
  Future<Result<void, RepositoryFailure>> record({
    required SpendingTransaction transaction,
    required LedgerEntry entry,
  });

  /// Supersedes [originalTransactionId] with a corrected record, atomically.
  ///
  /// Writes all three rows or none. [compensatingEntry] must cancel the
  /// original's entry exactly — same magnitude, opposite direction — for the
  /// same reason a reversal mirrors rather than recomputes: it is the only way
  /// the affected balance returns to precisely where it was.
  Future<Result<void, RepositoryFailure>> correct({
    required String originalTransactionId,
    required LedgerEntry compensatingEntry,
    required SpendingTransaction replacement,
    required LedgerEntry replacementEntry,
  });

  /// Spending for a category in a date range, newest first. Serves Q14 via
  /// IX-10.
  Future<List<SpendingTransaction>> transactionsForCategory(
    String categoryId, {
    DateRange? within,
    bool includeDeleted = false,
  });

  /// All spending in a range, newest first.
  Future<List<SpendingTransaction>> transactions({
    DateRange? within,
    int? limit,
    int offset = 0,
    bool includeDeleted = false,
  });

  /// Reactive [transactionsForCategory].
  Stream<List<SpendingTransaction>> watchTransactionsForCategory(
    String categoryId,
  );

  /// One transaction, or null.
  Future<SpendingTransaction?> transactionById(
    String id, {
    bool includeDeleted = false,
  });

  /// The transaction that corrects [transactionId], or null.
  ///
  /// A lookup, exactly as `LedgerRepository.isReversed` is: the original is not
  /// stamped with "superseded", the successor points back at it.
  Future<SpendingTransaction?> correctionOf(String transactionId);
}
