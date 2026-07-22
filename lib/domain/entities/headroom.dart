/// How much a category can still accept **right now, in this run**.
///
/// ALLOCATION_ALGORITHM §3.1: *"Unbounded must be represented explicitly, as a
/// distinct value — not as `int64.max`."* Using a sentinel integer means every
/// arithmetic site has to remember it is a sentinel; `min(pending, headroom)`
/// against `int64.max` happens to work, but `headroom - accepted` quietly does
/// not, and a sentinel that leaks into a stored amount is a corrupt balance.
///
/// A sealed type makes the two cases exhaustive at every call site instead.
sealed class Headroom {
  const Headroom();

  /// A capped category with [minorUnits] of room left. Never negative — the
  /// factory clamps, see [Headroom.bounded].
  const factory Headroom.bounded(int minorUnits) = BoundedHeadroom._clamped;

  /// An uncapped category, or the sink. Accepts whatever it is given.
  const factory Headroom.unbounded() = UnboundedHeadroom;

  /// How much of [pending] this category will accept.
  ///
  /// The `min` that ALLOCATION_ALGORITHM §3.2 performs, written once here so no
  /// call site has to case on the type to do it.
  int accept(int pending) => switch (this) {
    UnboundedHeadroom() => pending,
    BoundedHeadroom(:final int minorUnits) =>
      pending < minorUnits ? pending : minorUnits,
  };

  /// What is left over after [accept]. Always `>= 0`.
  int overflowOf(int pending) => pending - accept(pending);

  bool get isExhausted => switch (this) {
    UnboundedHeadroom() => false,
    BoundedHeadroom(:final int minorUnits) => minorUnits == 0,
  };
}

/// A capped category's remaining room.
final class BoundedHeadroom extends Headroom {
  /// Clamps at zero, implementing the `max(0, …)` of ALLOCATION_ALGORITHM §3.1.
  ///
  /// *"`max(0, …)` is not decoration."* A balance may exceed its ceiling after
  /// a manual override, after the user lowered a ceiling, or after a merge
  /// brought in entries from another device. Without the clamp the subtraction
  /// goes negative, `accept` returns a negative number, and conservation
  /// breaks. This is common, not exotic.
  const BoundedHeadroom._clamped(int minorUnits)
    : minorUnits = minorUnits < 0 ? 0 : minorUnits;

  final int minorUnits;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is BoundedHeadroom &&
          runtimeType == other.runtimeType &&
          minorUnits == other.minorUnits;

  @override
  int get hashCode => minorUnits.hashCode;

  @override
  String toString() => 'Headroom.bounded($minorUnits)';
}

/// An uncapped category's room: no limit at all.
final class UnboundedHeadroom extends Headroom {
  const UnboundedHeadroom();

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is UnboundedHeadroom;

  @override
  int get hashCode => 0x0F1E2D3C;

  @override
  String toString() => 'Headroom.unbounded()';
}
