import 'package:pookiebudget/domain/entities/income_event.dart';
import 'package:pookiebudget/domain/entities/ledger_entry.dart';
import 'package:pookiebudget/domain/repositories/repository_failure.dart';
import 'package:pookiebudget/domain/repositories/repository_queries.dart';
import 'package:pookiebudget/domain/result.dart';

/// Recording money arriving, and undoing it.
///
/// # Why the event and its entries are written by one method
///
/// [record] takes the event *and* its allocations together because they are
/// one fact, not two. An income event with only some of its allocations is not
/// a partial record — it is a **permanently wrong** one: the ledger is
/// append-only, so a short write cannot be corrected by editing it, only by a
/// compensating entry that someone first has to notice is needed. The balances
/// are wrong until then, and nothing in the app can tell that they are.
///
/// Offering `insertEvent` and `insertEntries` separately would make that
/// outcome reachable by ordinary use. So the pair is the unit, and the
/// transaction boundary is the method boundary.
///
/// # What [record] does in that one transaction
///
/// 1. Checks conservation — the entries must total exactly the event's amount
///    (INV-02), refused as [ConservationViolated] rather than stored.
/// 2. Inserts the event, idempotently by id.
/// 3. Appends the entries, idempotently by id.
/// 4. **Seals the rule version** the event was split by, if it is not already
///    sealed.
///
/// Step 4 is in the same transaction for the same reason as the rest: any
/// window in which a committed event references an unsealed version is a window
/// in which the percentages behind real history can still be edited, and INV-11
/// promises they cannot.
abstract interface class IncomeEventRepository {
  /// Records income and its allocations atomically. Either everything commits
  /// or nothing does.
  Future<Result<void, RepositoryFailure>> record({
    required IncomeEvent event,
    required List<LedgerEntry> entries,
  });

  /// Records a reversal atomically: the reversal event, its compensating
  /// entries, and the link back from the original.
  ///
  /// **Nothing about the original's ledger entries is touched.** The link is
  /// recorded on the new rows (`reverses_entry_id`) and by setting
  /// `reversed_by_event_id` on the original *event* row — the one permitted
  /// mutation in this design, and never on a ledger entry.
  ///
  /// [reversalEntries] must mirror the original's entries: same magnitudes,
  /// opposite directions. They are **not** recomputed by the engine, and this
  /// method does not recompute them either. If the user changed their
  /// percentages between the event and the undo, a recomputed split would
  /// restore every affected balance to the wrong value — mirroring is the only
  /// method that returns them to exactly what they were.
  ///
  /// Enforces guard R-1 ([AlreadyReversed]) and guard R-2
  /// ([CannotReverseAReversal]) against the *stored* original, not against what
  /// the caller believes: two devices can both decide to undo the same event.
  Future<Result<void, RepositoryFailure>> recordReversal({
    required String originalEventId,
    required IncomeEvent reversalEvent,
    required List<LedgerEntry> reversalEntries,
  });

  /// Recent income events, newest `occurred_at_ms` first. Serves Q10 via IX-07.
  Future<List<IncomeEvent>> events({
    DateRange? within,
    int? limit,
    int offset = 0,
    bool includeDeleted = false,
  });

  /// Reactive [events] — the dashboard's recent activity list.
  Stream<List<IncomeEvent>> watchEvents({int? limit});

  /// One event, or null.
  Future<IncomeEvent?> eventById(String id, {bool includeDeleted = false});

  /// Whether this event can still be undone.
  ///
  /// A convenience over the two guards, so a screen can disable the button
  /// rather than offering an action that will be refused. The guards are still
  /// enforced in [recordReversal] — a UI check is a courtesy, never the
  /// enforcement point (SCHEMA §6.1).
  Future<bool> canReverse(String eventId);
}
