import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Substage 4.4's first acceptance criterion, checked mechanically:
/// *"No repository method signature exposes a database or generated type."*
///
/// ## Why this is a test and not a review note
///
/// The criterion is what lets Stage 5 and Stage 6 be tested with no database at
/// all (ARCHITECTURE §2.2). It is also the easiest thing in the project to lose
/// by accident — one convenient `CategoriesCompanion` parameter added under
/// deadline, and every use case that touches it needs a database to be tested.
/// Guard G1 already bans the *imports* that would make that possible; this
/// closes the remaining gap by checking the text of the interfaces themselves,
/// so a type reaching them through some future re-export is caught too.
///
/// Comments are stripped before matching, for the reason `tool/guards/guards.dart`
/// records at length: a guard that fires on prose describing the rule is a guard
/// somebody switches off.
void main() {
  const String interfaceDirectory = 'lib/domain/repositories';

  /// Persistence vocabulary that must not appear in a domain interface.
  ///
  /// Each entry is a type the database layer generates or owns. `Row` alone is
  /// deliberately absent — it is a real English word that appears in prose and
  /// would make this guard noisy — so the generated row classes are listed by
  /// their actual names instead.
  const List<String> bannedTokens = <String>[
    'PookieDatabase',
    'Companion',
    'TableInfo',
    'GeneratedColumn',
    'SimpleSelectStatement',
    'QueryRow',
    'Insertable',
    'CategoryRow',
    'CategoryGroupRow',
    'AccountRow',
    'DistributionRuleVersionRow',
    'RuleLineRow',
    'RedirectTargetRow',
    'AppSettingsRow',
  ];

  const List<String> bannedImports = <String>[
    'package:drift',
    'package:sqlite3',
    'pookiebudget/data/',
  ];

  List<File> interfaceFiles() {
    final Directory dir = Directory(interfaceDirectory);
    expect(
      dir.existsSync(),
      isTrue,
      reason: '$interfaceDirectory must exist — it holds the domain contracts',
    );
    return dir
        .listSync()
        .whereType<File>()
        .where((File f) => f.path.endsWith('.dart'))
        .toList();
  }

  /// Removes `//` and `///` comments, and `/* */` blocks.
  ///
  /// String literals are left intact, because an import path *is* a string
  /// literal — the exact mistake substage 3.4.6 caught in G1 and G5, where
  /// stripping strings turned every import into `import ;` and both guards
  /// silently checked nothing.
  String stripComments(String source) {
    final String withoutBlocks = source.replaceAll(
      RegExp(r'/\*.*?\*/', dotAll: true),
      '',
    );
    return withoutBlocks
        .split('\n')
        .map((String line) {
          final int marker = line.indexOf('//');
          return marker == -1 ? line : line.substring(0, marker);
        })
        .join('\n');
  }

  test('the repository interfaces exist and are all covered', () {
    final Set<String> names = interfaceFiles()
        .map((File f) => f.uri.pathSegments.last)
        .toSet();
    expect(names, containsAll(<String>[
      'category_repository.dart',
      'account_repository.dart',
      'rule_repository.dart',
      'settings_repository.dart',
      'repository_failure.dart',
      'repository_queries.dart',
    ]));
  });

  test('NO DOMAIN INTERFACE NAMES A PERSISTENCE TYPE', () {
    final List<String> violations = <String>[];

    for (final File file in interfaceFiles()) {
      final String code = stripComments(file.readAsStringSync());
      for (final String token in bannedTokens) {
        if (code.contains(token)) {
          violations.add('${file.path}: names "$token"');
        }
      }
    }

    expect(
      violations,
      isEmpty,
      reason:
          'A domain repository interface must be expressible without the '
          'database. Anything named here has leaked persistence into the '
          'contract, and every use case that touches it now needs a database '
          'to be tested.\n${violations.join("\n")}',
    );
  });

  test('no domain interface imports the database layer', () {
    final List<String> violations = <String>[];

    for (final File file in interfaceFiles()) {
      for (final String line in stripComments(
        file.readAsStringSync(),
      ).split('\n')) {
        final String trimmed = line.trim();
        if (!trimmed.startsWith('import ') &&
            !trimmed.startsWith('export ')) {
          continue;
        }
        for (final String banned in bannedImports) {
          if (trimmed.contains(banned)) {
            violations.add('${file.path}: $trimmed');
          }
        }
      }
    }

    expect(violations, isEmpty, reason: violations.join('\n'));
  });

  test('the check itself detects a violation', () {
    // A guard that has never failed has never been tested — substage 3.4.6's
    // rule, applied to a test rather than a script. Without this, a typo in
    // `bannedTokens` would leave every assertion above passing vacuously.
    const String offending = '''
import 'package:drift/drift.dart';
abstract interface class Leaky {
  Future<void> save(CategoriesCompanion row);
}
''';
    final String code = stripComments(offending);
    expect(
      bannedTokens.any(code.contains),
      isTrue,
      reason: 'the token list must catch a companion in a signature',
    );
    expect(
      bannedImports.any(code.contains),
      isTrue,
      reason: 'the import list must catch the database package',
    );

    // And prose describing the rule must NOT trip it.
    const String innocent = '''
/// No Companion type and no PookieDatabase handle crosses this boundary.
abstract interface class Clean {}
''';
    expect(bannedTokens.any(stripComments(innocent).contains), isFalse);
  });
}
