/// Period boundary arithmetic — **the single authority**, ARCHITECTURE §8.4.
///
/// Two layers need to know which period an instant falls in: the engine, to
/// compute headroom for a `FIXED_RECURRING` category, and the data layer, to
/// compute how much was already allocated in that period. Implemented twice,
/// the anchor-day-31-in-February rule drifts — the two would disagree about
/// which period a payment belongs to, and headroom would be computed against
/// the wrong window.
///
/// So it is implemented once, here, and `data/balances/period_boundaries.dart`
/// contains no arithmetic at all: it calls this and applies the result to a
/// query.
///
/// ## Everything arrives as an argument
///
/// No clock is read (INV-09, guard G4) and no platform timezone is consulted.
/// [utcOffsetMs] is passed in for the reason ARCHITECTURE §8.3 gives: *"so
/// period boundary behaviour is testable without changing the device
/// timezone."* Guard G2 additionally forbids `async`, `Future`, `Stream` and
/// `Random` anywhere under `lib/domain/allocation/`, so every function here is
/// synchronous and total.
library;

/// One period window: `[startMs, endMs)`.
///
/// **Half-open, and stated in the type.** Consecutive periods share a boundary
/// instant, and if both claimed it, an allocation landing exactly on the anchor
/// would count in two periods — funding a bill twice. If neither claimed it, it
/// would count in none.
final class PeriodDefinition {
  const PeriodDefinition({
    required this.startMs,
    required this.endMs,
    required this.anchorDay,
  });

  /// Inclusive start, UTC epoch ms.
  final int startMs;

  /// **Exclusive** end, UTC epoch ms.
  final int endMs;

  /// 1–31, the configured anchor. Carried so the engine can report
  /// `PeriodDefinitionInvalid` (E-12) without a second lookup.
  final int anchorDay;

  /// Whether [atMs] falls in this period.
  bool contains(int atMs) => atMs >= startMs && atMs < endMs;

  /// The window's length in milliseconds. Varies by month, deliberately —
  /// a fixed 30-day window would drift away from the anchor date.
  int get lengthMs => endMs - startMs;

  /// E-12's condition, checked where the value is built rather than where it
  /// is used.
  bool get isValid => startMs < endMs && anchorDay >= 1 && anchorDay <= 31;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PeriodDefinition &&
          runtimeType == other.runtimeType &&
          startMs == other.startMs &&
          endMs == other.endMs &&
          anchorDay == other.anchorDay;

  @override
  int get hashCode => Object.hash(startMs, endMs, anchorDay);

  @override
  String toString() =>
      'PeriodDefinition([$startMs, $endMs), anchor $anchorDay)';
}

/// Days in [month] of [year]. Month is 1–12.
///
/// Written out rather than derived from `DateTime(year, month + 1, 0)` because
/// that idiom silently rolls December into the next year, and the rollover is
/// exactly the case this file exists to get right.
int daysInMonth(int year, int month) {
  const List<int> lengths = <int>[
    31, 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31, //
  ];
  if (month == 2 && isLeapYear(year)) return 29;
  return lengths[month - 1];
}

/// The proleptic Gregorian leap rule, in full.
///
/// The century exceptions matter: 2100 is not a leap year, and an app storing
/// a bill anchor of 29 will be asked about February 2100 by anyone who scrolls
/// a projection far enough.
bool isLeapYear(int year) =>
    (year % 4 == 0 && year % 100 != 0) || year % 400 == 0;

/// The anchor date within one month, **clamped** to the last day when the
/// anchor does not exist. SCHEMA V-20.
///
/// | Anchor | January | February (common) | February (leap) | April |
/// |---|---|---|---|---|
/// | 31 | 31 Jan | **28 Feb** | **29 Feb** | **30 Apr** |
/// | 30 | 30 Jan | **28 Feb** | **29 Feb** | 30 Apr |
/// | 29 | 29 Jan | **28 Feb** | 29 Feb | 29 Apr |
///
/// **Clamping, not rolling forward.** Rolling 31 February into 3 March would
/// make the boundary land *after* the next month's anchor in some years,
/// producing either a skipped period or two overlapping ones. Clamping keeps
/// exactly twelve periods per year for every anchor value, always.
int clampedAnchorDay(int year, int month, int anchorDay) {
  final int last = daysInMonth(year, month);
  return anchorDay < last ? anchorDay : last;
}

