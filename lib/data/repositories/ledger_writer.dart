/// The one place in the codebase that writes to `ledger_entries`, and the one
/// place that adjusts `balance_cache` incrementally.
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
///
/// # Why the balance cache is updated here too
///
/// SCHEMA §7.1: *"There is no code path that writes a ledger entry without
/// adjusting `balance_cache` atomically, and no code path that adjusts
/// `balance_cache` without a ledger entry."*
///
/// The only way to make that true is to make it the same code path. A cache
/// updated by a separate call is a cache that drifts the first time somebody
/// adds a fourth write path and forgets the second call — which is 4.6's named
/// pitfall, *"a cached balance updated on write but never verified"*, arriving
/// one step earlier.
///
/// The clause's second half — no cache adjustment without a ledger entry —
/// governs *incremental* adjustment, which happens only here.
/// `BalanceVerifier.recomputeAll` also writes the table, but it derives every
/// value from `ledger_entries` and takes no number from a caller, so it cannot
/// introduce a figure the ledger does not justify.
library;

import 'package:drift/drift.dart';
import 'package:pookiebudget/data/database/database.dart';
import 'package:pookiebudget/data/mappers/movement_mappers.dart';
import 'package:pookiebudget/data/repositories/repository_support.dart';
import 'package:pookiebudget/domain/entities/ledger_entry.dart';
import 'package:pookiebudget/domain/repositories/repository_failure.dart';

/// Appends [entries], skipping any id already present, and folds each newly
/// stored entry into its category's cached balance.
///
/// **`insertOrIgnore`, never `insertOnConflictUpdate`.** The difference is the
/// whole of INV-12's guarantee. Ignoring a duplicate id makes a retry a no-op,
/// which is what lets a sync push that timed out *after* committing simply be
/// repeated. Upserting would make the same retry an update — and a retry
/// carrying a different amount under the same id would silently rewrite
/// history, which is an update path wearing an insert's name.
///
/// Must be called inside a transaction; every caller here is. That is what
/// makes the entry and its cache adjustment atomic — a crash between the two
/// would leave a balance that no longer describes the entries beneath it, and
/// nothing in the app able to tell.
Future<void> appendLedgerEntries(
  PookieDatabase db,
  List<LedgerEntry> entries,
) async {
  for (final LedgerEntry entry in entries) {
    // Asked before inserting, because the cache must be folded **only for
    // entries that were actually stored**. `insertOrIgnore` silently does
    // nothing for a duplicate, and incrementing the balance anyway would make
    // a retried sync push inflate every category it touched — a cache
    // corruption caused by the very mechanism that exists to make retries
    // safe. The row count returned by an ignored insert cannot be relied on to
    // distinguish the two cases, so the question is asked directly.
    if (await _isAlreadyStored(db, entry.id)) continue;

    await db
        .into(db.ledgerEntries)
        .insert(
          ledgerEntryToCompanion(entry),
          mode: InsertMode.insertOrIgnore,
        );
    await _foldIntoCache(db, entry);
  }
}

Future<bool> _isAlreadyStored(PookieDatabase db, String entryId) async {
  final LedgerEntryRow? existing =
      await (db.select(db.ledgerEntries)..where((t) => t.id.equals(entryId)))
          .getSingleOrNull();
  return existing != null;
}

/// Adds one entry to its category's cached balance, creating the row if needed.
///
/// `is_stale` is deliberately **not** cleared on conflict. A row marked stale
/// by a merge needs a full recompute, and an incremental update does not
/// provide one — clearing the flag here would declare the row trustworthy on
/// the strength of a write that knows nothing about why it was doubted.
///
/// `computed_at_ms` takes the entry's own `recordedAtMs` rather than a clock
/// reading. The value means "as at", and the entry's write time is exactly
/// that — which also keeps this function clock-free, as INV-09 and guard G4
/// require of everything outside the `Clock` implementation.
Future<void> _foldIntoCache(PookieDatabase db, LedgerEntry entry) async {
  await db.customInsert(
    'INSERT INTO balance_cache '
    '(category_id, balance_minor, entry_count, last_entry_id, '
    'computed_at_ms, is_stale) '
    'VALUES (?, ?, 1, ?, ?, 0) '
    'ON CONFLICT(category_id) DO UPDATE SET '
    'balance_minor = balance_minor + excluded.balance_minor, '
    'entry_count = entry_count + 1, '
    'last_entry_id = excluded.last_entry_id, '
    'computed_at_ms = excluded.computed_at_ms',
    variables: <Variable<Object>>[
      Variable<String>(entry.categoryId),
      // The signed value — the only place the sign is applied, so the stored
      // amount stays unambiguously positive (SCHEMA §3.7).
      Variable<int>(entry.signedMinor),
      Variable<String>(entry.id),
      Variable<int>(entry.recordedAtMs),
    ],
    updates: <TableInfo<Table, Object?>>{db.balanceCache},
  );
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
