import 'package:drift/drift.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pookiebudget/data/database/database.dart';
import 'package:pookiebudget/data/repositories/drift_account_repository.dart';
import 'package:pookiebudget/data/repositories/drift_category_repository.dart';
import 'package:pookiebudget/domain/entities/account.dart';
import 'package:pookiebudget/domain/entities/enums.dart';
import 'package:pookiebudget/domain/repositories/account_repository.dart';
import 'package:pookiebudget/domain/repositories/repository_failure.dart';
import 'package:pookiebudget/domain/repositories/repository_queries.dart';
import 'package:pookiebudget/domain/result.dart';

import '../../support/builders/config_builders.dart';
import '../../support/fakes/fake_clock.dart';
import '../../support/test_database.dart';

void main() {
  late PookieDatabase db;
  late FakeClock clock;
  late AccountRepository repo;
  late DriftCategoryRepository categories;

  setUp(() async {
    db = await openTestDatabase();
    clock = FakeClock();
    repo = DriftAccountRepository(db, clock);
    categories = DriftCategoryRepository(db, clock);
  });

  tearDown(() async => db.close());

  void expectOk(Result<void, RepositoryFailure> result) {
    expect(
      result.isSuccess,
      isTrue,
      reason: 'expected the write to succeed, got ${result.failureOrNull}',
    );
  }

  RepositoryFailure expectRejected(Result<void, RepositoryFailure> result) {
    expect(result.isSuccess, isFalse, reason: 'expected a rejection');
    return result.failureOrNull!;
  }

  test('CRUD round trip', () async {
    expectOk(await repo.createAccount(buildAccount()));
    expect((await repo.accounts()).single.name, 'Current account');

    expectOk(
      await repo.updateAccount(
        buildAccount(name: 'Current account', institution: 'Meezan Bank'),
      ),
    );
    expect((await repo.accounts()).single.institution, 'Meezan Bank');
  });

  test('U-02 — a duplicate live name is rejected, archiving frees it',
      () async {
    expectOk(await repo.createAccount(buildAccount(id: 'a')));
    expect(
      expectRejected(await repo.createAccount(buildAccount(id: 'b'))),
      isA<DuplicateName>(),
    );

    expectOk(await repo.setAccountArchived('a', archived: true));
    expectOk(await repo.createAccount(buildAccount(id: 'b')));
    expect(await repo.accounts(), hasLength(1));
  });

  test('deletion is soft — the row survives with a tombstone', () async {
    expectOk(await repo.createAccount(buildAccount()));
    clock.advance(const Duration(days: 2));
    final int deletedAt = clock.peek();

    expectOk(await repo.deleteAccount('account-current'));

    expect(await repo.accounts(), isEmpty);
    expect(await repo.accountById('account-current'), isNull);

    final QueryRow? row = await rawRow(db, 'accounts', 'account-current');
    expect(
      row,
      isNotNull,
      reason: 'INV-10: configuration is never hard-deleted',
    );
    expect(row!.read<int>('is_deleted'), 1);
    expect(row.read<int>('deleted_at_ms'), deletedAt);
  });

  test('an account still linked to categories cannot be deleted', () async {
    expectOk(await categories.createGroup(buildGroup()));
    expectOk(await repo.createAccount(buildAccount()));
    expectOk(
      await categories.createCategory(
        buildCategory(linkedAccountId: 'account-current'),
      ),
    );

    final RepositoryFailure failure = expectRejected(
      await repo.deleteAccount('account-current'),
    );
    expect(failure, isA<RecordStillReferenced>());
    expect(
      failure.describe,
      contains('1'),
      reason: 'the message names how many links block the delete',
    );

    // The rejection must have rolled back cleanly: the account is still live.
    expect(await repo.accountById('account-current'), isNotNull);

    // Unlinking is the user's decision, and once made the delete proceeds.
    expectOk(
      await categories.updateCategory(
        buildCategory(),
      ),
    );
    expectOk(await repo.deleteAccount('account-current'));
  });

  group('filters', () {
    setUp(() async {
      expectOk(
        await repo.createAccount(
          buildAccount(id: 'a-1', name: 'Personal', sortOrder: 1),
        ),
      );
      expectOk(
        await repo.createAccount(
          buildAccount(
            id: 'a-2',
            name: 'Business',
            sortOrder: 2,
            scope: MoneyScope.business,
          ),
        ),
      );
      expectOk(
        await repo.createAccount(
          buildAccount(
            id: 'a-3',
            name: 'Closed',
            sortOrder: 3,
            isArchived: true,
          ),
        ),
      );
    });

    test('by scope', () async {
      final List<Account> business = await repo.accounts(
        query: const AccountQuery(scopeWireName: 'BUSINESS'),
      );
      expect(business.map((Account a) => a.id), <String>['a-2']);
    });

    test('by archived state', () async {
      expect(
        (await repo.accounts()).map((Account a) => a.id),
        <String>['a-1', 'a-2'],
      );
      expect(
        (await repo.accounts(
          query: const AccountQuery(archived: ArchivedFilter.archivedOnly),
        )).map((Account a) => a.id),
        <String>['a-3'],
      );
      expect(
        await repo.accounts(
          query: const AccountQuery(archived: ArchivedFilter.any),
        ),
        hasLength(3),
      );
    });

    test('archived and deleted are filtered independently', () async {
      expectOk(await repo.deleteAccount('a-1'));
      expect(
        await repo.accounts(
          query: const AccountQuery(archived: ArchivedFilter.any),
        ),
        hasLength(2),
        reason: 'asking for archived rows must not also return deleted ones',
      );
      expect(
        await repo.accounts(
          query: const AccountQuery(
            archived: ArchivedFilter.any,
            includeDeleted: true,
          ),
        ),
        hasLength(3),
      );
    });
  });
}
