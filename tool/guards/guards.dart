// Invariant guards G1–G6, specified in docs/ARCHITECTURE.md §2.3.
//
// These are what make INV-01 and INV-08 real for the next seven stages. An
// invariant that nothing checks is an intention.
//
// Run:  dart run tool/guards/guards.dart
// Exit: 0 = all pass, 1 = at least one violation.
//
// WHY THIS IS A DART SCRIPT AND NOT A GREP
// ----------------------------------------
// Substage 3.2 pre-checked the guard conditions with plain grep and G4 fired on
// a *documentation comment* in clock.dart that legitimately names
// `DateTime.now()`. That is precisely the pitfall substage 3.4 warns about:
//
//   "A grep-based guard with a pattern so loose it fires on comments, which
//    then gets disabled."
//
// A guard that cries wolf is a guard someone switches off, so every check below
// strips comments before matching.
//
// String literals are stripped only for the TOKEN guards (G2, G3, G4), so a
// banned word inside a message cannot fire. The IMPORT guards (G1, G5) must
// keep strings intact, because an import path is itself a string literal.
//
// That distinction is not theoretical. In the first run of substage 3.4.6's
// demonstration, G1 and G5 stripped strings too, turning every
// `import 'package:flutter/x.dart';` into `import ;`. Both guards passed their
// baseline and detected nothing whatsoever. They were caught only because 3.4.6
// requires each guard to be shown FAILING on a deliberate violation rather than
// accepting that it looks correct.

import 'dart:io';

void main(List<String> args) {
  final List<_Violation> violations = <_Violation>[
    ..._g1LayeringDomainImports(),
    ..._g2EnginePurity(),
    ..._g3MoneyType(),
    ..._g4Clock(),
    ..._g5DatabaseContainment(),
    ..._g6Telemetry(),
  ];

  if (violations.isEmpty) {
    stdout.writeln('All guards passed (G1-G6).');
    exit(0);
  }

  stderr.writeln('GUARD FAILURES: ${violations.length}\n');
  for (final _Violation v in violations) {
    stderr.writeln('${v.guard}  ${v.file}:${v.line}');
    stderr.writeln('    ${v.message}');
    stderr.writeln('    > ${v.source.trim()}\n');
  }
  exit(1);
}

// ---------------------------------------------------------------------------
// G1 — the domain layer imports nothing outward
// ---------------------------------------------------------------------------
List<_Violation> _g1LayeringDomainImports() {
  const List<String> forbidden = <String>[
    'package:flutter/',
    'dart:io',
    'dart:ui',
    'package:drift/',
    'package:riverpod',
    'package:flutter_riverpod',
    'package:googleapis',
    'package:google_sign_in',
    'package:http',
    '/data/',
    '/application/',
    '/presentation/',
  ];
  return _scan(
    guard: 'G1',
    root: 'lib/domain',
    message:
        'domain must not import Flutter, dart:io, dart:ui, any I/O package '
        'or any outer layer (ARCHITECTURE §2.1)',
    // An import path IS a string literal, so string stripping must be off here
    // or every import becomes `import ;` and this guard checks nothing.
    stripStrings: false,
    test: (String line) {
      if (!_isImport(line)) return false;
      return forbidden.any(line.contains);
    },
  );
}

// ---------------------------------------------------------------------------
// G2 — the allocation engine is a synchronous pure function
// ---------------------------------------------------------------------------
List<_Violation> _g2EnginePurity() {
  final RegExp async = RegExp(r'\b(async|await|Future|Stream)\b');
  final RegExp now = RegExp(r'DateTime\s*\.\s*now\s*\(');
  final RegExp random = RegExp(r'\bRandom\s*\(');
  return _scan(
    guard: 'G2',
    root: 'lib/domain/allocation',
    message:
        'the engine must be synchronous, clock-free and deterministic: no '
        'async/await/Future/Stream, no DateTime.now(), no Random (INV-08, '
        'ALLOCATION_ALGORITHM §2.5 rules P-1..P-5)',
    test: (String line) =>
        async.hasMatch(line) || now.hasMatch(line) || random.hasMatch(line),
  );
}

