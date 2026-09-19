import 'package:drift/drift.dart';
import 'package:pookiebudget/data/database/database.dart';
import 'package:pookiebudget/data/mappers/account_mappers.dart';
import 'package:pookiebudget/data/repositories/repository_support.dart';
import 'package:pookiebudget/data/validation/configuration_guard.dart';
import 'package:pookiebudget/domain/entities/account.dart';
import 'package:pookiebudget/domain/money/clock.dart';
import 'package:pookiebudget/domain/repositories/account_repository.dart';
import 'package:pookiebudget/domain/repositories/repository_failure.dart';
import 'package:pookiebudget/domain/repositories/repository_queries.dart';
import 'package:pookiebudget/domain/result.dart';
import 'package:pookiebudget/domain/validation/validators.dart';

/// The database-backed [AccountRepository].
class DriftAccountRepository implements AccountRepository {
  DriftAccountRepository(this._db, this._clock);

  final PookieDatabase _db;
  final Clock _clock;

  /// Substage 4.8.4 — see `DriftCategoryRepository`.
  late final ConfigurationGuard _guard = ConfigurationGuard(_db);

  @override
  Future<List<Account>> accounts({
    AccountQuery query = const AccountQuery(),
  }) async {
    final List<AccountRow> rows = await _accountSelect(query).get();
    return rows.map(accountFromRow).toList();
  }

  @override
  Stream<List<Account>> watchAccounts({
    AccountQuery query = const AccountQuery(),
  }) => _accountSelect(
    query,
  ).watch().map((List<AccountRow> rows) => rows.map(accountFromRow).toList());

  /// The single place an account list is filtered and ordered.
  SimpleSelectStatement<$AccountsTable, AccountRow> _accountSelect(
    AccountQuery query,
  ) =>
      _db.select(_db.accounts)
        ..where(
          (t) =>
              tombstoneTerm(t.isDeleted, includeDeleted: query.includeDeleted) &
              archivedTerm(t.isArchived, query.archived) &
              optionalEquals(t.scope, query.scopeWireName),
        )
        ..orderBy([
          (t) => OrderingTerm(expression: t.sortOrder),
          (t) => OrderingTerm(expression: t.id),
        ]);

  @override
  Future<Account?> accountById(
    String id, {
    bool includeDeleted = false,
  }) async {
    final AccountRow? row = await _accountRow(id, includeDeleted);
    return row == null ? null : accountFromRow(row);
  }

  @override
  Future<Result<void, RepositoryFailure>> createAccount(Account account) =>
      writeTransaction(_db, () async {
        await _rejectIfNameTaken(account);
        await _db.into(_db.accounts).insert(accountToCompanion(account));
      });

  @override
  Future<Result<void, RepositoryFailure>> updateAccount(Account account) =>
      writeTransaction(_db, () async {
        await _rejectIfNameTaken(account);
        final int changed =
            await (_db.update(_db.accounts)..where(
                  (t) =>
                      t.id.equals(account.id) &
                      tombstoneTerm(t.isDeleted, includeDeleted: false),
                ))
                .write(accountToCompanion(account));
        if (changed == 0) {
          reject(RecordNotFound(entity: 'account', id: account.id));
        }
      });

  @override
  Future<Result<void, RepositoryFailure>> deleteAccount(String id) =>
      writeTransaction(_db, () async {
        final AccountRow? row = await _accountRow(id, false);
        if (row == null) {
          reject(RecordNotFound(entity: 'account', id: id));
        }

        // V-21 — a category that silently forgot which real-world account holds
        // its money has lost information the user put there deliberately. So
        // the repository reports the links and stops; unlinking is a decision,
        // made by the user in Stage 6 or by the documented `ACCOUNT_UNLINKED`
        // repair in a Stage 7 merge.
        //
        // Routed through the validator rather than counted inline, as substage
        // 4.8 does for every numbered rule. It is also the better failure:
        // V-21's disposition is "block; **list** the linked categories", and
        // `AccountStillLinked` names them where the old inline check reported
        // only how many there were.
        await _guard.rejectIf(
          (ConfigurationSnapshot s) => validateCanDeleteAccount(s, id),
        );

        final int nowMs = _clock.nowMs();
        await _db.customUpdate(
          'UPDATE accounts '
          'SET is_deleted = 1, deleted_at_ms = ?, updated_at_ms = ? '
          'WHERE id = ?',
          variables: <Variable<Object>>[
            Variable<int>(nowMs),
            Variable<int>(nowMs),
            Variable<String>(id),
          ],
          // Declaring the update is what makes every open `.watch()` on this
          // table re-emit (substage 4.4.4).
          updates: <TableInfo<Table, Object?>>{_db.accounts},
        );
      });

  @override
  Future<Result<void, RepositoryFailure>> setAccountArchived(
    String id, {
    required bool archived,
  }) => writeTransaction(_db, () async {
    final AccountRow? row = await _accountRow(id, false);
    if (row == null) {
      reject(RecordNotFound(entity: 'account', id: id));
    }
    await (_db.update(_db.accounts)..where((t) => t.id.equals(id))).write(
      AccountsCompanion(
        isArchived: Value<bool>(archived),
        updatedAtMs: Value<int>(_clock.nowMs()),
      ),
    );
  });

  Future<AccountRow?> _accountRow(String id, bool includeDeleted) =>
      (_db.select(_db.accounts)..where(
            (t) =>
                t.id.equals(id) &
                tombstoneTerm(t.isDeleted, includeDeleted: includeDeleted),
          ))
          .getSingleOrNull();

  /// U-02 — an account name is unique among live, non-archived rows.
  ///
  /// Partial in exactly the way the index is: archiving frees the name, so the
  /// old "Meezan — closed" account does not block naming its replacement.
  Future<void> _rejectIfNameTaken(Account account) async {
    if (account.isArchived) return;
    final List<AccountRow> clashes =
        await (_db.select(_db.accounts)..where(
              (t) =>
                  t.name.equals(account.name) &
                  t.isArchived.equals(false) &
                  t.isDeleted.equals(false) &
                  t.id.equals(account.id).not(),
            ))
            .get();
    if (clashes.isNotEmpty) {
      reject(DuplicateName(entity: 'account', name: account.name));
    }
  }
}
