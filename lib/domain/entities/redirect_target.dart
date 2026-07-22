import 'package:pookiebudget/domain/entities/entity_failure.dart';
import 'package:pookiebudget/domain/entities/enums.dart';
import 'package:pookiebudget/domain/entities/sync_fields.dart';
import 'package:pookiebudget/domain/money/basis_points.dart';
import 'package:pookiebudget/domain/result.dart';

/// Where a full category's overflow goes.
///
/// Added by [ADR-006]. Replaces the single `redirect_target_category_id`
/// column: one target is the one-row case of many, and keeping both a column
/// and a table would give two places to read the same fact — the shape SCHEMA
/// §3.7 rejects when it refuses to store a signed amount alongside a direction.
///
/// **Targets are explicit, never inferred.** A category with no rows sends its
/// overflow to the sink, which is the documented terminal (INV-07), not a
/// guess. FR-16's *"not auto-inferred"* is the requirement; the reason is that
/// a redirect the user did not choose moves their money somewhere they did not
/// expect.
final class RedirectTarget {
  const RedirectTarget._({
    required this.id,
    required this.sourceCategoryId,
    required this.targetCategoryId,
    required this.priority,
    required this.basisPoints,
    required this.sync,
  });

  /// Rejects a self-redirect, a negative priority, and out-of-range shares.
  ///
  /// **Not checked here:** that the target exists, is not archived (V-28), that
  /// a `SPLIT` source's shares total 10000 (V-29), that the mode and the
  /// presence of [basisPoints] agree (V-30), or that the graph is acyclic
  /// (V-12). Each needs more than one row; they belong to substage 4.8's
  /// validator, which sees the whole set. Only the single-row rules live here.
  static Result<RedirectTarget, EntityFailure> create({
    required String id,
    required String sourceCategoryId,
    required String targetCategoryId,
    required int priority,
    required SyncFields sync,
    int? basisPoints,
  }) {
    // C-29 — the old C-20, relocated with the column it guarded. The one-node
    // case of the cycle rule, and the case a sync merge most easily produces.
    if (sourceCategoryId == targetCategoryId) {
      return Failure<RedirectTarget, EntityFailure>(
        SelfRedirect(sourceCategoryId),
      );
    }
    // C-32.
    if (priority < 0) {
      return Failure<RedirectTarget, EntityFailure>(
        NegativeRedirectPriority(priority),
      );
    }
    // C-31.
    BasisPoints? share;
    if (basisPoints != null) {
      final Result<BasisPoints, BasisPointsFailure> parsed =
          BasisPoints.tryFrom(basisPoints);
      switch (parsed) {
        case Failure<BasisPoints, BasisPointsFailure>():
          return Failure<RedirectTarget, EntityFailure>(
            BasisPointsOutOfRange(basisPoints),
          );
        case Success<BasisPoints, BasisPointsFailure>(:final BasisPoints value):
          share = value;
      }
    }

    return Success<RedirectTarget, EntityFailure>(
      RedirectTarget._(
        id: id,
        sourceCategoryId: sourceCategoryId,
        targetCategoryId: targetCategoryId,
        priority: priority,
        basisPoints: share,
        sync: sync,
      ),
    );
  }

  final String id;

  /// The category that is full.
  final String sourceCategoryId;

  /// Where its overflow goes.
  final String targetCategoryId;

  /// Order of offer under `PRIORITY`; lower is offered first.
  ///
  /// **Also the deterministic tie-break under `SPLIT`.** Two targets holding
  /// equal shares must still split a leftover minor unit reproducibly, and this
  /// is that key — the role `sort_order` plays for categories
  /// (ALLOCATION_ALGORITHM §5.1). That is why it is required rather than
  /// nullable: a tie-break key that can be absent is not a tie-break key.
  final int priority;

  /// Share under `SPLIT`; null under `PRIORITY`.
  ///
  /// Nullable rather than defaulting to zero because **0 is a meaningful
  /// share** — it says "this target gets nothing", which is a different
  /// statement from "this target is not weighted".
  final BasisPoints? basisPoints;

  final SyncFields sync;