/// The UTC epoch millisecond of the anchor instant in a given month, adjusted
/// for [utcOffsetMs].
///
/// The anchor falls at local midnight: a bill due on the 1st becomes due at the
/// start of the 1st where the user lives, not at 00:00 UTC, which may be the
/// previous afternoon for them.
int anchorInstantMs({
  required int year,
  required int month,
  required int anchorDay,
  required int utcOffsetMs,
}) {
  final int day = clampedAnchorDay(year, month, anchorDay);
  // Constructed as UTC and shifted, never as a local `DateTime`: a local
  // construction would consult the platform timezone, which is the dependency
  // ARCHITECTURE §8.3 removes so that this is testable anywhere.
  final DateTime utcMidnight = DateTime.utc(year, month, day);
  return utcMidnight.millisecondsSinceEpoch - utcOffsetMs;
}

/// The period containing [atMs], for a category anchored on [anchorDay].
///
/// A period runs from one month's anchor instant to the next month's,
/// half-open. If [atMs] falls before this month's anchor it belongs to the
/// period that began last month.
///
/// [utcOffsetMs] is the local offset from UTC in milliseconds — positive east.
/// It is an argument, never read from the platform.
PeriodDefinition periodContaining({
  required int atMs,
  required int anchorDay,
  int utcOffsetMs = 0,
}) {
  final DateTime local = DateTime.fromMillisecondsSinceEpoch(
    atMs + utcOffsetMs,
    isUtc: true,
  );

  int year = local.year;
  int month = local.month;

  // Which side of this month's anchor are we on? Compared against the *clamped*
  // anchor, so 31 January and 28 February are both "this month's anchor" for
  // their months rather than dates that never arrive.
  final int thisMonthAnchor = anchorInstantMs(
    year: year,
    month: month,
    anchorDay: anchorDay,
    utcOffsetMs: utcOffsetMs,
  );
  if (atMs < thisMonthAnchor) {
    month -= 1;
    if (month == 0) {
      month = 12;
      year -= 1;
    }
  }

  int nextMonth = month + 1;
  int nextYear = year;
  if (nextMonth == 13) {
    nextMonth = 1;
    nextYear += 1;
  }

  return PeriodDefinition(
    startMs: anchorInstantMs(
      year: year,
      month: month,
      anchorDay: anchorDay,
      utcOffsetMs: utcOffsetMs,
    ),
    endMs: anchorInstantMs(
      year: nextYear,
      month: nextMonth,
      anchorDay: anchorDay,
      utcOffsetMs: utcOffsetMs,
    ),
    anchorDay: anchorDay,
  );
}

/// The period immediately following [period].
///
/// Derived by asking [periodContaining] about the instant one millisecond after
/// this period ends, rather than by adding a month to the start. That is not a
/// stylistic choice: adding a month to a clamped start would compound the
/// clamp — a period starting 28 February would produce 28 March, and the anchor
/// of 31 would be lost after one short month.
PeriodDefinition nextPeriod(PeriodDefinition period, {int utcOffsetMs = 0}) =>
    periodContaining(
      atMs: period.endMs,
      anchorDay: period.anchorDay,
      utcOffsetMs: utcOffsetMs,
    );

/// The period immediately preceding [period].
PeriodDefinition previousPeriod(
  PeriodDefinition period, {
  int utcOffsetMs = 0,
}) => periodContaining(
  atMs: period.startMs - 1,
  anchorDay: period.anchorDay,
  utcOffsetMs: utcOffsetMs,
);
