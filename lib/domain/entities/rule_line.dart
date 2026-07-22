import 'package:pookiebudget/domain/entities/entity_failure.dart';
import 'package:pookiebudget/domain/entities/enums.dart';
import 'package:pookiebudget/domain/entities/sync_fields.dart';
import 'package:pookiebudget/domain/money/basis_points.dart';
import 'package:pookiebudget/domain/result.dart';

/// One share in the two-level split (PRD A-16).
///
/// Both levels live in one table, discriminated by [scope]: `GROUP` lines must
/// total exactly 10000 across the active groups, and `CATEGORY` lines must
/// total exactly 10000 within each group that has a non-zero share.
///
/// The totalling rules (V-01, V-02) are **not** checked here — a single line
/// cannot see its siblings. They belong to substage 4.8's validator, which sees
/// the whole set.
final class RuleLine {
  const RuleLine._({
    required this.id,
    required this.ruleVersionId,
    required this.scope,
    required this.groupId,
    required this.categoryId,
    required this.basisPoints,
    required this.sync,
  });

  /// Rejects a line whose scope and target column disagree, and basis points
  /// outside 0–10000.
  ///
  /// The scope check matters because a `GROUP` line carrying a `category_id`
  /// would be counted in neither total: the group pass would skip it for having
  /// a category, and the category pass would skip it for being group-scoped.
  /// A share that exists but is counted nowhere is money that vanishes from the
  /// totals while looking correct on screen.
  static Result<RuleLine, EntityFailure> create({
    required String id,
    required String ruleVersionId,
    required RuleLineScope scope,
    required int basisPoints,
    required SyncFields sync,
    String? groupId,
    String? categoryId,
  }) {
    switch (scope) {
      case RuleLineScope.group:
        if (groupId == null) {
          return const Failure<RuleLine, EntityFailure>(
            RuleLineScopeMismatch('a group share must name its group'),
          );
        }
        if (categoryId != null) {
          return const Failure<RuleLine, EntityFailure>(
            RuleLineScopeMismatch('a group share cannot name a category'),
          );
        }
      case RuleLineScope.category:
        if (categoryId == null) {
          return const Failure<RuleLine, EntityFailure>(
            RuleLineScopeMismatch('a category share must name its category'),
          );
        }
        if (groupId != null) {
          return const Failure<RuleLine, EntityFailure>(
            RuleLineScopeMismatch('a category share cannot name a group'),
          );
        }
    }

    final Result<BasisPoints, BasisPointsFailure> bp = BasisPoints.tryFrom(
      basisPoints,
    );
    return switch (bp) {
      Failure<BasisPoints, BasisPointsFailure>() =>
        Failure<RuleLine, EntityFailure>(BasisPointsOutOfRange(basisPoints)),
      Success<BasisPoints, BasisPointsFailure>(:final BasisPoints value) =>
        Success<RuleLine, EntityFailure>(
          RuleLine._(
            id: id,
            ruleVersionId: ruleVersionId,
            scope: scope,
            groupId: groupId,
            categoryId: categoryId,
            basisPoints: value,
            sync: sync,
          ),
        ),
    };
  }

  final String id;
  final String ruleVersionId;
  final RuleLineScope scope;

  /// Set iff [scope] is `GROUP`.
  final String? groupId;

  /// Set iff [scope] is `CATEGORY`.
  final String? categoryId;

  final BasisPoints basisPoints;
  final SyncFields sync;

  /// Whichever of [groupId] or [categoryId] this line applies to. Non-null by
  /// construction.
  String get targetId => (scope == RuleLineScope.group ? groupId : categoryId)!;

  Result<RuleLine, EntityFailure> copyWith({
    String? ruleVersionId,
    RuleLineScope? scope,
    String? groupId,
    String? categoryId,
    int? basisPoints,
    SyncFields? sync,
  }) {
    final RuleLineScope nextScope = scope ?? this.scope;
    // Switching scope must not carry the old target across — that is exactly
    // the "valid copied into invalid" pitfall, and here it would produce a line
    // counted in neither total.
    final bool scopeChanged = nextScope != this.scope;
    return RuleLine.create(
      id: id,
      ruleVersionId: ruleVersionId ?? this.ruleVersionId,
      scope: nextScope,
      groupId: groupId ?? (scopeChanged ? null : this.groupId),
      categoryId: categoryId ?? (scopeChanged ? null : this.categoryId),
      basisPoints: basisPoints ?? this.basisPoints.raw,
      sync: sync ?? this.sync,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is RuleLine &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          ruleVersionId == other.ruleVersionId &&
          scope == other.scope &&
          groupId == other.groupId &&
          categoryId == other.categoryId &&
          basisPoints == other.basisPoints &&
          sync == other.sync;

  @override
  int get hashCode => Object.hash(
    id,
    ruleVersionId,
    scope,
    groupId,
    categoryId,
    basisPoints,
    sync,
  );

  @override
  String toString() => 'RuleLine(${scope.wireName} $targetId → $basisPoints)';
}
