import 'package:drift/drift.dart';

part 'database.g.dart';

/// A deliberately trivial table that exists only to prove the Drift code
/// generator runs end to end (substage 3.3.3).
///
/// **Stage 4 substage 4.3 replaces this file wholesale** with the thirteen
/// tables transcribed from `docs/SCHEMA.md`. Nothing should be built on it.
///
/// Substage 3.3's `common_pitfalls` names the reason it exists now rather than
/// later: *"A generator misconfiguration that only surfaces when the first real
/// table is written"* costs a session to diagnose in the middle of Stage 4.
///
/// Even as a probe it honours the schema conventions, so that nobody copies a
/// violation out of it:
///
/// - `TEXT` primary key, never an auto-increment integer (INV-12, S-04)
/// - money as `INTEGER` minor units (INV-01, S-01)
@DataClassName('CodegenProbeRow')
class CodegenProbes extends Table {
  /// Client-generated UUID. No auto-increment anywhere in this project.
  TextColumn get id => text()();

  /// Integer minor units — never a floating-point type.
  IntColumn get amountMinor => integer()();

  @override
  Set<Column<Object>> get primaryKey => <Column<Object>>{id};
}

/// Proves the generator produces a working database class.
///
/// Replaced entirely in substage 4.3, including its schema version handling and
/// the `PRAGMA foreign_keys = ON` requirement of SCHEMA §5.1.
@DriftDatabase(tables: <Type>[CodegenProbes])
class ProbeDatabase extends _$ProbeDatabase {
  ProbeDatabase(super.e);

  @override
  int get schemaVersion => 1;
}
