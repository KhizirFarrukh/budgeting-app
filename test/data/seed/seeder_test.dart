import 'package:flutter_test/flutter_test.dart';
import 'package:pookiebudget/data/database/database.dart';
import 'package:pookiebudget/data/repositories/drift_category_repository.dart';
import 'package:pookiebudget/data/repositories/drift_rule_repository.dart';
import 'package:pookiebudget/data/repositories/drift_settings_repository.dart';
import 'package:pookiebudget/data/seed/seed_data.dart';
import 'package:pookiebudget/data/seed/seeder.dart';
import 'package:pookiebudget/domain/entities/app_settings.dart';
import 'package:pookiebudget/domain/entities/category.dart';
import 'package:pookiebudget/domain/entities/category_group.dart';
import 'package:pookiebudget/domain/entities/distribution_rule_version.dart';
import 'package:pookiebudget/domain/entities/entity_failure.dart';
import 'package:pookiebudget/domain/entities/enums.dart';
import 'package:pookiebudget/domain/entities/rule_line.dart';
import 'package:pookiebudget/domain/repositories/repository_failure.dart';
import 'package:pookiebudget/domain/result.dart';

import '../../support/builders/config_builders.dart';
import '../../support/fakes/fake_clock.dart';
import '../../support/fakes/fake_id_generator.dart';
import '../../support/test_database.dart';

