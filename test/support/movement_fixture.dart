import 'package:pookiebudget/data/database/database.dart';
import 'package:pookiebudget/data/repositories/drift_category_repository.dart';
import 'package:pookiebudget/data/repositories/drift_rule_repository.dart';
import 'package:pookiebudget/domain/repositories/repository_failure.dart';
import 'package:pookiebudget/domain/result.dart';

import 'builders/config_builders.dart';
import 'fakes/fake_clock.dart';

/// The smallest configuration a money movement can legally reference.
///
/// Foreign keys are enforced (`PRAGMA foreign_keys = ON`, asserted at open), so
/// a ledger entry cannot exist without its category, and an income event cannot
/// exist without its rule version. Every movement test therefore needs this
/// same skeleton, and building it in one place means a test that fails is
/// failing on its own subject rather than on its scenery.
///
/// Creates: one `SPENDING` group, three categories — `category-groceries`,
/// `category-transport`, `category-sink` — and one **unsealed** rule version
/// `rule-v1`. Unsealed matters: several tests assert that the first income
/// event seals it, which is unobservable if it arrives sealed.
Future<void> seedMovementFixture(PookieDatabase db) async {
  final FakeClock clock = FakeClock();
  final DriftCategoryRepository categories = DriftCategoryRepository(db, clock);
  final DriftRuleRepository rules = DriftRuleRepository(db, clock);

  void expectOk(Result<void, RepositoryFailure> result, String what) {
    if (!result.isSuccess) {
      throw StateError(
        'The movement fixture could not create $what: '
        '${result.failureOrNull}. Fix the fixture — a test failing here is '
        'failing on its scenery, not its subject.',
      );
    }
  }

  expectOk(await categories.createGroup(buildGroup()), 'the spending group');
  expectOk(await categories.createCategory(buildCategory()), 'groceries');
  expectOk(
    await categories.createCategory(
      buildCategory(id: 'category-transport', name: 'Transport', sortOrder: 1),
    ),
    'transport',
  );
  expectOk(await categories.createCategory(buildSink()), 'the sink');
  expectOk(await rules.createVersion(buildRuleVersion()), 'rule-v1');
}
