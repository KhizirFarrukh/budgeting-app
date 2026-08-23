/// The pieces every repository implementation shares.
///
/// Small on purpose. Each exists because a rule must be applied identically in
/// a dozen places, and applying it by hand a dozen times is how one place ends
/// up different.
library;

import 'package:drift/drift.dart';
import 'package:pookiebudget/data/database/database.dart';
import 'package:pookiebudget/domain/repositories/repository_failure.dart';
import 'package:pookiebudget/domain/repositories/repository_queries.dart';
import 'package:pookiebudget/domain/result.dart';

// ---------------------------------------------------------------------------
// Read predicates
// ---------------------------------------------------------------------------

/// A predicate that matches every row, for when a filter is not applied.
///
/// Written as a constant expression rather than by conditionally omitting the
/// `.where` clause, so a filtered and an unfiltered read take **the same code
/// path**. A branch that skips `.where` entirely is a branch where forgetting
/// the tombstone term is invisible.
const Expression<bool> matchAll = Constant<bool>(true);

/// The tombstone term. INV-10 and substage 4.4.3: *"every read path filters
/// tombstones by default, with an explicit opt-in to include them for sync."*
///
/// Takes the column rather than the table, so one function serves all ten
/// synced tables without naming a single generated type.
Expression<bool> tombstoneTerm(
  GeneratedColumn<bool> isDeleted, {
  required bool includeDeleted,
}) => includeDeleted ? matchAll : isDeleted.equals(false);

/// The archived term. Archiving and deleting are different states throughout
/// the schema, so they are different terms here — always combined, never
/// substituted for one another.
Expression<bool> archivedTerm(
  GeneratedColumn<bool> isArchived,
  ArchivedFilter filter,
) => switch (filter) {
  ArchivedFilter.liveOnly => isArchived.equals(false),
  ArchivedFilter.archivedOnly => isArchived.equals(true),
  ArchivedFilter.any => matchAll,
};

/// An optional equality term: matches everything when [value] is null.
Expression<bool> optionalEquals(
  GeneratedColumn<String> column,
  String? value,
) => value == null ? matchAll : column.equals(value);

// ---------------------------------------------------------------------------
// Write transactions
// ---------------------------------------------------------------------------

/// Thrown inside a write to reject it with a typed failure.
///
/// An exception rather than a returned value **so the transaction rolls back**.
/// A rejection signalled by returning early only unwinds cleanly when nothing
/// has been written yet, which is a property every future edit to a write path
/// would have to preserve without being reminded. Throwing makes the rollback
/// the database's job instead of the author's.
final class RejectedWrite implements Exception {
  const RejectedWrite(this.failure);

  final RepositoryFailure failure;

  @override
  String toString() => 'RejectedWrite($failure)';
}

/// Rejects the enclosing write with [failure].
///
/// Returns [Never], so the compiler knows the write path stops here and does
/// not require a redundant `return` after every check.
Never reject(RepositoryFailure failure) => throw RejectedWrite(failure);

/// Runs [body] in a transaction and converts its outcome to a typed result.
///
/// Three outcomes, deliberately distinguished:
///
/// - completes — [Success];
/// - [RejectedWrite] — the typed failure it carries, transaction rolled back;
/// - any other `Exception` — [ConstraintViolation], transaction rolled back.
///
/// `Error` is **not** caught. That distinction is load-bearing: `MappingError`
/// extends `Error` precisely so it passes straight through and reaches the
/// developer, while a constraint violation — an `Exception` — becomes a value
/// the caller handles.
///
/// The driver's exception type is deliberately not named. Staying independent
/// of the SQLite binding matters because the tests run on `NativeDatabase`
/// while the app runs through `drift_flutter`.
///
/// The [ConstraintViolation] branch is a **backstop**. Every rule a repository
/// knows about is checked before the write so the user gets a specific message;
/// anything reaching here means a constraint fired that the repository did not
/// anticipate, and the honest response is to report that the write did not
/// happen.
Future<Result<void, RepositoryFailure>> writeTransaction(
  PookieDatabase db,
  Future<void> Function() body,
) async {
  try {
    await db.transaction(body);
    return const Success<void, RepositoryFailure>(null);
  } on RejectedWrite catch (rejection) {
    return Failure<void, RepositoryFailure>(rejection.failure);
  } on Exception catch (e) {
    return Failure<void, RepositoryFailure>(ConstraintViolation(e.toString()));
  }
}
