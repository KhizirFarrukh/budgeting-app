import 'package:flutter/material.dart';

/// Design tokens — the **only** place colour, spacing and typography literals
/// may appear.
///
/// Substage 3.6's acceptance criterion: *"No colour, spacing or font literal
/// appears outside the theme definition."* Re-checked at 10.1.3 with a search.
///
/// Doing this once now is far cheaper than restyling twenty finished screens in
/// Stage 10.
class Spacing {
  const Spacing._();

  static const double xs = 4;
  static const double sm = 8;
  static const double md = 16;
  static const double lg = 24;
  static const double xl = 32;
  static const double xxl = 48;

  /// Minimum interactive target. NFR-08 requires at least 48dp, **including**
  /// the inline per-category edit controls in the allocation preview, which are
  /// the most likely to be undersized (substage 9.5.3).
  static const double minTouchTarget = 48;
}

class Radii {
  const Radii._();

  static const double sm = 4;
  static const double md = 8;
  static const double lg = 16;
}

/// Seed colours. Material 3 derives the full scheme from these, which keeps the
/// palette internally consistent and contrast-safe by construction.
class Palette {
  const Palette._();

  /// Calm, non-alarming primary. A finance app should not feel urgent.
  static const Color seed = Color(0xFF3D5A80);

  /// Business scope accent. Deliberately distinct in **hue and lightness**, not
  /// hue alone — see [BusinessScopeTheme].
  static const Color businessSeed = Color(0xFF6A4C93);

  /// A balance below zero. OQ-06 allows overspending with a prominent warning
  /// (PRD A-04), so this needs to read clearly without being alarming.
  static const Color negativeLight = Color(0xFFB3261E);
  static const Color negativeDark = Color(0xFFF2B8B5);

  /// A category that has reached its ceiling. This is a **success** state, not
  /// a warning — PRD §4.3: "being at ceiling is a success state".
  static const Color fullLight = Color(0xFF2E7D32);
  static const Color fullDark = Color(0xFFA5D6A7);
}

class TypeScale {
  const TypeScale._();

  static const double displaySm = 28;
  static const double headline = 22;
  static const double title = 18;
  static const double body = 16;
  static const double label = 14;
  static const double caption = 12;

  /// Money is read, compared and trusted, so it gets tabular figures and a
  /// slightly heavier weight wherever it appears.
  static const FontWeight moneyWeight = FontWeight.w600;
}
