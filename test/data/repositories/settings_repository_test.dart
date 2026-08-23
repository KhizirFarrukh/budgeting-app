import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:pookiebudget/data/database/database.dart';
import 'package:pookiebudget/data/repositories/drift_category_repository.dart';
import 'package:pookiebudget/data/repositories/drift_settings_repository.dart';
import 'package:pookiebudget/domain/entities/app_settings.dart';
import 'package:pookiebudget/domain/entities/enums.dart';
import 'package:pookiebudget/domain/repositories/repository_failure.dart';
import 'package:pookiebudget/domain/repositories/settings_repository.dart';
import 'package:pookiebudget/domain/result.dart';

import '../../support/builders/config_builders.dart';
import '../../support/fakes/fake_clock.dart';
import '../../support/test_database.dart';

void main() {
  late PookieDatabase db;
  late SettingsRepository repo;

  setUp(() async {
    db = await openTestDatabase();
    repo = DriftSettingsRepository(db);
  });

  tearDown(() async => db.close());

  void expectOk(Result<void, RepositoryFailure> result) {
    expect(
      result.isSuccess,
      isTrue,
      reason: 'expected the write to succeed, got ${result.failureOrNull}',
    );
  }

  /// Writes one ledger entry directly, so V-24's precondition — *money has been
  /// recorded* — is genuinely true.
  ///
  /// Raw SQL because `LedgerRepository` is substage 4.5's, and faking the
  /// precondition some other way would test a different rule than the one that
  /// ships.
  Future<void> recordOneLedgerEntry() async {
    final DriftCategoryRepository categories = DriftCategoryRepository(
      db,
      FakeClock(),
    );
    await categories.createGroup(buildGroup());
    await categories.createCategory(buildCategory());
    await db.customStatement(
      'INSERT INTO ledger_entries (id, category_id, direction, amount_minor, '
      'occurred_at_ms, recorded_at_ms, source_type, source_id, '
      'updated_at_ms, updated_by_device, hlc) VALUES '
      "('entry-1', 'category-groceries', 'IN', 1000, 0, 0, 'ALLOCATION', "
      "'income-1', 0, 'device-under-test', 'hlc-1')",
    );
  }

  test('read returns null before onboarding writes a row', () async {
    expect(await repo.read(), isNull);
  });

  test('write creates then updates the single row', () async {
    expectOk(await repo.write(buildSettings()));
    expect((await repo.read())!.currencyCode, 'PKR');

    expectOk(
      await repo.write(
        buildSettings(onboardingState: OnboardingState.complete),
      ),
    );
    final AppSettings? readBack = await repo.read();
    expect(readBack!.onboardingState, OnboardingState.complete);

    // U-09: one settings row, and an update must not create a second.
    expect(await rawCount(db, 'app_settings'), 1);
  });

  test('the stream emits on a write from another code path', () async {
    final List<AppSettings?> emissions = <AppSettings?>[];
    final StreamSubscription<AppSettings?> sub = repo.watch().listen(
      emissions.add,
    );
    await pumpEventQueue();
    expect(emissions, hasLength(1));
    expect(emissions.single, isNull, reason: 'no row yet');

    // A different repository instance over the same database — the shape a
    // background sync writer takes.
    final SettingsRepository other = DriftSettingsRepository(db);
    await other.write(buildSettings());
    await pumpEventQueue();

    expect(emissions, hasLength(2));
    expect(emissions.last!.currencyCode, 'PKR');
    await sub.cancel();
  });

  // ===========================================================================
  // V-24 — the currency exponent is immutable once money exists
  // ===========================================================================

  group('V-24 currency lock', () {
    test('the exponent is free to change while no money is recorded', () async {
      expectOk(await repo.write(buildSettings(currencyMinorExponent: 2)));
      expectOk(
        await repo.write(
          buildSettings(currencyCode: 'JPY', currencyMinorExponent: 0),
        ),
      );
      expect((await repo.read())!.currencyMinorExponent, 0);
    });

    test('CHANGING THE EXPONENT AFTER MONEY EXISTS IS REJECTED', () async {
      expectOk(await repo.write(buildSettings(currencyMinorExponent: 2)));
      await recordOneLedgerEntry();

      final Result<void, RepositoryFailure> result = await repo.write(
        buildSettings(currencyCode: 'JPY', currencyMinorExponent: 0),
      );
      expect(result.isSuccess, isFalse);
      final RepositoryFailure failure = result.failureOrNull!;
      expect(failure, isA<CurrencyLocked>());
      expect((failure as CurrencyLocked).ledgerEntryCount, 1);

      // Unchanged, so no stored amount has been reinterpreted: 12345 still
      // means 123.45 and not 12,345.
      final AppSettings? current = await repo.read();
      expect(current!.currencyMinorExponent, 2);
      expect(current.currencyCode, 'PKR');
    });

    test('everything else stays editable after money exists', () async {
      expectOk(await repo.write(buildSettings(currencyMinorExponent: 2)));
      await recordOneLedgerEntry();

      // Renaming the currency is cosmetic; only the exponent reinterprets
      // stored integers, so only the exponent is locked.
      expectOk(
        await repo.write(
          buildSettings(
            currencyCode: 'RS',
            locale: 'ur_PK',
            businessScopeEnabled: true,
            onboardingState: OnboardingState.complete,
          ),
        ),
      );
      final AppSettings? current = await repo.read();
      expect(current!.currencyCode, 'RS');
      expect(current.locale, 'ur_PK');
      expect(current.businessScopeEnabled, isTrue);
    });
  });
}
