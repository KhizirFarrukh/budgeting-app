import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:pookiebudget/presentation/router/router.dart';
import 'package:pookiebudget/presentation/theme/app_theme.dart';

/// The application shell.
///
/// Substage 3.6 wired the themes; substage 3.7 attaches the router and its 22
/// stub screens. Stage 6 replaces the stubs — the graph itself stays.
class PookieBudgetApp extends StatefulWidget {
  const PookieBudgetApp({super.key});

  @override
  State<PookieBudgetApp> createState() => _PookieBudgetAppState();
}

class _PookieBudgetAppState extends State<PookieBudgetApp> {
  /// Built once, in [initState], rather than on every rebuild — a router
  /// rebuilt mid-frame loses its navigation stack.
  ///
  /// Stage 6 substage 6.1 moves this into a Riverpod provider, once there is a
  /// state layer for it to live in.
  late final GoRouter _router = AppRouter.build();

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'PookieBudget',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      // Follows the system setting. A finance app that fights the user's own
      // display preference is one they read in the dark at 11pm.
      themeMode: ThemeMode.system,
      routerConfig: _router,
    );
  }
}
