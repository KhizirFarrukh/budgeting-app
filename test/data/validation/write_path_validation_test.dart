import 'package:flutter_test/flutter_test.dart';
import 'package:pookiebudget/data/database/database.dart';
import 'package:pookiebudget/data/repositories/drift_account_repository.dart';
import 'package:pookiebudget/data/repositories/drift_category_repository.dart';
import 'package:pookiebudget/data/repositories/drift_rule_repository.dart';
import 'package:pookiebudget/data/validation/configuration_guard.dart';
import 'package:pookiebudget/domain/entities/redirect_target.dart';
import 'package:pookiebudget/domain/entities/rule_line.dart';
import 'package:pookiebudget/domain/repositories/repository_failure.dart';
import 'package:pookiebudget/domain/result.dart';
import 'package:pookiebudget/domain/validation/validation_failure.dart';

import '../../support/builders/config_builders.dart';
import '../../support/fakes/fake_clock.dart';
import '../../support/movement_fixture.dart';
import '../../support/test_database.dart';

/// Substage 4.8.4 and its acceptance criterion: *"validation cannot be bypassed
/// by writing directly through the repository, proven by a test."*
///
/// Every test here goes **straight at the repository**, with no use case, no
/// screen and no prior validation call — which is exactly how Stage 7's merge,
/// a restore and a migration repair will write. SCHEMA §6.1: *"the UI is
/// bypassed entirely by sync, by restore, and by migration repair."*
void main() {
  late PookieDatabase db;
  late FakeClock clock;
  late DriftCategoryRepository categories;
  late DriftRuleRepository rules;
  late DriftAccountRepository accounts;

  setUp(() async {
    db = await openTestDatabase();
    await seedMovementFixture(db);
    clock = FakeClock();
    categories = DriftCategoryRepository(db, clock);
    rules = DriftRuleRepository(db, clock);
    accounts = DriftAccountRepository(db, clock);
  });

  tearDown(() async => db.close());

  ConfigurationInvalid expectInvalid(Result<void, RepositoryFailure> result) {
    expect(
      result.isSuccess,
      isFalse,
      reason: 'the repository accepted a write that leaves invalid state',
    );
    final RepositoryFailure failure = result.failureOrNull!;
    expect(failure, isA<ConfigurationInvalid>());
    return failure as ConfigurationInvalid;
  }

  List<String> rulesOf(ConfigurationInvalid failure) =>
      failure.failures.map((ValidationFailure f) => f.rule).toList();

  void expectOk(Result<void, RepositoryFailure> result) {
    expect(
      result.isSuccess,
      isTrue,
      reason: 'expected success, got ${result.failureOrNull}',
    );
  }

  // ===========================================================================
  // V-12 — cycles, through the write path
  // ===========================================================================

  group('V-12 the repository refuses to store a cycle', () {
    test('A SELF-REFERENCE, AT BOTH MECHANISMS THAT GUARD IT', () async {
      // The entity refuses to build one at all (C-29 / V-10), so a repository
      // call with a self-edge is unreachable through the normal path — which
      // is why this asserts the entity rather than the repository.
      expect(
        RedirectTarget.create(
          id: 'r-self',
          sourceCategoryId: 'category-groceries',
          targetCategoryId: 'category-groceries',
          priority: 0,
          sync: syncFields(),
        ).isSuccess,
        isFalse,
        reason: 'the entity is the first of the two guards',
      );

      // A merge writes rows without constructing entities, so the second guard
      // has to hold independently: the row goes in by raw SQL, and the
      // post-merge pass must still see the loop.
      await db.customStatement(
        'INSERT INTO redirect_targets (id, source_category_id, '
        'target_category_id, priority, updated_at_ms, updated_by_device, hlc) '
        "VALUES ('r-self', 'category-groceries', 'category-groceries', 0, 0, "
        "'other-device', 'h')",
      );
      expect(
        (await ConfigurationGuard(db).validateAll())
            .map((ValidationFailure f) => f.rule),
        contains('V-12'),
      );
    });

    test('A TWO-NODE CYCLE', () async {
      expectOk(
        await categories.createRedirectTarget(
          buildRedirectTarget(
            id: 'r1',
            sourceCategoryId: 'category-groceries',
            targetCategoryId: 'category-transport',
          ),
        ),
      );

      final ConfigurationInvalid failure = expectInvalid(
        await categories.createRedirectTarget(
          buildRedirectTarget(
            id: 'r2',
            sourceCategoryId: 'category-transport',
            targetCategoryId: 'category-groceries',
          ),
        ),
      );
      expect(rulesOf(failure), contains('V-12'));

      // Rolled back: the offending edge must not survive its own rejection.
      expect(
        await categories.redirectTargetsFor('category-transport'),
        isEmpty,
      );
      expect(await rawCount(db, 'redirect_targets'), 1);
    });

    test('A THREE-NODE CYCLE — the pitfall a pair check walks past', () async {
      expectOk(
        await categories.createRedirectTarget(
          buildRedirectTarget(
            id: 'r1',
            sourceCategoryId: 'category-groceries',
            targetCategoryId: 'category-transport',
          ),
        ),
      );
      expectOk(
        await categories.createRedirectTarget(
          buildRedirectTarget(
            id: 'r2',
            sourceCategoryId: 'category-transport',
            targetCategoryId: 'category-sink',
          ),
        ),
      );

      // sink → groceries closes the loop three hops back. Nothing about the
      // immediate pair is wrong.
      final ConfigurationInvalid failure = expectInvalid(
        await categories.createRedirectTarget(
          buildRedirectTarget(
            id: 'r3',
            sourceCategoryId: 'category-sink',
            targetCategoryId: 'category-groceries',
          ),
        ),
      );
      expect(rulesOf(failure), contains('V-12'));
      expect(await rawCount(db, 'redirect_targets'), 2);
    });

    test('an update that closes a loop is refused too', () async {
      // Not just inserts. Repointing an existing edge is the other way to
      // create a cycle, and a guard on `create` alone would miss it.
      expectOk(
        await categories.createRedirectTarget(
          buildRedirectTarget(
            id: 'r1',
            sourceCategoryId: 'category-groceries',
            targetCategoryId: 'category-sink',
          ),
        ),
      );
      expectOk(
        await categories.createRedirectTarget(
          buildRedirectTarget(
            id: 'r2',
            sourceCategoryId: 'category-transport',
            targetCategoryId: 'category-sink',
          ),
        ),
      );

      final ConfigurationInvalid failure = expectInvalid(
        await categories.updateRedirectTarget(
          buildRedirectTarget(
            id: 'r2',
            sourceCategoryId: 'category-transport',
            targetCategoryId: 'category-groceries',
          ),
        ),
      );
      expect(rulesOf(failure), contains('V-12'));

      // The original edge survives the rejected update untouched.
      final List<RedirectTarget> surviving = await categories
          .redirectTargetsFor('category-transport');
      expect(
        surviving.map((RedirectTarget t) => t.targetCategoryId),
        <String>['category-sink'],
      );
    });

    test('a legitimate branching graph is accepted', () async {
      // Two categories redirecting into the sink is not a cycle, and a guard
      // that refused it would make the feature unusable.
      expectOk(
        await categories.createRedirectTarget(
          buildRedirectTarget(
            id: 'r1',
            sourceCategoryId: 'category-groceries',
            targetCategoryId: 'category-sink',
          ),
        ),
      );
      expectOk(
        await categories.createRedirectTarget(
          buildRedirectTarget(
            id: 'r2',
            sourceCategoryId: 'category-transport',
            targetCategoryId: 'category-sink',
          ),
        ),
      );
      expect(await rawCount(db, 'redirect_targets'), 2);
    });
  });

  // ===========================================================================
  // V-14 — the archive guard
  // ===========================================================================

  test('V-14 — archiving a redirect target is refused, naming the dependant',
      () async {
    expectOk(
      await categories.createRedirectTarget(
        buildRedirectTarget(
          id: 'r1',
          sourceCategoryId: 'category-groceries',
          targetCategoryId: 'category-transport',
        ),
      ),
    );

    final ConfigurationInvalid failure = expectInvalid(
      await categories.setCategoryArchived(
        'category-transport',
        archived: true,
      ),
    );
    expect(rulesOf(failure), contains('V-14'));
    expect(failure.describe, contains('Groceries'));

    // Not archived, and the source with no dependants still can be.
    expect(
      (await categories.categoryById('category-transport'))!.isArchived,
      isFalse,
    );
    expectOk(
      await categories.setCategoryArchived(
        'category-groceries',
        archived: true,
      ),
    );
  });

  // ===========================================================================
  // V-01 / V-02 — percentages, through replaceLines
  // ===========================================================================

  group('percentages cannot be stored unbalanced', () {
    test('RULE LINES TOTALLING 9999 AND 10001 ARE BOTH REFUSED', () async {
      for (final int total in <int>[9999, 10001]) {
        final ConfigurationInvalid failure = expectInvalid(
          await rules.replaceLines('rule-v1', <RuleLine>[
            buildGroupLine(
              id: 'l-group',
              groupId: 'group-spending',
              basisPoints: total,
            ),
            buildCategoryLine(
              id: 'l-groceries',
              categoryId: 'category-groceries',
              basisPoints: 10000,
            ),
          ]),
        );
        expect(rulesOf(failure), contains('V-01'), reason: 'total $total');

        // Rolled back whole. A half-replaced set would be a configuration no
        // validator would have accepted, persisted by a write that reported
        // failure.
        expect(
          await rules.linesFor('rule-v1'),
          isEmpty,
          reason: 'total $total left lines behind',
        );
      }
    });

    test('a within-group total that is off is refused', () async {
      final ConfigurationInvalid failure = expectInvalid(
        await rules.replaceLines('rule-v1', <RuleLine>[
          buildGroupLine(
            id: 'l-group',
            groupId: 'group-spending',
            basisPoints: 10000,
          ),
          buildCategoryLine(
            id: 'l-groceries',
            categoryId: 'category-groceries',
            basisPoints: 5000,
          ),
          buildCategoryLine(
            id: 'l-transport',
            categoryId: 'category-transport',
            basisPoints: 4000,
          ),
        ]),
      );
      expect(rulesOf(failure), contains('V-02'));
    });

    test('a balanced set is accepted', () async {
      expectOk(
        await rules.replaceLines('rule-v1', <RuleLine>[
          buildGroupLine(
            id: 'l-group',
            groupId: 'group-spending',
            basisPoints: 10000,
          ),
          buildCategoryLine(
            id: 'l-groceries',
            categoryId: 'category-groceries',
            basisPoints: 6000,
          ),
          buildCategoryLine(
            id: 'l-transport',
            categoryId: 'category-transport',
            basisPoints: 4000,
          ),
          buildCategoryLine(
            id: 'l-sink',
            categoryId: 'category-sink',
            basisPoints: 0,
          ),
        ]),
      );
      expect(await rules.linesFor('rule-v1'), hasLength(4));
    });
  });

  // ===========================================================================
  // V-21 — accounts
  // ===========================================================================

  test('V-21 — deleting a linked account is refused, listing the categories',
      () async {
    await db.customStatement(
      'INSERT INTO accounts (id, name, sort_order, updated_at_ms, '
      "updated_by_device, hlc) VALUES ('acc-1', 'Current', 0, 0, 'd', 'h')",
    );
    expectOk(
      await categories.updateCategory(
        buildCategory(linkedAccountId: 'acc-1'),
      ),
    );

    final ConfigurationInvalid failure = expectInvalid(
      await accounts.deleteAccount('acc-1'),
    );
    expect(rulesOf(failure), contains('V-21'));
    expect(
      failure.describe,
      contains('Groceries'),
      reason: 'V-21 blocks and **lists** the linked categories',
    );
    expect(await accounts.accountById('acc-1'), isNotNull);
  });

  // ===========================================================================
  // 4.8.5 — the post-merge entry point
  // ===========================================================================

  group('4.8.5 the post-merge entry point', () {
    test('returns an empty list for a healthy configuration', () async {
      expect(await ConfigurationGuard(db).validateAll(), isEmpty);
    });

    test('RETURNS A LIST RATHER THAN THROWING, AND REPORTS EVERYTHING',
        () async {
      // Written by raw SQL, which is what a merge effectively is: rows
      // arriving from another device without passing a single validator.
      // Two independent problems at once — a cycle and an unbalanced set.
      await db.customStatement(
        'INSERT INTO redirect_targets (id, source_category_id, '
        'target_category_id, priority, updated_at_ms, updated_by_device, hlc) '
        "VALUES ('m1', 'category-groceries', 'category-transport', 0, 0, "
        "'other-device', 'h')",
      );
      await db.customStatement(
        'INSERT INTO redirect_targets (id, source_category_id, '
        'target_category_id, priority, updated_at_ms, updated_by_device, hlc) '
        "VALUES ('m2', 'category-transport', 'category-groceries', 0, 0, "
        "'other-device', 'h')",
      );
      await db.customStatement(
        'INSERT INTO rule_lines (id, rule_version_id, scope, group_id, '
        'basis_points, updated_at_ms, updated_by_device, hlc) VALUES '
        "('m3', 'rule-v1', 'GROUP', 'group-spending', 9000, 0, 'other', 'h')",
      );

      final List<ValidationFailure> failures = await ConfigurationGuard(db)
          .validateAll();

      expect(failures.map((ValidationFailure f) => f.rule), containsAll(
        <String>['V-12', 'V-01'],
      ));
      // A merge produces a state nobody chose, and repairing it needs the
      // whole list — fixing several problems one crash at a time is not a
      // repair procedure.
      expect(failures.length, greaterThanOrEqualTo(2));
    });

    test('every failure carries a rule id and a user-facing message', () async {
      await db.customStatement(
        'INSERT INTO rule_lines (id, rule_version_id, scope, group_id, '
        'basis_points, updated_at_ms, updated_by_device, hlc) VALUES '
        "('m3', 'rule-v1', 'GROUP', 'group-spending', 9000, 0, 'other', 'h')",
      );
      for (final ValidationFailure failure
          in await ConfigurationGuard(db).validateAll()) {
        expect(failure.rule, startsWith('V-'));
        expect(failure.describe, isNotEmpty);
        expect(
          failure.describe,
          isNot(contains('Exception')),
          reason: 'these reach a screen, not a log',
        );
      }
    });
  });
}
