/// Builders for the configuration entities, with valid defaults and named
/// overrides.
///
/// The companion to `money_builders.dart`, which said it plainly: *"Without
/// builders, every test that constructs one breaks the day a field is added —
/// and the usual response is to loosen the test rather than update it."*
/// `Category` alone has seventeen fields, so the repository tests would be
/// unreadable and brittle without this.
///
/// Every builder **unwraps the `Result` and throws on failure**, which is
/// correct here and wrong in production code. A builder that returned a
/// `Result` would make each test unwrap it before doing anything, and a builder
/// that silently substituted a valid value would let a test pass while
/// constructing something other than what it asked for. Throwing means an
/// invalid default is a loud failure in the builder, not a quiet one in the
/// assertion.
library;

import 'package:pookiebudget/domain/entities/account.dart';
import 'package:pookiebudget/domain/entities/app_settings.dart';
import 'package:pookiebudget/domain/entities/category.dart';
import 'package:pookiebudget/domain/entities/category_group.dart';
import 'package:pookiebudget/domain/entities/distribution_rule_version.dart';
import 'package:pookiebudget/domain/entities/entity_failure.dart';
import 'package:pookiebudget/domain/entities/enums.dart';
import 'package:pookiebudget/domain/entities/redirect_target.dart';
import 'package:pookiebudget/domain/entities/rule_line.dart';
import 'package:pookiebudget/domain/entities/sync_fields.dart';
import 'package:pookiebudget/domain/result.dart';

/// A sync stamp with everything set to a recognisable synthetic value.
///
/// `hlc` is a plausible-looking sortable string rather than the empty string
/// `SyncFields.local` produces, because a round-trip test must prove the column
/// carries a value — an empty string survives a mapper that dropped the field
/// entirely, since both sides read back as empty.
SyncFields syncFields({
  int updatedAtMs = 1767225600000,
  String updatedByDevice = 'device-under-test',
  String hlc = '1767225600000:0001:device-under-test',
  bool isDeleted = false,
  int? deletedAtMs,
}) => SyncFields(
  updatedAtMs: updatedAtMs,
  updatedByDevice: updatedByDevice,
  hlc: hlc,
  isDeleted: isDeleted,
  deletedAtMs: deletedAtMs,
);

T _require<T>(Result<T, EntityFailure> result, String what) =>
    switch (result) {
      Success<T, EntityFailure>(:final T value) => value,
      Failure<T, EntityFailure>(:final EntityFailure failure) =>
        throw StateError(
          'The $what builder produced an invalid entity: $failure. Fix the '
          'builder default or the override the test passed — do not relax the '
          'entity rule.',
        ),
    };

CategoryGroup buildGroup({
  String id = 'group-spending',
  CategoryGroupKind kind = CategoryGroupKind.spending,
  String name = 'Spending',
  int sortOrder = 0,
  bool isActive = true,
  SyncFields? sync,
}) => _require<CategoryGroup>(
  CategoryGroup.create(
    id: id,
    kind: kind,
    name: name,
    sortOrder: sortOrder,
    isActive: isActive,
    sync: sync ?? syncFields(),
  ),
  'group',
);

/// An `UNCAPPED_FLOW` category by default — the type with no required
/// companion fields, so an override never has to clear something first.
Category buildCategory({
  String id = 'category-groceries',
  String groupId = 'group-spending',
  String name = 'Groceries',
  CategoryType type = CategoryType.uncappedFlow,
  int sortOrder = 0,
  bool isArchived = false,
  bool isSink = false,
  bool isSuggestedSeed = false,
  int? seedVersion,
  int? ceilingMinor,
  int? billAmountMinor,
  int? periodAnchorDay,
  String? linkedAccountId,
  CeilingKind ceilingKind = CeilingKind.absolute,
  RedirectMode redirectMode = RedirectMode.priority,
  int? referenceMonthlyAmountMinor,
  SyncFields? sync,
}) => _require<Category>(
  Category.create(
    id: id,
    groupId: groupId,
    name: name,
    type: type,
    sortOrder: sortOrder,
    isArchived: isArchived,
    isSink: isSink,
    isSuggestedSeed: isSuggestedSeed,
    seedVersion: seedVersion,
    ceilingMinor: ceilingMinor,
    billAmountMinor: billAmountMinor,
    periodAnchorDay: periodAnchorDay,
    linkedAccountId: linkedAccountId,
    ceilingKind: ceilingKind,
    redirectMode: redirectMode,
    referenceMonthlyAmountMinor: referenceMonthlyAmountMinor,
    sync: sync ?? syncFields(),
  ),
  'category',
);

