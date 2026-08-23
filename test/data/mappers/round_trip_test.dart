import 'package:drift/drift.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pookiebudget/data/database/database.dart';
import 'package:pookiebudget/data/repositories/drift_account_repository.dart';
import 'package:pookiebudget/data/repositories/drift_category_repository.dart';
import 'package:pookiebudget/data/repositories/drift_rule_repository.dart';
import 'package:pookiebudget/data/repositories/drift_settings_repository.dart';
import 'package:pookiebudget/domain/entities/account.dart';
import 'package:pookiebudget/domain/entities/app_settings.dart';
import 'package:pookiebudget/domain/entities/category.dart';
import 'package:pookiebudget/domain/entities/category_group.dart';
import 'package:pookiebudget/domain/entities/distribution_rule_version.dart';
import 'package:pookiebudget/domain/entities/enums.dart';
import 'package:pookiebudget/domain/entities/redirect_target.dart';
import 'package:pookiebudget/domain/entities/rule_line.dart';
import 'package:pookiebudget/domain/entities/sync_fields.dart';
import 'package:pookiebudget/domain/repositories/repository_failure.dart';
import 'package:pookiebudget/domain/repositories/repository_queries.dart';
import 'package:pookiebudget/domain/result.dart';

import '../../support/builders/config_builders.dart';
import '../../support/fakes/fake_clock.dart';
import '../../support/test_database.dart';

