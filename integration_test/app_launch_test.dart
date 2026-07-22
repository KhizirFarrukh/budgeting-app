import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:pookiebudget/app.dart';

/// Substage 3.8.7: *"Configure integration_test and verify with one trivial
/// app-launch test on a device or emulator."*
///
/// Proving the integration harness works **now** matters because Stage 6
/// substage 6.12 runs every core flow through it — including the offline run
/// that is the sole evidence for NFR-02 — and Stage 9 automates the full
/// journeys. A misconfigured harness discovered then would block the evidence,
/// not just the tests.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('the app launches and renders its own first screen', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const PookieBudgetApp());
    await tester.pumpAndSettle();

    // Lands on the dashboard route, showing a stub that says what it is.
    expect(find.text('Dashboard'), findsOneWidget);
    expect(find.text('Placeholder — not implemented'), findsOneWidget);

    // Nothing here should resemble working functionality (substage 3.7.2).
    expect(tester.takeException(), isNull);
  });
}