/// The terminal catch-all. Uncapped and non-archivable by construction
/// (V-13 / C-19), so a test cannot accidentally build a capped one.
Category buildSink({
  String id = 'category-sink',
  String groupId = 'group-spending',
  String name = 'Everything else',
  int sortOrder = 999,
  SyncFields? sync,
}) => buildCategory(
  id: id,
  groupId: groupId,
  name: name,
  sortOrder: sortOrder,
  isSink: true,
  sync: sync,
);

Account buildAccount({
  String id = 'account-current',
  String name = 'Current account',
  int sortOrder = 0,
  String? institution,
  String? lastFour,
  MoneyScope scope = MoneyScope.personal,
  bool isArchived = false,
  SyncFields? sync,
}) => _require<Account>(
  Account.create(
    id: id,
    name: name,
    sortOrder: sortOrder,
    institution: institution,
    lastFour: lastFour,
    scope: scope,
    isArchived: isArchived,
    sync: sync ?? syncFields(),
  ),
  'account',
);

DistributionRuleVersion buildRuleVersion({
  String id = 'rule-v1',
  int effectiveFromMs = 1767225600000,
  int createdAtMs = 1767225600000,
  int? sealedAtMs,
  String? note,
  RuleSet ruleSet = RuleSet.defaultSet,
  SyncFields? sync,
}) => _require<DistributionRuleVersion>(
  DistributionRuleVersion.create(
    id: id,
    effectiveFromMs: effectiveFromMs,
    createdAtMs: createdAtMs,
    sealedAtMs: sealedAtMs,
    note: note,
    ruleSet: ruleSet,
    sync: sync ?? syncFields(),
  ),
  'rule version',
);

RuleLine buildGroupLine({
  String id = 'line-group-spending',
  String ruleVersionId = 'rule-v1',
  String groupId = 'group-spending',
  int basisPoints = 10000,
  SyncFields? sync,
}) => _require<RuleLine>(
  RuleLine.create(
    id: id,
    ruleVersionId: ruleVersionId,
    scope: RuleLineScope.group,
    basisPoints: basisPoints,
    groupId: groupId,
    sync: sync ?? syncFields(),
  ),
  'group rule line',
);

RuleLine buildCategoryLine({
  String id = 'line-category-groceries',
  String ruleVersionId = 'rule-v1',
  String categoryId = 'category-groceries',
  int basisPoints = 10000,
  SyncFields? sync,
}) => _require<RuleLine>(
  RuleLine.create(
    id: id,
    ruleVersionId: ruleVersionId,
    scope: RuleLineScope.category,
    basisPoints: basisPoints,
    categoryId: categoryId,
    sync: sync ?? syncFields(),
  ),
  'category rule line',
);

RedirectTarget buildRedirectTarget({
  String id = 'redirect-1',
  String sourceCategoryId = 'category-goal',
  String targetCategoryId = 'category-sink',
  int priority = 0,
  int? basisPoints,
  SyncFields? sync,
}) => _require<RedirectTarget>(
  RedirectTarget.create(
    id: id,
    sourceCategoryId: sourceCategoryId,
    targetCategoryId: targetCategoryId,
    priority: priority,
    basisPoints: basisPoints,
    sync: sync ?? syncFields(),
  ),
  'redirect target',
);

AppSettings buildSettings({
  String currencyCode = 'PKR',
  int currencyMinorExponent = 2,
  String locale = 'en_PK',
  int schemaVersion = 1,
  bool businessScopeEnabled = false,
  String? personalSinkCategoryId,
  String? businessSinkCategoryId,
  OnboardingState onboardingState = OnboardingState.notStarted,
  int? onboardingStep,
  String? activeRuleVersionId,
  SyncFields? sync,
}) => _require<AppSettings>(
  AppSettings.create(
    currencyCode: currencyCode,
    currencyMinorExponent: currencyMinorExponent,
    locale: locale,
    schemaVersion: schemaVersion,
    businessScopeEnabled: businessScopeEnabled,
    personalSinkCategoryId: personalSinkCategoryId,
    businessSinkCategoryId: businessSinkCategoryId,
    onboardingState: onboardingState,
    onboardingStep: onboardingStep,
    activeRuleVersionId: activeRuleVersionId,
    sync: sync ?? syncFields(),
  ),
  'settings',
);
