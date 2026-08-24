import 'dart:io';

import 'package:drift/drift.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pookiebudget/data/database/database.dart';
import 'package:pookiebudget/data/repositories/drift_ledger_repository.dart';
import 'package:pookiebudget/domain/entities/ledger_entry.dart';
import 'package:pookiebudget/domain/repositories/ledger_repository.dart';

import '../../support/builders/movement_builders.dart';
import '../../support/movement_fixture.dart';
import '../../support/test_database.dart';

/// Substage 4.5.5: *"Add a test that attempts, by any available route, to
/// modify an existing ledger row, and demonstrates there is no such route."*
///
/// The substage calls this a **design test, not a behaviour test**: it documents
/// the guarantee for future maintainers. So it is written to be read. Each group
/// below closes one route, and together they are the argument that INV-03 holds
/// — not because everyone was careful, but because every way in is shut.
///
/// | Route | Closed by |
/// |---|---|
/// | Calling an update method on the repository | There is none. Asserted by scanning the interface. |
/// | Building an amended entry to write back | `LedgerEntry` has no `copyWith`. |
/// | A partial companion from the mappers | Only an insert-shaped companion exists. |
/// | `db.update(db.ledgerEntries)` inside the data layer | Only `ledger_writer.dart` may name the table in a write, and it only inserts. |
/// | Tombstoning, including by a sync merge | Constraint C-15 pins `is_deleted` to 0. |
/// | Re-inserting a changed row under the same id | `insertOrIgnore` skips; it never overwrites. |
void main() {
  // ===========================================================================
  // Route 1 — the repository API
  // ===========================================================================

  group('the ledger interface offers no mutation', () {
    const String interfacePath =
        'lib/domain/repositories/ledger_repository.dart';

    /// Words that name a mutation. `set` is deliberately absent: it would fire
    /// on prose and on `Set<...>`, and a guard that cries wolf is a guard
    /// somebody switches off (`tool/guards/guards.dart` records why at length).
    const List<String> mutatingVerbs = <String>[
      'update',
      'delete',
      'remove',
      'edit',
      'amend',
      'modify',
      'patch',
      'replace',
      'tombstone',
    ];

    /// Method declarations only — comments stripped, so the class comment's
    /// discussion of "no update method" cannot trip this.
    List<String> declaredMethods(String path) {
      final String source = File(path).readAsStringSync();
      final String code = source
          .split('\n')
          .map((String line) {
            final int marker = line.indexOf('//');
            return marker == -1 ? line : line.substring(0, marker);
          })
          .join('\n');
      return RegExp(r'\b([a-z][A-Za-z0-9_]*)\s*\(')
          .allMatches(code)
          .map((RegExpMatch m) => m.group(1)!)
          .toList();
    }

    test('NO METHOD ON LedgerRepository NAMES A MUTATION', () {
      final List<String> methods = declaredMethods(interfacePath);
      expect(
        methods,
        isNotEmpty,
        reason: 'the scan must actually be reading the file',
      );

      final List<String> offenders = methods
          .where(
            (String m) => mutatingVerbs.any(
              (String verb) => m.toLowerCase().contains(verb),
            ),
          )
          .toList();

      expect(
        offenders,
        isEmpty,
        reason:
            'INV-03 is enforced by absence, because absence is the only '
            'enforcement that cannot be forgotten under deadline. A correction '
            'is a new compensating entry.\nFound: ${offenders.join(", ")}',
      );
    });

    test('the scan would catch a mutation if one were added', () {
      // A guard that has never failed has never been tested.
      const List<String> pretend = <String>['append', 'updateEntry'];
      expect(
        pretend.where(
          (String m) =>
              mutatingVerbs.any((String v) => m.toLowerCase().contains(v)),
        ),
        <String>['updateEntry'],
      );
    });
  });

  // ===========================================================================
  // Route 2 — building an amended entry
  // ===========================================================================

  test('LedgerEntry has no copyWith', () {
    final String source = File(
      'lib/domain/entities/ledger_entry.dart',
    ).readAsStringSync();
    expect(
      source.contains('copyWith'),
      isFalse,
      reason:
          'Every other entity has one. This one must not: offering a copyWith '
          'is offering a way to build an amended entry and write it back, '
          'which is the second half of an update path.',
    );
  });

  // ===========================================================================
  // Routes 3 and 4 — inside the data layer
  // ===========================================================================

  group('the data layer has one ledger write, and it only inserts', () {
    test('ONLY ledger_writer.dart WRITES TO ledger_entries', () {
      // The repository interface stops the layers above. It does not stop this
      // one: three repositories hold a live PookieDatabase, on which
      // `db.update(db.ledgerEntries)` is an ordinary expression.
      final List<File> dataFiles = Directory('lib/data/repositories')
          .listSync()
          .whereType<File>()
          .where(
            (File f) =>
                f.path.endsWith('.dart') &&
                !f.path.replaceAll(r'\', '/').endsWith('ledger_writer.dart'),
          )
          .toList();
      expect(dataFiles, isNotEmpty);

      final List<String> offenders = <String>[];
      for (final File file in dataFiles) {
        final String source = file.readAsStringSync();
        for (final String pattern in <String>[
          'update(_db.ledgerEntries)',
          'update(db.ledgerEntries)',
          'delete(_db.ledgerEntries)',
          'delete(db.ledgerEntries)',
          'UPDATE ledger_entries',
          'DELETE FROM ledger_entries',
        ]) {
          if (source.contains(pattern)) {
            offenders.add('${file.path}: $pattern');
          }
        }
      }
      expect(
        offenders,
        isEmpty,
        reason:
            'Ledger writes are funnelled through appendLedgerEntries, which '
            'can only insert.\n${offenders.join("\n")}',
      );
    });

    test('the one write uses insertOrIgnore, never an upsert', () {
      final String writer = File(
        'lib/data/repositories/ledger_writer.dart',
      ).readAsStringSync();
      expect(writer, contains('InsertMode.insertOrIgnore'));
      expect(
        writer.contains('insertOnConflictUpdate'),
        isFalse,
        reason:
            'An upsert is an update path wearing an insert\'s name: a retry '
            'carrying a different amount under the same id would silently '
            'rewrite history.',
      );
    });

    test('the mappers expose no partial ledger companion', () {
      final String mappers = File(
        'lib/data/mappers/movement_mappers.dart',
      ).readAsStringSync();
      final int companionBuilders = RegExp(
        r'LedgerEntriesCompanion\s+\w+\s*\(',
      ).allMatches(mappers).length;
      expect(
        companionBuilders,
        1,
        reason:
            'Exactly one, and it sets every column. A partial companion is the '
            'shape an update takes.',
      );
    });
  });

  // ===========================================================================
  // Routes 5 and 6 — behaviour, at the database
  // ===========================================================================

  group('the database refuses what the code cannot express', () {
    late PookieDatabase db;
    late LedgerRepository ledger;

    setUp(() async {
      db = await openTestDatabase();
      await seedMovementFixture(db);
      ledger = DriftLedgerRepository(db);
      await ledger.append(<LedgerEntry>[buildLedgerEntry(amountMinor: 5000)]);
    });

    tearDown(() async => db.close());

    test('C-15 — an entry cannot be tombstoned, even by raw SQL', () async {
      // The route a sync merge takes. C-15 is a database constraint, which
      // SCHEMA §6.1 calls the absolute enforcement point: it holds against code
      // paths that never asked.
      await expectLater(
        db.customStatement(
          "UPDATE ledger_entries SET is_deleted = 1, deleted_at_ms = 1 "
          "WHERE id = 'entry-1'",
        ),
        throwsA(isA<Exception>()),
      );
      final LedgerEntry? survivor = await ledger.entryById('entry-1');
      expect(survivor, isNotNull);
      expect(survivor!.sync.isDeleted, isFalse);
    });

    test('re-appending the same id does not change the stored amount',
        () async {
      await ledger.append(<LedgerEntry>[
        buildLedgerEntry(amountMinor: 9999999),
      ]);
      expect((await ledger.entryById('entry-1'))!.amountMinor, 5000);
      expect(await rawCount(db, 'ledger_entries'), 1);
    });

    test('every stored entry has is_deleted = 0', () async {
      // Which is why no read in DriftLedgerRepository carries a tombstone
      // filter: the term could never change a result, and a filter that never
      // matters teaches the next reader the wrong thing about this table.
      final int live = await rawCount(db, 'ledger_entries');
      final QueryRow row = await db
          .customSelect(
            'SELECT COUNT(*) AS c FROM ledger_entries WHERE is_deleted = 0',
          )
          .getSingle();
      expect(row.read<int>('c'), live);
    });
  });
}