// ---------------------------------------------------------------------------
// G3 — no floating point on the money path
// ---------------------------------------------------------------------------
List<_Violation> _g3MoneyType() {
  // Word-boundary matched so `numberOfThings` and `doubleCheck` do not fire.
  final RegExp floaty = RegExp(r'\b(double|float|num)\b');
  final List<_Violation> out = <_Violation>[];
  for (final String root in <String>['lib/domain', 'lib/data']) {
    out.addAll(
      _scan(
        guard: 'G3',
        root: root,
        message:
            'money is int64 minor units; double/float/num are forbidden on '
            'the money path including intermediates (INV-01)',
        test: floaty.hasMatch,
      ),
    );
  }
  return out;
}

// ---------------------------------------------------------------------------
// G4 — time comes from the injected Clock
// ---------------------------------------------------------------------------
List<_Violation> _g4Clock() {
  final RegExp now = RegExp(r'DateTime\s*\.\s*now\s*\(');
  return _scan(
    guard: 'G4',
    root: 'lib',
    message:
        'DateTime.now() is only permitted inside the Clock implementation; '
        'everywhere else time is injected (INV-09)',
    test: now.hasMatch,
    // The one legitimate home for the real clock.
    skipFile: (String path) => path.endsWith('data/clock_impl.dart'),
  );
}

// ---------------------------------------------------------------------------
// G5 — only the data layer touches the database package
// ---------------------------------------------------------------------------
List<_Violation> _g5DatabaseContainment() {
  final List<_Violation> out = <_Violation>[];
  for (final String root in <String>[
    'lib/domain',
    'lib/application',
    'lib/presentation',
  ]) {
    out.addAll(
      _scan(
        guard: 'G5',
        root: root,
        message:
            'only lib/data may import the database package (ARCHITECTURE §2.1)',
        // As G1: import paths are string literals.
        stripStrings: false,
        test: (String line) =>
            _isImport(line) &&
            (line.contains('package:drift') ||
                line.contains('package:sqlite3')),
      ),
    );
  }
  return out;
}

// ---------------------------------------------------------------------------
// G6 — no telemetry anywhere in the RESOLVED dependency tree
// ---------------------------------------------------------------------------
List<_Violation> _g6Telemetry() {
  const List<String> banned = <String>[
    'firebase_analytics',
    'firebase_crashlytics',
    'firebase_performance',
    'sentry',
    'sentry_flutter',
    'amplitude_flutter',
    'mixpanel_flutter',
    'appsflyer_sdk',
    'google_mobile_ads',
    'facebook_app_events',
    'datadog_flutter_plugin',
    'bugsnag_flutter',
    'posthog_flutter',
    'segment_analytics',
    'matomo_tracker',
  ];

  final File lock = File('pubspec.lock');
  if (!lock.existsSync()) {
    return <_Violation>[
      const _Violation(
        'G6',
        'pubspec.lock',
        0,
        'pubspec.lock missing - cannot verify the resolved tree',
        '',
      ),
    ];
  }

  final List<String> lines = lock.readAsLinesSync();
  final List<_Violation> out = <_Violation>[];
  for (int i = 0; i < lines.length; i++) {
    final String line = lines[i];
    // Package names sit at exactly two spaces of indentation in pubspec.lock.
    final RegExpMatch? m = RegExp(r'^  ([a-z0-9_]+):\s*$').firstMatch(line);
    if (m == null) continue;
    final String name = m.group(1)!;
    if (banned.contains(name)) {
      out.add(
        _Violation(
          'G6',
          'pubspec.lock',
          i + 1,
          'no analytics, crash reporting, advertising or telemetry package may '
              'appear in the resolved tree, transitively or otherwise '
              '(NG-04, NG-08, NFR-01)',
          line,
        ),
      );
    }
  }
  return out;
}

