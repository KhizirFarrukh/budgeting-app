import 'package:drift/drift.dart';
import 'package:pookiebudget/data/balances/balance_sql.dart';
import 'package:pookiebudget/data/database/database.dart';
import 'package:pookiebudget/domain/repositories/balance_repository.dart';

/// Recompute-and-compare (SCHEMA §7.1, substage 4.6.4).
///
/// ## Why this exists at all
///
/// The cache is what makes Option B affordable, and verification is what makes
/// it honest. INV-04's phrasing is the standard: *"a stored balance that nobody
/// can re-derive is a number nobody can trust after the first sync merge."*
/// The cache is not trusted here — it is **audited**, against the only source
/// of truth there is.
///
/// ## It returns, it does not throw
///
/// Substage 4.6.4: *"returns a list of discrepancies rather than throwing, so
/// it can be run as a diagnostic."* A diagnostic that crashes on finding the
/// thing it went looking for cannot be run from a settings screen, cannot be
/// run before an export, and cannot be run after a merge — which are the three
/// places SCHEMA §7.1 requires it.
class BalanceVerifier {
  BalanceVerifier(this._db);

  final PookieDatabase _db;

  /// Compares the ledger against the cache.
  ///
  /// The cheap tier compares counts; the full tier compares counts **and**
  /// amounts. Counts are in both because they are the half that catches a merge
  /// (ADR-007), and a full tier that only compared totals would report two
  /// cancelling errors as healthy.
  Future<List<BalanceDiscrepancy>> verify({bool full = true}) async {
    final Map<String, int> derivedCounts = await derivedEntryCounts(_db);
    final Map<String, int> derivedTotals = full
        ? await derivedBalances(_db)
        : <String, int>{};
    final List<BalanceCacheRow> cacheRows = await _db
        .select(_db.balanceCache)
        .get();

    final Map<String, BalanceCacheRow> cache = <String, BalanceCacheRow>{
      for (final BalanceCacheRow row in cacheRows) row.categoryId: row,
    };

    final List<BalanceDiscrepancy> found = <BalanceDiscrepancy>[];

    for (final MapEntry<String, int> entry in derivedCounts.entries) {
      final String categoryId = entry.key;
      final int derivedCount = entry.value;
      final int derivedTotal = derivedTotals[categoryId] ?? 0;
      final BalanceCacheRow? cached = cache[categoryId];

      // A category with entries but no cache row. Reported only when it
      // actually holds movement: a freshly created category legitimately has
      // no cache row until its first allocation, and flagging that would make
      // every clean install report discrepancies on its first launch.
      if (cached == null) {
        if (derivedCount > 0) {
          found.add(
            BalanceDiscrepancy(
              categoryId: categoryId,
              kind: DiscrepancyKind.missingCacheRow,
              derivedMinor: derivedTotal,
              cachedMinor: null,
              derivedEntryCount: derivedCount,
              cachedEntryCount: null,
            ),
          );
        }
        continue;
      }

      // Stale is reported first and on its own. It is not a fault — a merge
      // sets it deliberately — but the cached value must not be displayed
      // until it is resolved, and reporting a *mismatch* on a row already
      // known to need recomputation would bury that under noise.
      if (cached.isStale) {
        found.add(
          _discrepancy(
            categoryId,
            DiscrepancyKind.staleFlagSet,
            derivedTotal,
            derivedCount,
            cached,
          ),
        );
        continue;
      }

      if (cached.entryCount != derivedCount) {
        found.add(
          _discrepancy(
            categoryId,
            DiscrepancyKind.entryCountMismatch,
            derivedTotal,
            derivedCount,
            cached,
          ),
        );
        continue;
      }

      if (full && cached.balanceMinor != derivedTotal) {
        found.add(
          _discrepancy(
            categoryId,
            DiscrepancyKind.balanceMismatch,
            derivedTotal,
            derivedCount,
            cached,
          ),
        );
      }
    }

    // Cache rows the ledger cannot account for. Harmless to any balance the
    // app displays, but it means something removed a category without clearing
    // its cache — and the row would come back to life if the id were reused.
    for (final String cachedId in cache.keys) {
      if (derivedCounts.containsKey(cachedId)) continue;
      final BalanceCacheRow row = cache[cachedId]!;
      found.add(
        BalanceDiscrepancy(
          categoryId: cachedId,
          kind: DiscrepancyKind.orphanCacheRow,
          derivedMinor: 0,
          cachedMinor: row.balanceMinor,
          derivedEntryCount: 0,
          cachedEntryCount: row.entryCount,
        ),
      );
    }

    return found;
  }

  BalanceDiscrepancy _discrepancy(
    String categoryId,
    DiscrepancyKind kind,
    int derivedMinor,
    int derivedCount,
    BalanceCacheRow cached,
  ) => BalanceDiscrepancy(
    categoryId: categoryId,
    kind: kind,
    derivedMinor: derivedMinor,
    cachedMinor: cached.balanceMinor,
    derivedEntryCount: derivedCount,
    cachedEntryCount: cached.entryCount,
  );

  /// Rebuilds every cache row from the ledger.
  ///
  /// **Takes no balance from any caller.** That is what keeps this a recompute
  /// rather than the setter substage 4.6's `must_not` forbids: the only input is
  /// `ledger_entries`, so the result is reproducible by anyone who runs it
  /// again, which is precisely INV-04's requirement.
  ///
  /// One transaction, so a crash halfway cannot leave the cache partly rebuilt
  /// and wholly untrustworthy — with the stale flags of the rows it had not
  /// reached already cleared.
  Future<void> recomputeAll({int? computedAtMs}) async {
    final Map<String, int> totals = await derivedBalances(_db);
    final Map<String, int> counts = await derivedEntryCounts(_db);
    final int stamp = computedAtMs ?? 0;

    await _db.transaction(() async {
      // Cleared wholesale rather than reconciled row by row. The table is
      // device-local, derived and disposable (SCHEMA §3.12), so rebuilding it
      // is always cheaper to reason about than patching it — and it removes
      // orphan rows as a side effect rather than needing a second pass.
      await _db.delete(_db.balanceCache).go();

      for (final MapEntry<String, int> entry in totals.entries) {
        await _db
            .into(_db.balanceCache)
            .insert(
              BalanceCacheCompanion(
                categoryId: Value<String>(entry.key),
                balanceMinor: Value<int>(entry.value),
                entryCount: Value<int>(counts[entry.key] ?? 0),
                lastEntryId: const Value<String?>(null),
                computedAtMs: Value<int>(stamp),
                isStale: const Value<bool>(false),
              ),
            );
      }
    });
  }

  /// Marks a category's cache row stale, so it is recomputed before use.
  ///
  /// What a sync merge calls (S07.6.5) instead of importing a balance: the
  /// merge brings entries, this says "the cached total no longer describes
  /// them", and the recompute derives the new one locally. A merge is never
  /// trusted with a number.
  Future<void> markStale(Iterable<String> categoryIds) async {
    for (final String categoryId in categoryIds) {
      await _db.customUpdate(
        'UPDATE balance_cache SET is_stale = 1 WHERE category_id = ?',
        variables: <Variable<Object>>[Variable<String>(categoryId)],
        updates: <TableInfo<Table, Object?>>{_db.balanceCache},
      );
    }
  }
}
