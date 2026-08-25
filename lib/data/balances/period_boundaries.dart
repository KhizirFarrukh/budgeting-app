/// Applying a period to a query. **Contains no period arithmetic.**
///
/// ARCHITECTURE §8.4 is explicit: *"`data/balances/period_boundaries.dart`
/// contains **no** period arithmetic; it calls the domain function and applies
/// the result to a query."*
///
/// That is the whole content of this file, and its shortness is the point. The
/// anchor-day-31-in-February rule exists in exactly one place
/// (`domain/allocation/period.dart`); if it were reimplemented here, the engine
/// and the data layer would eventually disagree about which period a payment
/// belongs to, and headroom would be computed against the wrong window. A
/// second implementation is not a risk to be managed but a defect to be
/// prevented, so there is nothing here to drift.
library;

import 'package:pookiebudget/domain/allocation/period.dart';
import 'package:pookiebudget/domain/repositories/repository_queries.dart';

/// The query range for [period].
///
/// Both types are half-open `[start, end)`, so this is a rename and not a
/// conversion — there is no boundary adjustment to get wrong. They stay
/// separate types because they mean different things: a `PeriodDefinition` is
/// a *billing* window with an anchor, a `DateRange` is any interval a query can
/// filter on.
DateRange rangeOf(PeriodDefinition period) =>
    DateRange(fromMs: period.startMs, toMs: period.endMs);

/// The period containing [atMs] for a category anchored on [anchorDay],
/// as a query range.
///
/// The convenience the data layer actually reaches for. [utcOffsetMs] is passed
/// straight through — never read from the platform, so period behaviour is
/// testable without changing the device timezone (ARCHITECTURE §8.3).
DateRange rangeContaining({
  required int atMs,
  required int anchorDay,
  int utcOffsetMs = 0,
}) => rangeOf(
  periodContaining(
    atMs: atMs,
    anchorDay: anchorDay,
    utcOffsetMs: utcOffsetMs,
  ),
);
