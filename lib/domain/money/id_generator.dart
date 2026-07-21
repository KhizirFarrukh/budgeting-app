/// A source of record identifiers, injected so tests get deterministic ids.
///
/// INV-12: all identifiers are client-generated UUIDs stored as text, so
/// records created offline on separate devices never collide and every write is
/// idempotent. No auto-increment integer key exists anywhere in the schema.
///
/// ARCHITECTURE.md §8.6 assigns versions by record class:
///
/// - **v7** for ledger entries and income events. Time-sortable, which gives
///   index locality where it matters: PRD §7.2 shows these are 80–89% of all
///   rows at the Heavy profile.
/// - **v4** for configuration records. Low volume, no ordering benefit, and v4
///   avoids embedding record-creation times in the sync payload.
abstract interface class IdGenerator {
  /// A time-sortable identifier, for high-volume append-only records.
  String newTimeSortableId();

  /// A random identifier, for configuration records.
  String newRandomId();
}
