/// Row ↔ entity for the three tables that describe where money can land.
///
/// ## Both directions live in one file, next to each other
///
/// Substage 4.4's named pitfall is *"a mapping function updated for writes but
/// not for reads, losing a field silently."* Keeping `fromRow` and `toCompanion`
/// adjacent makes the omission visible while the change is being made rather
/// than months later, when a category quietly stops remembering its ceiling.
///
/// ## Writes are total, never partial
///
/// Every companion below sets **every** column, including nullable ones set to
/// an explicit null. Using `Value.absent()` for a null field would make an
/// update leave the previous value in place — so clearing a ceiling by
/// switching a savings goal to an open envelope would keep the old ceiling in
/// the database while the entity in memory says there is none. One row shape,
/// written whole, has no such gap.
library;

import 'package:drift/drift.dart';
import 'package:pookiebudget/data/database/database.dart';
import 'package:pookiebudget/data/mappers/mapping_error.dart';
import 'package:pookiebudget/data/mappers/sync_field_mapper.dart';
import 'package:pookiebudget/domain/entities/category.dart';
import 'package:pookiebudget/domain/entities/category_group.dart';
import 'package:pookiebudget/domain/entities/entity_failure.dart';
import 'package:pookiebudget/domain/entities/enums.dart';
import 'package:pookiebudget/domain/entities/redirect_target.dart';
import 'package:pookiebudget/domain/result.dart';

// ---------------------------------------------------------------------------
// CategoryGroup
// ---------------------------------------------------------------------------

CategoryGroup categoryGroupFromRow(CategoryGroupRow row) {
  final CategoryGroupKind? kind = CategoryGroupKind.fromWire(row.kind);
  if (kind == null) {
    throw MappingError.unknownEnum(
      table: 'category_groups',
      recordId: row.id,
      column: 'kind',
      value: row.kind,
      permitted: CategoryGroupKind.values
          .map((CategoryGroupKind v) => v.wireName)
          .toList(),
    );
  }

  final Result<CategoryGroup, EntityFailure> result = CategoryGroup.create(
    id: row.id,
    kind: kind,
    name: row.name,
    sortOrder: row.sortOrder,
    isActive: row.isActive,
    sync: readSyncFields(
      updatedAtMs: row.updatedAtMs,
      updatedByDevice: row.updatedByDevice,
      hlc: row.hlc,
      isDeleted: row.isDeleted,
      deletedAtMs: row.deletedAtMs,
    ),
  );

  return switch (result) {
    Success<CategoryGroup, EntityFailure>(:final CategoryGroup value) => value,
    Failure<CategoryGroup, EntityFailure>(:final EntityFailure failure) =>
      throw MappingError.rejectedByEntity(
        table: 'category_groups',
        recordId: row.id,
        failure: failure,
      ),
  };
}

CategoryGroupsCompanion categoryGroupToCompanion(CategoryGroup group) =>
    CategoryGroupsCompanion(
      id: Value<String>(group.id),
      kind: Value<String>(group.kind.wireName),
      name: Value<String>(group.name),
      sortOrder: Value<int>(group.sortOrder),
      isActive: Value<bool>(group.isActive),
      updatedAtMs: Value<int>(group.sync.updatedAtMs),
      updatedByDevice: Value<String>(group.sync.updatedByDevice),
      hlc: Value<String>(group.sync.hlc),
      isDeleted: Value<bool>(group.sync.isDeleted),
      deletedAtMs: Value<int?>(group.sync.deletedAtMs),
    );

// ---------------------------------------------------------------------------
// Category
// ---------------------------------------------------------------------------

Category categoryFromRow(CategoryRow row) {
  final CategoryType? type = CategoryType.fromWire(row.type);
  if (type == null) {
    throw MappingError.unknownEnum(
      table: 'categories',
      recordId: row.id,
      column: 'type',
      value: row.type,
      permitted: CategoryType.values
          .map((CategoryType v) => v.wireName)
          .toList(),
    );
  }

  final CeilingKind? ceilingKind = CeilingKind.fromWire(row.ceilingKind);
  if (ceilingKind == null) {
    throw MappingError.unknownEnum(
      table: 'categories',
      recordId: row.id,
      column: 'ceiling_kind',
      value: row.ceilingKind,
      permitted: CeilingKind.values.map((CeilingKind v) => v.wireName).toList(),
    );
  }

  final RedirectMode? redirectMode = RedirectMode.fromWire(row.redirectMode);
  if (redirectMode == null) {
    throw MappingError.unknownEnum(
      table: 'categories',
      recordId: row.id,
      column: 'redirect_mode',
      value: row.redirectMode,
      permitted: RedirectMode.values
          .map((RedirectMode v) => v.wireName)
          .toList(),
    );
  }

  // The five reserved columns are not read into the entity, because the entity
  // has no fields for them (C-21 pins them to their v1 defaults). They are
  // carried through export and import instead, so a v1.1 client reading a v1.0
  // backup finds them present — substage 4.9's concern, not this one.

  final Result<Category, EntityFailure> result = Category.create(
    id: row.id,
    groupId: row.groupId,
    name: row.name,
    type: type,
    sortOrder: row.sortOrder,
    isArchived: row.isArchived,
    isSink: row.isSink,
    isSuggestedSeed: row.isSuggestedSeed,
    seedVersion: row.seedVersion,
    ceilingMinor: row.ceilingMinor,
    billAmountMinor: row.billAmountMinor,
    periodAnchorDay: row.periodAnchorDay,
    linkedAccountId: row.linkedAccountId,
    ceilingKind: ceilingKind,
    redirectMode: redirectMode,
    referenceMonthlyAmountMinor: row.referenceMonthlyAmountMinor,
    sync: readSyncFields(
      updatedAtMs: row.updatedAtMs,
      updatedByDevice: row.updatedByDevice,
      hlc: row.hlc,
      isDeleted: row.isDeleted,
      deletedAtMs: row.deletedAtMs,
    ),
  );

  return switch (result) {
    Success<Category, EntityFailure>(:final Category value) => value,
    Failure<Category, EntityFailure>(:final EntityFailure failure) =>
      throw MappingError.rejectedByEntity(
        table: 'categories',
        recordId: row.id,
        failure: failure,
      ),
  };
}

