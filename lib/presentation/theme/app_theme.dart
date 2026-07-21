import 'package:flutter/material.dart';
import 'package:pookiebudget/presentation/theme/business_scope_theme.dart';
import 'package:pookiebudget/presentation/theme/tokens.dart';

/// Light and dark themes, built from the tokens in `tokens.dart`.
///
/// Substage 3.6: defining this once now is far cheaper than restyling twenty
/// finished screens in Stage 10, and 10.1.3 re-checks that no literal escaped.
class AppTheme {
  const AppTheme._();

  static ThemeData light() => _build(Brightness.light);

  static ThemeData dark() => _build(Brightness.dark);

  static ThemeData _build(Brightness brightness) {
    final ColorScheme scheme = ColorScheme.fromSeed(
      seedColor: Palette.seed,
      brightness: brightness,
    );
    final bool isDark = brightness == Brightness.dark;

    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      extensions: <ThemeExtension<dynamic>>[
        isDark
            ? BusinessScopeTheme.dark(scheme)
            : BusinessScopeTheme.light(scheme),
        isDark ? const MoneyStateTheme.dark() : const MoneyStateTheme.light(),
      ],
      appBarTheme: AppBarTheme(
        centerTitle: false,
        backgroundColor: scheme.surface,
        foregroundColor: scheme.onSurface,
        elevation: 0,
        scrolledUnderElevation: 1,
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        margin: const EdgeInsets.symmetric(
          horizontal: Spacing.md,
          vertical: Spacing.sm,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(Radii.md),
        ),
      ),
      listTileTheme: const ListTileThemeData(
        contentPadding: EdgeInsets.symmetric(
          horizontal: Spacing.md,
          vertical: Spacing.xs,
        ),
        minVerticalPadding: Spacing.sm,
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          // NFR-08: every interactive target is at least 48dp.
          minimumSize: const Size(
            Spacing.minTouchTarget * 2,
            Spacing.minTouchTarget,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(Radii.sm),
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          minimumSize: const Size(
            Spacing.minTouchTarget,
            Spacing.minTouchTarget,
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(Radii.sm),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: Spacing.md,
          vertical: Spacing.md,
        ),
      ),
      textTheme: const TextTheme(
        displaySmall: TextStyle(fontSize: TypeScale.displaySm),
        headlineSmall: TextStyle(fontSize: TypeScale.headline),
        titleMedium: TextStyle(fontSize: TypeScale.title),
        bodyLarge: TextStyle(fontSize: TypeScale.body),
        bodyMedium: TextStyle(fontSize: TypeScale.body),
        labelLarge: TextStyle(fontSize: TypeScale.label),
        labelSmall: TextStyle(fontSize: TypeScale.caption),
      ),
    );
  }
}
