/// Route paths, one per screen in `docs/NAVIGATION.md` §1.
///
/// Held as constants so no route path is ever written as a bare string at a
/// call site — a typo'd literal fails at runtime, a typo'd constant fails to
/// compile.
///
/// **22 screens.** Substage 3.7.6 walks every one and 3.9.1 compares this list
/// against NAVIGATION.md with a difference column.
class Routes {
  const Routes._();

  // --- onboarding (NAVIGATION §1.1) ---------------------------------------
  static const String welcome = '/onboarding/welcome';
  static const String currency = '/onboarding/currency';
  static const String scope = '/onboarding/scope';
  static const String topLevelSplit = '/onboarding/groups';
  static const String categorySelection = '/onboarding/categories/:group';
  static const String categoryPercentages = '/onboarding/percentages';
  static const String ceilingsSetup = '/onboarding/ceilings';
  static const String accountsSetup = '/onboarding/accounts';
  static const String setupSummary = '/onboarding/summary';
  static const String restoreFromCloud = '/onboarding/restore';

  // --- core (NAVIGATION §1.2) ---------------------------------------------
  static const String dashboard = '/';
  static const String addIncome = '/income/add';
  static const String allocationPreview = '/income/preview';
  static const String adjustSplit = '/income/adjust';
  static const String incomeConfirmed = '/income/confirmed';
  static const String addSpending = '/spending/add';
  static const String categoryDetail = '/categories/:id';
  static const String transactionHistory = '/history';

  // --- management (NAVIGATION §1.3) ---------------------------------------
  static const String categoryList = '/categories';
  static const String categoryEdit = '/categories/:id/edit';
  static const String categoryNew = '/categories/new';
  static const String accountList = '/accounts';
  static const String accountEdit = '/accounts/:id/edit';
  static const String accountNew = '/accounts/new';
  static const String reports = '/reports';
  static const String settings = '/settings';
  static const String syncAccount = '/settings/sync';
  static const String diagnostics = '/settings/diagnostics';

  /// **Removed in substage 10.2.7.** Listed on the Stage 10 checklist the
  /// moment it was created (substage 3.7.5), because a developer menu that
  /// survives to release is one nobody wrote down.
  static const String devMenu = '/dev';

  /// Builds a concrete path for a parameterised route.
  static String categoryDetailFor(String id) => '/categories/$id';
  static String categoryEditFor(String id) => '/categories/$id/edit';
  static String accountEditFor(String id) => '/accounts/$id/edit';
  static String categorySelectionFor(String group) =>
      '/onboarding/categories/$group';
}
