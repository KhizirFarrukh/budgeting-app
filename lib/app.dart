import 'package:flutter/material.dart';

/// The application shell.
///
/// Substage 3.1 stands this up only far enough to prove the project builds and
/// launches to a screen of its own rather than generated boilerplate. Theming
/// arrives in substage 3.6 and the router with its 22 stub screens in 3.7; both
/// replace what is here.
class PookieBudgetApp extends StatelessWidget {
  const PookieBudgetApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'PookieBudget',
      debugShowCheckedModeBanner: false,
      home: const _ScaffoldPlaceholder(),
    );
  }
}

/// Deliberately identifies itself as unfinished.
///
/// Substage 3.7's `must_not` forbids anything that could be mistaken for
/// working functionality, and the anti-pattern list warns against stubs with
/// plausible figures being screenshotted as progress. This screen shows no
/// money, no categories and no data of any kind.
class _ScaffoldPlaceholder extends StatelessWidget {
  const _ScaffoldPlaceholder();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('PookieBudget')),
      body: const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              Text(
                'Scaffold placeholder',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 12),
              Text(
                'Stage 3 substage 3.1. No features are implemented.\n'
                'The router and screens arrive in substage 3.7.',
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