/// Substage 4.7 — FR-08, NFR-04, INV-07.
void main() {
  late PookieDatabase db;
  late FakeClock clock;
  late Seeder seeder;
  late DriftCategoryRepository categories;
  late DriftRuleRepository rules;
  late DriftSettingsRepository settings;

  setUp(() async {
    db = await openTestDatabase();
    clock = FakeClock();
    seeder = Seeder(db, FakeIdGenerator(prefix: 'seed'), clock);
    categories = DriftCategoryRepository(db, clock);
    rules = DriftRuleRepository(db, clock);
    settings = DriftSettingsRepository(db);
    // The seeder needs a currency exponent, so onboarding writes settings
    // first. Making the ordering explicit here matches what the app does.
    await settings.write(buildSettings());
  });

  tearDown(() async => db.close());

  void expectOk(Result<void, RepositoryFailure> result) {
    expect(
      result.isSuccess,
      isTrue,
      reason: 'expected the seed to succeed, got ${result.failureOrNull}',
    );
  }

  Future<void> seedPersonal({int exponent = 2}) async => expectOk(
    await seeder.seed(currencyMinorExponent: exponent, deviceId: 'device-test'),
  );

  // ===========================================================================
  // 4.7.3 — the percentages, checked before anything else
  // ===========================================================================

  group('4.7.3 default percentages total exactly 10000', () {
    // Written first and deliberately as pure arithmetic, with no database in
    // sight. The named pitfall is "default percentages that total 9999 because
    // of a hand-computed split, which blocks onboarding" — so this must fail
    // for the numbers themselves, not for anything about how they are stored.

    test('GROUP SHARES TOTAL 10000, WITH AND WITHOUT BUSINESS', () {
      expect(
        kPersonalGroupShares.values.reduce((int a, int b) => a + b),
        10000,
      );
      expect(
        kBusinessGroupShares.values.reduce((int a, int b) => a + b),
        10000,
      );
    });

    test('EVERY GROUP\'S CATEGORY SHARES TOTAL 10000', () {
      for (final CategoryGroupKind kind in CategoryGroupKind.values) {
        final Map<String, int> shares = categoryShares(suggestionsFor(kind));
        expect(
          shares.values.reduce((int a, int b) => a + b),
          10000,
          reason:
              '${kind.wireName} shares total something other than 10000, which '
              'V-02 rejects and onboarding cannot get past',
        );
      }
    });

    test('distributeEvenly is exact for every count that could arise', () {
      // Nine savings categories at a hand-computed 1111 total 9999. The point
      // of computing them is that no count can produce that.
      for (int parts = 1; parts <= 40; parts++) {
        final List<int> shares = distributeEvenly(10000, parts);
        expect(shares, hasLength(parts));
        expect(
          shares.reduce((int a, int b) => a + b),
          10000,
          reason: 'a split into $parts parts did not total 10000',
        );
        // The remainder is spread one unit at a time, so no share is more than
        // one basis point from any other — a split that dumped the whole
        // remainder on one category would be arbitrary.
        final int largest = shares.reduce((int a, int b) => a > b ? a : b);
        final int smallest = shares.reduce((int a, int b) => a < b ? a : b);
        expect(largest - smallest, lessThanOrEqualTo(1));
      }
    });

    test('the sink gets a zero share, not an absent one', () {
      final Map<String, int> shares = categoryShares(kSpendingSuggestions);
      expect(shares.containsKey('unallocated_surplus'), isTrue);
      expect(
        shares['unallocated_surplus'],
        0,
        reason:
            'the sink is where overflow lands, not a destination the user '
            'chose a percentage for. A base share would divert income away '
            'from the goals they actually set.',
      );
    });
  });

  // ===========================================================================
  // 4.7.1, 4.7.2, 4.7.4 — what gets written
  // ===========================================================================

  group('seeding an empty database', () {
    test('creates the personal groups and their suggestions', () async {
      await seedPersonal();

      expect(await categories.groups(), hasLength(2));
      expect(
        (await categories.groups())
            .map((CategoryGroup g) => g.kind)
            .toSet(),
        <CategoryGroupKind>{
          CategoryGroupKind.spending,
          CategoryGroupKind.savings,
        },
      );

      final List<Category> all = await categories.categories();
      expect(
        all,
        hasLength(kSpendingSuggestions.length + kSavingsSuggestions.length),
      );
      expect(
        all.map((Category c) => c.name),
        containsAll(<String>['Groceries', 'Hajj fund', 'Unallocated Surplus']),
      );
    });

    test('PRD A-20 — a personal-only user has no business group at all',
        () async {
      await seedPersonal();
      expect(await categories.groupByKind(CategoryGroupKind.business), isNull);
      expect(
        (await categories.categories()).map((Category c) => c.name),
        isNot(contains('Business miscellaneous')),
      );
    });

    test('4.7.1 — each suggestion carries its suggested type', () async {
      await seedPersonal();
      final List<Category> all = await categories.categories();

      Category named(String name) =>
          all.firstWhere((Category c) => c.name == name);

      expect(named('Groceries').type, CategoryType.uncappedFlow);
      expect(named('Mobile/Internet').type, CategoryType.fixedRecurring);
      expect(named('Hajj fund').type, CategoryType.accumulatingReserve);
    });

    test('4.7.2 — every seeded row is flagged and versioned', () async {
      await seedPersonal();
      for (final Category category in await categories.categories()) {
        expect(category.isSuggestedSeed, isTrue, reason: category.name);
        expect(category.seedVersion, kSeedVersion, reason: category.name);
      }
    });

    test('amounts scale to the currency exponent, never to two decimals',
        () async {
      // The same seed set in a 0-decimal and a 3-decimal currency. Hardcoding
      // two decimal places would make a Hajj ceiling 1000x wrong in KWD.
      await seedPersonal();
      final Category hajjPkr = (await categories.categories()).firstWhere(
        (Category c) => c.name == 'Hajj fund',
      );
      expect(hajjPkr.ceilingMinor, 1500000 * 100);

      // A second, independent database rather than reopening `db` — the outer
      // tearDown owns that one, and closing it here would leave the teardown
      // closing an already-closed handle.
      final PookieDatabase jpyDb = await openTestDatabase();
      addTearDown(jpyDb.close);

      await DriftSettingsRepository(jpyDb).write(
        buildSettings(currencyCode: 'JPY', currencyMinorExponent: 0),
      );
      expectOk(
        await Seeder(jpyDb, FakeIdGenerator(prefix: 'seed'), clock).seed(
          currencyMinorExponent: 0,
          deviceId: 'device-test',
        ),
      );
      final Category hajjJpy =
          (await DriftCategoryRepository(jpyDb, clock).categories()).firstWhere(
            (Category c) => c.name == 'Hajj fund',
          );
      expect(
        hajjJpy.ceilingMinor,
        1500000,
        reason:
            'JPY has no minor units, so the ceiling is the major figure '
            'unscaled. Hardcoding two decimal places would make it 100x wrong.',
      );
    });

    test('INV-07 — the sink exists, is uncapped, and settings point at it',
        () async {
      await seedPersonal();

      final Category? sink = await categories.sinkForGroup(
        (await categories.groupByKind(CategoryGroupKind.spending))!.id,
      );
      expect(sink, isNotNull);
      expect(sink!.name, 'Unallocated Surplus');
      expect(sink.type, CategoryType.uncappedFlow);
      expect(sink.ceilingMinor, isNull);
      expect(sink.billAmountMinor, isNull);

      final AppSettings? stored = await settings.read();
      expect(stored!.personalSinkCategoryId, sink.id);
      expect(
        stored.businessSinkCategoryId,
        isNull,
        reason: 'no business group was seeded, so there is no business sink',
      );
    });

    test('the sink cannot be deleted, but everything else can', () async {
      await seedPersonal();
      final List<Category> all = await categories.categories();
      final Category sink = all.firstWhere((Category c) => c.isSink);

      expect(
        (await categories.deleteCategory(sink.id)).failureOrNull,
        isA<SinkProtected>(),
      );

      // "Do not make any seeded category permanent or uneditable, except the
      // sink's existence." Every other suggestion is genuinely removable.
      for (final Category category in all.where((Category c) => !c.isSink)) {
        final Result<void, RepositoryFailure> deleted = await categories
            .deleteCategory(category.id);
        expect(
          deleted.isSuccess,
          isTrue,
          reason: '${category.name} should be removable, '
              'got ${deleted.failureOrNull}',
        );
      }
    });

    test('every seeded category can be renamed, retyped and re-ceilinged',
        () async {
      await seedPersonal();
      final Category hajj = (await categories.categories()).firstWhere(
        (Category c) => c.name == 'Hajj fund',
      );

      final Result<Category, EntityFailure> renamed = hajj.copyWith(
        name: 'Umrah fund',
        ceilingMinor: 99999,
      );
      expectOk(await categories.updateCategory(renamed.valueOrNull!));

      final Category updated = (await categories.categories()).firstWhere(
        (Category c) => c.id == hajj.id,
      );
      expect(updated.name, 'Umrah fund');
      expect(updated.ceilingMinor, 99999);
      expect(
        updated.isSuggestedSeed,
        isTrue,
        reason: 'the flag records provenance; it confers no protection',
      );
    });

    test('the seeded rule version is left unsealed for onboarding to edit',
        () async {
      await seedPersonal();
      final DistributionRuleVersion? draft = await rules.draftVersion();
      expect(draft, isNotNull);
      expect(draft!.isSealed, isFalse);
      expect((await settings.read())!.activeRuleVersionId, draft.id);

      final List<RuleLine> lines = await rules.linesFor(draft.id);
      expect(
        lines.where((RuleLine l) => l.scope == RuleLineScope.group),
        hasLength(2),
      );
      expect(
        lines.where((RuleLine l) => l.scope == RuleLineScope.category),
        hasLength(kSpendingSuggestions.length + kSavingsSuggestions.length),
      );
    });
  });

  // ===========================================================================
  // 4.7.5 — idempotent
  // ===========================================================================

  group('4.7.5 running the seeder twice is a no-op', () {
    test('ROW COUNTS AND TIMESTAMPS ARE UNCHANGED BY A SECOND RUN', () async {
      await seedPersonal();

      final int groupsBefore = await rawCount(db, 'category_groups');
      final int categoriesBefore = await rawCount(db, 'categories');
      final int linesBefore = await rawCount(db, 'rule_lines');
      final int versionsBefore = await rawCount(
        db,
        'distribution_rule_versions',
      );
      final List<Category> before = await categories.categories();

      clock.advance(const Duration(days: 30));
      await seedPersonal();

      expect(await rawCount(db, 'category_groups'), groupsBefore);
      expect(await rawCount(db, 'categories'), categoriesBefore);
      expect(await rawCount(db, 'rule_lines'), linesBefore);
      expect(await rawCount(db, 'distribution_rule_versions'), versionsBefore);

      // Timestamps too: a seeder that rewrote identical values would still
      // churn `updated_at_ms`, which means a sync push on every launch.
      expect(await categories.categories(), before);
    });

    test('needsSeeding reports honestly before and after', () async {
      expect(await seeder.needsSeeding(), isTrue);
      await seedPersonal();
      expect(await seeder.needsSeeding(), isFalse);
      expect(
        await seeder.needsSeeding(includeBusiness: true),
        isTrue,
        reason: 'the business group has not been seeded yet',
      );
    });
  });

  // ===========================================================================
  // 4.7.6 — non-destructive
  // ===========================================================================

  group('4.7.6 a user edit survives a re-run', () {
    test('A RENAMED AND RETYPED SUGGESTION IS LEFT ALONE', () async {
      await seedPersonal();
      final Category groceries = (await categories.categories()).firstWhere(
        (Category c) => c.name == 'Groceries',
      );
      expectOk(
        await categories.updateCategory(
          groceries
              .copyWith(name: 'Food & household', sortOrder: 42)
              .valueOrNull!,
        ),
      );

      clock.advance(const Duration(days: 1));
      await seedPersonal();

      final Category after = (await categories.categories()).firstWhere(
        (Category c) => c.id == groceries.id,
      );
      expect(after.name, 'Food & household');
      expect(after.sortOrder, 42);
      expect(
        (await categories.categories()).map((Category c) => c.name),
        isNot(contains('Groceries')),
        reason:
            'the pitfall is "a seeder that overwrites user edits on every app '
            'launch" — re-adding the original under a new id is the same '
            'defect wearing a different hat',
      );
    });

    test('a deleted suggestion stays deleted', () async {
      await seedPersonal();
      final Category eatingOut = (await categories.categories()).firstWhere(
        (Category c) => c.name == 'Eating out',
      );
      expectOk(await categories.deleteCategory(eatingOut.id));

      await seedPersonal();
      expect(
        (await categories.categories()).map((Category c) => c.name),
        isNot(contains('Eating out')),
        reason: 'a suggestion the user removed must not come back',
      );
    });

    test('an edited sink pointer is not moved', () async {
      await seedPersonal();
      final Category groceries = (await categories.categories()).firstWhere(
        (Category c) => c.name == 'Groceries',
      );
      final AppSettings current = (await settings.read())!;
      expectOk(
        await settings.write(
          current.copyWith(personalSinkCategoryId: groceries.id).valueOrNull!,
        ),
      );

      await seedPersonal();
      expect((await settings.read())!.personalSinkCategoryId, groceries.id);
    });
  });

  // ===========================================================================
  // Enabling business later
  // ===========================================================================

  group('enabling business scope after onboarding', () {
    test('U-04 — seeds into the existing draft, not a second version',
        () async {
      await seedPersonal();
      final int versionsBefore = await rawCount(
        db,
        'distribution_rule_versions',
      );

      expectOk(
        await seeder.seed(
          currencyMinorExponent: 2,
          deviceId: 'device-test',
          includeBusiness: true,
        ),
      );

      expect(
        await rawCount(db, 'distribution_rule_versions'),
        versionsBefore,
        reason:
            'a second unsealed version would violate U-04 and abort the seed',
      );
      expect(
        await categories.groupByKind(CategoryGroupKind.business),
        isNotNull,
      );

      final AppSettings? stored = await settings.read();
      expect(stored!.businessSinkCategoryId, isNotNull);
      expect(
        stored.personalSinkCategoryId,
        isNot(stored.businessSinkCategoryId),
        reason:
            'OQ-07 answered yes to both, so business overflow stays in the '
            'business rather than landing in a household category',
      );
    });

    test('the business group shares replace the personal-only ones', () async {
      expectOk(
        await seeder.seed(
          currencyMinorExponent: 2,
          deviceId: 'device-test',
          includeBusiness: true,
        ),
      );
      final DistributionRuleVersion? draft = await rules.draftVersion();
      final List<RuleLine> groupLines = await rules.linesFor(
        draft!.id,
        scope: RuleLineScope.group,
      );
      expect(groupLines, hasLength(3));
      expect(
        groupLines.fold<int>(
          0,
          (int acc, RuleLine l) => acc + l.basisPoints.raw,
        ),
        10000,
      );
    });
  });

  test('the seeder refuses to run before settings exist', () async {
    // A separate database, because this one needs the setUp's settings row
    // *absent* — and the outer tearDown owns `db`.
    final PookieDatabase bareDb = await openTestDatabase();
    addTearDown(bareDb.close);

    final Result<void, RepositoryFailure> result =
        await Seeder(bareDb, FakeIdGenerator(prefix: 'seed'), clock).seed(
          currencyMinorExponent: 2,
          deviceId: 'device-test',
        );

    expect(result.isSuccess, isFalse);
    expect(
      result.failureOrNull,
      isA<RecordNotFound>(),
      reason:
          'the currency exponent comes from settings, and a seed that ran '
          'without them would leave the sink pointer unset — a sink category '
          'that nothing points at, with INV-07 silently unwired',
    );
    expect(
      await rawCount(bareDb, 'categories'),
      0,
      reason: 'a refused seed writes nothing at all',
    );
  });
}
