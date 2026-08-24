/// The one place in the codebase that writes to `ledger_entries`.
///
/// # Why this file exists at all
///
/// `LedgerRepository` exposes no update and no delete, which stops the
/// application and presentation layers. It does not stop the **data** layer:
/// three repositories write ledger rows — income, spending, and their
/// corrections — and each of them holds a live `PookieDatabase` on which
/// `db.update(db.ledgerEntries)` is a perfectly ordinary expression.
///
/// So the writes are funnelled through one function that can only insert. The
/// interface's shape protects the callers; this protects the implementations.
/// `append_only_design_test.dart` asserts that no file under
/// `lib/data/repositories/` outside this one mentions `ledgerEntries` in a
/// mutating position, which turns "we were careful" into something a build can
/// check.
///
/// The substage's named pitfall is *"a generic repository base class that
/// supplies update and delete to every table including the ledger."* This is
/// the opposite arrangement on purpose: not a base class that grants
/// capabilities broadly, but a single narrow function that grants exactly one.
library;

import 'package:drift/drift.dart';
import 'package:pookiebudget/data/database/database.dart';
import 'package:pookiebudget/data/mappers/movement_mappers.dart';
import 'package:pookiebudget/data/repositories/repository_support.dart';
import 'package:pookiebudget/domain/entities/ledger_entry.dart';
import 'package:pookiebudget/domain/repositories/repository_failure.dart';

/// Appends [entries], skipping any id already present.
///
/// **`insertOrIgnore`, never `insertOnConflictUpdate`.** The difference is the
/// whole of INV-12's guarantee. Ignoring a duplicate id makes a retry a no-op,
/// which is what lets a sync push that timed out *after* committing simply be
/// repeated. Upserting would make the same retry an update — and a retry
/// carrying a different amount under the same id would silently rewrite
/// history, which is an update path wearing an insert's name.
///
/// Must be called inside a transaction; every caller here is.
Future<void> appendLedgerEntries(
  PookieDatabase db,
  List<LedgerEntry> entries,
) async {
  for (final LedgerEntry entry in entries) {
    await db
        .into(db.ledgerEntries)
        .insert(
          ledgerEntryToCompanion(entry),
          mode: InsertMode.insertOrIgnore,
        );
  }
}

/// The sum of [entries]' magnitudes, ignoring direction.
///
/// Magnitudes rather than signed values because both movements this checks are
/// single-direction: an allocation is entirely `IN`, its reversal entirely
/// `OUT`, and both must total the event's amount. Summing signed values would
/// make a reversal's total negative and the check would need a special case —
/// which is a branch, and a branch is somewhere for the two to diverge.
int totalMagnitudeMinor(List<LedgerEntry> entries) =>
    entries.fold<int>(0, (int acc, LedgerEntry e) => acc + e.amountMinor);

/// Rejects the enclosing write unless [entries] total exactly [expectedMinor].
///
/// INV-02, checked at the moment of storage rather than trusted from upstream.
/// The engine guarantees conservation and Stage 5 proves it over fifteen golden
/// vectors — but this is the boundary where a computed split becomes rows that
/// can never be edited, so it is the last moment the check is free.
void requireConservation({
  required int expectedMinor,
  required List<LedgerEntry> entries,
}) {
  final int actual = totalMagnitudeMinor(entries);
  if (actual != expectedMinor) {
    reject(
      ConservationViolated(
        expectedMinor: expectedMinor,
        actualMinor: actual,
        entryCount: entries.length,
      ),
    );
  }
}
