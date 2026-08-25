/// The derivation queries, in one place.
///
/// Shared by `balance_queries.dart` (which serves them to the app) and
/// `balance_verifier.dart` (which compares them against the cache). Kept
/// separate from both so neither has to import the other — the verifier
/// recomputes, the query layer delegates verification, and a mutual import
/// between the two would make that relationship harder to read than it is.
///
/// **Every function here reads `ledger_entries` and nothing else.** That is
/// INV-04 stated as a file boundary: if a balance could be derived from
/// anything but the ledger, it would be derivable two ways, and two ways
/// eventually disagree.
library;

import 'package:drift/drift.dart';
import 'package:pookiebudget/data/database/database.dart';
import 'package:pookiebudget/domain/repositories/repository_queries.dart';

/// The signed-sum expression, written once.
///
/// The amount column is always positive and `direction` carries the sign
/// (SCHEMA §3.7), so every balance query needs this `CASE`. Repeated inline in
/// five queries it would eventually be typed with the branches the wrong way
/// round in one of them — and a balance correct in four places and negated in
/// the fifth is exactly the defect that reaches a user.
///
/// Integer throughout: SQLite's `SUM` over an INTEGER column returns an
/// INTEGER, so INV-01 holds end to end with no floating point anywhere on the
/// path.
const String kSignedSum =
    "SUM(CASE direction WHEN 'IN' THEN amount_minor "
    'ELSE -amount_minor END)';

/// One category's balance, from the ledger alone.
Future<int> derivedBalanceOf(PookieDatabase db, String categoryId) async {
  final QueryRow row = await db
      .customSelect(
        'SELECT COALESCE($kSignedSum, 0) AS total FROM ledger_entries '
        'WHERE category_id = ?',
        variables: <Variable<Object>>[Variable<String>(categoryId)],
      )
      .getSingle();
  return row.read<int>('total');
}

/// Every live category's balance, in one grouped scan.
///
/// **`LEFT JOIN` from `categories`, not `GROUP BY` over entries.** A category
/// with no entries must appear with a balance of zero rather than be absent: a
/// dashboard that dropped it would silently hide a bucket the user created and
/// has not funded yet, which reads as the app forgetting it. It also makes the
/// verifier able to say "the cache has a row the ledger does not justify",
/// which a grouped scan over entries could never surface.
Future<Map<String, int>> derivedBalances(PookieDatabase db) async {
  final List<QueryRow> rows = await db
      .customSelect(
        'SELECT c.id AS category_id, COALESCE($kSignedSum, 0) AS total '
        'FROM categories c '
        'LEFT JOIN ledger_entries e ON e.category_id = c.id '
        'WHERE c.is_deleted = 0 '
        'GROUP BY c.id',
      )
      .get();
  return <String, int>{
    for (final QueryRow row in rows)
      row.read<String>('category_id'): row.read<int>('total'),
  };
}

/// Every live category's entry count, for the cheap verifier tier (ADR-007).
///
/// `COUNT(e.id)` rather than `COUNT(*)`: the latter counts the outer join's
/// null row and reports 1 for every category that has no entries at all.
Future<Map<String, int>> derivedEntryCounts(PookieDatabase db) async {
  final List<QueryRow> rows = await db
      .customSelect(
        'SELECT c.id AS category_id, COUNT(e.id) AS n '
        'FROM categories c '
        'LEFT JOIN ledger_entries e ON e.category_id = c.id '
        'WHERE c.is_deleted = 0 '
        'GROUP BY c.id',
      )
      .get();
  return <String, int>{
    for (final QueryRow row in rows)
      row.read<String>('category_id'): row.read<int>('n'),
  };
}

/// How much was allocated to a category within [range].
///
/// `REVERSAL` counts alongside `ALLOCATION`, signed, so undoing an allocation
/// gives back the headroom it consumed — otherwise a reversed bill payment
/// permanently occupies its period's capacity. Spending is excluded: the cap is
/// on what may be *allocated* per period, not what may be spent, and counting a
/// paid bill would free capacity to fund it twice.
Future<int> allocatedInRange(
  PookieDatabase db,
  String categoryId,
  DateRange range,
) async {
  final QueryRow row = await db
      .customSelect(
        'SELECT COALESCE($kSignedSum, 0) AS total FROM ledger_entries '
        'WHERE category_id = ? '
        'AND occurred_at_ms >= ? AND occurred_at_ms < ? '
        "AND source_type IN ('ALLOCATION','REVERSAL')",
        variables: <Variable<Object>>[
          Variable<String>(categoryId),
          Variable<int>(range.fromMs),
          Variable<int>(range.toMs),
        ],
      )
      .getSingle();
  return row.read<int>('total');
}

/// An account's total: the balances of the categories linked to it.
///
/// Joined through `categories.linked_account_id`, **not** through
/// `ledger_entries.account_id`. The two differ deliberately — the entry column
/// is denormalised at write time so history survives a re-link, while an
/// account's total is what it holds *now*. Summing the entry column would
/// report money against an account the category no longer belongs to.
Future<int> derivedAccountTotal(PookieDatabase db, String accountId) async {
  final QueryRow row = await db
      .customSelect(
        'SELECT COALESCE($kSignedSum, 0) AS total '
        'FROM ledger_entries e '
        'JOIN categories c ON c.id = e.category_id '
        'WHERE c.linked_account_id = ? AND c.is_deleted = 0',
        variables: <Variable<Object>>[Variable<String>(accountId)],
      )
      .getSingle();
  return row.read<int>('total');
}
