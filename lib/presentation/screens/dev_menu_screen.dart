import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:pookiebudget/presentation/router/routes.dart';
import 'package:pookiebudget/presentation/theme/tokens.dart';

/// Temporary developer route menu — **every route reachable in one tap**.
///
/// Added by substage 3.7.5 so a reviewer can walk the whole graph without
/// typing URLs, and so substage 3.7.6's manual walk is practical.
///
/// ## THIS IS REMOVED IN SUBSTAGE 10.2.7
///
/// It is on the Stage 10 checklist **now**, at the moment of creation, rather
/// than trusted to memory — substage 3.7's `common_pitfalls`:
///
/// > *"A developer menu that survives to release because nobody wrote it down."*
///
/// Substage 10.2.7 removes it and verifies removal **by inspecting the built
/// artefact**, not only the source, because a menu removed from navigation but
/// still reachable by route name is not removed (10.2's `must_not`: *"Do not
/// leave a debug entry point behind a hidden gesture."*).
class DevMenuScreen extends StatelessWidget {
  const DevMenuScreen({super.key});

  static const List<({String label, String path, String stage})>
  _routes = <({String label, String path, String stage})>[
    (label: 'Dashboard', path: Routes.dashboard, stage: '6.8'),
    (label: 'Add Income', path: Routes.addIncome, stage: '6.4'),
    (label: 'Allocation Preview', path: Routes.allocationPreview, stage: '6.4'),
    (label: 'Adjust Split', path: Routes.adjustSplit, stage: '6.5'),
    (label: 'Income Confirmed', path: Routes.incomeConfirmed, stage: '6.5'),
    (label: 'Add Spending', path: Routes.addSpending, stage: '6.9'),
    (
      label: 'Transaction History',
      path: Routes.transactionHistory,
      stage: '6.9',
    ),
    (label: 'Welcome', path: Routes.welcome, stage: '6.2'),
    (label: 'Currency Confirmation', path: Routes.currency, stage: '6.2'),
    (label: 'Scope Selection', path: Routes.scope, stage: '6.2'),
    (label: 'Top-Level Split', path: Routes.topLevelSplit, stage: '6.2'),
    (
      label: 'Category Selection',
      path: '/onboarding/categories/savings',
      stage: '6.3',
    ),
    (
      label: 'Category Percentages',
      path: Routes.categoryPercentages,
      stage: '6.3',
    ),
    (label: 'Ceilings Setup', path: Routes.ceilingsSetup, stage: '6.3'),
    (label: 'Accounts Setup', path: Routes.accountsSetup, stage: '6.3'),
    (label: 'Setup Summary', path: Routes.setupSummary, stage: '6.3'),
    (label: 'Restore From Cloud', path: Routes.restoreFromCloud, stage: '7.8'),
    (label: 'Category List', path: Routes.categoryList, stage: '6.6'),
    (label: 'Category Edit (new)', path: Routes.categoryNew, stage: '6.6'),
    (label: 'Category Edit', path: '/categories/sample/edit', stage: '6.6'),
    (label: 'Category Detail', path: '/categories/sample', stage: '6.6'),
    (label: 'Account List', path: Routes.accountList, stage: '6.7'),
    (label: 'Account Edit (new)', path: Routes.accountNew, stage: '6.7'),
    (label: 'Account Edit', path: '/accounts/sample/edit', stage: '6.7'),
    (label: 'Reports', path: Routes.reports, stage: '8.2'),
    (label: 'Settings', path: Routes.settings, stage: '6.1'),
    (label: 'Sync & Account', path: Routes.syncAccount, stage: '7.9'),
    (label: 'Diagnostics', path: Routes.diagnostics, stage: '7.9'),
  ];

  /// Every route, for the substage 3.7.6 walk and the 3.9.1 comparison table.
  static List<String> get allPaths => _routes
      .map((({String label, String path, String stage}) r) => r.path)
      .toList();

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Developer route menu')),
      body: ListView(
        children: <Widget>[
          Container(
            width: double.infinity,
            color: theme.colorScheme.errorContainer,
            padding: const EdgeInsets.all(Spacing.md),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  'Removed in substage 10.2.7',
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: theme.colorScheme.onErrorContainer,
                  ),
                ),
                const SizedBox(height: Spacing.xs),
                Text(
                  'This menu exists only so every route can be reached during '
                  'Stage 3 verification. It must not ship.',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onErrorContainer,
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(Spacing.md),
            child: Text(
              '${_routes.length} routes',
              style: theme.textTheme.labelLarge,
            ),
          ),
          ..._routes.map(
            (({String label, String path, String stage}) r) => ListTile(
              title: Text(r.label),
              subtitle: Text('${r.path}   ·   builds in ${r.stage}'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => context.push(r.path),
            ),
          ),
        ],
      ),
    );
  }
}
