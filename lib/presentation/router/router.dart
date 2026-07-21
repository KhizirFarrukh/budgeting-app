import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:pookiebudget/presentation/router/routes.dart';
import 'package:pookiebudget/presentation/screens/dev_menu_screen.dart';
import 'package:pookiebudget/presentation/widgets/stub_screen.dart';

/// The navigation graph from `docs/NAVIGATION.md` §2.
///
/// **Declarative**, as decided in NAVIGATION §3, on two specific grounds:
/// startup routing is state-driven (`onboarding_state` chooses between three
/// destinations at cold start), and onboarding must resume after process death
/// — a redirect under route-per-step, but a serialisation problem under a
/// single stateful widget.
///
/// Substage 3.7 wires the graph with one stub per route. Stage 6 replaces the
/// stubs; the shape stays.
///
/// **Startup redirect is not implemented yet.** It depends on reading
/// `onboarding_state` from settings, which is Stage 4's data layer and Stage
/// 6.1.5's wiring. Until then the app opens on the dashboard, and the developer
/// menu reaches everything else.
class AppRouter {
  const AppRouter._();

  static GoRouter build() {
    return GoRouter(
      initialLocation: Routes.dashboard,
      debugLogDiagnostics: false,
      routes: <RouteBase>[
        // ---------------------------------------------------------------
        // Core
        // ---------------------------------------------------------------
        GoRoute(
          path: Routes.dashboard,
          builder: (BuildContext c, GoRouterState s) => StubScreen(
            title: 'Dashboard',
            buildsIn: '6.8',
            purpose:
                'Balances, ceiling progress and recent activity. Every figure '
                'derived from the ledger and updating reactively.',
            journeyStep: 'J1-A step 11, J1-B step 12, J1-C steps 18/20/21',
            actions: <StubAction>[
              StubAction(
                label: 'Add income  →  /income/add',
                onPressed: () => c.push(Routes.addIncome),
              ),
              StubAction(
                label: 'Add spending  →  /spending/add',
                onPressed: () => c.push(Routes.addSpending),
              ),
              StubAction(
                label: 'History  →  /history',
                onPressed: () => c.push(Routes.transactionHistory),
              ),
              StubAction(
                label: 'Reports  →  /reports',
                onPressed: () => c.push(Routes.reports),
              ),
              StubAction(
                label: 'Settings  →  /settings',
                onPressed: () => c.push(Routes.settings),
              ),
              StubAction(
                label: 'Developer menu (removed in 10.2.7)',
                onPressed: () => c.push(Routes.devMenu),
              ),
            ],
          ),
        ),
        GoRoute(
          path: Routes.addIncome,
          builder: (BuildContext c, GoRouterState s) => StubScreen(
            title: 'Add Income',
            buildsIn: '6.4',
            purpose: 'Amount, source label, date and an optional note.',
            journeyStep: 'J1-B step 13, J2-B step 13',
            actions: <StubAction>[
              StubAction(
                label: 'Preview  →  /income/preview',
                onPressed: () => c.push(Routes.allocationPreview),
              ),
            ],
          ),
        ),
        GoRoute(
          path: Routes.allocationPreview,
          builder: (BuildContext c, GoRouterState s) => StubScreen(
            title: 'Allocation Preview',
            buildsIn: '6.4',
            purpose:
                'Per-category amounts, the diagnostics trace explaining every '
                'redirect, and the running total against the entered amount.',
            journeyStep: 'J1-B steps 14-15, J2-B steps 14-16',
            actions: <StubAction>[
              StubAction(
                label: 'Adjust split  →  /income/adjust',
                onPressed: () => c.push(Routes.adjustSplit),
              ),
              StubAction(
                label: 'Confirm  →  /income/confirmed',
                onPressed: () => c.push(Routes.incomeConfirmed),
              ),
            ],
          ),
        ),
        GoRoute(
          path: Routes.adjustSplit,
          builder: (BuildContext c, GoRouterState s) => const StubScreen(
            title: 'Adjust Split',
            buildsIn: '6.5',
            purpose:
                'Per-category manual override. Confirmation is impossible '
                'unless the total equals the income exactly.',
            journeyStep: 'US-016',
          ),
        ),
        GoRoute(
          path: Routes.incomeConfirmed,
          builder: (BuildContext c, GoRouterState s) => StubScreen(
            title: 'Income Confirmed',
            buildsIn: '6.5',
            purpose:
                'What happened, including any redirects, with a direct undo '
                'action.',
            journeyStep: 'J1-B step 16, J2-B step 17',
            actions: <StubAction>[
              StubAction(
                label: 'Back to dashboard',
                onPressed: () => c.go(Routes.dashboard),
              ),
            ],
          ),
        ),
        GoRoute(
          path: Routes.addSpending,
          builder: (BuildContext c, GoRouterState s) => const StubScreen(
            title: 'Add Spending',
            buildsIn: '6.9',
            purpose: 'Amount, category, account, date and note.',
            journeyStep: 'J1-C step 19',
          ),
        ),
        GoRoute(
          path: Routes.transactionHistory,
          builder: (BuildContext c, GoRouterState s) => const StubScreen(
            title: 'Transaction History',
            buildsIn: '6.9',
            purpose:
                'Filterable list with running balances. Reversals and '
                'corrections shown explicitly, so nothing ever appears to '
                'vanish.',
            journeyStep: 'US-026',
          ),
        ),

        // ---------------------------------------------------------------
        // Onboarding
        // ---------------------------------------------------------------
        GoRoute(
          path: Routes.welcome,
          builder: (BuildContext c, GoRouterState s) => StubScreen(
            title: 'Welcome',
            buildsIn: '6.2',
            purpose: 'One sentence on what the app does.',
            journeyStep: 'J1-A step 1, J2-A step 1',
            actions: <StubAction>[
              StubAction(
                label: 'Currency  →  /onboarding/currency',
                onPressed: () => c.push(Routes.currency),
              ),
              StubAction(
                label: 'Restore from cloud  →  /onboarding/restore',
                onPressed: () => c.push(Routes.restoreFromCloud),
              ),
            ],
          ),
        ),
        GoRoute(
          path: Routes.currency,
          builder: (BuildContext c, GoRouterState s) => StubScreen(
            title: 'Currency Confirmation',
            buildsIn: '6.2',
            purpose:
                'Confirm the currency detected from device locale. Changeable '
                'only while no money has been recorded.',
            journeyStep: 'J1-A step 2',
            actions: <StubAction>[
              StubAction(
                label: 'Scope  →  /onboarding/scope',
                onPressed: () => c.push(Routes.scope),
              ),
            ],
          ),
        ),
        GoRoute(
          path: Routes.scope,
          builder: (BuildContext c, GoRouterState s) => StubScreen(
            title: 'Scope Selection',
            buildsIn: '6.2',
            purpose:
                'Personal only, or personal plus business. Personal-only hides '
                'the business group entirely rather than showing an empty one.',
            journeyStep: 'J1-A step 3',
            actions: <StubAction>[
              StubAction(
                label: 'Top-level split  →  /onboarding/groups',
                onPressed: () => c.push(Routes.topLevelSplit),
              ),
            ],
          ),
        ),
        GoRoute(
          path: Routes.topLevelSplit,
          builder: (BuildContext c, GoRouterState s) => StubScreen(
            title: 'Top-Level Split',
            buildsIn: '6.2',
            purpose:
                'Group percentages, pre-filled and valid. Submitting anything '
                'other than exactly 100% is impossible.',
            journeyStep: 'J1-A step 4',
            actions: <StubAction>[
              StubAction(
                label: 'Categories  →  /onboarding/categories/savings',
                onPressed: () => c.push(Routes.categorySelectionFor('savings')),
              ),
            ],
          ),
        ),
        GoRoute(
          path: Routes.categorySelection,
          builder: (BuildContext c, GoRouterState s) => StubScreen(
            title: 'Category Selection (${s.pathParameters['group'] ?? '?'})',
            buildsIn: '6.3',
            purpose:
                'Suggested categories, pre-ticked and editable inline. Visited '
                'once per active group.',
            journeyStep: 'J1-A steps 5-6',
            actions: <StubAction>[
              StubAction(
                label: 'Percentages  →  /onboarding/percentages',
                onPressed: () => c.push(Routes.categoryPercentages),
              ),
            ],
          ),
        ),
        GoRoute(
          path: Routes.categoryPercentages,
          builder: (BuildContext c, GoRouterState s) => StubScreen(
            title: 'Category Percentages',
            buildsIn: '6.3',
            purpose:
                'Within-group shares, pre-filled and valid. Adding or removing '
                'a category never leaves the group invalid.',
            journeyStep: 'J1-A step 7',
            actions: <StubAction>[
              StubAction(
                label: 'Ceilings  →  /onboarding/ceilings',
                onPressed: () => c.push(Routes.ceilingsSetup),
              ),
            ],
          ),
        ),
        GoRoute(
          path: Routes.ceilingsSetup,
          builder: (BuildContext c, GoRouterState s) => StubScreen(
            title: 'Ceilings Setup',
            buildsIn: '6.3',
            purpose:
                'Optional targets and redirect targets. Skipping is obvious '
                'and consequence-free.',
            journeyStep: 'J1-A step 8',
            actions: <StubAction>[
              StubAction(
                label: 'Accounts  →  /onboarding/accounts',
                onPressed: () => c.push(Routes.accountsSetup),
              ),
            ],
          ),
        ),
        GoRoute(
          path: Routes.accountsSetup,
          builder: (BuildContext c, GoRouterState s) => StubScreen(
            title: 'Accounts Setup',
            buildsIn: '6.3',
            purpose:
                'Optional account labels, fully skippable. The app does not '
                'connect to any bank.',
            journeyStep: 'J1-A step 9',
            actions: <StubAction>[
              StubAction(
                label: 'Summary  →  /onboarding/summary',
                onPressed: () => c.push(Routes.setupSummary),
              ),
            ],
          ),
        ),
        GoRoute(
          path: Routes.setupSummary,
          builder: (BuildContext c, GoRouterState s) => StubScreen(
            title: 'Setup Summary',
            buildsIn: '6.3',
            purpose: 'The whole configuration in one view, then confirm.',
            journeyStep: 'J1-A step 10',
            actions: <StubAction>[
              StubAction(
                label: 'Dashboard',
                onPressed: () => c.go(Routes.dashboard),
              ),
            ],
          ),
        ),
        GoRoute(
          path: Routes.restoreFromCloud,
          builder: (BuildContext c, GoRouterState s) => const StubScreen(
            title: 'Restore From Cloud',
            buildsIn: '7.8',
            purpose:
                'Offered when a new install finds existing cloud data, BEFORE '
                'any local configuration is written.',
            journeyStep: 'FJ-4 steps 2-5, FJ-5(a)',
          ),
        ),

        // ---------------------------------------------------------------
        // Management
        // ---------------------------------------------------------------
        GoRoute(
          path: Routes.categoryList,
          builder: (BuildContext c, GoRouterState s) => StubScreen(
            title: 'Category List',
            buildsIn: '6.6',
            purpose:
                'All categories grouped, with the business group visually '
                'distinct.',
            journeyStep: 'US-006',
            actions: <StubAction>[
              StubAction(
                label: 'Category detail  →  /categories/sample',
                onPressed: () => c.push(Routes.categoryDetailFor('sample')),
              ),
              StubAction(
                label: 'New category  →  /categories/new',
                onPressed: () => c.push(Routes.categoryNew),
              ),
            ],
          ),
        ),
        GoRoute(
          path: Routes.categoryNew,
          builder: (BuildContext c, GoRouterState s) => const StubScreen(
            title: 'Category Edit (new)',
            buildsIn: '6.6',
            purpose:
                'Name, group, type, percentage, ceiling or bill, redirect '
                'target, linked account.',
            journeyStep: 'US-004 to US-007, US-018, US-020',
          ),
        ),
        GoRoute(
          path: Routes.categoryEdit,
          builder: (BuildContext c, GoRouterState s) => StubScreen(
            title: 'Category Edit (${s.pathParameters['id'] ?? '?'})',
            buildsIn: '6.6',
            purpose:
                'As above. The redirect target picker excludes any choice that '
                'would create a cycle, computed live.',
            journeyStep: 'US-004 to US-007',
          ),
        ),
        GoRoute(
          path: Routes.categoryDetail,
          builder: (BuildContext c, GoRouterState s) => StubScreen(
            title: 'Category Detail (${s.pathParameters['id'] ?? '?'})',
            buildsIn: '6.6',
            purpose:
                'Balance, ceiling progress, redirect destination and recent '
                'entries.',
            journeyStep: 'J1-C step 22',
            actions: <StubAction>[
              StubAction(
                label: 'Edit  →  /categories/sample/edit',
                onPressed: () => c.push(Routes.categoryEditFor('sample')),
              ),
            ],
          ),
        ),
        GoRoute(
          path: Routes.accountList,
          builder: (BuildContext c, GoRouterState s) => StubScreen(
            title: 'Account List',
            buildsIn: '6.7',
            purpose:
                'Accounts with derived totals. Labels only — no bank '
                'connectivity is implied anywhere.',
            journeyStep: 'US-011',
            actions: <StubAction>[
              StubAction(
                label: 'New account  →  /accounts/new',
                onPressed: () => c.push(Routes.accountNew),
              ),
              StubAction(
                label: 'Edit account  →  /accounts/sample/edit',
                onPressed: () => c.push(Routes.accountEditFor('sample')),
              ),
            ],
          ),
        ),
        GoRoute(
          path: Routes.accountNew,
          builder: (BuildContext c, GoRouterState s) => const StubScreen(
            title: 'Account Edit (new)',
            buildsIn: '6.7',
            purpose: 'Name, institution, last four digits, scope.',
            journeyStep: 'US-011, US-012',
          ),
        ),
        GoRoute(
          path: Routes.accountEdit,
          builder: (BuildContext c, GoRouterState s) => StubScreen(
            title: 'Account Edit (${s.pathParameters['id'] ?? '?'})',
            buildsIn: '6.7',
            purpose:
                'As above. Deleting an account with linked categories requires '
                'explicit reassignment.',
            journeyStep: 'US-011',
          ),
        ),
        GoRoute(
          path: Routes.reports,
          builder: (BuildContext c, GoRouterState s) => const StubScreen(
            title: 'Reports',
            buildsIn: '8.2',
            purpose:
                'Monthly and yearly summaries, ceiling progress, trends and '
                'CSV export.',
            journeyStep: 'US-033 to US-037',
          ),
        ),
        GoRoute(
          path: Routes.settings,
          builder: (BuildContext c, GoRouterState s) => StubScreen(
            title: 'Settings',
            buildsIn: '6.1',
            purpose:
                'Scope, currency, categories, accounts, sync, backup, about.',
            journeyStep: 'US-002, US-032',
            actions: <StubAction>[
              StubAction(
                label: 'Categories  →  /categories',
                onPressed: () => c.push(Routes.categoryList),
              ),
              StubAction(
                label: 'Accounts  →  /accounts',
                onPressed: () => c.push(Routes.accountList),
              ),
              StubAction(
                label: 'Sync & account  →  /settings/sync',
                onPressed: () => c.push(Routes.syncAccount),
              ),
              StubAction(
                label: 'Diagnostics  →  /settings/diagnostics',
                onPressed: () => c.push(Routes.diagnostics),
              ),
            ],
          ),
        ),
        GoRoute(
          path: Routes.syncAccount,
          builder: (BuildContext c, GoRouterState s) => const StubScreen(
            title: 'Sync & Account',
            buildsIn: '7.9',
            purpose:
                'Sign-in state, last sync, pending count, the repair log, and '
                'controls. Never blocks the app.',
            journeyStep: 'US-028 to US-031, FJ-2',
          ),
        ),
        GoRoute(
          path: Routes.diagnostics,
          builder: (BuildContext c, GoRouterState s) => const StubScreen(
            title: 'Diagnostics',
            buildsIn: '7.9',
            purpose:
                'Recompute-and-compare, the repair log, and export. The one '
                'screen with no PRD journey — declared in NAVIGATION §1.4.',
          ),
        ),

        // ---------------------------------------------------------------
        // Developer menu — REMOVED IN SUBSTAGE 10.2.7
        // ---------------------------------------------------------------
        GoRoute(
          path: Routes.devMenu,
          builder: (BuildContext c, GoRouterState s) => const DevMenuScreen(),
        ),
      ],
      errorBuilder: (BuildContext c, GoRouterState s) => Scaffold(
        appBar: AppBar(title: const Text('Route not found')),
        body: Center(child: Text('No route for ${s.uri}')),
      ),
    );
  }
}
