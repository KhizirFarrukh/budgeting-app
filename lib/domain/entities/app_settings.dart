import 'package:pookiebudget/domain/entities/entity_failure.dart';
import 'package:pookiebudget/domain/entities/enums.dart';
import 'package:pookiebudget/domain/entities/sync_fields.dart';
import 'package:pookiebudget/domain/money/currency.dart';
import 'package:pookiebudget/domain/result.dart';

/// The single settings row. [id] is fixed at `'singleton'` so a merge cannot
/// produce two.
final class AppSettings {
  const AppSettings._({
    required this.currencyCode,
    required this.currencyMinorExponent,
    required this.locale,
    required this.businessScopeEnabled,
    required this.personalSinkCategoryId,
    required this.businessSinkCategoryId,
    required this.onboardingState,
    required this.onboardingStep,
    required this.schemaVersion,
    required this.activeRuleVersionId,
    required this.sync,
  });

  /// The fixed primary key.
  static const String singletonId = 'singleton';

  /// Rejects an unsupported currency exponent (V-25 / C-12) and a blank locale.
  ///
  /// **Immutability of the currency is not enforced here** — V-24 makes it
  /// immutable *once any ledger entry exists*, which an entity cannot know.
  /// That check belongs to the repository, which can count entries. Putting it
  /// here would either be unenforceable or would require the entity to reach
  /// into storage, which the domain layer must not do.
  static Result<AppSettings, EntityFailure> create({
    required String currencyCode,
    required int currencyMinorExponent,
    required String locale,
    required int schemaVersion,
    required SyncFields sync,
    bool businessScopeEnabled = false,
    String? personalSinkCategoryId,
    String? businessSinkCategoryId,
    OnboardingState onboardingState = OnboardingState.notStarted,
    int? onboardingStep,
    String? activeRuleVersionId,
  }) {
    // V-25 — 0, 2 or 3. Every stored amount is interpreted through this, so an
    // unsupported value would misread every balance in the database.
    if (currencyMinorExponent != 0 &&
        currencyMinorExponent != 2 &&
        currencyMinorExponent != 3) {
      return Failure<AppSettings, EntityFailure>(
        UnsupportedCurrencyExponent(currencyMinorExponent),
      );
    }
    if (currencyCode.trim().isEmpty) {
      return const Failure<AppSettings, EntityFailure>(BlankName('currency'));
    }
    if (locale.trim().isEmpty) {
      return const Failure<AppSettings, EntityFailure>(BlankName('locale'));
    }
    return Success<AppSettings, EntityFailure>(
      AppSettings._(
        currencyCode: currencyCode.trim(),
        currencyMinorExponent: currencyMinorExponent,
        locale: locale.trim(),
        businessScopeEnabled: businessScopeEnabled,
        personalSinkCategoryId: personalSinkCategoryId,
        businessSinkCategoryId: businessSinkCategoryId,
        onboardingState: onboardingState,
        onboardingStep: onboardingStep,
        schemaVersion: schemaVersion,
        activeRuleVersionId: activeRuleVersionId,
        sync: sync,
      ),
    );
  }

  String get id => singletonId;

  /// ISO 4217, e.g. `PKR`, `USD`, `JPY`, `KWD`.
  final String currencyCode;

  /// 0, 2 or 3. Drives all parsing and formatting. **Immutable once any ledger
  /// entry exists** (V-24) — enforced at the repository, see [create].
  final int currencyMinorExponent;

  /// For display formatting.
  final String locale;

  final bool businessScopeEnabled;

  /// Required once onboarding completes.
  final String? personalSinkCategoryId;

  /// Required when business scope is enabled.
  final String? businessSinkCategoryId;

  /// Enables resume-where-you-left-off.
  final OnboardingState onboardingState;

  final int? onboardingStep;
  final int schemaVersion;
  final String? activeRuleVersionId;
  final SyncFields sync;

  /// The currency these settings describe — **the one place it is defined**.
  ///
  /// Entities store bare `int` minor units precisely so that this is the single
  /// source of truth; a copy on every entity would be ten values that can
  /// disagree.
  Currency get currency =>
      Currency(code: currencyCode, minorUnitExponent: currencyMinorExponent);

  /// The sink for a given scope. Which one applies is a settings question, not
  /// a caller question — OQ-07 answered *yes to both*, so business overflow
  /// stays in the business.
  String? sinkFor(MoneyScope scope) => switch (scope) {
    MoneyScope.personal => personalSinkCategoryId,
    MoneyScope.business => businessSinkCategoryId,
  };

  bool get isOnboardingComplete => onboardingState == OnboardingState.complete;

  Result<AppSettings, EntityFailure> copyWith({
    String? currencyCode,
    int? currencyMinorExponent,
    String? locale,
    bool? businessScopeEnabled,
    String? personalSinkCategoryId,
    String? businessSinkCategoryId,
    OnboardingState? onboardingState,
    int? onboardingStep,
    int? schemaVersion,
    String? activeRuleVersionId,
    SyncFields? sync,
    bool clearOnboardingStep = false,
  }) => AppSettings.create(
    currencyCode: currencyCode ?? this.currencyCode,
    currencyMinorExponent: currencyMinorExponent ?? this.currencyMinorExponent,
    locale: locale ?? this.locale,
    businessScopeEnabled: businessScopeEnabled ?? this.businessScopeEnabled,
    personalSinkCategoryId:
        personalSinkCategoryId ?? this.personalSinkCategoryId,
    businessSinkCategoryId:
        businessSinkCategoryId ?? this.businessSinkCategoryId,
    onboardingState: onboardingState ?? this.onboardingState,
    onboardingStep: clearOnboardingStep
        ? null
        : (onboardingStep ?? this.onboardingStep),
    schemaVersion: schemaVersion ?? this.schemaVersion,
    activeRuleVersionId: activeRuleVersionId ?? this.activeRuleVersionId,
    sync: sync ?? this.sync,
  );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AppSettings &&
          runtimeType == other.runtimeType &&
          currencyCode == other.currencyCode &&
          currencyMinorExponent == other.currencyMinorExponent &&
          locale == other.locale &&
          businessScopeEnabled == other.businessScopeEnabled &&
          personalSinkCategoryId == other.personalSinkCategoryId &&
          businessSinkCategoryId == other.businessSinkCategoryId &&
          onboardingState == other.onboardingState &&
          onboardingStep == other.onboardingStep &&
          schemaVersion == other.schemaVersion &&
          activeRuleVersionId == other.activeRuleVersionId &&
          sync == other.sync;

  @override
  int get hashCode => Object.hashAll(<Object?>[
    currencyCode,
    currencyMinorExponent,
    locale,
    businessScopeEnabled,
    personalSinkCategoryId,
    businessSinkCategoryId,
    onboardingState,
    onboardingStep,
    schemaVersion,
    activeRuleVersionId,
    sync,
  ]);

  @override
  String toString() =>
      'AppSettings($currencyCode/$currencyMinorExponent, $locale, '
      '${onboardingState.wireName})';
}
