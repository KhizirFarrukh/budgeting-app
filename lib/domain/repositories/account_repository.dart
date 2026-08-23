import 'package:pookiebudget/domain/entities/account.dart';
import 'package:pookiebudget/domain/repositories/repository_failure.dart';
import 'package:pookiebudget/domain/repositories/repository_queries.dart';
import 'package:pookiebudget/domain/result.dart';

/// Storage for accounts — **labels with a derived total**, not balances.
///
/// There is no `balanceOf` method here and there will not be one. Under OQ-02's
/// answer an account holds no money of its own; its total is the sum of the
/// balances of the categories linked to it, which is a balance question and
/// belongs to substage 4.6's ledger-derived queries. Putting a total here would
/// create a second place to ask the same question and eventually a second
/// answer (INV-04).
///
/// Deletion is soft throughout, as everywhere else in configuration (INV-10).
abstract interface class AccountRepository {
  /// Accounts matching [query], ordered by `sort_order` then `id`.
  Future<List<Account>> accounts({AccountQuery query = const AccountQuery()});

  /// Reactive [accounts].
  Stream<List<Account>> watchAccounts({
    AccountQuery query = const AccountQuery(),
  });

  /// One account, or null when it does not exist or is tombstoned.
  Future<Account?> accountById(String id, {bool includeDeleted = false});

  Future<Result<void, RepositoryFailure>> createAccount(Account account);

  Future<Result<void, RepositoryFailure>> updateAccount(Account account);

  /// Tombstones the account.
  ///
  /// Fails with [RecordStillReferenced] while live categories link to it,
  /// naming how many. Unlinking them is a decision the user makes in Stage 6 or
  /// the merge makes as the documented `ACCOUNT_UNLINKED` repair — never
  /// something this method does quietly, because a category that silently
  /// forgot which real-world account holds it has lost information the user put
  /// there deliberately.
  Future<Result<void, RepositoryFailure>> deleteAccount(String id);

  /// Hides the account from pickers while keeping its history. Frees the name
  /// for reuse, since U-02 is partial on `is_archived = 0`.
  Future<Result<void, RepositoryFailure>> setAccountArchived(
    String id, {
    required bool archived,
  });
}
