import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pookiebudget/data/database/database.dart';
import 'package:pookiebudget/data/database/tables/sync_columns.dart';

/// Substage 4.3's acceptance criteria, checked against the **live schema**
/// rather than against the definition source.
///
/// 4.3.6 is explicit about why: *"Read the schema at runtime rather than
/// trusting the definition source, so a generator change cannot slip past."*
/// Every test here queries `PRAGMA table_info` or executes real SQL; none of
/// them inspects the Dart table classes.
void main() {
  late PookieDatabase db;

  setUp(() async {
    db = PookieDatabase(NativeDatabase.memory());
    // Force the connection open so `beforeOpen` runs.
    await db.customSelect('SELECT 1').get();
  });

  tearDown(() async => db.close());

  Future<List<QueryRow>> tableInfo(String table) =>
      db.customSelect('PRAGMA table_info($table)').get();

  Future<List<String>> tableNames() async {
    final List<QueryRow> rows = await db
        .customSelect(
          "SELECT name FROM sqlite_master WHERE type = 'table' "
          "AND name NOT LIKE 'sqlite_%' ORDER BY name",
        )
        .get();
    return rows.map((QueryRow r) => r.read<String>('name')).toList();
  }

  // ===========================================================================
  // 4.3.3 — foreign key enforcement
  // ===========================================================================

  group('4.3.3 foreign keys are enforced, not merely declared', () {
    test('PRAGMA foreign_keys reports ON', () async {
      final QueryRow row = await db
          .customSelect('PRAGMA foreign_keys')
          .getSingle();
      expect(row.data.values.first, 1);
    });

    test('AN ORPHAN INSERT FAILS', () async {
      // The pitfall: "Foreign keys defined but never enforced, so orphans
      // accumulate until a report breaks." SQLite defaults enforcement OFF.
      // Without `PRAGMA foreign_keys = ON` this insert SUCCEEDS.
      expect(
        () => db.customStatement(
          'INSERT INTO categories '
          '(id, group_id, name, type, sort_order, updated_at_ms, '
          'updated_by_device, hlc) VALUES '
          "('orphan', 'no-such-group', 'Orphan', 'UNCAPPED_FLOW', 0, 0, "
          "'d', 'h')",
        ),
        throwsA(isA<SqliteException>()),
      );
    });

    test('ON DELETE RESTRICT blocks deleting a referenced row', () async {
      // CASCADE is forbidden: it would silently destroy ledger history when a
      // category row was removed, which is exactly what INV-03 prevents.
      await db.customStatement(
        'INSERT INTO category_groups (id, kind, name, sort_order, '
        'updated_at_ms, updated_by_device, hlc) VALUES '
        "('g1', 'SPENDING', 'Spending', 0, 0, 'd', 'h')",
      );
      await db.customStatement(
        'INSERT INTO categories (id, group_id, name, type, sort_order, '
        'updated_at_ms, updated_by_device, hlc) VALUES '
        "('c1', 'g1', 'Groceries', 'UNCAPPED_FLOW', 0, 0, 'd', 'h')",
      );
      expect(
        () => db.customStatement("DELETE FROM category_groups WHERE id = 'g1'"),
        throwsA(isA<SqliteException>()),
      );
    });

    test('every declared foreign key uses RESTRICT, never CASCADE', () async {
      // Read from the live schema: PRAGMA foreign_key_list reports the actual
      // on-delete action per key.
      for (final String table in await tableNames()) {
        final List<QueryRow> keys = await db
            .customSelect('PRAGMA foreign_key_list($table)')
            .get();
        for (final QueryRow key in keys) {
          expect(
            key.read<String>('on_delete'),
            'RESTRICT',
            reason:
                '$table.${key.read<String>('from')} → '
                '${key.read<String>('table')}',
          );
        }
      }
    });
  });

  // ===========================================================================
  // 4.3.6 — no floating point storage class anywhere
  // ===========================================================================

  group('4.3.6 no column has a floating point storage class', () {
    test('READS THE LIVE SCHEMA, not the Dart definitions', () async {
      // INV-01. A REAL column would silently reintroduce binary floating point
      // into stored money, which no amount of care in Dart could undo.
      const List<String> forbidden = <String>[
        'REAL',
        'DOUBLE',
        'FLOAT',
        'NUMERIC',
        'DECIMAL',
      ];
      final List<String> offenders = <String>[];
      for (final String table in await tableNames()) {
        for (final QueryRow column in await tableInfo(table)) {
          final String declared = column.read<String>('type').toUpperCase();
          if (forbidden.any(declared.contains)) {
            offenders.add('$table.${column.read<String>('name')}: $declared');
          }
        }
      }
      expect(offenders, isEmpty);
    });

    test('every column is TEXT or INTEGER, and nothing else', () async {
      // Stronger than the blocklist above: an allowlist catches a storage class
      // nobody thought to forbid.
      for (final String table in await tableNames()) {
        for (final QueryRow column in await tableInfo(table)) {
          expect(
            column.read<String>('type').toUpperCase(),
            anyOf('TEXT', 'INTEGER'),
            reason: '$table.${column.read<String>('name')}',
          );
        }
      }
    });

    test(
      'SQLite would not silently accept a float into a money column',
      () async {
        // Column affinity, demonstrated rather than assumed: INTEGER affinity
        // converts a float only when it is losslessly representable, and stores
        // it as an integer.
        await db.customStatement(
          'INSERT INTO category_groups (id, kind, name, sort_order, '
          'updated_at_ms, updated_by_device, hlc) VALUES '
          "('g1', 'SPENDING', 'S', 0, 0, 'd', 'h')",
        );
        await db.customStatement(
          'INSERT INTO categories (id, group_id, name, type, sort_order, '
          'updated_at_ms, updated_by_device, hlc) VALUES '
          "('c1', 'g1', 'C', 'UNCAPPED_FLOW', 0, 0, 'd', 'h')",
        );
        await db.customStatement(
          'INSERT INTO balance_cache (category_id, balance_minor, '
          "computed_at_ms) VALUES ('c1', 5000.0, 0)",
        );
        final QueryRow row = await db
            .customSelect(
              'SELECT typeof(balance_minor) AS t FROM balance_cache '
              "WHERE category_id = 'c1'",
            )
            .getSingle();
        expect(row.read<String>('t'), 'integer');
      },
    );
  });

  // ===========================================================================
  // 4.3.2 — the five sync columns on every synced table
  // ===========================================================================

  group('4.3.2 sync columns', () {
    test('EVERY synced table carries ALL FIVE', () async {
      for (final String table in kSyncedTableNames) {
        final Set<String> columns = (await tableInfo(
          table,
        )).map((QueryRow c) => c.read<String>('name')).toSet();
        for (final String required in kSyncColumnNames) {
          expect(
            columns,
            contains(required),
            reason: '$table is missing $required',
          );
        }
      }
    });

    test('the four device-local tables carry NONE of them', () async {
      // Not an oversight in each case but a stated decision: syncing a device's
      // clock state is meaningless, syncing a balance would let a merge import
      // one (INV-04), and the repair log is deterministic per device so syncing
      // it would duplicate every entry.
      for (final String table in <String>[
        'sync_metadata',
        'outbox',
        'balance_cache',
        'repair_log',
      ]) {
        final Set<String> columns = (await tableInfo(
          table,
        )).map((QueryRow c) => c.read<String>('name')).toSet();
        // `outbox.hlc` is the HLC *of the change being sent*, not a sync column
        // on the outbox row itself, so it is excluded from this assertion.
        for (final String syncColumn in kSyncColumnNames) {
          if (table == 'outbox' && syncColumn == 'hlc') continue;
          expect(
            columns,
            isNot(contains(syncColumn)),
            reason: '$table should not carry $syncColumn',
          );
        }
      }
    });

    test('the nine synced tables are exactly the ones named', () async {
      expect(kSyncedTableNames.length, 9);
      final List<String> all = await tableNames();
      for (final String table in kSyncedTableNames) {
        expect(all, contains(table));
      }
    });
  });

  // ===========================================================================
  // 4.3.1 — the transcription itself
  // ===========================================================================

  group('4.3.1 the schema matches SCHEMA.md', () {
    test('all thirteen tables exist', () async {
      expect(
        await tableNames(),
        containsAll(<String>[
          'category_groups',
          'categories',
          'accounts',
          'distribution_rule_versions',
          'rule_lines',
          'income_events',
          'ledger_entries',
          'spending_transactions',
          'app_settings',
          'sync_metadata',
          'outbox',
          'balance_cache',
          'repair_log',
        ]),
      );
    });

    test('every primary key is TEXT — no auto-increment integers', () async {
      // INV-12, S-04. Ids are client-generated UUIDs so two devices can create
      // records offline without colliding; an auto-increment integer makes that
      // impossible.
      for (final String table in await tableNames()) {
        for (final QueryRow column in await tableInfo(table)) {
          if (column.read<int>('pk') > 0) {
            expect(
              column.read<String>('type').toUpperCase(),
              'TEXT',
              reason: '$table.${column.read<String>('name')} is a primary key',
            );
          }
        }
      }
    });

    test('columns the design marks NOT NULL are not nullable', () async {
      // The pitfall: "A nullable column that the design marked required, which
      // permits invalid rows the domain will later trip over." Spot-checked
      // against the columns whose nullability carries meaning.
      const Map<String, List<String>> required = <String, List<String>>{
        'categories': <String>['group_id', 'name', 'type', 'sort_order'],
        'ledger_entries': <String>[
          'category_id',
          'direction',
          'amount_minor',
          'occurred_at_ms',
          'recorded_at_ms',
          'source_type',
          'source_id',
        ],
        'income_events': <String>[
          'amount_minor',
          'occurred_at_ms',
          'recorded_at_ms',
          'evaluated_at_ms',
          'rule_version_id',
        ],
        'app_settings': <String>[
          'currency_code',
          'currency_minor_exponent',
          'locale',
          'schema_version',
        ],
        'repair_log': <String>[
          'occurred_at_ms',
          'merge_session_id',
          'kind',
          'table_name',
          'record_id',
          'detail_json',
        ],
      };
      for (final MapEntry<String, List<String>> entry in required.entries) {
        final List<QueryRow> info = await tableInfo(entry.key);
        for (final String column in entry.value) {
          final QueryRow row = info.firstWhere(
            (QueryRow c) => c.read<String>('name') == column,
          );
          expect(
            row.read<int>('notnull'),
            1,
            reason: '${entry.key}.$column must be NOT NULL',
          );
        }
      }
    });

    test('columns the design marks nullable ARE nullable', () async {
      // The mirror of the above: over-tightening is a divergence too, and would
      // reject rows the design permits.
      const Map<String, List<String>> nullable = <String, List<String>>{
        'categories': <String>[
          'ceiling_minor',
          'bill_amount_minor',
          'period_anchor_day',
          'redirect_target_category_id',
          'linked_account_id',
          'seed_version',
        ],
        'ledger_entries': <String>[
          'account_id',
          'reason',
          'redirected_from_category_id',
          'hop_count',
          'reverses_entry_id',
          'note',
        ],
        'income_events': <String>['source_label', 'overrides_json', 'note'],
      };
      for (final MapEntry<String, List<String>> entry in nullable.entries) {
        final List<QueryRow> info = await tableInfo(entry.key);
        for (final String column in entry.value) {
          final QueryRow row = info.firstWhere(
            (QueryRow c) => c.read<String>('name') == column,
          );
          expect(
            row.read<int>('notnull'),
            0,
            reason: '${entry.key}.$column must be nullable',
          );
        }
      }
    });
  });

  // ===========================================================================
  // Check constraints — the ones protecting an invariant
  // ===========================================================================

  group('check constraints are live, not decorative', () {
    Future<void> seedGroupAndCategory() async {
      await db.customStatement(
        'INSERT INTO category_groups (id, kind, name, sort_order, '
        'updated_at_ms, updated_by_device, hlc) VALUES '
        "('g1', 'SPENDING', 'Spending', 0, 0, 'd', 'h')",
      );
      await db.customStatement(
        'INSERT INTO categories (id, group_id, name, type, sort_order, '
        'updated_at_ms, updated_by_device, hlc) VALUES '
        "('c1', 'g1', 'Groceries', 'UNCAPPED_FLOW', 0, 0, 'd', 'h')",
      );
    }

    test('C-15 — a ledger entry can never be tombstoned (INV-03)', () async {
      await seedGroupAndCategory();
      expect(
        () => db.customStatement(
          'INSERT INTO ledger_entries (id, category_id, direction, '
          'amount_minor, occurred_at_ms, recorded_at_ms, source_type, '
          'source_id, updated_at_ms, updated_by_device, hlc, is_deleted, '
          "deleted_at_ms) VALUES ('l1', 'c1', 'IN', 100, 0, 0, "
          "'ALLOCATION', 's1', 0, 'd', 'h', 1, 1)",
        ),
        throwsA(isA<SqliteException>()),
      );
    });

    test('C-19 — a sink can never be capped (INV-07 termination)', () async {
      await db.customStatement(
        'INSERT INTO category_groups (id, kind, name, sort_order, '
        'updated_at_ms, updated_by_device, hlc) VALUES '
        "('g1', 'SAVINGS', 'Savings', 0, 0, 'd', 'h')",
      );
      expect(
        () => db.customStatement(
          'INSERT INTO categories (id, group_id, name, type, sort_order, '
          'is_sink, ceiling_minor, updated_at_ms, updated_by_device, hlc) '
          "VALUES ('c1', 'g1', 'Sink', 'ACCUMULATING_RESERVE', 0, 1, 5000, "
          "0, 'd', 'h')",
        ),
        throwsA(isA<SqliteException>()),
      );
    });

    test('C-20 — a category cannot redirect to itself', () async {
      await db.customStatement(
        'INSERT INTO category_groups (id, kind, name, sort_order, '
        'updated_at_ms, updated_by_device, hlc) VALUES '
        "('g1', 'SPENDING', 'S', 0, 0, 'd', 'h')",
      );
      expect(
        () => db.customStatement(
          'INSERT INTO categories (id, group_id, name, type, sort_order, '
          'redirect_target_category_id, updated_at_ms, updated_by_device, '
          "hlc) VALUES ('c1', 'g1', 'C', 'UNCAPPED_FLOW', 0, 'c1', 0, "
          "'d', 'h')",
        ),
        throwsA(isA<SqliteException>()),
      );
    });

    test('C-02 — a zero or negative amount is rejected', () async {
      await seedGroupAndCategory();
      for (final int bad in <int>[0, -100]) {
        expect(
          () => db.customStatement(
            'INSERT INTO ledger_entries (id, category_id, direction, '
            'amount_minor, occurred_at_ms, recorded_at_ms, source_type, '
            'source_id, updated_at_ms, updated_by_device, hlc) VALUES '
            "('l$bad', 'c1', 'IN', $bad, 0, 0, 'ALLOCATION', 's1', 0, "
            "'d', 'h')",
          ),
          throwsA(isA<SqliteException>()),
          reason: 'amount $bad',
        );
      }
    });

    test('C-17 — type and ceiling must agree, in both directions', () async {
      await db.customStatement(
        'INSERT INTO category_groups (id, kind, name, sort_order, '
        'updated_at_ms, updated_by_device, hlc) VALUES '
        "('g1', 'SAVINGS', 'S', 0, 0, 'd', 'h')",
      );
      // A reserve with no ceiling.
      expect(
        () => db.customStatement(
          'INSERT INTO categories (id, group_id, name, type, sort_order, '
          'updated_at_ms, updated_by_device, hlc) VALUES '
          "('c1', 'g1', 'A', 'ACCUMULATING_RESERVE', 0, 0, 'd', 'h')",
        ),
        throwsA(isA<SqliteException>()),
      );
      // A non-reserve carrying one.
      expect(
        () => db.customStatement(
          'INSERT INTO categories (id, group_id, name, type, sort_order, '
          'ceiling_minor, updated_at_ms, updated_by_device, hlc) VALUES '
          "('c2', 'g1', 'B', 'UNCAPPED_FLOW', 0, 5000, 0, 'd', 'h')",
        ),
        throwsA(isA<SqliteException>()),
      );
    });

    test('C-21 — a v1 build cannot write a reserved column', () async {
      await db.customStatement(
        'INSERT INTO category_groups (id, kind, name, sort_order, '
        'updated_at_ms, updated_by_device, hlc) VALUES '
        "('g1', 'SPENDING', 'S', 0, 0, 'd', 'h')",
      );
      // This is what lets a v1.1 client trust that every v1.0 row carries the
      // documented defaults.
      expect(
        () => db.customStatement(
          'INSERT INTO categories (id, group_id, name, type, sort_order, '
          'soft_budget_minor, updated_at_ms, updated_by_device, hlc) VALUES '
          "('c1', 'g1', 'C', 'UNCAPPED_FLOW', 0, 5000, 0, 'd', 'h')",
        ),
        throwsA(isA<SqliteException>()),
      );
      expect(
        () => db.customStatement(
          'INSERT INTO categories (id, group_id, name, type, sort_order, '
          'ceiling_kind, updated_at_ms, updated_by_device, hlc) VALUES '
          "('c2', 'g1', 'D', 'UNCAPPED_FLOW', 0, 'DERIVED', 0, 'd', 'h')",
        ),
        throwsA(isA<SqliteException>()),
      );
    });

    test('C-13 — a tombstone must carry its date, and only then', () async {
      await db.customStatement(
        'INSERT INTO category_groups (id, kind, name, sort_order, '
        'updated_at_ms, updated_by_device, hlc) VALUES '
        "('g1', 'SPENDING', 'S', 0, 0, 'd', 'h')",
      );
      // Deleted with no date.
      expect(
        () => db.customStatement(
          "UPDATE category_groups SET is_deleted = 1 WHERE id = 'g1'",
        ),
        throwsA(isA<SqliteException>()),
      );
      // Live with a date.
      expect(
        () => db.customStatement(
          "UPDATE category_groups SET deleted_at_ms = 5 WHERE id = 'g1'",
        ),
        throwsA(isA<SqliteException>()),
      );
      // Both together is fine.
      await db.customStatement(
        'UPDATE category_groups SET is_deleted = 1, deleted_at_ms = 5 '
        "WHERE id = 'g1'",
      );
    });
  });

  // ===========================================================================
  // Unique constraints — the partial ones, where the partiality is the point
  // ===========================================================================

  group('partial unique indexes apply among live rows only', () {
    test('U-01 — a name is reusable once the holder is archived', () async {
      await db.customStatement(
        'INSERT INTO category_groups (id, kind, name, sort_order, '
        'updated_at_ms, updated_by_device, hlc) VALUES '
        "('g1', 'SPENDING', 'S', 0, 0, 'd', 'h')",
      );
      await db.customStatement(
        'INSERT INTO categories (id, group_id, name, type, sort_order, '
        'updated_at_ms, updated_by_device, hlc) VALUES '
        "('c1', 'g1', 'Groceries', 'UNCAPPED_FLOW', 0, 0, 'd', 'h')",
      );
      // A duplicate live name is refused.
      expect(
        () => db.customStatement(
          'INSERT INTO categories (id, group_id, name, type, sort_order, '
          'updated_at_ms, updated_by_device, hlc) VALUES '
          "('c2', 'g1', 'Groceries', 'UNCAPPED_FLOW', 1, 0, 'd', 'h')",
        ),
        throwsA(isA<SqliteException>()),
      );
      // Archiving the holder frees the name — an archived category must not
      // block reusing it.
      await db.customStatement(
        "UPDATE categories SET is_archived = 1 WHERE id = 'c1'",
      );
      await db.customStatement(
        'INSERT INTO categories (id, group_id, name, type, sort_order, '
        'updated_at_ms, updated_by_device, hlc) VALUES '
        "('c2', 'g1', 'Groceries', 'UNCAPPED_FLOW', 1, 0, 'd', 'h')",
      );
    });

    test('U-08 — at most one sink per group', () async {
      await db.customStatement(
        'INSERT INTO category_groups (id, kind, name, sort_order, '
        'updated_at_ms, updated_by_device, hlc) VALUES '
        "('g1', 'SPENDING', 'S', 0, 0, 'd', 'h')",
      );
      await db.customStatement(
        'INSERT INTO categories (id, group_id, name, type, sort_order, '
        'is_sink, updated_at_ms, updated_by_device, hlc) VALUES '
        "('c1', 'g1', 'Buffer', 'UNCAPPED_FLOW', 0, 1, 0, 'd', 'h')",
      );
      expect(
        () => db.customStatement(
          'INSERT INTO categories (id, group_id, name, type, sort_order, '
          'is_sink, updated_at_ms, updated_by_device, hlc) VALUES '
          "('c2', 'g1', 'Buffer2', 'UNCAPPED_FLOW', 1, 1, 0, 'd', 'h')",
        ),
        throwsA(isA<SqliteException>()),
      );
    });

    test('U-04 — at most one unsealed rule version', () async {
      await db.customStatement(
        'INSERT INTO distribution_rule_versions (id, effective_from_ms, '
        'created_at_ms, updated_at_ms, updated_by_device, hlc) VALUES '
        "('rv1', 1000, 1000, 0, 'd', 'h')",
      );
      expect(
        () => db.customStatement(
          'INSERT INTO distribution_rule_versions (id, effective_from_ms, '
          'created_at_ms, updated_at_ms, updated_by_device, hlc) VALUES '
          "('rv2', 2000, 2000, 0, 'd', 'h')",
        ),
        throwsA(isA<SqliteException>()),
      );
      // Sealing the first makes room for the next — the timeline is
      // non-overlapping, with at most one editable version at any moment.
      await db.customStatement(
        'UPDATE distribution_rule_versions SET sealed_at_ms = 1500 '
        "WHERE id = 'rv1'",
      );
      await db.customStatement(
        'INSERT INTO distribution_rule_versions (id, effective_from_ms, '
        'created_at_ms, updated_at_ms, updated_by_device, hlc) VALUES '
        "('rv2', 2000, 2000, 0, 'd', 'h')",
      );
    });

    test('U-09 — app_settings cannot hold a second row', () async {
      await db.customStatement(
        'INSERT INTO app_settings (id, currency_code, '
        'currency_minor_exponent, locale, schema_version, updated_at_ms, '
        "updated_by_device, hlc) VALUES ('singleton', 'PKR', 2, 'en_PK', "
        "1, 0, 'd', 'h')",
      );
      expect(
        () => db.customStatement(
          'INSERT INTO app_settings (id, currency_code, '
          'currency_minor_exponent, locale, schema_version, updated_at_ms, '
          "updated_by_device, hlc) VALUES ('other', 'USD', 2, 'en_US', "
          "1, 0, 'd', 'h')",
        ),
        throwsA(isA<SqliteException>()),
      );
    });
  });

  // ===========================================================================
  // 4.3.5 / 4.3.7 — indexes and the schema version
  // ===========================================================================

  group('indexes and schema version', () {
    test('every index named in SCHEMA §5.3 and §5.5 exists', () async {
      final List<QueryRow> rows = await db
          .customSelect(
            "SELECT name FROM sqlite_master WHERE type = 'index' "
            'AND name IS NOT NULL',
          )
          .get();
      final Set<String> names = rows
          .map((QueryRow r) => r.read<String>('name'))
          .toSet();
      // U-01..U-08 (U-09 is a check, U-10 is a primary key).
      for (int i = 1; i <= 8; i++) {
        final String prefix = 'u_0$i';
        expect(
          names.any((String n) => n.startsWith(prefix)),
          isTrue,
          reason: 'missing unique index $prefix',
        );
      }
      // IX-01..IX-10 and IX-12; IX-11 is one per synced table.
      for (final String prefix in <String>[
        'ix_01',
        'ix_02',
        'ix_03',
        'ix_04',
        'ix_05',
        'ix_06',
        'ix_07',
        'ix_08',
        'ix_09',
        'ix_10',
        'ix_12',
      ]) {
        expect(
          names.any((String n) => n.startsWith(prefix)),
          isTrue,
          reason: 'missing index $prefix',
        );
      }
      // IX-11 — an hlc index on each of the nine synced tables.
      for (final String table in kSyncedTableNames) {
        expect(names, contains('ix_11_${table}_hlc'));
      }
    });

    test(
      'IX-01 is actually USED by balance derivation, not just present',
      () async {
        // SCHEMA §5.5: "Substage 4.6.1 and 8.1.5 both require verifying by query
        // plan that these indexes are actually used, rather than assuming."
        final List<QueryRow> plan = await db
            .customSelect(
              'EXPLAIN QUERY PLAN SELECT SUM(amount_minor) FROM ledger_entries '
              "WHERE category_id = 'c1' AND occurred_at_ms >= 0",
            )
            .get();
        final String detail = plan
            .map((QueryRow r) => r.read<String>('detail'))
            .join(' ');
        expect(detail, contains('ix_01_ledger_category_time'));
      },
    );

    test('the deliberately-omitted Q9 composite index is absent', () async {
      // Recorded in SCHEMA §5.5 so Stage 4 does not add it speculatively:
      // ledger_entries is the highest-volume table, and every extra index is
      // paid on every allocation write.
      final List<QueryRow> rows = await db
          .customSelect(
            "SELECT name FROM sqlite_master WHERE type = 'index' "
            "AND tbl_name = 'ledger_entries' AND name IS NOT NULL",
          )
          .get();
      final List<String> names = rows
          .map((QueryRow r) => r.read<String>('name'))
          .toList();
      expect(names.any((String n) => n.contains('source_type')), isFalse);
    });

    test(
      '4.3.7 — the schema version constant is 1 and reaches the database',
      () async {
        expect(kSchemaVersion, 1);
        expect(db.schemaVersion, kSchemaVersion);
        await db.customStatement(
          'INSERT INTO app_settings (id, currency_code, '
          'currency_minor_exponent, locale, schema_version, updated_at_ms, '
          "updated_by_device, hlc) VALUES ('singleton', 'PKR', 2, 'en_PK', "
          "$kSchemaVersion, 0, 'd', 'h')",
        );
        final QueryRow row = await db
            .customSelect('SELECT schema_version FROM app_settings')
            .getSingle();
        expect(row.read<int>('schema_version'), kSchemaVersion);
      },
    );
  });
}