  Result<RedirectTarget, EntityFailure> copyWith({
    String? sourceCategoryId,
    String? targetCategoryId,
    int? priority,
    int? basisPoints,
    SyncFields? sync,
    bool clearBasisPoints = false,
  }) => RedirectTarget.create(
    id: id,
    sourceCategoryId: sourceCategoryId ?? this.sourceCategoryId,
    targetCategoryId: targetCategoryId ?? this.targetCategoryId,
    priority: priority ?? this.priority,
    basisPoints: clearBasisPoints
        ? null
        : (basisPoints ?? this.basisPoints?.raw),
    sync: sync ?? this.sync,
  );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is RedirectTarget &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          sourceCategoryId == other.sourceCategoryId &&
          targetCategoryId == other.targetCategoryId &&
          priority == other.priority &&
          basisPoints == other.basisPoints &&
          sync == other.sync;

  @override
  int get hashCode => Object.hash(
    id,
    sourceCategoryId,
    targetCategoryId,
    priority,
    basisPoints,
    sync,
  );

  @override
  String toString() =>
      'RedirectTarget($sourceCategoryId → $targetCategoryId, p$priority'
      '${basisPoints == null ? "" : ", $basisPoints"})';
}

/// Ordering and validation over a category's whole target list.
///
/// These are the rules a single [RedirectTarget] cannot see. Kept beside the
/// entity rather than in the validator because the *ordering* is part of the
/// allocation contract — ALLOCATION_ALGORITHM §3.10 requires
/// `priority ASC, id ASC`, and an engine that sorted differently would produce
/// a different, still-conserving, still-wrong answer.
extension RedirectTargetList on List<RedirectTarget> {
  /// The engine's iteration order. Deterministic (INV-08): `id` breaks a tie on
  /// equal priority, which U-12 should prevent but a merge can still produce.
  List<RedirectTarget> get inOfferOrder {
    final List<RedirectTarget> sorted = List<RedirectTarget>.of(this);
    sorted.sort((RedirectTarget a, RedirectTarget b) {
      final int byPriority = a.priority.compareTo(b.priority);
      return byPriority != 0 ? byPriority : a.id.compareTo(b.id);
    });
    return sorted;
  }

  /// The divisor for a `SPLIT` distribution: the sum of these targets' shares.
  ///
  /// **Callers must pass only the live targets.** Dividing by a constant 10000
  /// when one of three targets is archived leaves a third of the overflow
  /// unallocated — the identical defect substage 2.8 found in override
  /// redistribution (ALLOCATION_ALGORITHM §3.10.3).
  int get shareDivisor => fold<int>(
    0,
    (int acc, RedirectTarget t) => acc + (t.basisPoints?.raw ?? 0),
  );

  /// V-29 — under `SPLIT`, the live shares must total exactly 10000.
  bool get sharesSumToFull => shareDivisor == 10000;
}

/// V-30, checked over a source category's whole list: under `PRIORITY` no
/// shares are set, under `SPLIT` all of them are.
///
/// Free-standing rather than a method on [Category] because it needs both the
/// category's mode and its targets, and the category does not hold its targets
/// — loading them is a repository concern (substage 4.4).
Result<void, EntityFailure> validateRedirectMode(
  RedirectMode mode,
  List<RedirectTarget> targets,
) {
  switch (mode) {
    case RedirectMode.priority:
      if (targets.any((RedirectTarget t) => t.basisPoints != null)) {
        return const Failure<void, EntityFailure>(
          RedirectModeMismatch(
            'a priority-ordered redirect does not use percentage shares',
          ),
        );
      }
    case RedirectMode.split:
      if (targets.any((RedirectTarget t) => t.basisPoints == null)) {
        return const Failure<void, EntityFailure>(
          RedirectModeMismatch('every target in a split needs a share'),
        );
      }
      if (targets.isNotEmpty && !targets.sharesSumToFull) {
        return Failure<void, EntityFailure>(
          RedirectSharesDoNotSum(targets.shareDivisor),
        );
      }
  }
  return const Success<void, EntityFailure>(null);
}
