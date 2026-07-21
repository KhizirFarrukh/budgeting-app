import 'package:flutter/material.dart';

import 'app.dart';

/// Entry point.
///
/// This is the composition root and nothing else: it wires dependencies and
/// hands off to [PookieBudgetApp]. No business logic, no I/O, no widgets are
/// defined here (ARCHITECTURE.md §4.2).
void main() {
  runApp(const PookieBudgetApp());
}
