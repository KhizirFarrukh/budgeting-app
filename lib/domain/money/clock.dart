/// A source of the current time, injected rather than read from the platform.
///
/// INV-09: all timestamps are UTC epoch milliseconds. Guard **G4** forbids
/// `DateTime.now()` anywhere except the real implementation of this interface,
/// so that every test controls time and no behaviour depends on the wall clock.
///
/// The allocation engine does not hold a `Clock` at all — stricter than the rest
/// of the domain layer. Its evaluation timestamp arrives in the request
/// (INV-08, ALLOCATION_ALGORITHM.md §1.1), because a pure function cannot read
/// anything, including this.
abstract interface class Clock {
  /// The current time as UTC epoch milliseconds.
  int nowMs();
}
