import 'package:pookiebudget/domain/entities/ledger_entry.dart';
import 'package:pookiebudget/domain/repositories/repository_failure.dart';
import 'package:pookiebudget/domain/repositories/repository_queries.dart';
import 'package:pookiebudget/domain/result.dart';

/// Read access to the immutable record of every money movement, and the one
/// way to add to it.
///
/// # There is no update method and no delete method
///
/// Not "there should not be" — there is not one. INV-03 is enforced here by
/// **absence**, because absence is the only enforcement that cannot be
/// forgotten under deadline. An editable ledger is an unauditable ledger, and
/// substage 4.5's whole point is that this is stronger than enforcing it by
/// discipline: a maintainer who wants to amend an entry finds no method to
/// call, rather than finding one and a comment asking them not to.
///
/// Four independent mechanisms hold the line, and each covers a route the
/// others do not:
///
/// | Mechanism | Blocks |
/// |---|---|
/// | This interface's shape | Any caller in the application or presentation layer |
/// | `LedgerEntry` has no `copyWith` | Building an "amended" entry to write back |
/// | Constraint C-15 (`is_deleted = 0`) | Tombstoning, including by a sync merge |
/// | The design test in `append_only_design_test.dart` | An UPDATE reaching the table from inside the data layer |
///
/// **A correction is a new compensating entry**, referencing the entry it
/// reverses. The original stays exactly as written, and both are visible.
///
/// # "Reversed" is a lookup, not a flag
///
/// Marking an entry reversed would mean writing to it, which is the thing that
/// cannot happen. So the reversal points at the original
/// (`reverses_entry_id`), and [isReversed] answers the question by looking for
/// that pointer — served by index IX-04, which exists for exactly this query
/// (Q6, the double-undo guard).
abstract interface class LedgerRepository {
  // ---------------------------------------------------------------------------
  // The only write
  // ---------------------------------------------------------------------------

  /// Appends entries. **Idempotent**: an id already present is skipped, never
  /// overwritten.
  ///
  /// Idempotency is keyed on the client-generated UUID (INV-12), which is what
  /// makes a retry safe — the same batch applied twice leaves the same rows,
  /// so a sync push that times out after the write committed can simply be
  /// repeated. Stage 7 depends on that, but the guarantee belongs here, where
  /// the write happens.
  ///
  /// Skipping rather than overwriting is the load-bearing half. An upsert would
  /// be an update path in disguise: a retry carrying a different amount under
  /// the same id would silently rewrite history, which is precisely what this
  /// interface exists to prevent.
  ///
  /// All entries commit or none do.
  Future<Result<void, RepositoryFailure>> append(List<LedgerEntry> entries);

  // ---------------------------------------------------------------------------
  // Reads
  // ---------------------------------------------------------------------------

  /// One category's entries, newest first. Serves Q2 via index IX-01.
  Future<List<LedgerEntry>> entriesForCategory(
    String categoryId, {
    DateRange? within,
  });

  /// Reactive [entriesForCategory], for the category detail screen.
  Stream<List<LedgerEntry>> watchEntriesForCategory(String categoryId);

  /// Every entry produced by one income event or spending transaction.
  ///
  /// Serves Q5 via IX-03. This is what a reversal mirrors and what a drill-down
  /// shows, so it is ordered deterministically by `id` — the entries of one
  /// event carry the same timestamp, and a list whose order changed between
  /// reads would be a bug report nobody could reproduce.
  Future<List<LedgerEntry>> entriesForSource(String sourceId);

  /// All entries in a date range, newest first. Serves Q3 via IX-02.
  ///
  /// [limit] and [offset] page the history screen. Unbounded by default,
  /// because reports need the whole range and silently truncating a report is
  /// worse than a slow one.
  Future<List<LedgerEntry>> entriesInRange(
    DateRange range, {
    int? limit,
    int offset = 0,
  });

  /// One entry, or null.
  Future<LedgerEntry?> entryById(String id);

  /// Whether a reversal entry pointing at [entryId] exists. Serves Q6.
  ///
  /// The double-undo guard, asked by lookup rather than by reading a flag on
  /// the entry — see the class comment.
  Future<bool> isReversed(String entryId);

  /// The entry that reverses [entryId], or null.
  Future<LedgerEntry?> reversalOf(String entryId);

  /// The total already allocated to a category within [period].
  ///
  /// Serves Q9 via IX-01 — the headroom input for a `FIXED_RECURRING` category,
  /// which caps per period rather than per balance. Counts `ALLOCATION` and
  /// `REVERSAL` entries only, signed, so a reversed allocation frees the
  /// headroom it consumed.
  Future<int> allocatedInPeriodMinor(String categoryId, DateRange period);
}