CategoriesCompanion categoryToCompanion(Category category) =>
    CategoriesCompanion(
      id: Value<String>(category.id),
      groupId: Value<String>(category.groupId),
      name: Value<String>(category.name),
      type: Value<String>(category.type.wireName),
      sortOrder: Value<int>(category.sortOrder),
      isArchived: Value<bool>(category.isArchived),
      isSink: Value<bool>(category.isSink),
      isSuggestedSeed: Value<bool>(category.isSuggestedSeed),
      seedVersion: Value<int?>(category.seedVersion),
      ceilingMinor: Value<int?>(category.ceilingMinor),
      billAmountMinor: Value<int?>(category.billAmountMinor),
      periodAnchorDay: Value<int?>(category.periodAnchorDay),
      redirectMode: Value<String>(category.redirectMode.wireName),
      referenceMonthlyAmountMinor: Value<int?>(
        category.referenceMonthlyAmountMinor,
      ),
      linkedAccountId: Value<String?>(category.linkedAccountId),
      ceilingKind: Value<String>(category.ceilingKind.wireName),
      // The five reserved columns, written explicitly as their v1 defaults
      // rather than left absent. C-21 rejects anything else, so a v1.1 client
      // reading a v1.0 row can trust every one of them holds the default —
      // which is the whole value of reserving them (SCHEMA §6.7).
      targetDateMs: const Value<int?>(null),
      ceilingParam: const Value<String?>(null),
      parentCategoryId: const Value<String?>(null),
      softBudgetMinor: const Value<int?>(null),
      softBudgetPeriod: const Value<String?>(null),
      updatedAtMs: Value<int>(category.sync.updatedAtMs),
      updatedByDevice: Value<String>(category.sync.updatedByDevice),
      hlc: Value<String>(category.sync.hlc),
      isDeleted: Value<bool>(category.sync.isDeleted),
      deletedAtMs: Value<int?>(category.sync.deletedAtMs),
    );

// ---------------------------------------------------------------------------
// RedirectTarget (ADR-006)
// ---------------------------------------------------------------------------

RedirectTarget redirectTargetFromRow(RedirectTargetRow row) {
  final Result<RedirectTarget, EntityFailure> result = RedirectTarget.create(
    id: row.id,
    sourceCategoryId: row.sourceCategoryId,
    targetCategoryId: row.targetCategoryId,
    priority: row.priority,
    basisPoints: row.basisPoints,
    sync: readSyncFields(
      updatedAtMs: row.updatedAtMs,
      updatedByDevice: row.updatedByDevice,
      hlc: row.hlc,
      isDeleted: row.isDeleted,
      deletedAtMs: row.deletedAtMs,
    ),
  );

  return switch (result) {
    Success<RedirectTarget, EntityFailure>(:final RedirectTarget value) =>
      value,
    Failure<RedirectTarget, EntityFailure>(:final EntityFailure failure) =>
      throw MappingError.rejectedByEntity(
        table: 'redirect_targets',
        recordId: row.id,
        failure: failure,
      ),
  };
}

RedirectTargetsCompanion redirectTargetToCompanion(RedirectTarget target) =>
    RedirectTargetsCompanion(
      id: Value<String>(target.id),
      sourceCategoryId: Value<String>(target.sourceCategoryId),
      targetCategoryId: Value<String>(target.targetCategoryId),
      priority: Value<int>(target.priority),
      // `basisPoints` is null under PRIORITY and set under SPLIT, and the null
      // is meaningful: "not weighted" is a different statement from "weighted
      // at zero". Writing it explicitly preserves that distinction on update.
      basisPoints: Value<int?>(target.basisPoints?.raw),
      updatedAtMs: Value<int>(target.sync.updatedAtMs),
      updatedByDevice: Value<String>(target.sync.updatedByDevice),
      hlc: Value<String>(target.sync.hlc),
      isDeleted: Value<bool>(target.sync.isDeleted),
      deletedAtMs: Value<int?>(target.sync.deletedAtMs),
    );
