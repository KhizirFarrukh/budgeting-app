import 'package:pookiebudget/domain/money/clock.dart';

/// A [Clock] under complete test control.
///
/// Substage 3.8.2: *"so no test depends on wall-clock time."* Substage 3.8's
/// `must_not` is blunter still — *"Do not write a test that reads the system
/// clock."*
///
/// This matters beyond flakiness. INV-08 requires the allocation engine to be
/// deterministic, and the engine's `evaluated_at_ms` comes from a clock read by
/// the *caller*. A test whose clock moves cannot assert byte-identical output.
class FakeClock implements Clock {
  FakeClock([int initialMs = _defaultStart]) : _nowMs = initialMs;

  /// 2026-01-01T00:00:00Z. A fixed, recognisable instant — a test that prints
  /// a timestamp should show something obviously synthetic rather than
  /// something that looks like real data.
  static const int _defaultStart = 1767225600000;

  int _nowMs;

  /// Every call this clock has served, in order.
  ///
  /// Lets a test assert *how many times* the clock was read, which is how the
  /// engine's no-clock rule gets verified from the outside: the engine should
  /// cause zero reads.
  final List<int> reads = <int>[];

  @override
  int nowMs() {
    reads.add(_nowMs);
    return _nowMs;
  }

  /// Moves time forward. Negative values are rejected — a clock that goes
  /// backwards is a bug in the test, and hides HLC ordering defects rather
  /// than exposing them (Stage 7 tests skew deliberately and explicitly).
  void advance(Duration by) {
    if (by.isNegative) {
      throw ArgumentError.value(
        by,
        'by',
        'FakeClock cannot go backwards. To test clock skew, construct a '
            'separate clock at an earlier instant — Stage 7 substage 7.4.6.',
      );
    }
    _nowMs += by.inMilliseconds;
  }

  /// Jumps to an exact instant, including backwards.
  ///
  /// Separate from [advance] so that going backwards is always deliberate and
  /// visible at the call site.
  void setTo(int epochMs) => _nowMs = epochMs;

  /// The current instant without recording a read.
  int peek() => _nowMs;
}
