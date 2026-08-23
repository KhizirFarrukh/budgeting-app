import 'package:drift/drift.dart';
import 'package:pookiebudget/data/database/database.dart';
import 'package:pookiebudget/data/mappers/settings_mappers.dart';
import 'package:pookiebudget/data/repositories/repository_support.dart';
import 'package:pookiebudget/domain/entities/app_settings.dart';
import 'package:pookiebudget/domain/repositories/repository_failure.dart';
import 'package:pookiebudget/domain/repositories/settings_repository.dart';
import 'package:pookiebudget/domain/result.dart';

/// The database-backed [SettingsRepository].
///
/// Holds no `Clock`, unlike every other repository here, because there is no
/// delete path: the settings row is created once and updated in place forever.
/// A tombstoned settings row would be an app with no currency and no sink
/// (U-09 permits only one row, so there is no second one to fall back to), so
/// the operation does not exist rather than existing and being guarded.
class DriftSettingsRepository implements SettingsRepository {
  DriftSettingsRepository(this._db);

  final PookieDatabase _db;

  @override
  Future<AppSettings?> read() async {
    final AppSettingsRow? row = await _settingsRow();
    return row == null ? null : appSettingsFromRow(row);
  }

  @override
  Stream<AppSettings?> watch() => _settingsSelect().watchSingleOrNull().map(
    (AppSettingsRow? row) => row == null ? null : appSettingsFromRow(row),
  );

  @override
  Future<Result<void, RepositoryFailure>> write(AppSettings settings) =>
      writeTransaction(_db, () async {
        await _rejectIfCurrencyLocked(settings);
        await _db
            .into(_db.appSettingsTable)
            .insertOnConflictUpdate(appSettingsToCompanion(settings));
      });

  /// V-24 — the currency exponent is immutable once any ledger entry exists.
  ///
  /// `AppSettings.create` says outright that it cannot enforce this: an entity
  /// cannot know whether money has been recorded. The repository can count, so
  /// it does.
  ///
  /// The check is on the **exponent**, not the code. Renaming `PKR` to `RS` is
  /// cosmetic; changing 2 decimal places to 0 reinterprets every integer in the
  /// database — 12345 stops meaning 123.45 and starts meaning 12,345. Only the
  /// second is destructive, so only the second is locked.
  Future<void> _rejectIfCurrencyLocked(AppSettings incoming) async {
    final AppSettingsRow? current = await _settingsRow();
    if (current == null) return;
    if (current.currencyMinorExponent == incoming.currencyMinorExponent) {
      return;
    }

    // Counted in SQL rather than by loading rows: `ledger_entries` is the
    // highest-volume table in the schema (PRD §7.2 puts it at 80–89% of all
    // rows), and this runs on every settings write.
    final QueryRow row = await _db
        .customSelect('SELECT COUNT(*) AS c FROM ledger_entries')
        .getSingle();
    final int entryCount = row.read<int>('c');
    if (entryCount > 0) {
      reject(CurrencyLocked(ledgerEntryCount: entryCount));
    }
  }

  Future<AppSettingsRow?> _settingsRow() =>
      _settingsSelect().getSingleOrNull();

  SimpleSelectStatement<$AppSettingsTableTable, AppSettingsRow>
  _settingsSelect() =>
      _db.select(_db.appSettingsTable)..where(
        // The settings row is never tombstoned — see the class comment — but
        // the term is applied anyway. A read path that filters tombstones only
        // where they are expected is a read path that stops filtering them the
        // day the expectation changes.
        (t) => tombstoneTerm(t.isDeleted, includeDeleted: false),
      );
}
