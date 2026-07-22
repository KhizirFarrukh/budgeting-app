import 'package:flutter_test/flutter_test.dart';
import 'package:pookiebudget/domain/entities/category.dart';
import 'package:pookiebudget/domain/entities/entity_failure.dart';
import 'package:pookiebudget/domain/entities/enums.dart';
import 'package:pookiebudget/domain/entities/headroom.dart';
import 'package:pookiebudget/domain/entities/redirect_target.dart';
import 'package:pookiebudget/domain/entities/sync_fields.dart';
import 'package:pookiebudget/domain/money/currency.dart';
import 'package:pookiebudget/domain/money/money.dart';
import 'package:pookiebudget/domain/result.dart';

/// FR-16 / ADR-006 — ceiling-triggered cascade redirect.
///
/// The engine itself is Stage 5, driven by golden vectors V-16…V-19. What Stage
/// 4 can and must prove is that **the data model supports each of the four
/// cases the requirement names, and that the arithmetic those vectors assert is
/// actually reachable from these types**. Each group below walks its vector by
/// hand using `Category.headroom` and `Money.multiplyByBasisPoints`, and
/// asserts conservation.
///
/// Doing the arithmetic here rather than waiting for Stage 5 is deliberate: a
/// vector whose expected numbers were never executed is a guess, and substage
/// 2.8 found a real defect precisely by running the algorithm instead of
/// reading it.
void main() {
  const Currency pkr = Currency(code: 'PKR', minorUnitExponent: 2);
  const SyncFields sync = SyncFields(
    updatedAtMs: 1000,
    updatedByDevice: 'device-a',
    hlc: '0000000001000:0000:device-a',
  );

  Category reserve({
    required String id,
    required int ceiling,
    int? referenceMonthly,
    RedirectMode mode = RedirectMode.priority,
  }) => Category.create(
    id: id,
    groupId: 'savings',
    name: id,
    type: CategoryType.accumulatingReserve,
    sortOrder: 0,
    ceilingMinor: ceiling,
    referenceMonthlyAmountMinor: referenceMonthly,
    redirectMode: mode,
    sync: sync,
  ).valueOrNull!;

  RedirectTarget target(
    String source,
    String to, {
    required int priority,
    int? basisPoints,
  }) => RedirectTarget.create(
    id: 'rt-$source-$to',
    sourceCategoryId: source,
    targetCategoryId: to,
    priority: priority,
    basisPoints: basisPoints,
    sync: sync,
  ).valueOrNull!;

  // ===========================================================================
  // The requirement's own example
  // ===========================================================================

  group('the EV Bike example from the requirement', () {
    test('below its ceiling, a reserve simply accepts its allocation', () {
      // "While a category's balance is below its ceiling, its reference amount
      // is allocated to it normally on every income event."
      final Category bike = reserve(
        id: 'ev_bike',
        ceiling: 350000,
        referenceMonthly: 193000,
      );
      final Headroom room = bike.headroom(
        currentBalanceMinor: 134000,
        allocatedInPeriodMinor: 0,
      );
      expect(room, const Headroom.bounded(216000));
      expect(room.accept(193000), 193000);
      expect(room.overflowOf(193000), 0);
    });

    test('the reference amount is stored, and only on a reserve (C-33)', () {
      expect(
        reserve(
          id: 'ev_bike',
          ceiling: 350000,
          referenceMonthly: 193000,
        ).referenceMonthlyAmountMinor,
        193000,
      );
      // OQ-19 is open on whether this drives allocation; C-33 makes sure that
      // whichever way it resolves, no row exists that the answer invalidates.
      expect(
        Category.create(
          id: 'groceries',
          groupId: 'spending',
          name: 'Groceries',
          type: CategoryType.uncappedFlow,
          sortOrder: 0,
          referenceMonthlyAmountMinor: 193000,
          sync: sync,
        ).failureOrNull,
        isA<ReferenceAmountTypeMismatch>(),
      );
      expect(
        Category.create(
          id: 'ev_bike',
          groupId: 'savings',
          name: 'EV Bike',
          type: CategoryType.accumulatingReserve,
          sortOrder: 0,
          ceilingMinor: 350000,
          referenceMonthlyAmountMinor: 0,
          sync: sync,
        ).failureOrNull,
        isA<NonPositiveAmount>(),
      );
    });
  });

  // ===========================================================================
  // V-16 — simple single-target redirect (PRIORITY, first target has room)
  // ===========================================================================

  group('V-16 simple redirect: the first target has room', () {
    test('overflow goes wholly to the priority-0 target, and conserves', () {
      final Category bike = reserve(id: 'ev_bike', ceiling: 350000);
      final List<RedirectTarget> targets = <RedirectTarget>[
        target('ev_bike', 'wedding', priority: 1),
        target('ev_bike', 'hajj', priority: 0),
      ];

      // Phase A gave the bike 193,000; it is at 250,000 of a 350,000 ceiling.
      final Headroom room = bike.headroom(
        currentBalanceMinor: 250000,
        allocatedInPeriodMinor: 0,
      );
      final int accepted = room.accept(193000);
      final int overflow = room.overflowOf(193000);
      expect(accepted, 100000);
      expect(overflow, 93000);

      // PRIORITY offers the WHOLE overflow to the first live target.
      final RedirectTarget first = targets.inOfferOrder.first;
      expect(first.targetCategoryId, 'hajj');

      final Category hajj = reserve(id: 'hajj', ceiling: 500000);
      final Headroom hajjRoom = hajj.headroom(
        currentBalanceMinor: 0,
        allocatedInPeriodMinor: 0,
      );
      expect(hajjRoom.accept(overflow), 93000);
      // Wedding gets nothing — that is what "fill one, then the next" means.
      expect(hajjRoom.overflowOf(overflow), 0);

      // Conservation across the whole event: 193,000 spend + these two.
      expect(accepted + 93000 + 193000, 386000);
    });

    test('offer order is priority ASC then id ASC, and is deterministic', () {
      // INV-08. `id` breaks a tie that U-12 should prevent but a merge can
      // still produce, so the engine never has to pick arbitrarily.
      final List<RedirectTarget> shuffled = <RedirectTarget>[
        target('a', 'z', priority: 2),
        target('a', 'm', priority: 0),
        target('a', 'b', priority: 1),
      ];
      expect(
        shuffled.inOfferOrder
            .map((RedirectTarget t) => t.targetCategoryId)
            .toList(),
        <String>['m', 'b', 'z'],
      );
      // Same input in a different order gives the same result.
      expect(
        shuffled.reversed.toList().inOfferOrder.map((RedirectTarget t) => t.id),
        shuffled.inOfferOrder.map((RedirectTarget t) => t.id),
      );
    });
  });

  // ===========================================================================
  // V-17 — multi-target SPLIT, with a leftover that must break a tie
  // ===========================================================================

  group('V-17 split redirect across two targets', () {
    test('93,001 splits 6000/4000 as 55,801 / 37,200 and conserves', () {
      final Category bike = reserve(
        id: 'ev_bike',
        ceiling: 350000,
        mode: RedirectMode.split,
      );
      final List<RedirectTarget> targets = <RedirectTarget>[
        target('ev_bike', 'hajj', priority: 0, basisPoints: 6000),
        target('ev_bike', 'wedding', priority: 1, basisPoints: 4000),
      ];
      expect(
        validateRedirectMode(RedirectMode.split, targets).isSuccess,
        isTrue,
      );

      final Headroom room = bike.headroom(
        currentBalanceMinor: 250001,
        allocatedInPeriodMinor: 0,
      );
      final int overflow = room.overflowOf(193000);
      expect(room.accept(193000), 99999);
      expect(overflow, 93001);

      final int divisor = targets.shareDivisor;
      expect(divisor, 10000);

      final Money parcel = Money.fromMinorUnits(overflow, pkr);
      final BasisPointSplit hajj = parcel
          .multiplyByBasisPoints(6000, divisor: divisor)
          .valueOrNull!;
      final BasisPointSplit wedding = parcel
          .multiplyByBasisPoints(4000, divisor: divisor)
          .valueOrNull!;

      expect(hajj.floor.minorUnits, 55800);
      expect(wedding.floor.minorUnits, 37200);
      // One minor unit is left over; the larger remainder takes it.
      expect(hajj.remainder, greaterThan(wedding.remainder));
      final int leftover =
          overflow - hajj.floor.minorUnits - wedding.floor.minorUnits;
      expect(leftover, 1);

      final int hajjFinal = hajj.floor.minorUnits + leftover;
      expect(hajjFinal, 55801);
      // CONSERVATION: nothing created, nothing lost.
      expect(hajjFinal + wedding.floor.minorUnits, overflow);
      expect(99999 + hajjFinal + wedding.floor.minorUnits + 193000, 386000);
    });

    test('THE DIVISOR IS THE LIVE TOTAL, NOT A CONSTANT 10000', () {
      // ALLOCATION_ALGORITHM §3.10.3. If one of three equal targets is
      // archived, the live weights total 6667 — dividing by 10000 would leave a
      // third of the overflow unallocated. The identical defect substage 2.8
      // found in override redistribution, in a second place.
      final List<RedirectTarget> live = <RedirectTarget>[
        target('src', 'a', priority: 0, basisPoints: 3333),
        target('src', 'b', priority: 1, basisPoints: 3334),
      ];
      expect(live.shareDivisor, 6667);

      const int overflow = 90000;
      final Money parcel = Money.fromMinorUnits(overflow, pkr);
      final int a = parcel
          .multiplyByBasisPoints(3333, divisor: live.shareDivisor)
          .valueOrNull!
          .floor
          .minorUnits;
      final int b = parcel
          .multiplyByBasisPoints(3334, divisor: live.shareDivisor)
          .valueOrNull!
          .floor
          .minorUnits;
      // Floors plus leftover recover the whole overflow.
      expect(a + b, lessThanOrEqualTo(overflow));
      expect(overflow - a - b, lessThan(2));

      // The same computation against the constant loses roughly a third.
      final int wrongA = parcel
          .multiplyByBasisPoints(3333)
          .valueOrNull!
          .floor
          .minorUnits;
      final int wrongB = parcel
          .multiplyByBasisPoints(3334)
          .valueOrNull!
          .floor
          .minorUnits;
      expect(overflow - wrongA - wrongB, greaterThan(29000));
    });

    test('V-29 — split shares must total exactly 10000', () {
      final List<RedirectTarget> short = <RedirectTarget>[
        target('src', 'a', priority: 0, basisPoints: 6000),
        target('src', 'b', priority: 1, basisPoints: 3000),
      ];
      expect(short.sharesSumToFull, isFalse);
      final Result<void, EntityFailure> r = validateRedirectMode(
        RedirectMode.split,
        short,
      );
      expect(r.isSuccess, isFalse);
      expect(r.failureOrNull, isA<RedirectSharesDoNotSum>());
      expect((r.failureOrNull! as RedirectSharesDoNotSum).total, 9000);
    });

    test('V-30 — mode and shares must agree, both ways', () {
      final List<RedirectTarget> weighted = <RedirectTarget>[
        target('src', 'a', priority: 0, basisPoints: 10000),
      ];
      final List<RedirectTarget> unweighted = <RedirectTarget>[
        target('src', 'a', priority: 0),
      ];
      expect(
        validateRedirectMode(RedirectMode.priority, weighted).failureOrNull,
        isA<RedirectModeMismatch>(),
      );
      expect(
        validateRedirectMode(RedirectMode.split, unweighted).failureOrNull,
        isA<RedirectModeMismatch>(),
      );
      expect(
        validateRedirectMode(RedirectMode.priority, unweighted).isSuccess,
        isTrue,
      );
      expect(
        validateRedirectMode(RedirectMode.split, weighted).isSuccess,
        isTrue,
      );
    });
  });

  // ===========================================================================
  // V-18 — chained cascade: sibling fallback, then descend, then sink
  // ===========================================================================

  group('V-18 chained cascade when a target is also full', () {
    test('sibling before descendant, then the sink, conserving throughout', () {
      // EV Bike full → Hajj (p0) partly full → Wedding (p1, EV Bike's SIBLING,
      // not Hajj's descendant) → sink. This is the ordering decision of
      // ALLOCATION_ALGORITHM §3.10.1; under the rejected reading Wedding would
      // never be reached.
      final Category bike = reserve(id: 'ev_bike', ceiling: 350000);
      final Category hajj = reserve(id: 'hajj', ceiling: 500000);
      final Category wedding = reserve(id: 'wedding', ceiling: 300000);
      final List<RedirectTarget> bikeTargets = <RedirectTarget>[
        target('ev_bike', 'hajj', priority: 0),
        target('ev_bike', 'wedding', priority: 1),
      ];

      // EV Bike is exactly at its ceiling: headroom zero, accepts nothing.
      final Headroom bikeRoom = bike.headroom(
        currentBalanceMinor: 350000,
        allocatedInPeriodMinor: 0,
      );
      expect(bikeRoom, const Headroom.bounded(0));
      expect(bikeRoom.accept(193000), 0);
      final int overflow = bikeRoom.overflowOf(193000);
      expect(overflow, 193000);

      // Hop 1 — the origin's priority-0 target.
      expect(bikeTargets.inOfferOrder[0].targetCategoryId, 'hajj');
      final Headroom hajjRoom = hajj.headroom(
        currentBalanceMinor: 460000,
        allocatedInPeriodMinor: 0,
      );
      final int hajjTakes = hajjRoom.accept(overflow);
      final int afterHajj = hajjRoom.overflowOf(overflow);
      expect(hajjTakes, 40000);
      expect(afterHajj, 153000);

      // Hop 2 — the origin's NEXT target, not Hajj's own chain.
      expect(bikeTargets.inOfferOrder[1].targetCategoryId, 'wedding');
      final Headroom weddingRoom = wedding.headroom(
        currentBalanceMinor: 280000,
        allocatedInPeriodMinor: 0,
      );
      final int weddingTakes = weddingRoom.accept(afterHajj);
      final int afterWedding = weddingRoom.overflowOf(afterHajj);
      expect(weddingTakes, 20000);
      expect(afterWedding, 133000);

      // Hop 3 — the origin's list is spent and Wedding has no targets of its
      // own, so the remainder terminates in the sink.
      const List<RedirectTarget> weddingTargets = <RedirectTarget>[];
      expect(weddingTargets.inOfferOrder, isEmpty);

      // CONSERVATION across the whole event, including the 193,000 base
      // allocation to the spending category.
      expect(hajjTakes + weddingTakes + afterWedding + 193000, 386000);
      // EV Bike accepted zero, so it produces NO line — not a zero line (§2.2).
      expect(bikeRoom.accept(193000), 0);
    });

    test(
      'a full target accepts nothing rather than going over its ceiling',
      () {
        // The clamp, at the point it matters most: an already-over-ceiling
        // category must not produce a negative acceptance that would break
        // conservation downstream.
        final Category hajj = reserve(id: 'hajj', ceiling: 500000);
        final Headroom over = hajj.headroom(
          currentBalanceMinor: 600000,
          allocatedInPeriodMinor: 0,
        );
        expect(over, const Headroom.bounded(0));
        expect(over.accept(153000), 0);
        expect(over.overflowOf(153000), 153000);
      },
    );
  });

  // ===========================================================================
  // V-19 — no valid target: the surplus fallback
  // ===========================================================================

  group('V-19 the chain runs out of valid targets', () {
    test('a category with no targets sends everything onward, losing none', () {
      final Category bike = reserve(id: 'ev_bike', ceiling: 350000);
      const List<RedirectTarget> none = <RedirectTarget>[];

      final Headroom room = bike.headroom(
        currentBalanceMinor: 350000,
        allocatedInPeriodMinor: 0,
      );
      final int overflow = room.overflowOf(193000);
      expect(none.inOfferOrder, isEmpty);
      // Nothing is absorbed and nothing is dropped: the full amount is still
      // looking for a home, and INV-07 routes it to the sink.
      expect(overflow, 193000);
      expect(room.accept(193000) + overflow, 193000);
    });

    test('THE SINK CAN ALWAYS ACCEPT — INV-07 terminates here', () {
      // C-19 guarantees the sink is uncapped, which is what makes "route the
      // funds to a default surplus bucket" a guarantee rather than a hope.
      final Category sink = Category.create(
        id: 'surplus',
        groupId: 'spending',
        name: 'Unallocated Surplus',
        type: CategoryType.uncappedFlow,
        sortOrder: 99,
        isSink: true,
        sync: sync,
      ).valueOrNull!;

      final Headroom room = sink.headroom(
        currentBalanceMinor: 999999999,
        allocatedInPeriodMinor: 999999999,
      );
      expect(room, isA<UnboundedHeadroom>());
      expect(room.accept(193000), 193000);
      expect(room.overflowOf(193000), 0);
      expect(room.isExhausted, isFalse);
    });

    test('a capped surplus bucket cannot be constructed', () {
      // The failure mode this guards: a sink that can refuse money is a
      // terminating guarantee that does not terminate.
      expect(
        Category.create(
          id: 'surplus',
          groupId: 'spending',
          name: 'Unallocated Surplus',
          type: CategoryType.accumulatingReserve,
          sortOrder: 0,
          isSink: true,
          ceilingMinor: 500000,
          sync: sync,
        ).failureOrNull,
        isA<SinkNotUncapped>(),
      );
    });
  });

  // ===========================================================================
  // Row-level rules
  // ===========================================================================

  group('RedirectTarget construction rules', () {
    test('C-32 — a negative priority is rejected', () {
      expect(
        RedirectTarget.create(
          id: 'rt-1',
          sourceCategoryId: 'a',
          targetCategoryId: 'b',
          priority: -1,
          sync: sync,
        ).failureOrNull,
        isA<NegativeRedirectPriority>(),
      );
    });

    test('C-31 — a share outside 0..10000 is rejected', () {
      for (final int bad in <int>[-1, 10001]) {
        expect(
          RedirectTarget.create(
            id: 'rt-1',
            sourceCategoryId: 'a',
            targetCategoryId: 'b',
            priority: 0,
            basisPoints: bad,
            sync: sync,
          ).failureOrNull,
          isA<BasisPointsOutOfRange>(),
          reason: 'share $bad',
        );
      }
    });

    test('copyWith cannot turn a valid row into a self-redirect', () {
      final RedirectTarget t = target('a', 'b', priority: 0);
      expect(
        t.copyWith(targetCategoryId: 'a').failureOrNull,
        isA<SelfRedirect>(),
      );
      expect(t.copyWith(priority: 3).valueOrNull!.priority, 3);
    });

    test('rows compare by value', () {
      expect(target('a', 'b', priority: 0), target('a', 'b', priority: 0));
      expect(
        target('a', 'b', priority: 0),
        isNot(target('a', 'b', priority: 1)),
      );
    });
  });
}
