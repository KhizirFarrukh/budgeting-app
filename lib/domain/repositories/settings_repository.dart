import 'package:pookiebudget/domain/entities/app_settings.dart';
import 'package:pookiebudget/domain/repositories/repository_failure.dart';
import 'package:pookiebudget/domain/result.dart';

/// Storage for the single settings row.
///
/// `app_settings.id` is fixed at `'singleton'` (U-09) so a merge cannot produce
/// two rows, and this interface mirrors that: there is no `settingsById`, no
/// list method and no id parameter anywhere. A method taking an id would imply
/// a second row could exist.
///
/// ## The one rule this repository owns outright
///
/// V-24 — the currency exponent is immutable once any ledger entry exists.
/// `AppSettings.create` cannot enforce it, and says so: an entity cannot know
/// whether money has been recorded. The repository can count ledger rows, so
/// [write] does, and returns [CurrencyLocked] rather than reinterpreting every
/// stored amount in the database.
abstract interface class SettingsRepository {
  /// The settings row, or null before onboarding has written one.
  ///
  /// Nullable rather than defaulted, deliberately. A default would give the app
  /// a currency nobody chose, and every amount subsequently entered would be
  /// stored against it — the exact misreading V-24 exists to prevent, arrived
  /// at from the other direction.
  Future<AppSettings?> read();

  /// Reactive [read]. Emits null until the row is first written.
  Stream<AppSettings?> watch();

  /// Creates or updates the settings row.
  ///
  /// Fails with [CurrencyLocked] if `currencyMinorExponent` differs from what
  /// is stored while any ledger entry exists.
  Future<Result<void, RepositoryFailure>> write(AppSettings settings);
}
