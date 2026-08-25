import 'package:flutter_test/flutter_test.dart';
import 'package:pookiebudget/domain/allocation/period.dart';

/// Substage 4.6.2 and SCHEMA V-20.
///
/// The acceptance criterion is specific: *"Period-scoped derivation handles an
/// anchor day of 31 through a 28-day February without skipping or duplicating a
/// period."* The named pitfall is its mirror: *"period logic that silently skips
/// February when the anchor day is 30 or 31."*
///
/// Both are properties of a *sequence*, not of a single call, so the central
/// tests below walk a whole year and assert contiguity rather than checking
/// individual boundaries and hoping they line up.
void main() {
  int utcMs(int year, int month, int day) =>
      DateTime.utc(year, month, day).millisecondsSinceEpoch;

  group('calendar arithmetic', () {
    test('leap years follow the full Gregorian rule', () {
      expect(isLeapYear(2024), isTrue, reason: 'divisible by 4');
      expect(isLeapYear(2026), isFalse);
      expect(
        isLeapYear(1900),
        isFalse,
        reason: 'a century that is not divisible by 400',
      );
      expect(isLeapYear(2000), isTrue, reason: 'divisible by 400');
      // Anyone scrolling a projection far enough will be asked about this one.
      expect(isLeapYear(2100), isFalse);
    });

    test('February has the right length in both kinds of year', () {
      expect(daysInMonth(2026, 2), 28);
      expect(daysInMonth(2024, 2), 29);
      expect(daysInMonth(2026, 12), 31);
      expect(daysInMonth(2026, 4), 30);
    });

    test('V-20 — the anchor clamps to the last day, never rolls forward', () {
      // The table from SCHEMA V-20, verbatim.
      expect(clampedAnchorDay(2026, 1, 31), 31, reason: 'January');
      expect(clampedAnchorDay(2026, 2, 31), 28, reason: 'common February');
      expect(clampedAnchorDay(2024, 2, 31), 29, reason: 'leap February');
      expect(clampedAnchorDay(2026, 4, 31), 30, reason: 'April');

      expect(clampedAnchorDay(2026, 1, 30), 30);
      expect(clampedAnchorDay(2026, 2, 30), 28);
      expect(clampedAnchorDay(2024, 2, 30), 29);
      expect(clampedAnchorDay(2026, 4, 30), 30);

      expect(clampedAnchorDay(2026, 1, 29), 29);
      expect(clampedAnchorDay(2026, 2, 29), 28);
      expect(clampedAnchorDay(2024, 2, 29), 29);
      expect(clampedAnchorDay(2026, 4, 29), 29);
    });

    test('an anchor that exists is never moved', () {
      for (int month = 1; month <= 12; month++) {
        expect(clampedAnchorDay(2026, month, 1), 1);
        expect(clampedAnchorDay(2026, month, 15), 15);
      }
    });
  });

  group('ANCHOR 31 THROUGH A 28-DAY FEBRUARY', () {
    test('the February period starts on the 28th and ends on 31 March', () {
      final PeriodDefinition february = periodContaining(
        atMs: utcMs(2026, 3, 1),
        anchorDay: 31,
      );
      expect(february.startMs, utcMs(2026, 2, 28));
      expect(february.endMs, utcMs(2026, 3, 31));
    });

    test('in a leap year it starts on the 29th', () {
      final PeriodDefinition february = periodContaining(
        atMs: utcMs(2024, 3, 1),
        anchorDay: 31,
      );
      expect(february.startMs, utcMs(2024, 2, 29));
      expect(february.endMs, utcMs(2024, 3, 31));
    });

    test('28 February belongs to the new period, not the old one', () {
      // The boundary instant itself. Half-open means it belongs to exactly one
      // period; if both claimed it, an allocation landing on the anchor would
      // fund a bill twice, and if neither did, it would fund it never.
      final PeriodDefinition atBoundary = periodContaining(
        atMs: utcMs(2026, 2, 28),
        anchorDay: 31,
      );
      expect(atBoundary.startMs, utcMs(2026, 2, 28));

      final PeriodDefinition justBefore = periodContaining(
        atMs: utcMs(2026, 2, 28) - 1,
        anchorDay: 31,
      );
      expect(justBefore.startMs, utcMs(2026, 1, 31));
      expect(
        justBefore.endMs,
        atBoundary.startMs,
        reason: 'contiguous: one period ends exactly where the next begins',
      );
    });

    test('TWELVE PERIODS A YEAR, NO GAP AND NO OVERLAP', () {
      // The property the criterion is really about. Checking boundaries one at
      // a time and hoping they line up is how a skipped February survives
      // review; walking the sequence makes a gap impossible to miss.
      for (final int anchor in <int>[28, 29, 30, 31]) {
        PeriodDefinition period = periodContaining(
          atMs: utcMs(2026, 1, 31),
          anchorDay: anchor,
        );
        final int yearStart = period.startMs;
        final List<PeriodDefinition> year = <PeriodDefinition>[period];

        for (int i = 0; i < 11; i++) {
          final PeriodDefinition next = nextPeriod(period);
          expect(
            next.startMs,
            period.endMs,
            reason:
                'anchor $anchor, period ${i + 1}: a gap here is a month whose '
                'allocations belong to no period at all',
          );
          expect(
            next.endMs,
            greaterThan(next.startMs),
            reason: 'anchor $anchor: a period must have positive length',
          );
          year.add(next);
          period = next;
        }

        expect(year, hasLength(12));
        expect(
          year.last.endMs,
          greaterThan(yearStart),
          reason: 'anchor $anchor: twelve periods must advance a full year',
        );
        // Twelve consecutive periods span roughly a year — never two, which is
        // what a skipped February would produce.
        final int spanDays =
            (year.last.endMs - yearStart) ~/ Duration.millisecondsPerDay;
        expect(spanDays, inInclusiveRange(365, 366));
      }
    });

    test('every instant in a year lands in exactly one period', () {
      // The complement of the contiguity check: walk day by day and assert the
      // period found actually contains the day. Catches an off-by-one that
      // leaves the sequence contiguous but shifted.
      for (int month = 1; month <= 12; month++) {
        for (int day = 1; day <= daysInMonth(2026, month); day++) {
          final int instant = utcMs(2026, month, day);
          final PeriodDefinition period = periodContaining(
            atMs: instant,
            anchorDay: 31,
          );
          expect(
            period.contains(instant),
            isTrue,
            reason: '2026-$month-$day fell outside the period returned for it',
          );
        }
      }
    });

    test('nextPeriod does not compound the clamp', () {
      // Adding a month to a clamped start would give 28 Feb -> 28 Mar, and the
      // anchor of 31 would be lost permanently after one short month. Deriving
      // the next period from the instant after this one ends cannot drift.
      final PeriodDefinition february = periodContaining(
        atMs: utcMs(2026, 2, 28),
        anchorDay: 31,
      );
      final PeriodDefinition march = nextPeriod(february);
      expect(march.startMs, utcMs(2026, 3, 31));
      expect(
        nextPeriod(march).startMs,
        utcMs(2026, 4, 30),
        reason: 'April clamps to 30, then May must return to 31',
      );
      expect(nextPeriod(nextPeriod(march)).startMs, utcMs(2026, 5, 31));
    });

    test('previousPeriod is the inverse of nextPeriod', () {
      final PeriodDefinition march = periodContaining(
        atMs: utcMs(2026, 3, 31),
        anchorDay: 31,
      );
      expect(previousPeriod(nextPeriod(march)), march);
      expect(nextPeriod(previousPeriod(march)), march);
    });

    test('the year boundary is crossed correctly', () {
      final PeriodDefinition december = periodContaining(
        atMs: utcMs(2026, 12, 31),
        anchorDay: 31,
      );
      expect(december.startMs, utcMs(2026, 12, 31));
      expect(december.endMs, utcMs(2027, 1, 31));

      // 15 January falls *before* the 31st, so it belongs to the period that
      // opened on 31 December. Stepping back once from there lands in November,
      // which has 30 days — so the anchor clamps, and the year rolls back.
      final PeriodDefinition november = previousPeriod(
        periodContaining(atMs: utcMs(2026, 1, 15), anchorDay: 31),
      );
      expect(november.startMs, utcMs(2025, 11, 30));
      expect(november.endMs, utcMs(2025, 12, 31));
    });
  });

  group('timezone is an argument, never the platform', () {
    test('a positive offset moves the boundary earlier in UTC', () {
      const int pkt = 5 * 60 * 60 * 1000; // UTC+5
      final PeriodDefinition period = periodContaining(
        atMs: utcMs(2026, 3, 15),
        anchorDay: 1,
        utcOffsetMs: pkt,
      );
      // Local midnight on 1 March in UTC+5 is 19:00 on 28 February UTC. A bill
      // due on the 1st is due at the start of the 1st where the user lives.
      expect(period.startMs, utcMs(2026, 3, 1) - pkt);
      expect(period.endMs, utcMs(2026, 4, 1) - pkt);
    });

    test('offsets do not break contiguity', () {
      for (final int offset in <int>[
        -11 * 60 * 60 * 1000,
        0,
        5 * 60 * 60 * 1000 + 30 * 60 * 1000, // UTC+5:30, a half-hour zone
        14 * 60 * 60 * 1000,
      ]) {
        PeriodDefinition period = periodContaining(
          atMs: utcMs(2026, 1, 15),
          anchorDay: 31,
          utcOffsetMs: offset,
        );
        for (int i = 0; i < 12; i++) {
          final PeriodDefinition next = nextPeriod(period, utcOffsetMs: offset);
          expect(next.startMs, period.endMs, reason: 'offset $offset');
          period = next;
        }
      }
    });
  });

  test('isValid rejects what the engine reports as E-12', () {
    expect(
      const PeriodDefinition(startMs: 100, endMs: 100, anchorDay: 1).isValid,
      isFalse,
      reason: 'a zero-length period would give every category zero headroom',
    );
    expect(
      const PeriodDefinition(startMs: 200, endMs: 100, anchorDay: 1).isValid,
      isFalse,
    );
    expect(
      const PeriodDefinition(startMs: 0, endMs: 100, anchorDay: 0).isValid,
      isFalse,
    );
    expect(
      const PeriodDefinition(startMs: 0, endMs: 100, anchorDay: 32).isValid,
      isFalse,
    );
    expect(
      const PeriodDefinition(startMs: 0, endMs: 100, anchorDay: 31).isValid,
      isTrue,
    );
  });
}
