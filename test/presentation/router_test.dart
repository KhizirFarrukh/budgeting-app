import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:pookiebudget/presentation/router/router.dart';
import 'package:pookiebudget/presentation/router/routes.dart';
import 'package:pookiebudget/presentation/screens/dev_menu_screen.dart';

/// Substage 3.7.6 requires walking every route and confirming reachability.
///
/// Doing it as a test rather than only by hand means it stays true: Stage 6
/// replaces every stub, and a route that stops resolving will fail here rather
/// than being discovered by a user.
///
/// Acceptance criteria covered:
/// - every route in NAVIGATION.md is reachable
/// - there is no dead route, and none absent from the design document
/// - placeholders visibly identify themselves as placeholders
void main() {
  /// The 22 screens of NAVIGATION.md §1, as concrete paths.
  ///
  /// Parameterised routes appear with a sample argument, since that is what a
  /// user actually navigates to.
  const List<String> designRoutes = <String>[
    // onboarding — NAVIGATION §1.1
    Routes.welcome,
    Routes.currency,
    Routes.scope,
    Routes.topLevelSplit,
    '/onboarding/categories/savings',
    Routes.categoryPercentages,
    Routes.ceilingsSetup,
    Routes.accountsSetup,
    Routes.setupSummary,
    Routes.restoreFromCloud,
    // core — NAVIGATION §1.2
    Routes.dashboard,
    Routes.addIncome,
    Routes.allocationPreview,
    Routes.adjustSplit,
    Routes.incomeConfirmed,
    Routes.addSpending,
    '/categories/sample',
    Routes.transactionHistory,
    // management — NAVIGATION §1.3
    Routes.categoryList,
    Routes.categoryNew,
    '/categories/sample/edit',
    Routes.accountList,
    Routes.accountNew,
    '/accounts/sample/edit',
    Routes.reports,
    Routes.settings,
    Routes.syncAccount,
    Routes.diagnostics,
  ];

  Widget appWith(GoRouter router) => MaterialApp.router(routerConfig: router);

  group('every designed route resolves', () {
    for (final String path in designRoutes) {
      testWidgets('reaches $path', (WidgetTester tester) async {
        final GoRouter router = AppRouter.build();
        router.go(path);
        await tester.pumpWidget(appWith(router));
        await tester.pumpAndSettle();

        // The error route would render this; nothing else does.
        expect(
          find.text('Route not found'),
          findsNothing,
          reason: '$path fell through to the error builder',
        );
        expect(tester.takeException(), isNull, reason: '$path threw');
      });
    }
  });

  testWidgets('placeholders visibly identify themselves', (
    WidgetTester tester,
  ) async {
    // Substage 3.7.2: "The placeholder should visibly say it is a placeholder."
    // Anti-pattern guarded against: stubs with plausible figures being
    // screenshotted as progress.
    final GoRouter router = AppRouter.build();
    router.go(Routes.dashboard);
    await tester.pumpWidget(appWith(router));
    await tester.pumpAndSettle();

    expect(find.text('Placeholder — not implemented'), findsOneWidget);
    expect(find.textContaining('Built in substage'), findsOneWidget);
  });

  testWidgets('an unknown route lands on the error builder, not a crash', (
    WidgetTester tester,
  ) async {
    final GoRouter router = AppRouter.build();
    router.go('/no/such/route');
    await tester.pumpWidget(appWith(router));
    await tester.pumpAndSettle();

    expect(find.text('Route not found'), findsOneWidget);
  });

  test('the developer menu lists every designed route', () {
    // Keeps the menu honest: if a route is added to the design and the router
    // but not the menu, substage 3.7.6's walk would silently miss it.
    final Set<String> inMenu = DevMenuScreen.allPaths.toSet();
    final Set<String> inDesign = designRoutes.toSet();

    expect(
      inDesign.difference(inMenu),
      isEmpty,
      reason: 'designed routes missing from the developer menu',
    );
    expect(
      inMenu.difference(inDesign),
      isEmpty,
      reason: 'developer menu offers routes absent from the design',
    );
  });

  test('route count matches the design document', () {
    // NAVIGATION.md §1 defines 22 screens. Several are parameterised or have a
    // new/edit pair, giving 28 concrete paths.
    expect(designRoutes.length, 28);
    expect(designRoutes.toSet().length, 28, reason: 'duplicate route path');
  });
}
