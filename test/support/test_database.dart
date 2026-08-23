import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:pookiebudget/data/database/database.dart';

/// An in-memory database, opened and ready.
///
/// Substage 4.4.7: *"Write repository tests against an in-memory database
/// instance so they are fast and hermetic."* Nothing here touches the file
/// system, so tests cannot leak state into each other through a leftover file
/// and cannot fail because of one.
///
/// The `SELECT 1` is not a formality. Drift opens lazily, so without a query
/// the `beforeOpen` callback has not run — and `beforeOpen` is where
/// `PRAGMA foreign_keys = ON` is set. A test that skipped it would run against
/// a database where every `ON DELETE RESTRICT` is decorative, and would pass
/// while proving nothing.
Future<PookieDatabase> openTestDatabase() async {
  final PookieDatabase db = PookieDatabase(NativeDatabase.memory());
  await db.customSelect('SELECT 1').get();
  return db;
}

/// Reads a row **past every repository filter**, straight from SQL.
///
/// This is how substage 4.4.3's acceptance criterion is proved: *"Every
/// configuration delete is soft, proven by a test that finds the row still
/// present with a tombstone."* Asking the repository would prove nothing —
/// the repository is the thing under test, and a hard delete and a correctly
/// filtered soft delete look identical through it.
Future<QueryRow?> rawRow(
  PookieDatabase db,
  String table,
  String id,
) async {
  final List<QueryRow> rows = await db
      .customSelect(
        'SELECT * FROM $table WHERE id = ?',
        variables: <Variable<Object>>[Variable<String>(id)],
      )
      .get();
  return rows.isEmpty ? null : rows.first;
}

/// The number of rows in [table], tombstones included.
Future<int> rawCount(PookieDatabase db, String table) async {
  final QueryRow row = await db
      .customSelect('SELECT COUNT(*) AS c FROM $table')
      .getSingle();
  return row.read<int>('c');
}
