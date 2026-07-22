import 'package:pookiebudget/domain/entities/entity_failure.dart';
import 'package:pookiebudget/domain/entities/enums.dart';
import 'package:pookiebudget/domain/entities/sync_fields.dart';
import 'package:pookiebudget/domain/result.dart';

/// The immutable record of one money movement.
///
/// **Append-only** (INV-03). There is no update path and no delete path at any
/// layer; corrections are new compensating rows. This type has no `copyWith`
/// for that reason — offering one would be offering a way to rewrite history,
/// and substage 4.5 enforces the same rule at the repository.
final class LedgerEntry {
  const LedgerEntry._({
    required this.id,
    required this.categoryId,
    required this.accountId,
    required this.direction,
    required this.amountMinor,
    required this.occurredAtMs,
    required this.recordedAtMs,
    required this.sourceType,
    required this.sourceId,
    required this.reason,
    required this.redirectedFromCategoryId,
    required this.hopCount,
    required this.reversesEntryId,
    required this.note,
    required this.sync,
  });

  /// Rejects a non-positive amount, a tombstoned entry, and a redirect source
  /// that disagrees with the reason.
  ///
  /// The tombstone check implements SCHEMA §3.7: the `is_deleted` column exists
  /// for structural uniformity and because the merge reads it, but **it is
  /// never 1 for a ledger entry**. A row arriving that way is corruption, not a
  /// deletion — deleting money movement is exactly what INV-03 forbids.
  static Result<LedgerEntry, EntityFailure> create({
    required String id,
    required String categoryId,
    required LedgerDirection direction,
    required int amountMinor,
    required int occurredAtMs,
    required int recordedAtMs,
    required LedgerSourceType sourceType,
    required String sourceId,
    required SyncFields sync,
    String? accountId,
    AllocationReason? reason,
    String? redirectedFromCategoryId,
    int? hopCount,
    String? reversesEntryId,
    String? note,
  }) {
    // Always positive; `direction` carries the sign. A signed amount plus a
    // direction gives two ways to express the same thing and eventually they
    // disagree (SCHEMA §3.7).
    if (amountMinor <= 0) {
      return Failure<LedgerEntry, EntityFailure>(
        NonPositiveAmount(field: 'amount_minor', value: amountMinor),
      );
    }
    if (sync.isDeleted) {
      return Failure<LedgerEntry, EntityFailure>(LedgerEntryTombstoned(id));
    }
    if (reason != null &&
        reason.carriesRedirectSource != (redirectedFromCategoryId != null)) {
      return Failure<LedgerEntry, EntityFailure>(
        RedirectSourceMismatch(
          reasonWireName: reason.wireName,
          hasSource: redirectedFromCategoryId != null,
        ),
      );
    }
    if (hopCount != null && hopCount < 0) {
      return Failure<LedgerEntry, EntityFailure>(NegativeHopCount(hopCount));
    }
    return Success<LedgerEntry, EntityFailure>(
      LedgerEntry._(
        id: id,
        categoryId: categoryId,
        accountId: accountId,
        direction: direction,
        amountMinor: amountMinor,
        occurredAtMs: occurredAtMs,
        recordedAtMs: recordedAtMs,
        sourceType: sourceType,
        sourceId: sourceId,
        reason: reason,
        redirectedFromCategoryId: redirectedFromCategoryId,
        hopCount: hopCount,
        reversesEntryId: reversesEntryId,
        note: note,
        sync: sync,
      ),
    );
  }

  /// UUID **v7**, and the **idempotency key**: inserting the same id twice is a
  /// no-op. That is what makes a retried sync safe.
  final String id;

  final String categoryId;

  /// **Denormalised from the category at write time**, so history survives a
  /// later re-link. If the user re-links a category to a different account next
  /// year, last year's entries must still report the account the money actually
  /// went to — a join would rewrite history.
  final String? accountId;

  final LedgerDirection direction;

  /// Always **positive**; [direction] carries the sign.
  final int amountMinor;

  final int occurredAtMs;
  final int recordedAtMs;
  final LedgerSourceType sourceType;

  /// The income event or spending transaction that produced this.
  final String sourceId;

  /// Set for allocations.
  final AllocationReason? reason;

  /// Set when [reason] is `REDIRECT` or `SINK_TERMINAL`. **This is what lets
  /// the UI say where overflow came from.**
  final String? redirectedFromCategoryId;

  /// How many redirects this parcel travelled. 0 for a base allocation.
  final int? hopCount;

  final String? reversesEntryId;
  final String? note;
  final SyncFields sync;

  /// Signed value for summation. The only place the sign is applied, so the
  /// stored amount stays unambiguous.
  int get signedMinor =>
      direction == LedgerDirection.inbound ? amountMinor : -amountMinor;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is LedgerEntry &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          categoryId == other.categoryId &&
          accountId == other.accountId &&
          direction == other.direction &&
          amountMinor == other.amountMinor &&
          occurredAtMs == other.occurredAtMs &&
          recordedAtMs == other.recordedAtMs &&
          sourceType == other.sourceType &&
          sourceId == other.sourceId &&
          reason == other.reason &&
          redirectedFromCategoryId == other.redirectedFromCategoryId &&
          hopCount == other.hopCount &&
          reversesEntryId == other.reversesEntryId &&
          note == other.note &&
          sync == other.sync;

  @override
  int get hashCode => Object.hashAll(<Object?>[
    id,
    categoryId,
    accountId,
    direction,
    amountMinor,
    occurredAtMs,
    recordedAtMs,
    sourceType,
    sourceId,
    reason,
    redirectedFromCategoryId,
    hopCount,
    reversesEntryId,
    note,
    sync,
  ]);

  @override
  String toString() =>
      'LedgerEntry($id, ${direction.wireName} $amountMinor, $categoryId, '
      '${sourceType.wireName})';
}
