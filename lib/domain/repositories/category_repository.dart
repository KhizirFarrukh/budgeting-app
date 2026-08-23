import 'package:pookiebudget/domain/entities/category.dart';
import 'package:pookiebudget/domain/entities/category_group.dart';
import 'package:pookiebudget/domain/entities/enums.dart';
import 'package:pookiebudget/domain/entities/redirect_target.dart';
import 'package:pookiebudget/domain/repositories/repository_failure.dart';
import 'package:pookiebudget/domain/repositories/repository_queries.dart';
import 'package:pookiebudget/domain/result.dart';

/// Storage for the three configuration record classes that describe *where
/// money can land*: groups, categories, and the redirect edges between them.
///
/// ## Why these three share one interface
///
/// They are edited as one thing. A category cannot exist without its group, and
/// since ADR-006 a category's overflow behaviour is a list of `redirect_targets`
/// rows rather than a column on the category — so "edit this category" now
/// spans two tables. Splitting them across two interfaces would put the two
/// halves of a single user action behind two objects and make the atomicity
/// substage 4.5 requires harder to express, not easier.
///
/// ## The dependency rule
///
/// Every type in every signature below is a domain type. No row class, no
/// generated class, no SQL concept and no database handle appears — which is
/// substage 4.4's first acceptance criterion, and what lets Stage 5 and Stage 6
/// be tested with no database at all (ARCHITECTURE §2.2).
///
/// ## Deletion is always soft
///
/// INV-10: configuration records are tombstoned, never removed. A hard delete
/// would make a record's disappearance invisible to the other device, which
/// would then happily re-create it on the next merge. Every `delete` method
/// here sets `is_deleted` and `deleted_at_ms`; none removes a row.
///
/// ## Where sync stamps come from
///
/// The repository does **not** invent `SyncFields`. Callers hand over a
/// complete entity, stamp included, because the hybrid logical clock that
/// orders concurrent edits is Stage 7's to implement (S07.4) and a placeholder
/// invented here would be a second, wrong source of ordering.
///
/// The one exception is soft delete, which is the only write a repository
/// *originates* rather than relays: it applies `SyncFields.tombstoned` using
/// the injected `Clock`, preserving the rest of the stamp. Substage 7.7 hooks
/// the outbox onto the same write path.
abstract interface class CategoryRepository {
  // ---------------------------------------------------------------------------
  // Groups
  // ---------------------------------------------------------------------------

  /// Every group, in `sort_order`.
  Future<List<CategoryGroup>> groups({bool includeDeleted = false});

  /// Reactive [groups]. Emits on every change to the table made through this
  /// database instance, including one made by a background sync writer.
  Stream<List<CategoryGroup>> watchGroups({bool includeDeleted = false});

  /// One group, or null when it does not exist or is tombstoned.
  Future<CategoryGroup?> groupById(String id, {bool includeDeleted = false});

  /// The single live group of a kind. U-03 makes at most one exist.
  ///
  /// Returns null for `BUSINESS` on a personal-only setup, where the row is
  /// absent entirely rather than present and inactive (PRD A-20).
  Future<CategoryGroup?> groupByKind(CategoryGroupKind kind);

  Future<Result<void, RepositoryFailure>> createGroup(CategoryGroup group);

  Future<Result<void, RepositoryFailure>> updateGroup(CategoryGroup group);

  /// Tombstones the group. Fails with [RecordStillReferenced] while live
  /// categories remain in it — a group whose categories outlive it would leave
  /// them unreachable from every picker while their money stayed on the ledger.
  Future<Result<void, RepositoryFailure>> deleteGroup(String id);

  // ---------------------------------------------------------------------------
  // Categories
  // ---------------------------------------------------------------------------

  /// Categories matching [query], ordered by `sort_order` then `id`.
  ///
  /// The secondary key is not decoration: `sort_order` is the allocation
  /// tie-break (ALLOCATION_ALGORITHM §5.1) and a merge can produce two
  /// categories sharing one, so `id` makes the order total and the engine
  /// deterministic (INV-08).
  Future<List<Category>> categories({
    CategoryQuery query = const CategoryQuery(),
  });

  /// Reactive [categories]. Serves Q7 — the dashboard and every picker.
  Stream<List<Category>> watchCategories({
    CategoryQuery query = const CategoryQuery(),
  });

  /// One category, or null when it does not exist or is tombstoned.
  Future<Category?> categoryById(String id, {bool includeDeleted = false});

  /// The live sink of a group. INV-07's terminal; U-08 makes at most one exist.
  Future<Category?> sinkForGroup(String groupId);

  Future<Result<void, RepositoryFailure>> createCategory(Category category);

  Future<Result<void, RepositoryFailure>> updateCategory(Category category);

  /// Tombstones the category.
  ///
  /// Fails with [SinkProtected] for the sink, and with
  /// [RecordStillReferenced] while other categories still redirect into it —
  /// overflow aimed at a deleted category is overflow with nowhere to go.
  Future<Result<void, RepositoryFailure>> deleteCategory(String id);

  /// Hides the category from pickers while keeping its history.
  ///
  /// Distinct from deletion at every level of the design, so it is a distinct
  /// method: archiving frees the name for reuse (U-01 is partial on
  /// `is_archived = 0`), while a tombstone frees it too but also removes the
  /// row from every user-facing read.
  Future<Result<void, RepositoryFailure>> setCategoryArchived(
    String id, {
    required bool archived,
  });

  // ---------------------------------------------------------------------------
  // Redirect targets (ADR-006)
  // ---------------------------------------------------------------------------

  /// Where [sourceCategoryId]'s overflow goes, **in offer order**.
  ///
  /// Serves Q16, which the engine runs once per full category on every income
  /// event. The order is `priority ASC, id ASC` — the contract
  /// ALLOCATION_ALGORITHM §3.10 requires, applied here rather than left to each
  /// caller, because an engine that sorted differently would produce a
  /// different, still-conserving, still-wrong answer.
  Future<List<RedirectTarget>> redirectTargetsFor(
    String sourceCategoryId, {
    bool includeDeleted = false,
  });

  /// Reactive [redirectTargetsFor], for Stage 6's redirect editor.
  Stream<List<RedirectTarget>> watchRedirectTargetsFor(String sourceCategoryId);

  /// Every live redirect edge, keyed by source category, each list in offer
  /// order.
  ///
  /// The whole graph in one read, because the rules that matter about it are
  /// graph-wide: substage 4.8 walks this for cycle detection (V-12) and Stage 7
  /// re-walks it after every merge. Loading it edge by edge would be N+1 reads
  /// of a structure that is only ever meaningful whole.
  Future<Map<String, List<RedirectTarget>>> redirectGraph();

  Future<Result<void, RepositoryFailure>> createRedirectTarget(
    RedirectTarget target,
  );

  Future<Result<void, RepositoryFailure>> updateRedirectTarget(
    RedirectTarget target,
  );

  /// Tombstones one redirect edge. Removing the last edge is legal and means
  /// *send overflow to the sink*, which is the documented terminal (INV-07) —
  /// not an error, and not a guess.
  Future<Result<void, RepositoryFailure>> deleteRedirectTarget(String id);
}
