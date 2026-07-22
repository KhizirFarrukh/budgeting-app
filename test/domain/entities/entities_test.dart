import 'package:flutter_test/flutter_test.dart';
import 'package:pookiebudget/domain/entities/account.dart';
import 'package:pookiebudget/domain/entities/allocation.dart';
import 'package:pookiebudget/domain/entities/app_settings.dart';
import 'package:pookiebudget/domain/entities/category.dart';
import 'package:pookiebudget/domain/entities/category_group.dart';
import 'package:pookiebudget/domain/entities/distribution_rule_version.dart';
import 'package:pookiebudget/domain/entities/entity_failure.dart';
import 'package:pookiebudget/domain/entities/enums.dart';
import 'package:pookiebudget/domain/entities/headroom.dart';
import 'package:pookiebudget/domain/entities/income_event.dart';
import 'package:pookiebudget/domain/entities/ledger_entry.dart';
import 'package:pookiebudget/domain/entities/rule_line.dart';
import 'package:pookiebudget/domain/entities/spending_transaction.dart';
import 'package:pookiebudget/domain/entities/sync_fields.dart';
import 'package:pookiebudget/domain/result.dart';

/// Substage 4.2.7: *"prove each invalid construction is rejected with a typed
/// failure rather than an exception."*
void main() {
  const SyncFields sync = SyncFields(
    updatedAtMs: 1000,
    updatedByDevice: 'device-a',
    hlc: '0000000001000:0000:device-a',
  );

  Result<Category, EntityFailure> category({
    String id = 'cat-1',
    String name = 'Groceries',
    CategoryType type = CategoryType.uncappedFlow,
    bool isSink = false,
    int? ceilingMinor,
    int? billAmountMinor,
    int? periodAnchorDay,
    String? redirectTargetCategoryId,
  }) => Category.create(
    id: id,
    groupId: 'grp-1',
    name: name,
    type: type,
    sortOrder: 0,
    sync: sync,
    isSink: isSink,
    ceilingMinor: ceilingMinor,
    billAmountMinor: billAmountMinor,
    periodAnchorDay: periodAnchorDay,
    redirectTargetCategoryId: redirectTargetCategoryId,
  );

  // ===========================================================================
  // 4.2.4 — every invalid construction the substage enumerates
  // ===========================================================================

  group('4.2.4 invalid constructions are rejected with a typed failure', () {
    test('negative or zero ceiling when a ceiling is set (V-07)', () {
      for (final int bad in <int>[0, -1, -100000]) {
        final Result<Category, EntityFailure> r = category(
          type: CategoryType.accumulatingReserve,
          ceilingMinor: bad,
        );
        expect(r.isSuccess, isFalse, reason: 'ceiling $bad');
        expect(r.failureOrNull, isA<NonPositiveCeiling>());
        expect(r.failureOrNull!.rule, 'V-07');
      }
    });

    test('a ceiling on a non-reserve type, and none on a reserve (V-08)', () {
      expect(
        category(
          type: CategoryType.uncappedFlow,
          ceilingMinor: 5000,
        ).failureOrNull,
        isA<CeilingTypeMismatch>(),
      );
      expect(
        category(type: CategoryType.accumulatingReserve).failureOrNull,
        isA<CeilingTypeMismatch>(),
      );
    });

    test('basis points outside 0 to 10000 (V-01)', () {
      for (final int bad in <int>[-1, 10001, 999999]) {
        final Result<RuleLine, EntityFailure> r = RuleLine.create(
          id: 'rl-1',
          ruleVersionId: 'rv-1',
          scope: RuleLineScope.group,
          groupId: 'grp-1',
          basisPoints: bad,
          sync: sync,
        );
        expect(r.isSuccess, isFalse, reason: 'basis points $bad');
        expect(r.failureOrNull, isA<BasisPointsOutOfRange>());
      }
      // The endpoints themselves are valid.
      for (final int ok in <int>[0, 10000]) {
        expect(
          RuleLine.create(
            id: 'rl-1',
            ruleVersionId: 'rv-1',
            scope: RuleLineScope.group,
            groupId: 'grp-1',
            basisPoints: ok,
            sync: sync,
          ).isSuccess,
          isTrue,
          reason: 'basis points $ok',
        );
      }
    });

    test('empty or whitespace-only names, on every named entity', () {
      for (final String blank in <String>['', '   ', '\t', '\n  ']) {
        expect(category(name: blank).failureOrNull, isA<BlankName>());
        expect(
          CategoryGroup.create(
            id: 'grp-1',
            kind: CategoryGroupKind.spending,
            name: blank,
            sortOrder: 0,
            sync: sync,
          ).failureOrNull,
          isA<BlankName>(),
        );
        expect(
          Account.create(
            id: 'acc-1',
            name: blank,
            sortOrder: 0,
            sync: sync,
          ).failureOrNull,
          isA<BlankName>(),
        );
      }
    });

    test('names are trimmed rather than stored with their padding', () {
      expect(category(name: '  Groceries  ').valueOrNull!.name, 'Groceries');
    });

    test('a category whose redirect target is itself (V-10)', () {
      final Result<Category, EntityFailure> r = category(
        id: 'cat-1',
        redirectTargetCategoryId: 'cat-1',
      );
      expect(r.isSuccess, isFalse);
      expect(r.failureOrNull, isA<SelfRedirect>());
      expect(r.failureOrNull!.rule, 'V-10');
      // Pointing at a different category is fine.
      expect(
        category(id: 'cat-1', redirectTargetCategoryId: 'cat-2').isSuccess,
        isTrue,
      );
    });

    test('FIXED_RECURRING with no bill amount (V-18)', () {
      expect(
        category(
          type: CategoryType.fixedRecurring,
          periodAnchorDay: 15,
        ).failureOrNull,
        isA<BillTypeMismatch>(),
      );
      // And bill fields on a type that should not have them.
      expect(
        category(
          type: CategoryType.uncappedFlow,
          billAmountMinor: 5000,
        ).failureOrNull,
        isA<BillTypeMismatch>(),
      );
    });

    test('a bill amount of zero or less (V-17)', () {
      expect(
        category(
          type: CategoryType.fixedRecurring,
          billAmountMinor: 0,
          periodAnchorDay: 15,
        ).failureOrNull,
        isA<NonPositiveBillAmount>(),
      );
    });

    test('an anchor day outside 1 to 31 (V-19)', () {
      for (final int bad in <int>[0, -1, 32, 100]) {
        final Result<Category, EntityFailure> r = category(
          type: CategoryType.fixedRecurring,
          billAmountMinor: 5000,
          periodAnchorDay: bad,
        );
        expect(r.isSuccess, isFalse, reason: 'anchor $bad');
        expect(r.failureOrNull, isA<AnchorDayOutOfRange>());
      }
      // 1 and 31 are both valid. An anchor of 31 in February clamps at read
      // time (V-20); it is not a construction error.
      for (final int ok in <int>[1, 28, 29, 30, 31]) {
        expect(
          category(
            type: CategoryType.fixedRecurring,
            billAmountMinor: 5000,
            periodAnchorDay: ok,
          ).isSuccess,
          isTrue,
          reason: 'anchor $ok',
        );
      }
    });

    test('a sink category that has a ceiling (V-13)', () {
      // A sink must be UNCAPPED_FLOW, so a ceiling is caught by the type rule
      // first; both paths are checked.
      expect(
        category(
          isSink: true,
          type: CategoryType.accumulatingReserve,
          ceilingMinor: 5000,
        ).failureOrNull,
        isA<SinkNotUncapped>(),
      );
      final Result<Category, EntityFailure> valid = category(isSink: true);
      expect(valid.isSuccess, isTrue);
      // INV-07's termination guarantee: the sink's headroom is never bounded.
      expect(
        valid.valueOrNull!.headroom(
          currentBalanceMinor: 999999999,
          allocatedInPeriodMinor: 999999999,
        ),
        isA<UnboundedHeadroom>(),
      );
    });
  });

  // ===========================================================================
  // 4.2.2 — headroom lives on the category type
  // ===========================================================================

  group('4.2.2 headroom semantics', () {
    test('ACCUMULATING_RESERVE: ceiling minus balance minus accepted', () {
      final Category c = category(
        type: CategoryType.accumulatingReserve,
        ceilingMinor: 100000,
      ).valueOrNull!;
      expect(
        c.headroom(currentBalanceMinor: 30000, allocatedInPeriodMinor: 0),
        const Headroom.bounded(70000),
      );
    });

    test(
      'FIXED_RECURRING: bill minus allocated this period minus accepted',
      () {
        final Category c = category(
          type: CategoryType.fixedRecurring,
          billAmountMinor: 50000,
          periodAnchorDay: 1,
        ).valueOrNull!;
        expect(
          c.headroom(
            currentBalanceMinor: 999999,
            allocatedInPeriodMinor: 20000,
          ),
          const Headroom.bounded(30000),
        );
      },
    );

    test('UNCAPPED_FLOW is unbounded', () {
      expect(
        category().valueOrNull!.headroom(
          currentBalanceMinor: 0,
          allocatedInPeriodMinor: 0,
        ),
        isA<UnboundedHeadroom>(),
      );
    });

    test('ALREADY OVER CEILING clamps to zero, never negative', () {
      // ALLOCATION_ALGORITHM §3.1: "max(0, ...) is not decoration." A balance
      // can exceed its ceiling after an override, a lowered ceiling, or a
      // merge. Without the clamp, accept() returns a negative number and
      // conservation breaks.
      final Category c = category(
        type: CategoryType.accumulatingReserve,
        ceilingMinor: 100000,
      ).valueOrNull!;
      final Headroom h = c.headroom(
        currentBalanceMinor: 150000,
        allocatedInPeriodMinor: 0,
      );
      expect(h, const Headroom.bounded(0));
      expect(h.accept(50000), 0);
      expect(h.overflowOf(50000), 50000);
      expect(h.isExhausted, isTrue);
    });

    test('acceptedSoFar prevents a category filling twice in one run', () {
      // §3.2: a category can be reached twice — once in phase A, again by a
      // redirect. Computing headroom once and reusing it would let both
      // parcels see the same room.
      final Category c = category(
        type: CategoryType.accumulatingReserve,
        ceilingMinor: 100000,
      ).valueOrNull!;
      final Headroom first = c.headroom(
        currentBalanceMinor: 0,
        allocatedInPeriodMinor: 0,
      );
      expect(first.accept(60000), 60000);
      final Headroom second = c.headroom(
        currentBalanceMinor: 0,
        allocatedInPeriodMinor: 0,
        acceptedSoFarMinor: 60000,
      );
      expect(second.accept(60000), 40000);
      expect(second.overflowOf(60000), 20000);
    });

    test('accept and overflowOf always partition the parcel exactly', () {
      // The conservation property, at the smallest scale: nothing is created
      // and nothing is lost by a single acceptance.
      for (final Headroom h in <Headroom>[
        const Headroom.bounded(0),
        const Headroom.bounded(1),
        const Headroom.bounded(9999),
        const Headroom.unbounded(),
      ]) {
        for (final int pending in <int>[0, 1, 5000, 1000000]) {
          expect(h.accept(pending) + h.overflowOf(pending), pending);
          expect(h.accept(pending), greaterThanOrEqualTo(0));
          expect(h.overflowOf(pending), greaterThanOrEqualTo(0));
        }
      }
    });
  });

  // ===========================================================================
  // 4.2.3 — stable string serialisation, never ordinal
  // ===========================================================================

  group('4.2.3 enumerations round-trip as stable strings', () {
    test('every value of every enum survives a wire round-trip', () {
      void check<T extends WireEnum>(List<T> values, T? Function(String) from) {
        for (final T v in values) {
          expect(from(v.wireName), same(v), reason: v.wireName);
        }
      }

      check(CategoryGroupKind.values, CategoryGroupKind.fromWire);
      check(CategoryType.values, CategoryType.fromWire);
      check(LedgerDirection.values, LedgerDirection.fromWire);
      check(LedgerSourceType.values, LedgerSourceType.fromWire);
      check(AllocationReason.values, AllocationReason.fromWire);
      check(RuleLineScope.values, RuleLineScope.fromWire);
      check(MoneyScope.values, MoneyScope.fromWire);
      check(OnboardingState.values, OnboardingState.fromWire);
      check(OutboxOperation.values, OutboxOperation.fromWire);
      check(OutboxState.values, OutboxState.fromWire);
      check(CeilingKind.values, CeilingKind.fromWire);
      check(RuleSet.values, RuleSet.fromWire);
      check(RepairKind.values, RepairKind.fromWire);
    });

    test('wire names are the exact SCHEMA §4 strings, not derived', () {
      // Pinned literally. If someone renames a Dart value, this fails rather
      // than silently changing what is written to the database.
      expect(CategoryType.fixedRecurring.wireName, 'FIXED_RECURRING');
      expect(CategoryType.accumulatingReserve.wireName, 'ACCUMULATING_RESERVE');
      expect(CategoryType.uncappedFlow.wireName, 'UNCAPPED_FLOW');
      expect(LedgerDirection.inbound.wireName, 'IN');
      expect(LedgerDirection.outbound.wireName, 'OUT');
      expect(AllocationReason.sinkTerminal.wireName, 'SINK_TERMINAL');
      expect(OnboardingState.notStarted.wireName, 'NOT_STARTED');
      expect(OutboxState.inFlight.wireName, 'IN_FLIGHT');
      expect(RuleSet.defaultSet.wireName, 'DEFAULT');
      expect(CeilingKind.absolute.wireName, 'ABSOLUTE');
    });

    test('an unrecognised string returns null, never a default', () {
      // A silent fallback to the first value would turn a corrupt row into a
      // plausible one, which is worse than rejecting it at the mapper.
      expect(CategoryType.fromWire('GOAL'), isNull);
      expect(CategoryType.fromWire('fixed_recurring'), isNull);
      expect(CategoryType.fromWire(''), isNull);
      expect(LedgerDirection.fromWire('0'), isNull);
    });

    test('no enum is stored by ordinal — wire names are non-numeric', () {
      // must_not: "Do not store enums as ordinals."
      for (final WireEnum v in <WireEnum>[
        ...CategoryGroupKind.values,
        ...CategoryType.values,
        ...LedgerDirection.values,
        ...LedgerSourceType.values,
        ...AllocationReason.values,
        ...RuleLineScope.values,
        ...MoneyScope.values,
        ...OnboardingState.values,
        ...OutboxOperation.values,
        ...OutboxState.values,
        ...RepairKind.values,
      ]) {
        expect(int.tryParse(v.wireName), isNull, reason: v.wireName);
        expect(v.wireName, isNotEmpty);
      }
    });
  });

  // ===========================================================================
  // 4.2.5 — equality, hashCode, copyWith
  // ===========================================================================

  group('4.2.5 value equality and copyWith', () {
    test('entities compare by value, so tests can assert on them directly', () {
      expect(category().valueOrNull, equals(category().valueOrNull));
      expect(
        category().valueOrNull!.hashCode,
        category().valueOrNull!.hashCode,
      );
      expect(
        category(name: 'Groceries').valueOrNull,
        isNot(equals(category(name: 'Transport').valueOrNull)),
      );
    });

    test('COPYWITH CANNOT PRODUCE AN INVALID ENTITY', () {
      // common_pitfalls: "copyWith that allows a valid entity to be copied into
      // an invalid one." copyWith returns Result for exactly this reason.
      final Category reserve = category(
        type: CategoryType.accumulatingReserve,
        ceilingMinor: 100000,
      ).valueOrNull!;

      // Changing the type without clearing the ceiling is now a failure, not a
      // broken object.
      expect(
        reserve.copyWith(type: CategoryType.uncappedFlow).failureOrNull,
        isA<CeilingTypeMismatch>(),
      );
      // Doing it properly works.
      expect(
        reserve
            .copyWith(type: CategoryType.uncappedFlow, clearCeiling: true)
            .isSuccess,
        isTrue,
      );
      // And a ceiling cannot be copied to an invalid value.
      expect(
        reserve.copyWith(ceilingMinor: -5).failureOrNull,
        isA<NonPositiveCeiling>(),
      );
      // Nor a name to a blank one.
      expect(reserve.copyWith(name: '  ').failureOrNull, isA<BlankName>());
      // Nor a redirect into a self-reference.
      expect(
        reserve.copyWith(redirectTargetCategoryId: 'cat-1').failureOrNull,
        isA<SelfRedirect>(),
      );
    });

    test('copyWith leaves untouched fields alone', () {
      final Category c = category().valueOrNull!;
      final Category renamed = c.copyWith(name: 'Food').valueOrNull!;
      expect(renamed.name, 'Food');
      expect(renamed.id, c.id);
      expect(renamed.groupId, c.groupId);
      expect(renamed.type, c.type);
      expect(renamed.sortOrder, c.sortOrder);
    });

    test('a rule line changing scope does not carry its old target', () {
      final RuleLine groupLine = RuleLine.create(
        id: 'rl-1',
        ruleVersionId: 'rv-1',
        scope: RuleLineScope.group,
        groupId: 'grp-1',
        basisPoints: 5000,
        sync: sync,
      ).valueOrNull!;
      // Without clearing group_id, this would be a line counted in neither
      // total — a share that exists but is summed nowhere.
      expect(
        groupLine.copyWith(scope: RuleLineScope.category).failureOrNull,
        isA<RuleLineScopeMismatch>(),
      );
      expect(
        groupLine
            .copyWith(scope: RuleLineScope.category, categoryId: 'cat-1')
            .valueOrNull!
            .groupId,
        isNull,
      );
    });
  });

  // ===========================================================================
  // The remaining entities
  // ===========================================================================

  group('RuleLine scope consistency (C-21)', () {
    test('a GROUP line must name a group and not a category', () {
      expect(
        RuleLine.create(
          id: 'rl-1',
          ruleVersionId: 'rv-1',
          scope: RuleLineScope.group,
          basisPoints: 5000,
          sync: sync,
        ).failureOrNull,
        isA<RuleLineScopeMismatch>(),
      );
      expect(
        RuleLine.create(
          id: 'rl-1',
          ruleVersionId: 'rv-1',
          scope: RuleLineScope.group,
          groupId: 'grp-1',
          categoryId: 'cat-1',
          basisPoints: 5000,
          sync: sync,
        ).failureOrNull,
        isA<RuleLineScopeMismatch>(),
      );
    });

    test('a CATEGORY line must name a category and not a group', () {
      expect(
        RuleLine.create(
          id: 'rl-1',
          ruleVersionId: 'rv-1',
          scope: RuleLineScope.category,
          basisPoints: 5000,
          sync: sync,
        ).failureOrNull,
        isA<RuleLineScopeMismatch>(),
      );
      expect(
        RuleLine.create(
          id: 'rl-1',
          ruleVersionId: 'rv-1',
          scope: RuleLineScope.category,
          categoryId: 'cat-1',
          groupId: 'grp-1',
          basisPoints: 5000,
          sync: sync,
        ).failureOrNull,
        isA<RuleLineScopeMismatch>(),
      );
    });

    test('targetId returns whichever the scope selects', () {
      expect(
        RuleLine.create(
          id: 'rl-1',
          ruleVersionId: 'rv-1',
          scope: RuleLineScope.category,
          categoryId: 'cat-9',
          basisPoints: 5000,
          sync: sync,
        ).valueOrNull!.targetId,
        'cat-9',
      );
    });
  });

  group('DistributionRuleVersion sealing', () {
    DistributionRuleVersion version() => DistributionRuleVersion.create(
      id: 'rv-1',
      effectiveFromMs: 1000,
      createdAtMs: 1000,
      sync: sync,
    ).valueOrNull!;

    test('starts unsealed and seals once', () {
      final DistributionRuleVersion v = version();
      expect(v.isSealed, isFalse);
      final DistributionRuleVersion sealed = v.sealedAt(2000);
      expect(sealed.isSealed, isTrue);
      expect(sealed.sealedAtMs, 2000);
    });

    test('SEALING IS IDEMPOTENT — it keeps the first timestamp', () {
      // The moment history became fixed is the first income event, not the
      // latest. Overwriting it would misreport when the version stopped being
      // editable.
      final DistributionRuleVersion sealed = version().sealedAt(2000);
      expect(sealed.sealedAt(9000).sealedAtMs, 2000);
    });
  });

  group('IncomeEvent', () {
    Result<IncomeEvent, EntityFailure> event(int amount) => IncomeEvent.create(
      id: 'inc-1',
      amountMinor: amount,
      occurredAtMs: 1000,
      recordedAtMs: 1000,
      evaluatedAtMs: 1000,
      ruleVersionId: 'rv-1',
      sync: sync,
    );

    test('ZERO income is REJECTED (C-02), not stored as an empty event', () {
      // Vector V-11a expects `IncomeNotPositive`. An earlier draft of this
      // entity read V-11a as "zero produces no lines" and allowed it; the 4.3
      // transcription pass caught the disagreement with C-02.
      expect(event(0).failureOrNull, isA<NonPositiveAmount>());
    });

    test('negative income is rejected', () {
      expect(event(-1).failureOrNull, isA<NonPositiveAmount>());
    });

    test('one minor unit is accepted — vector V-13 splits it', () {
      expect(event(1).isSuccess, isTrue);
    });

    test(
      'overrides are recorded as input, so the event stays reproducible',
      () {
        final IncomeEvent e = IncomeEvent.create(
          id: 'inc-1',
          amountMinor: 100000,
          occurredAtMs: 1000,
          recordedAtMs: 1000,
          evaluatedAtMs: 1000,
          ruleVersionId: 'rv-1',
          overridesJson: '{"cat-1":50000}',
          sync: sync,
        ).valueOrNull!;
        expect(e.hasOverrides, isTrue);
        expect(e.overridesJson, '{"cat-1":50000}');
      },
    );
  });

  group('LedgerEntry — append-only', () {
    Result<LedgerEntry, EntityFailure> entry({
      int amount = 5000,
      SyncFields s = sync,
      AllocationReason? reason,
      String? redirectedFrom,
    }) => LedgerEntry.create(
      id: 'led-1',
      categoryId: 'cat-1',
      direction: LedgerDirection.inbound,
      amountMinor: amount,
      occurredAtMs: 1000,
      recordedAtMs: 1000,
      sourceType: LedgerSourceType.allocation,
      sourceId: 'inc-1',
      reason: reason,
      redirectedFromCategoryId: redirectedFrom,
      sync: s,
    );

    test('amount must be positive; direction carries the sign', () {
      expect(entry(amount: 0).failureOrNull, isA<NonPositiveAmount>());
      expect(entry(amount: -5000).failureOrNull, isA<NonPositiveAmount>());
      expect(entry().valueOrNull!.signedMinor, 5000);
    });

    test('an OUT entry sums negative while storing a positive amount', () {
      final LedgerEntry out = LedgerEntry.create(
        id: 'led-2',
        categoryId: 'cat-1',
        direction: LedgerDirection.outbound,
        amountMinor: 5000,
        occurredAtMs: 1000,
        recordedAtMs: 1000,
        sourceType: LedgerSourceType.spending,
        sourceId: 'sp-1',
        sync: sync,
      ).valueOrNull!;
      expect(out.amountMinor, 5000);
      expect(out.signedMinor, -5000);
    });

    test('A TOMBSTONED LEDGER ENTRY IS REJECTED (INV-03)', () {
      // SCHEMA §3.7: is_deleted is never 1 for a ledger entry; such a row is
      // corruption, not a deletion.
      final SyncFields deleted = sync.tombstoned(2000);
      final Result<LedgerEntry, EntityFailure> r = entry(s: deleted);
      expect(r.isSuccess, isFalse);
      expect(r.failureOrNull, isA<LedgerEntryTombstoned>());
      expect(r.failureOrNull!.rule, 'V-06');
    });

    test('a redirect reason requires its source, and BASE forbids one', () {
      expect(
        entry(reason: AllocationReason.redirect).failureOrNull,
        isA<RedirectSourceMismatch>(),
      );
      expect(
        entry(
          reason: AllocationReason.base,
          redirectedFrom: 'cat-2',
        ).failureOrNull,
        isA<RedirectSourceMismatch>(),
      );
      expect(
        entry(
          reason: AllocationReason.redirect,
          redirectedFrom: 'cat-2',
        ).isSuccess,
        isTrue,
      );
      expect(
        entry(
          reason: AllocationReason.sinkTerminal,
          redirectedFrom: 'cat-2',
        ).isSuccess,
        isTrue,
      );
    });
  });

  group('AllocationLine', () {
    test('A ZERO LINE IS REJECTED — no line, not a zero line', () {
      // ALLOCATION_ALGORITHM §2.2: a zero line would write a ledger row saying
      // no money moved, inflating the highest-volume table with rows carrying
      // no information.
      expect(
        AllocationLine.create(
          categoryId: 'cat-1',
          amountMinor: 0,
          reason: AllocationReason.base,
        ).failureOrNull,
        isA<NonPositiveAmount>(),
      );
      expect(
        AllocationLine.create(
          categoryId: 'cat-1',
          amountMinor: -1,
          reason: AllocationReason.base,
        ).failureOrNull,
        isA<NonPositiveAmount>(),
      );
    });

    test('a negative hop count is rejected', () {
      expect(
        AllocationLine.create(
          categoryId: 'cat-1',
          amountMinor: 100,
          reason: AllocationReason.base,
          hopCount: -1,
        ).failureOrNull,
        isA<NegativeHopCount>(),
      );
    });
  });

  group('SpendingTransaction', () {
    test('amount must be positive', () {
      expect(
        SpendingTransaction.create(
          id: 'sp-1',
          amountMinor: 0,
          categoryId: 'cat-1',
          occurredAtMs: 1000,
          recordedAtMs: 1000,
          sync: sync,
        ).failureOrNull,
        isA<NonPositiveAmount>(),
      );
    });
  });

  group('AppSettings', () {
    Result<AppSettings, EntityFailure> settings({
      int exponent = 2,
      String code = 'PKR',
      String locale = 'en_PK',
    }) => AppSettings.create(
      currencyCode: code,
      currencyMinorExponent: exponent,
      locale: locale,
      schemaVersion: 1,
      sync: sync,
    );

    test('accepts exponents 0, 2 and 3 and rejects everything else (V-25)', () {
      for (final int ok in <int>[0, 2, 3]) {
        expect(
          settings(exponent: ok).isSuccess,
          isTrue,
          reason: 'exponent $ok',
        );
      }
      for (final int bad in <int>[-1, 1, 4, 8]) {
        expect(
          settings(exponent: bad).failureOrNull,
          isA<UnsupportedCurrencyExponent>(),
          reason: 'exponent $bad',
        );
      }
    });

    test('the currency is derived here, the one place it is defined', () {
      final AppSettings s = settings(code: 'KWD', exponent: 3).valueOrNull!;
      expect(s.currency.code, 'KWD');
      expect(s.currency.minorUnitExponent, 3);
      expect(s.currency.minorUnitsPerMajor, 1000);
    });

    test(
      'sinkFor picks by scope, keeping business overflow in the business',
      () {
        final AppSettings s = AppSettings.create(
          currencyCode: 'PKR',
          currencyMinorExponent: 2,
          locale: 'en_PK',
          schemaVersion: 1,
          businessScopeEnabled: true,
          personalSinkCategoryId: 'cat-personal-sink',
          businessSinkCategoryId: 'cat-business-sink',
          sync: sync,
        ).valueOrNull!;
        expect(s.sinkFor(MoneyScope.personal), 'cat-personal-sink');
        expect(s.sinkFor(MoneyScope.business), 'cat-business-sink');
      },
    );

    test('the id is always the singleton constant', () {
      expect(settings().valueOrNull!.id, 'singleton');
    });
  });

  group('SyncFields', () {
    test(
      'tombstoning sets the flag, the timestamp and updated_at together',
      () {
        final SyncFields t = sync.tombstoned(5000);
        expect(t.isDeleted, isTrue);
        expect(t.deletedAtMs, 5000);
        expect(t.updatedAtMs, 5000);
        expect(t.hlc, sync.hlc);
      },
    );

    test('compares by value', () {
      expect(sync, equals(sync.copyWith()));
      expect(sync, isNot(equals(sync.copyWith(hlc: 'other'))));
    });
  });
}
