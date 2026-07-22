import 'package:pookiebudget/domain/money/clock.dart';

/// The real [Clock].
///
/// **This is the only file in the project permitted to call
/// `DateTime.now()`.** Guard G4 fails the build on any other occurrence, and
/// skips this file by name (`tool/guards/guards.dart`).
///
/// Everything else receives time injected, which is what makes INV-08's
/// determinism testable: the allocation engine's `evaluated_at_ms` is read
/// here, by the caller, and crosses the purity boundary as data.
class SystemClock implements Clock {
  const SystemClock();

  @override
  int nowMs() => DateTime.now().toUtc().millisecondsSinceEpoch;
}