/// Substage 4.4.6: *"Implement mapping between database rows and domain
/// entities in one place, with round-trip tests."*
///
/// ## Why equality is the assertion, not a field-by-field check
///
/// Every entity implements `==` across **all** of its fields. So
/// `expect(readBack, original)` asserts the whole record at once, and — more
/// importantly — it keeps asserting the whole record when a field is added.
/// A test that listed fields explicitly would silently stop covering the
/// seventeenth one the day it was introduced, which is the exact defect this
/// substage names: *"a mapping function updated for writes but not for reads,
/// losing a field silently."*
///
/// ## Why every value is deliberately non-default
///
/// A round trip through a dropped field is invisible when the value happens to
/// equal the column default. If `sortOrder` were left at 0 and the mapper never
/// wrote it, the row would read back as 0 and the test would pass. So each
/// field below carries a distinctive value that no default could produce.
void main() {
  late PookieDatabase db;
  late DriftCategoryRepository categories;
  late DriftAccountRepository accounts;
  late DriftRuleRepository rules;
  late DriftSettingsRepository settings;

  setUp(() async {
    db = await openTestDatabase();
    final FakeClock clock = FakeClock();
    categories = DriftCategoryRepository(db, clock);
    accounts = DriftAccountRepository(db, clock);
    rules = DriftRuleRepository(db, clock);
    settings = DriftSettingsRepository(db);
  });

  tearDown(() async => db.close());

  void expectOk(Result<void, RepositoryFailure> result) {
    expect(
      result.isSuccess,
      isTrue,
      reason: 'expected the write to succeed, got ${result.failureOrNull}',
    );
  }

  /// A sync stamp whose every field differs from anything a default or a
  /// dropped write could produce.
  final SyncFields stamp = syncFields(
    updatedAtMs: 1793491200123,
    updatedByDevice: 'device-round-trip',
    hlc: '1793491200123:0042:device-round-trip',
  );

  // ===========================================================================

  test('CategoryGroup round-trips every field', () async {
    final CategoryGroup original = buildGroup(
      id: 'group-business',
      kind: CategoryGroupKind.business,
      name: 'Business',
      sortOrder: 7,
      isActive: false,
      sync: stamp,
    );
    expectOk(await categories.createGroup(original));

    final CategoryGroup? readBack = await categories.groupById(
      'group-business',
    );
    expect(readBack, original);
  });

  test('Account round-trips every field', () async {
    final Account original = buildAccount(
      id: 'account-business',
      name: 'Meezan business',
      sortOrder: 11,
      institution: 'Meezan Bank',
      lastFour: '4417',
      scope: MoneyScope.business,
      isArchived: true,
      sync: stamp,
    );
    expectOk(await accounts.createAccount(original));

    final Account? readBack = await accounts.accountById('account-business');
    expect(readBack, original);
  });

  group('Category round-trips every field', () {
    setUp(() async {
      expectOk(await categories.createGroup(buildGroup()));
      expectOk(await accounts.createAccount(buildAccount()));
    });

    test('ACCUMULATING_RESERVE — ceiling, split mode, reference amount',
        () async {
      final Category original = buildCategory(
        id: 'category-bike',
        name: 'EV Bike',
        type: CategoryType.accumulatingReserve,
        sortOrder: 42,
        isArchived: true,
        isSuggestedSeed: true,
        seedVersion: 3,
        ceilingMinor: 57500000,
        linkedAccountId: 'account-current',
        redirectMode: RedirectMode.split,
        referenceMonthlyAmountMinor: 19300000,
        sync: stamp,
      );
      expectOk(await categories.createCategory(original));

      // Archived, not deleted — so a default read still finds it. The two
      // states are filtered separately and this is one of the places that
      // proves it.
      final Category? readBack = await categories.categoryById('category-bike');
      expect(readBack, original);
    });

    test('FIXED_RECURRING — bill amount and anchor day', () async {
      final Category original = buildCategory(
        id: 'category-rent',
        name: 'Rent',
        type: CategoryType.fixedRecurring,
        sortOrder: 5,
        billAmountMinor: 12500000,
        periodAnchorDay: 28,
        sync: stamp,
      );
      expectOk(await categories.createCategory(original));

      expect(await categories.categoryById('category-rent'), original);
    });

    test('the sink — isSink survives, uncapped', () async {
      final Category original = buildSink(sortOrder: 99, sync: stamp);
      expectOk(await categories.createCategory(original));

      final Category? readBack = await categories.categoryById('category-sink');
      expect(readBack, original);
      expect(readBack!.isSink, isTrue);
    });

    test('the five reserved columns are written as their v1 defaults',
        () async {
      // C-21 pins these, and the entity has no fields for them — so they are
      // outside the equality assertion above and need their own check. The
      // promise SCHEMA §6.7 makes is that a v1.1 client reading a v1.0 row can
      // trust every one of them holds the default; that is only true if v1
      // actually writes them.
      expectOk(await categories.createCategory(buildCategory()));
      final QueryRow? row = await rawRow(
        db,
        'categories',
        'category-groceries',
      );
      expect(row!.read<String>('ceiling_kind'), 'ABSOLUTE');
      for (final String column in <String>[
        'target_date_ms',
        'ceiling_param',
        'parent_category_id',
        'soft_budget_minor',
        'soft_budget_period',
      ]) {
        expect(
          row.data[column],
          isNull,
          reason: '$column is reserved and unused in v1',
        );
      }
    });
  });

  group('rules round-trip every field', () {
    setUp(() async {
      expectOk(await categories.createGroup(buildGroup()));
      expectOk(await categories.createCategory(buildCategory()));
    });

    test('DistributionRuleVersion, including sealedAtMs and note', () async {
      final DistributionRuleVersion original = buildRuleVersion(
        id: 'rule-sealed',
        effectiveFromMs: 1790000000000,
        createdAtMs: 1789999999000,
        sealedAtMs: 1790000500000,
        note: 'raised savings to 35%',
        sync: stamp,
      );
      expectOk(await rules.createVersion(original));

      final DistributionRuleVersion? readBack = await rules.versionById(
        'rule-sealed',
      );
      expect(readBack, original);
      expect(
        readBack!.isSealed,
        isTrue,
        reason: 'INV-11 rests on this field surviving storage',
      );
    });

    test('RuleLine, both scopes', () async {
      expectOk(await rules.createVersion(buildRuleVersion()));

      final RuleLine groupLine = buildGroupLine(
        id: 'line-g',
        basisPoints: 3750,
        sync: stamp,
      );
      final RuleLine categoryLine = buildCategoryLine(
        id: 'line-c',
        basisPoints: 6250,
        sync: stamp,
      );
      expectOk(await rules.createLine(groupLine));
      expectOk(await rules.createLine(categoryLine));

      final List<RuleLine> lines = await rules.linesFor('rule-v1');
      expect(lines, hasLength(2));
      expect(
        lines.firstWhere((RuleLine l) => l.id == 'line-g'),
        groupLine,
      );
      expect(
        lines.firstWhere((RuleLine l) => l.id == 'line-c'),
        categoryLine,
      );
    });
  });

  group('RedirectTarget round-trips every field', () {
    setUp(() async {
      expectOk(await categories.createGroup(buildGroup()));
      expectOk(await categories.createCategory(buildSink()));
      expectOk(
        await categories.createCategory(
          buildCategory(id: 'category-goal', name: 'EV Bike'),
        ),
      );
    });

    test('SPLIT — a weighted share survives', () async {
      final RedirectTarget original = buildRedirectTarget(
        priority: 9,
        basisPoints: 2500,
        sync: stamp,
      );
      expectOk(await categories.createRedirectTarget(original));

      final List<RedirectTarget> targets = await categories.redirectTargetsFor(
        'category-goal',
      );
      expect(targets.single, original);
    });

    test('PRIORITY — an absent share stays absent, not zero', () async {
      // The distinction the schema comment insists on: "0 is a meaningful
      // share". A mapper that defaulted null to 0 would turn "not weighted"
      // into "weighted at nothing", and the two behave differently under SPLIT.
      final RedirectTarget original = buildRedirectTarget(
        priority: 4,
        sync: stamp,
      );
      expectOk(await categories.createRedirectTarget(original));

      final List<RedirectTarget> targets = await categories.redirectTargetsFor(
        'category-goal',
      );
      expect(targets.single, original);
      expect(targets.single.basisPoints, isNull);
    });
  });

  test('AppSettings round-trips every field', () async {
    expectOk(await categories.createGroup(buildGroup()));
    expectOk(await categories.createCategory(buildSink()));
    expectOk(
      await categories.createCategory(
        buildCategory(id: 'category-business-sink', name: 'Business float'),
      ),
    );
    expectOk(await rules.createVersion(buildRuleVersion()));

    final AppSettings original = buildSettings(
      currencyCode: 'KWD',
      currencyMinorExponent: 3,
      locale: 'ar_KW',
      businessScopeEnabled: true,
      personalSinkCategoryId: 'category-sink',
      businessSinkCategoryId: 'category-business-sink',
      onboardingState: OnboardingState.complete,
      onboardingStep: 4,
      activeRuleVersionId: 'rule-v1',
      sync: stamp,
    );
    expectOk(await settings.write(original));

    expect(await settings.read(), original);
  });

  // ===========================================================================
  // The sync columns, called out separately
  // ===========================================================================

  test('THE FIVE SYNC COLUMNS SURVIVE ON EVERY SYNCED ENTITY', () async {
    // These are the fields most easily forgotten, because nothing in the app
    // reads them until Stage 7 — at which point a dropped `hlc` is a merge
    // that orders edits wrongly rather than a test that fails.
    expectOk(await categories.createGroup(buildGroup(sync: stamp)));
    expectOk(await categories.createCategory(buildCategory(sync: stamp)));
    expectOk(await accounts.createAccount(buildAccount(sync: stamp)));

    final CategoryGroup group = (await categories.groups()).single;
    final Category category = (await categories.categories()).single;
    final Account account = (await accounts.accounts()).single;

    for (final SyncFields actual in <SyncFields>[
      group.sync,
      category.sync,
      account.sync,
    ]) {
      expect(actual.updatedAtMs, 1793491200123);
      expect(actual.updatedByDevice, 'device-round-trip');
      expect(actual.hlc, '1793491200123:0042:device-round-trip');
      expect(actual.isDeleted, isFalse);
      expect(actual.deletedAtMs, isNull);
    }
  });

  test('a tombstone round-trips as a tombstone', () async {
    expectOk(await categories.createGroup(buildGroup()));
    expectOk(await categories.createCategory(buildCategory()));
    expectOk(await categories.deleteCategory('category-groceries'));

    final Category tombstoned = (await categories.categories(
      query: const CategoryQuery(includeDeleted: true),
    )).single;
    expect(tombstoned.sync.isDeleted, isTrue);
    expect(tombstoned.sync.deletedAtMs, isNotNull);
  });
}
