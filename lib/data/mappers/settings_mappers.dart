/// Row ↔ entity for `app_settings`.
///
/// The entity has no `id` field of its own — `AppSettings.id` is a getter
/// returning the constant `'singleton'`. The companion below writes that
/// constant rather than anything read from the entity, so there is no path by
/// which a second settings row can be created: U-09 constrains the column, and
/// this mapper never offers it another value to reject.
library;

import 'package:drift/drift.dart';
import 'package:pookiebudget/data/database/database.dart';
import 'package:pookiebudget/data/mappers/mapping_error.dart';
import 'package:pookiebudget/data/mappers/sync_field_mapper.dart';
import 'package:pookiebudget/domain/entities/app_settings.dart';
import 'package:pookiebudget/domain/entities/entity_failure.dart';
import 'package:pookiebudget/domain/entities/enums.dart';
import 'package:pookiebudget/domain/result.dart';

AppSettings appSettingsFromRow(AppSettingsRow row) {
  final OnboardingState? onboardingState = OnboardingState.fromWire(
    row.onboardingState,
  );
  if (onboardingState == null) {
    throw MappingError.unknownEnum(
      table: 'app_settings',
      recordId: row.id,
      column: 'onboarding_state',
      value: row.onboardingState,
      permitted: OnboardingState.values
          .map((OnboardingState v) => v.wireName)
          .toList(),
    );
  }

  final Result<AppSettings, EntityFailure> result = AppSettings.create(
    currencyCode: row.currencyCode,
    currencyMinorExponent: row.currencyMinorExponent,
    locale: row.locale,
    schemaVersion: row.schemaVersion,
    businessScopeEnabled: row.businessScopeEnabled,
    personalSinkCategoryId: row.personalSinkCategoryId,
    businessSinkCategoryId: row.businessSinkCategoryId,
    onboardingState: onboardingState,
    onboardingStep: row.onboardingStep,
    activeRuleVersionId: row.activeRuleVersionId,
    sync: readSyncFields(
      updatedAtMs: row.updatedAtMs,
      updatedByDevice: row.updatedByDevice,
      hlc: row.hlc,
      isDeleted: row.isDeleted,
      deletedAtMs: row.deletedAtMs,
    ),
  );

  return switch (result) {
    Success<AppSettings, EntityFailure>(:final AppSettings value) => value,
    Failure<AppSettings, EntityFailure>(:final EntityFailure failure) =>
      throw MappingError.rejectedByEntity(
        table: 'app_settings',
        recordId: row.id,
        failure: failure,
      ),
  };
}

AppSettingsTableCompanion appSettingsToCompanion(AppSettings settings) =>
    AppSettingsTableCompanion(
      // The constant, not `settings.id`. See the library comment.
      id: const Value<String>(AppSettings.singletonId),
      currencyCode: Value<String>(settings.currencyCode),
      currencyMinorExponent: Value<int>(settings.currencyMinorExponent),
      locale: Value<String>(settings.locale),
      businessScopeEnabled: Value<bool>(settings.businessScopeEnabled),
      personalSinkCategoryId: Value<String?>(settings.personalSinkCategoryId),
      businessSinkCategoryId: Value<String?>(settings.businessSinkCategoryId),
      onboardingState: Value<String>(settings.onboardingState.wireName),
      onboardingStep: Value<int?>(settings.onboardingStep),
      schemaVersion: Value<int>(settings.schemaVersion),
      activeRuleVersionId: Value<String?>(settings.activeRuleVersionId),
      updatedAtMs: Value<int>(settings.sync.updatedAtMs),
      updatedByDevice: Value<String>(settings.sync.updatedByDevice),
      hlc: Value<String>(settings.sync.hlc),
      isDeleted: Value<bool>(settings.sync.isDeleted),
      deletedAtMs: Value<int?>(settings.sync.deletedAtMs),
    );
