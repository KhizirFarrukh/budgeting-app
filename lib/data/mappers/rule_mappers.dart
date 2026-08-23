/// Row ↔ entity for `distribution_rule_versions` and `rule_lines`.
///
/// `sealed_at_ms` maps straight through as a nullable integer and is never
/// defaulted or recomputed. It is the field INV-11 rests on: once set, the
/// version's lines are frozen because an income event has already been split by
/// them. A mapper that supplied a value for it — "not sealed yet, so now" — or
/// dropped it on a round trip would unfreeze history, which is why it is called
/// out here rather than treated as one more nullable column.
library;

import 'package:drift/drift.dart';
import 'package:pookiebudget/data/database/database.dart';
import 'package:pookiebudget/data/mappers/mapping_error.dart';
import 'package:pookiebudget/data/mappers/sync_field_mapper.dart';
import 'package:pookiebudget/domain/entities/distribution_rule_version.dart';
import 'package:pookiebudget/domain/entities/entity_failure.dart';
import 'package:pookiebudget/domain/entities/enums.dart';
import 'package:pookiebudget/domain/entities/rule_line.dart';
import 'package:pookiebudget/domain/result.dart';

// ---------------------------------------------------------------------------
// DistributionRuleVersion
// ---------------------------------------------------------------------------

DistributionRuleVersion ruleVersionFromRow(DistributionRuleVersionRow row) {
  final RuleSet? ruleSet = RuleSet.fromWire(row.ruleSet);
  if (ruleSet == null) {
    throw MappingError.unknownEnum(
      table: 'distribution_rule_versions',
      recordId: row.id,
      column: 'rule_set',
      value: row.ruleSet,
      permitted: RuleSet.values.map((RuleSet v) => v.wireName).toList(),
    );
  }

  final Result<DistributionRuleVersion, EntityFailure> result =
      DistributionRuleVersion.create(
        id: row.id,
        effectiveFromMs: row.effectiveFromMs,
        createdAtMs: row.createdAtMs,
        sealedAtMs: row.sealedAtMs,
        note: row.note,
        ruleSet: ruleSet,
        sync: readSyncFields(
          updatedAtMs: row.updatedAtMs,
          updatedByDevice: row.updatedByDevice,
          hlc: row.hlc,
          isDeleted: row.isDeleted,
          deletedAtMs: row.deletedAtMs,
        ),
      );

  return switch (result) {
    Success<DistributionRuleVersion, EntityFailure>(
      :final DistributionRuleVersion value,
    ) =>
      value,
    Failure<DistributionRuleVersion, EntityFailure>(
      :final EntityFailure failure,
    ) =>
      throw MappingError.rejectedByEntity(
        table: 'distribution_rule_versions',
        recordId: row.id,
        failure: failure,
      ),
  };
}

DistributionRuleVersionsCompanion ruleVersionToCompanion(
  DistributionRuleVersion version,
) => DistributionRuleVersionsCompanion(
  id: Value<String>(version.id),
  effectiveFromMs: Value<int>(version.effectiveFromMs),
  createdAtMs: Value<int>(version.createdAtMs),
  sealedAtMs: Value<int?>(version.sealedAtMs),
  note: Value<String?>(version.note),
  ruleSet: Value<String>(version.ruleSet.wireName),
  updatedAtMs: Value<int>(version.sync.updatedAtMs),
  updatedByDevice: Value<String>(version.sync.updatedByDevice),
  hlc: Value<String>(version.sync.hlc),
  isDeleted: Value<bool>(version.sync.isDeleted),
  deletedAtMs: Value<int?>(version.sync.deletedAtMs),
);

// ---------------------------------------------------------------------------
// RuleLine
// ---------------------------------------------------------------------------

RuleLine ruleLineFromRow(RuleLineRow row) {
  final RuleLineScope? scope = RuleLineScope.fromWire(row.scope);
  if (scope == null) {
    throw MappingError.unknownEnum(
      table: 'rule_lines',
      recordId: row.id,
      column: 'scope',
      value: row.scope,
      permitted: RuleLineScope.values
          .map((RuleLineScope v) => v.wireName)
          .toList(),
    );
  }

  final Result<RuleLine, EntityFailure> result = RuleLine.create(
    id: row.id,
    ruleVersionId: row.ruleVersionId,
    scope: scope,
    basisPoints: row.basisPoints,
    groupId: row.groupId,
    categoryId: row.categoryId,
    sync: readSyncFields(
      updatedAtMs: row.updatedAtMs,
      updatedByDevice: row.updatedByDevice,
      hlc: row.hlc,
      isDeleted: row.isDeleted,
      deletedAtMs: row.deletedAtMs,
    ),
  );

  return switch (result) {
    Success<RuleLine, EntityFailure>(:final RuleLine value) => value,
    Failure<RuleLine, EntityFailure>(:final EntityFailure failure) =>
      throw MappingError.rejectedByEntity(
        table: 'rule_lines',
        recordId: row.id,
        failure: failure,
      ),
  };
}

RuleLinesCompanion ruleLineToCompanion(RuleLine line) => RuleLinesCompanion(
  id: Value<String>(line.id),
  ruleVersionId: Value<String>(line.ruleVersionId),
  scope: Value<String>(line.scope.wireName),
  // Exactly one of these is non-null, guaranteed by the entity and re-checked
  // by C-24. Both are written explicitly so switching a line's scope clears the
  // target it no longer applies to — a GROUP line still carrying a category_id
  // would be counted in neither total.
  groupId: Value<String?>(line.groupId),
  categoryId: Value<String?>(line.categoryId),
  basisPoints: Value<int>(line.basisPoints.raw),
  updatedAtMs: Value<int>(line.sync.updatedAtMs),
  updatedByDevice: Value<String>(line.sync.updatedByDevice),
  hlc: Value<String>(line.sync.hlc),
  isDeleted: Value<bool>(line.sync.isDeleted),
  deletedAtMs: Value<int?>(line.sync.deletedAtMs),
);
