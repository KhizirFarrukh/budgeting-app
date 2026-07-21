import 'package:flutter/material.dart';
import 'package:pookiebudget/presentation/theme/tokens.dart';

/// A placeholder screen that **visibly identifies itself as a placeholder**.
///
/// Substage 3.7.2 requires exactly this, and the stage's anti-pattern list is
/// blunt about why:
///
/// > *"Stub screens with plausible dummy numbers that get demoed as progress."*
///
/// So this widget shows **no money, no categories, no data of any kind**. It
/// names the screen, states which substage will build it, and lists what it
/// will do — nothing that could be screenshotted and mistaken for a working
/// feature.
class StubScreen extends StatelessWidget {
  const StubScreen({
    required this.title,
    required this.buildsIn,
    required this.purpose,
    this.journeyStep,
    this.actions = const <StubAction>[],
    super.key,
  });

  /// The screen name from `docs/NAVIGATION.md` §1.
  final String title;

  /// The substage that replaces this stub, e.g. `'6.4'`.
  final String buildsIn;

  /// One line on what the screen is for, from the design.
  final String purpose;

  /// The PRD journey step this screen serves, where it has one.
  final String? journeyStep;

  /// Onward navigation, so every route is reachable by tapping (substage
  /// 3.7.6's manual walk) rather than only by typing a URL.
  final List<StubAction> actions;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: ListView(
        padding: const EdgeInsets.all(Spacing.md),
        children: <Widget>[
          Card(
            color: theme.colorScheme.surfaceContainerHighest,
            child: Padding(
              padding: const EdgeInsets.all(Spacing.md),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Row(
                    children: <Widget>[
                      Icon(
                        Icons.construction_outlined,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                      const SizedBox(width: Spacing.sm),
                      Expanded(
                        child: Text(
                          'Placeholder — not implemented',
                          style: theme.textTheme.titleMedium,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: Spacing.sm),
                  Text(
                    'Built in substage $buildsIn.',
                    style: theme.textTheme.bodyMedium,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: Spacing.md),
          Text('Purpose', style: theme.textTheme.labelLarge),
          const SizedBox(height: Spacing.xs),
          Text(purpose, style: theme.textTheme.bodyMedium),
          if (journeyStep != null) ...<Widget>[
            const SizedBox(height: Spacing.md),
            Text('Journey step', style: theme.textTheme.labelLarge),
            const SizedBox(height: Spacing.xs),
            Text(journeyStep!, style: theme.textTheme.bodyMedium),
          ],
          if (actions.isNotEmpty) ...<Widget>[
            const SizedBox(height: Spacing.lg),
            Text('Goes to', style: theme.textTheme.labelLarge),
            const SizedBox(height: Spacing.xs),
            ...actions.map(
              (StubAction a) => Padding(
                padding: const EdgeInsets.only(bottom: Spacing.sm),
                child: OutlinedButton(
                  onPressed: a.onPressed,
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Text(a.label),
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// A labelled navigation action offered by a [StubScreen].
class StubAction {
  const StubAction({required this.label, required this.onPressed});

  final String label;
  final VoidCallback onPressed;
}
