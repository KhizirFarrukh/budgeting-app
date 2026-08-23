/// Why a repository could not complete a read or a write.
///
/// The companion to `EntityFailure`, one layer out. An entity failure says
/// *this value is not a valid category*; a repository failure says *this
/// category cannot be stored here, now, alongside what is already stored*. The
/// distinction is what a single row can see: an entity validates itself, a
/// repository validates it against the rest of the database.
///
/// ARCHITECTURE.md §8.1 governs the choice of a result over an exception: every
/// failure below is one a *user* can cause — a duplicate name, an edit to
/// sealed history, a delete of the catch-all — so each is a value the caller
/// must handle rather than an exception they can forget to catch.
///
/// Failures that indicate a **bug** are deliberately absent. A row that cannot
/// be mapped to an entity throws (see `data/mappers/mapping_error.dart`),
/// because no caller can do anything sensible with it.
library;

/// The base of the repository failure taxonomy.
sealed class RepositoryFailure {
  const RepositoryFailure();

  /// The `SCHEMA.md` rule identifier this failure enforces, e.g. `'U-01'`.
  /// `null` where the rule is structural rather than numbered.
  String? get rule;

  /// Plain-language explanation, **written for the user**. These reach form
  /// errors and snackbars in Stage 6; a message that reads as developer output
  /// leaves that stage nothing to render.
  String get describe;

  @override
  String toString() => '${rule ?? "structural"}: $describe';
}

/// No live record with that id exists.
///
/// A tombstoned record reads as absent unless the caller opted in to
/// tombstones, so a user-facing reader and a sync-facing reader get consistent
/// answers to different questions without either having to remember which.
final class RecordNotFound extends RepositoryFailure {
  const RecordNotFound({required this.entity, required this.id});

  /// `'category'`, `'account'`, `'rule version'` — lower case, so it reads
  /// correctly mid-sentence.
  final String entity;

  final String id;

  @override
  String? get rule => null;

  @override
  String get describe => 'That $entity no longer exists.';
}

/// A name that is already taken among the live rows.
///
/// SCHEMA U-01 (category name within its group) and U-02 (account name). Both
/// are **partial** unique indexes over non-archived, non-deleted rows: an
/// archived category must not block reusing its name, or a user who tidied up
/// last year cannot name this year's goal the same thing.
///
/// Checked in the repository as well as by the index, because the index can
/// only say that *something* collided — it cannot say which record, and a user
/// staring at a form needs to be told.
final class DuplicateName extends RepositoryFailure {
  const DuplicateName({required this.entity, required this.name});

  final String entity;
  final String name;

  @override
  String get rule => 'U-01/U-02';

  @override
  String get describe => 'A $entity called "$name" already exists.';
}

/// An attempt to delete or archive the terminal catch-all.
///
/// INV-07 — every unit of income lands somewhere — terminates at the sink.
/// Removing it does not make allocation fail loudly; it makes the final parcel
/// of a redirect chain have nowhere to go, which is the failure mode the
/// invariant exists to prevent.
final class SinkProtected extends RepositoryFailure {
  const SinkProtected({required this.categoryId, required this.action});

  final String categoryId;

  /// `'deleted'` or `'archived'`.
  final String action;

  @override
  String get rule => 'V-14';

  @override
  String get describe =>
      'The catch-all category cannot be $action — it is where leftover money '
      'goes when everything else is full.';
}

/// An attempt to change a rule version, or its lines, after it was sealed.
///
/// INV-11: a historical income event stays explainable against the rules in
/// force when it was applied. A version is sealed by the first income event
/// that references it, and from that moment editing it would silently
/// re-derive history. Changing percentages after that point creates a **new**
/// version; it never mutates the sealed one.
final class RuleVersionSealed extends RepositoryFailure {
  const RuleVersionSealed({required this.versionId, required this.sealedAtMs});

  final String versionId;
  final int sealedAtMs;

  @override
  String get rule => 'V-22';

  @override
  String get describe =>
      'These percentages have already been used to split income, so they can '
      'no longer be edited. Create a new version instead — your history stays '
      'as it was.';
}

/// An attempt to change the currency after money has been recorded.
///
/// SCHEMA V-24. Every stored amount is a bare integer interpreted through
/// `app_settings.currency_minor_exponent`, so changing the exponent would
/// silently reinterpret every balance in the database — 12345 read as 123.45
/// becomes 12,345.
///
/// `AppSettings.create` deliberately does **not** check this: the entity cannot
/// know whether a ledger entry exists. The repository can count them, which is
/// why the rule lives here.
final class CurrencyLocked extends RepositoryFailure {
  const CurrencyLocked({required this.ledgerEntryCount});

  final int ledgerEntryCount;

  @override
  String get rule => 'V-24';

  @override
  String get describe =>
      'The currency cannot be changed once money has been recorded. Every '
      'amount already saved is stored in it.';
}

/// A record that other live records still point at.
///
/// Returned rather than resolved, deliberately. Unlinking every category from
/// a deleted account is a **decision**, not a detail: the categories keep their
/// money either way, but the user loses the record of where it is held. Stage 6
/// asks the user; Stage 7's merge takes the documented `ACCOUNT_UNLINKED`
/// repair. Neither is the repository's call to make silently.
final class RecordStillReferenced extends RepositoryFailure {
  const RecordStillReferenced({
    required this.entity,
    required this.id,
    required this.referenceCount,
    required this.referencedBy,
  });

  final String entity;
  final String id;
  final int referenceCount;

  /// What holds the references, e.g. `'categories'`.
  final String referencedBy;

  @override
  String? get rule => null;

  @override
  String get describe => referenceCount == 1
      ? 'That $entity is still linked to 1 item. Unlink it first.'
      : 'That $entity is still linked to $referenceCount items. Unlink them '
            'first.';
}

/// A write whose entity could not be rebuilt from the values supplied.
///
/// Wraps the `EntityFailure` verbatim rather than restating it, so the specific
/// rule — V-08, V-18, C-33 — survives the trip out of the repository instead of
/// collapsing into "invalid".
final class InvalidEntity extends RepositoryFailure {
  const InvalidEntity(this.failure);

  /// Always an `EntityFailure`. Typed as [Object] so this file stays free of a
  /// dependency on the entity taxonomy it reports on; callers pattern-match.
  final Object failure;

  @override
  String? get rule => null;

  @override
  String get describe => failure.toString();
}

/// A database constraint fired that the repository did not anticipate.
///
/// The backstop, and it is meant to be rare: every rule the repository knows
/// about is checked before the write, so the user gets a specific message. This
/// exists because the schema's constraints are the **absolute** enforcement
/// point (SCHEMA §6.1) — they hold even against a code path that forgot to ask,
/// and when one fires unexpectedly the honest answer is to say so rather than
/// to report success.
final class ConstraintViolation extends RepositoryFailure {
  const ConstraintViolation(this.detail);

  /// The driver's message. **Diagnostic, never user-facing** — see [describe],
  /// which deliberately does not include it.
  final String detail;

  @override
  String? get rule => null;

  @override
  String get describe =>
      'That change conflicts with something already saved and was not applied.';
}
