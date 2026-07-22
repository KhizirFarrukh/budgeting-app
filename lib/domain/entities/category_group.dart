import 'package:pookiebudget/domain/entities/entity_failure.dart';
import 'package:pookiebudget/domain/entities/enums.dart';
import 'package:pookiebudget/domain/entities/sync_fields.dart';
import 'package:pookiebudget/domain/result.dart';

/// One of the three top-level buckets.
///
/// A table rather than an enum because each carries a sort order and because
/// **the business group can be absent entirely** (PRD A-20) — a personal-only
/// user has no `BUSINESS` row at all.
///
/// The group's percentage share is not stored here: it lives on a `RuleLine`,
/// so that changing a share creates a new rule version rather than mutating the
/// group. INV-11 — history stays explainable — depends on that separation.
final class CategoryGroup {
  const CategoryGroup._({
    required this.id,
    required this.kind,
    required this.name,
    required this.sortOrder,
    required this.isActive,
    required this.sync,
  });

  static Result<CategoryGroup, EntityFailure> create({
    required String id,
    required CategoryGroupKind kind,
    required String name,
    required int sortOrder,
    required SyncFields sync,
    bool isActive = true,
  }) {
    final String trimmed = name.trim();
    if (trimmed.isEmpty) {
      return const Failure<CategoryGroup, EntityFailure>(BlankName('group'));
    }
    return Success<CategoryGroup, EntityFailure>(
      CategoryGroup._(
        id: id,
        kind: kind,
        name: trimmed,
        sortOrder: sortOrder,
        isActive: isActive,
        sync: sync,
      ),
    );
  }

  final String id;

  /// Unique among non-deleted rows (U-01).
  final CategoryGroupKind kind;

  /// User-renameable.
  final String name;

  /// Display order, and the deterministic tie-break key for allocation.
  final int sortOrder;

  /// Covers the transition when business scope is enabled or disabled.
  final bool isActive;

  final SyncFields sync;

  Result<CategoryGroup, EntityFailure> copyWith({
    CategoryGroupKind? kind,
    String? name,
    int? sortOrder,
    bool? isActive,
    SyncFields? sync,
  }) => CategoryGroup.create(
    id: id,
    kind: kind ?? this.kind,
    name: name ?? this.name,
    sortOrder: sortOrder ?? this.sortOrder,
    isActive: isActive ?? this.isActive,
    sync: sync ?? this.sync,
  );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CategoryGroup &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          kind == other.kind &&
          name == other.name &&
          sortOrder == other.sortOrder &&
          isActive == other.isActive &&
          sync == other.sync;

  @override
  int get hashCode => Object.hash(id, kind, name, sortOrder, isActive, sync);

  @override
  String toString() => 'CategoryGroup($id, ${kind.wireName}, "$name")';
}
