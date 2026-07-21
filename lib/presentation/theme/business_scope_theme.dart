import 'package:flutter/material.dart';
import 'package:pookiebudget/presentation/theme/tokens.dart';

/// The visual treatment that distinguishes business money from household money.
///
/// Delivered as a `ThemeExtension` rather than scattered colour literals
/// (substage 3.6.2), so the distinction is defined once and consumed everywhere.
///
/// **Meaning must not depend on colour alone** (NFR-08, substage 3.6.2): the
/// treatment must survive greyscale, and a user with a colour vision deficiency
/// must still be able to tell business from personal. Colour is therefore
/// paired with an [icon] and a [label], and consumers are expected to use all
/// three.
///
/// NFR-03's binary condition is what this exists for: business figures must
/// never appear in personal totals, and any combined figure must say so.
@immutable
class BusinessScopeTheme extends ThemeExtension<BusinessScopeTheme> {
  const BusinessScopeTheme({
    required this.accent,
    required this.onAccent,
    required this.container,
    required this.icon,
    required this.label,
  });

  factory BusinessScopeTheme.light(ColorScheme scheme) {
    final ColorScheme business = ColorScheme.fromSeed(
      seedColor: Palette.businessSeed,
    );
    return BusinessScopeTheme(
      accent: business.primary,
      onAccent: business.onPrimary,
      container: business.primaryContainer,
      icon: Icons.storefront_outlined,
      label: 'Business',
    );
  }

  factory BusinessScopeTheme.dark(ColorScheme scheme) {
    final ColorScheme business = ColorScheme.fromSeed(
      seedColor: Palette.businessSeed,
      brightness: Brightness.dark,
    );
    return BusinessScopeTheme(
      accent: business.primary,
      onAccent: business.onPrimary,
      container: business.primaryContainer,
      icon: Icons.storefront_outlined,
      label: 'Business',
    );
  }

  final Color accent;
  final Color onAccent;
  final Color container;

  /// Carries the distinction when colour cannot — greyscale, colour vision
  /// deficiency, or a screenshot printed in black and white.
  final IconData icon;

  /// The word itself. The strongest non-colour signal available, and the one a
  /// screen reader conveys.
  final String label;

  @override
  BusinessScopeTheme copyWith({
    Color? accent,
    Color? onAccent,
    Color? container,
    IconData? icon,
    String? label,
  }) {
    return BusinessScopeTheme(
      accent: accent ?? this.accent,
      onAccent: onAccent ?? this.onAccent,
      container: container ?? this.container,
      icon: icon ?? this.icon,
      label: label ?? this.label,
    );
  }

  @override
  BusinessScopeTheme lerp(ThemeExtension<BusinessScopeTheme>? other, double t) {
    if (other is! BusinessScopeTheme) return this;
    return BusinessScopeTheme(
      accent: Color.lerp(accent, other.accent, t) ?? accent,
      onAccent: Color.lerp(onAccent, other.onAccent, t) ?? onAccent,
      container: Color.lerp(container, other.container, t) ?? container,
      icon: t < 0.5 ? icon : other.icon,
      label: t < 0.5 ? label : other.label,
    );
  }
}

/// Colours for money states that mean something specific.
@immutable
class MoneyStateTheme extends ThemeExtension<MoneyStateTheme> {
  const MoneyStateTheme({required this.negative, required this.atCeiling});

  const MoneyStateTheme.light()
    : negative = Palette.negativeLight,
      atCeiling = Palette.fullLight;

  const MoneyStateTheme.dark()
    : negative = Palette.negativeDark,
      atCeiling = Palette.fullDark;

  /// A balance below zero (OQ-06 permits this, with a prominent warning).
  final Color negative;

  /// A category that has reached its ceiling — a **success** state, not a
  /// warning (PRD §4.3).
  final Color atCeiling;

  @override
  MoneyStateTheme copyWith({Color? negative, Color? atCeiling}) =>
      MoneyStateTheme(
        negative: negative ?? this.negative,
        atCeiling: atCeiling ?? this.atCeiling,
      );

  @override
  MoneyStateTheme lerp(ThemeExtension<MoneyStateTheme>? other, double t) {
    if (other is! MoneyStateTheme) return this;
    return MoneyStateTheme(
      negative: Color.lerp(negative, other.negative, t) ?? negative,
      atCeiling: Color.lerp(atCeiling, other.atCeiling, t) ?? atCeiling,
    );
  }
}
