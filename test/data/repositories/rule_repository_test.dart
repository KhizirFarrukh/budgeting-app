import 'package:drift/drift.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pookiebudget/data/database/database.dart';
import 'package:pookiebudget/data/repositories/drift_category_repository.dart';
import 'package:pookiebudget/data/repositories/drift_rule_repository.dart';
import 'package:pookiebudget/domain/entities/distribution_rule_version.dart';
import 'package:pookiebudget/domain/entities/enums.dart';
import 'package:pookiebudget/domain/entities/rule_line.dart';
import 'package:pookiebudget/domain/repositories/repository_failure.dart';
import 'package:pookiebudget/domain/repositories/repository_queries.dart';
import 'package:pookiebudget/domain/repositories/rule_repository.dart';
import 'package:pookiebudget/domain/result.dart';

import '../../support/builders/config_builders.dart';
import '../../support/fakes/fake_clock.dart';
import '../../support/test_database.dart';

void main() {
  late PookieDatabase db;
  late FakeClock clock;
  late RuleRepository repo;

  setUp(() async {
    db = await openTestDatabase();
    clock = FakeClock();
    repo = DriftRuleRepository(db, clock);

    final DriftCategoryRepository categories = DriftCategoryRepository(
      db,
      clock,
    );
    await categories.createGroup(buildGroup());
    await categories.createCategory(buildCategory());
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

  // ===========================================================================
  // Sealing — INV-11
  // ===========================================================================

  group('INV-11 sealing freezes history', () {
    test('an unsealed version accepts edits', () async {
      expectOk(await repo.createVersion(buildRuleVersion()));
      expectOk(await repo.createLine(buildGroupLine()));
      expectOk(
        await repo.updateVersion(buildRuleVersion(note: 'first draft')),
      );

      expect((await repo.versionById('rule-v1'))!.note, 'first draft');
      expect(await repo.linesFor('rule-v1'), hasLength(1));
    });

    test('EVERY MUTATING PATH IS REFUSED ONCE SEALED', () async {
      expectOk(await repo.createVersion(buildRuleVersion()));
      expectOk(await repo.createLine(buildGroupLine()));
      expectOk(await repo.sealVersion('rule-v1', atMs: 1770000000000));

      // The whole point of one gate: each of these is a separate way to edit
      // percentages that have already split someone's salary.
      expect(
        expectRejected(await repo.updateVersion(buildRuleVersion(note: 'x'))),
        isA<RuleVersionSealed>(),
      );
      expect(
        expectRejected(
          await repo.createLine(
            buildCategoryLine(id: 'line-new', basisPoints: 5000),
          ),
        ),
        isA<RuleVersionSealed>(),
      );
      expect(
        expectRejected(
          await repo.updateLine(buildGroupLine(basisPoints: 5000)),
        ),
        isA<RuleVersionSealed>(),
      );
      expect(
        expectRejected(await repo.deleteLine('line-group-spending')),
        isA<RuleVersionSealed>(),
      );
      expect(
        expectRejected(await repo.replaceLines('rule-v1', <RuleLine>[])),
        isA<RuleVersionSealed>(),
      );
      expect(
        expectRejected(await repo.deleteVersion('rule-v1')),
        isA<RuleVersionSealed>(),
      );

      // And nothing changed as a result of any of them.
      final List<RuleLine> lines = await repo.linesFor('rule-v1');
      expect(lines.single.basisPoints.raw, 10000);
      expect((await repo.versionById('rule-v1'))!.note, isNull);
    });

    test('sealing is idempotent and keeps the FIRST instant', () async {
      expectOk(await repo.createVersion(buildRuleVersion()));
      expectOk(await repo.sealVersion('rule-v1', atMs: 1770000000000));
      expectOk(await repo.sealVersion('rule-v1', atMs: 1780000000000));

      expect(
        (await repo.versionById('rule-v1'))!.sealedAtMs,
        1770000000000,
        reason:
            'history became fixed at the first income event, not the latest — '
            'refreshing the stamp would misreport when editing stopped',
      );
    });

    test('sealing a version that does not exist is rejected', () async {
      expect(
        expectRejected(await repo.sealVersion('nope', atMs: 1)),
        isA<RecordNotFound>(),
      );
    });
  });

  // ===========================================================================
  // Version lookup
  // ===========================================================================

  group('version lookup', () {
    setUp(() async {
      expectOk(
        await repo.createVersion(
          buildRuleVersion(
            id: 'v-old',
            effectiveFromMs: 1000,
            sealedAtMs: 1500,
          ),
        ),
      );
      expectOk(
        await repo.createVersion(
          buildRuleVersion(
            id: 'v-mid',
            effectiveFromMs: 2000,
            sealedAtMs: 2500,
          ),
        ),
      );
      expectOk(
        await repo.createVersion(
          buildRuleVersion(id: 'v-draft', effectiveFromMs: 3000),
        ),
      );
    });

    test('U-04 — there is at most one draft', () async {
      expect((await repo.draftVersion())!.id, 'v-draft');
      expect(
        await repo.versions(query: const RuleVersionQuery(sealed: false)),
        hasLength(1),
      );
    });

    test('versionEffectiveAt resolves against the past, not the present',
        () async {
      // Recording income that arrived last week must use last week's
      // percentages. That is why this is a query and not a settings field.
      expect((await repo.versionEffectiveAt(1500))!.id, 'v-old');
      expect((await repo.versionEffectiveAt(2000))!.id, 'v-mid');
      expect((await repo.versionEffectiveAt(2999))!.id, 'v-mid');
      expect((await repo.versionEffectiveAt(9999))!.id, 'v-draft');
      expect(
        await repo.versionEffectiveAt(999),
        isNull,
        reason: 'no rules were in force before the first version',
      );
    });

    test('by date range, half-open', () async {
      final List<DistributionRuleVersion> found = await repo.versions(
        query: const RuleVersionQuery(
          effectiveWithin: DateRange(fromMs: 1000, toMs: 3000),
        ),
      );
      expect(
        found.map((DistributionRuleVersion v) => v.id),
        <String>['v-mid', 'v-old'],
        reason:
            'newest first; 3000 is excluded because the upper bound belongs to '
            'the next range',
      );
    });

    test('a sealed version cannot be deleted; a draft can', () async {
      expect(
        expectRejected(await repo.deleteVersion('v-old')),
        isA<RuleVersionSealed>(),
      );
      expectOk(await repo.deleteVersion('v-draft'));
      expect(await repo.draftVersion(), isNull);
      expect(
        await rawCount(db, 'distribution_rule_versions'),
        3,
        reason: 'INV-10: the delete was soft',
      );
    });

    test('deleting a draft tombstones its lines with it', () async {
      expectOk(
        await repo.createLine(buildGroupLine(ruleVersionId: 'v-draft')),
      );
      expectOk(await repo.deleteVersion('v-draft'));

      expect(await repo.linesFor('v-draft'), isEmpty);
      final QueryRow? row = await rawRow(
        db,
        'rule_lines',
        'line-group-spending',
      );
      expect(row!.read<int>('is_deleted'), 1);
    });
  });

  // ===========================================================================
  // replaceLines — atomicity
  // ===========================================================================

  group('replaceLines is atomic', () {
    setUp(() async {
      expectOk(await repo.createVersion(buildRuleVersion()));
    });

    test('surviving lines keep their id, dropped lines are tombstoned',
        () async {
      expectOk(await repo.createLine(buildGroupLine(id: 'keep')));
      expectOk(
        await repo.createLine(
          buildCategoryLine(id: 'drop', basisPoints: 4000),
        ),
      );

      expectOk(
        await repo.replaceLines('rule-v1', <RuleLine>[
          buildGroupLine(id: 'keep', basisPoints: 6000),
        ]),
      );

      final List<RuleLine> lines = await repo.linesFor('rule-v1');
      expect(lines.map((RuleLine l) => l.id), <String>['keep']);
      expect(
        lines.single.basisPoints.raw,
        6000,
        reason: 'a surviving line is updated in place, not recreated',
      );

      final QueryRow? dropped = await rawRow(db, 'rule_lines', 'drop');
      expect(dropped!.read<int>('is_deleted'), 1);
    });

    test('A REJECTED REPLACEMENT LEAVES THE OLD SET INTACT', () async {
      expectOk(await repo.createLine(buildGroupLine(basisPoints: 10000)));

      // A category line naming a category that does not exist trips the
      // foreign key mid-transaction, after the tombstone of the existing line
      // has already been written. If the transaction did not roll back, the
      // stored configuration would total 0% — a set no validator would accept,
      // persisted by a write that reported failure.
      final RepositoryFailure failure = expectRejected(
        await repo.replaceLines('rule-v1', <RuleLine>[
          buildCategoryLine(id: 'ghost', categoryId: 'no-such-category'),
        ]),
      );
      expect(failure, isA<ConstraintViolation>());

      final List<RuleLine> lines = await repo.linesFor('rule-v1');
      expect(lines, hasLength(1));
      expect(lines.single.id, 'line-group-spending');
      expect(lines.single.basisPoints.raw, 10000);
    });
  });

  test('lines can be filtered by scope', () async {
    expectOk(await repo.createVersion(buildRuleVersion()));
    expectOk(await repo.createLine(buildGroupLine()));
    expectOk(await repo.createLine(buildCategoryLine(basisPoints: 10000)));

    expect(
      await repo.linesFor('rule-v1', scope: RuleLineScope.group),
      hasLength(1),
    );
    expect(
      await repo.linesFor('rule-v1', scope: RuleLineScope.category),
      hasLength(1),
    );
    expect(await repo.linesFor('rule-v1'), hasLength(2));
  });
}