// ---------------------------------------------------------------------------
// Scanning machinery
// ---------------------------------------------------------------------------

/// Runs [test] over every non-generated Dart file under [root].
///
/// Comments are **always** stripped, so prose that names a forbidden construct
/// cannot trip a guard — the false positive substage 3.2 hit on `clock.dart`.
///
/// String literals are stripped only when [stripStrings] is true. Token guards
/// (G2, G3, G4) want it, so a banned word inside a message cannot fire. **Import
/// guards (G1, G5) must switch it off**, because an import path is itself a
/// string literal: with stripping on, `import 'package:flutter/x.dart';` becomes
/// `import ;` and the guard silently checks nothing.
///
/// That failure was real. Both import guards passed their baseline and did
/// nothing at all until substage 3.4.6's deliberate-violation demonstration
/// exposed them.
List<_Violation> _scan({
  required String guard,
  required String root,
  required String message,
  required bool Function(String line) test,
  bool stripStrings = true,
  bool Function(String path)? skipFile,
}) {
  final Directory dir = Directory(root);
  if (!dir.existsSync()) return <_Violation>[];

  final List<_Violation> out = <_Violation>[];
  for (final FileSystemEntity entity in dir.listSync(recursive: true)) {
    if (entity is! File || !entity.path.endsWith('.dart')) continue;

    final String path = entity.path.replaceAll(r'\', '/');
    // Generated code is not ours to police; it is regenerated from sources
    // that are.
    if (path.endsWith('.g.dart') ||
        path.endsWith('.freezed.dart') ||
        path.endsWith('.mocks.dart')) {
      continue;
    }
    if (skipFile != null && skipFile(path)) continue;

    final List<String> raw = entity.readAsLinesSync();
    final List<String> stripped = _stripCommentsAndStrings(
      raw,
      stripStrings: stripStrings,
    );

    for (int i = 0; i < stripped.length; i++) {
      if (stripped[i].trim().isEmpty) continue;
      if (test(stripped[i])) {
        out.add(_Violation(guard, path, i + 1, message, raw[i]));
      }
    }
  }
  return out;
}

/// Removes `//` comments and `/* */` blocks, and optionally the contents of
/// string literals.
///
/// Line count is preserved so reported line numbers stay accurate. Comment
/// stripping is what stops a guard firing on prose that names the very thing it
/// forbids — the false positive substage 3.2 hit on `clock.dart`.
List<String> _stripCommentsAndStrings(
  List<String> lines, {
  required bool stripStrings,
}) {
  final List<String> out = <String>[];
  bool inBlockComment = false;

  for (final String line in lines) {
    final StringBuffer buf = StringBuffer();
    String? quote;
    int i = 0;

    while (i < line.length) {
      final String rest = line.substring(i);

      if (inBlockComment) {
        if (rest.startsWith('*/')) {
          inBlockComment = false;
          i += 2;
        } else {
          i++;
        }
        continue;
      }

      if (quote == null && rest.startsWith('/*')) {
        inBlockComment = true;
        i += 2;
        continue;
      }
      if (quote == null && rest.startsWith('//')) {
        break; // rest of line is a comment
      }

      final String ch = line[i];

      if (stripStrings) {
        if (quote == null && (ch == "'" || ch == '"')) {
          quote = ch;
          buf.write(' ');
          i++;
          continue;
        }
        if (quote != null) {
          if (ch == r'\') {
            i += 2; // skip the escaped character
            continue;
          }
          if (ch == quote) {
            quote = null;
          }
          buf.write(' ');
          i++;
          continue;
        }
      }

      buf.write(ch);
      i++;
    }
    out.add(buf.toString());
  }
  return out;
}

bool _isImport(String line) {
  final String t = line.trimLeft();
  return t.startsWith('import ') || t.startsWith('export ');
}

class _Violation {
  const _Violation(this.guard, this.file, this.line, this.message, this.source);

  final String guard;
  final String file;
  final int line;
  final String message;
  final String source;
}
