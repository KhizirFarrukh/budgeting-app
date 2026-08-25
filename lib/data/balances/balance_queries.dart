import 'package:pookiebudget/data/balances/balance_sql.dart' as sql;
import 'package:pookiebudget/data/balances/balance_verifier.dart';
import 'package:pookiebudget/data/balances/period_boundaries.dart';
import 'package:pookiebudget/data/database/database.dart';
import 'package:pookiebudget/domain/allocation/period.dart';
import 'package:pookiebudget/domain/repositories/balance_repository.dart';

/// The database-backed [BalanceRepository].
///
/// A thin surface over `balance_sql.dart` and `BalanceVerifier`, deliberately.
/// The queries live in one file because two callers need them; the verification
/// lives in another because it is a different job; this is the contract the
/// application layer sees, and it holds no logic of its own that could disagree
/// with either.
///
/// ## No clock, and no setter
///
/// Substage 4.6's two prohibitions, both structural rather than reviewed. This
/// class holds no `Clock` — every period arrives as an argument (4.6.2) — and
/// no method accepts a balance. [recomputeAll] reads the ledger; it does not
/// take a number, which is the difference between a recompute and the setter
/// 4.6's `must_not` forbids.
///
/// ## Derived and cached are separate methods, on purpose
///
/// A single `balanceOf` that silently returned "the cache if fresh, otherwise a
/// recompute" would make it impossible to write the verifier — there would be
/// no way to ask for the derived value specifically, and the comparison would
/// compare the cache against itself.
class BalanceQueries implements BalanceRepository {
  BalanceQueries(this._db);

  final PookieDatabase _db;

  // ===========================================================================
  // Derived — the source of truth
  // ===========================================================================

  @override
  Future<int> derivedBalanceOf(String categoryId) =>
      sql.derivedBalanceOf(_db, categoryId);

  @override
  Future<Map<String, int>> derivedBalances() => sql.derivedBalances(_db);

  /// Every live category's entry count. Exposed for the cheap verifier tier and
  /// for tests; not part of [BalanceRepository], because no screen needs it.
  Future<Map<String, int>> derivedEntryCounts() => sql.derivedEntryCounts(_db);

  @override
  Future<int> allocatedInPeriod(String categoryId, PeriodDefinition period) =>
      sql.allocatedInRange(_db, categoryId, rangeOf(period));

  @override
  Future<int> accountTotal(String accountId) =>
      sql.derivedAccountTotal(_db, accountId);

  // ===========================================================================
  // Cached — the fast path
  // ===========================================================================

  @override
  Future<Map<String, int>> cachedBalances() async {
    final List<BalanceCacheRow> rows = await _db.select(_db.balanceCache).get();
    return _asMap(rows);
  }

  @override
  Stream<Map<String, int>> watchCachedBalances() =>
      _db.select(_db.balanceCache).watch().map(_asMap);

  Map<String, int> _asMap(List<BalanceCacheRow> rows) => <String, int>{
    for (final BalanceCacheRow row in rows) row.categoryId: row.balanceMinor,
  };

  // ===========================================================================
  // Verification
  // ===========================================================================

  @override
  Future<List<BalanceDiscrepancy>> verify({bool full = true}) =>
      BalanceVerifier(_db).verify(full: full);

  @override
  Future<void> recomputeAll() => BalanceVerifier(_db).recomputeAll();
}
