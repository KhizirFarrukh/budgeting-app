import 'package:flutter/material.dart';
import 'package:pookiebudget/presentation/theme/tokens.dart';

/// Shared empty / loading / error views, built in substage 3.6.4 with **no
/// logic in them** — they display what they are given and nothing more.
///
/// Every one of the 22 screens needs all three states (NAVIGATION.md §7), and
/// substage 6.11.1 walks the inventory ticking each one off. Building them once
/// here means Stage 6 fills in copy rather than inventing components, and Stage
/// 10 has nothing to retrofit.

/// Shown when a screen has nothing to display *and that is a normal situation*.
///
/// [action] matters: NAVIGATION §7 requires the dashboard's empty state to
/// offer "exactly one obvious next action", and every other empty state to name
/// what would appear here.
class EmptyStateView extends StatelessWidget {
  const EmptyStateView({
    required this.title,
    required this.message,
    this.icon,
    this.action,
    super.key,
  });

  final String title;
  final String message;
  final IconData? icon;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(Spacing.lg),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            if (icon != null) ...<Widget>[
              Icon(icon, size: Spacing.xxl, color: theme.colorScheme.outline),
              const SizedBox(height: Spacing.md),
            ],
            Text(
              title,
              style: theme.textTheme.titleMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: Spacing.sm),
            Text(
              message,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
            if (action != null) ...<Widget>[
              const SizedBox(height: Spacing.lg),
              action!,
            ],
          ],
        ),
      ),
    );
  }
}

/// Shown while data is being derived.
///
/// Deliberately **not** a full-screen blocking spinner. Substage 10.2.3:
/// "skeletons or inline indicators rather than full-screen blocking spinners",
/// and INV-06 forbids blocking the UI on anything at all.
class LoadingStateView extends StatelessWidget {
  const LoadingStateView({this.message, super.key});

  final String? message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(Spacing.lg),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            const SizedBox(
              width: Spacing.xl,
              height: Spacing.xl,
              child: CircularProgressIndicator(strokeWidth: 3),
            ),
            if (message != null) ...<Widget>[
              const SizedBox(height: Spacing.md),
              Text(message!, style: Theme.of(context).textTheme.bodyMedium),
            ],
          ],
        ),
      ),
    );
  }
}

/// Shown when something failed.
///
/// [message] must be plain language with an actionable cause, and [onRetry]
/// gives a route forward — substage 10.2.2: *"No stack traces. No bare error
/// codes. No provider jargon. Every message should tell the user what to do
/// next, not only what went wrong."*
///
/// [isStale] covers the dashboard case NAVIGATION §7.1 singles out: when
/// balance derivation fails, showing blank or zero reads as *"your money is
/// gone"*, so the last known figures are shown **clearly marked stale** instead.
class ErrorStateView extends StatelessWidget {
  const ErrorStateView({
    required this.title,
    required this.message,
    this.onRetry,
    this.retryLabel = 'Try again',
    this.isStale = false,
    super.key,
  });

  final String title;
  final String message;
  final VoidCallback? onRetry;
  final String retryLabel;
  final bool isStale;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(Spacing.lg),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            Icon(
              isStale ? Icons.history_toggle_off : Icons.error_outline,
              size: Spacing.xxl,
              color: theme.colorScheme.error,
            ),
            const SizedBox(height: Spacing.md),
            Text(
              title,
              style: theme.textTheme.titleMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: Spacing.sm),
            Text(
              message,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
            if (onRetry != null) ...<Widget>[
              const SizedBox(height: Spacing.lg),
              FilledButton(onPressed: onRetry, child: Text(retryLabel)),
            ],
          ],
        ),
      ),
    );
  }
}

/// Progress toward a ceiling.
///
/// Two rules from the design are enforced here rather than left to callers:
///
/// - **Never shows 100% before a category is genuinely full.** Substage 8.3.1
///   requires the percentage be computed from integers and 8.3's `must_not`
///   forbids rounding up to 100. `999/1000` displays as 99%, not 100%.
/// - **Renders over-ceiling without clipping.** A balance can exceed its
///   ceiling after a manual override (ALLOCATION_ALGORITHM §4.5), and substage
///   8.3.5 requires that not to break the indicator.
///
/// Progress is never conveyed by colour alone (NFR-08): the numeric label is
/// always present.
class CeilingProgressBar extends StatelessWidget {
  const CeilingProgressBar({
    required this.balanceMinor,
    required this.ceilingMinor,
    this.semanticLabel,
    super.key,
  });

  final int balanceMinor;
  final int ceilingMinor;
  final String? semanticLabel;

  /// Integer percentage, floored, capped at 100 for the *bar* but not for the
  /// label. Floored so 99.9% never reads as complete.
  int get percent {
    if (ceilingMinor <= 0) return 0;
    if (balanceMinor <= 0) return 0;
    return (balanceMinor * 100) ~/ ceilingMinor;
  }

  bool get isOverCeiling => ceilingMinor > 0 && balanceMinor > ceilingMinor;

  bool get isFull => ceilingMinor > 0 && balanceMinor >= ceilingMinor;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final int p = percent;
    // The bar itself saturates; the label tells the truth.
    final double fraction = p >= 100 ? 1.0 : p / 100.0;

    return Semantics(
      label: semanticLabel,
      value: '$p percent',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          ClipRRect(
            borderRadius: BorderRadius.circular(Radii.sm),
            child: LinearProgressIndicator(
              value: fraction,
              minHeight: Spacing.sm,
              backgroundColor: theme.colorScheme.surfaceContainerHighest,
            ),
          ),
          const SizedBox(height: Spacing.xs),
          Text(
            isOverCeiling ? '$p% (over target)' : '$p%',
            style: theme.textTheme.labelSmall,
          ),
        ],
      ),
    );
  }
}
