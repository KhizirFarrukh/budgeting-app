import 'package:pookiebudget/domain/entities/entity_failure.dart';
import 'package:pookiebudget/domain/entities/enums.dart';
import 'package:pookiebudget/domain/entities/sync_fields.dart';
import 'package:pookiebudget/domain/result.dart';

/// Money arriving, and the full record of how it was split.
///
/// Every field an allocation depends on is stored, because INV-08 requires that
/// identical inputs produce byte-identical output and INV-11 requires that
/// history stay explainable. The recoverable input tuple is: [amountMinor],
/// [evaluatedAtMs], [ruleVersionId], [overridesJson], plus the balances
/// derivable from the entries preceding this event.
final class IncomeEvent {
  const IncomeEvent._({
    required this.id,
    required this.amountMinor,
    required this.sourceLabel,
    required this.occurredAtMs,
    required this.recordedAtMs,
    required this.evaluatedAtMs,
    required this.ruleVersionId,
    required this.scope,
    required this.overridesJson,
    required this.reversedByEventId,
    required this.isReversal,
    required this.reversesEventId,
    required this.note,
    required this.sync,
  });

  static Result<IncomeEvent, EntityFailure> create({
    required String id,
    required int amountMinor,
    required int occurredAtMs,
    required int recordedAtMs,
    required int evaluatedAtMs,
    required String ruleVersionId,
    required SyncFields sync,
    String? sourceLabel,
    MoneyScope scope = MoneyScope.personal,
    String? overridesJson,
    String? reversedByEventId,
    bool isReversal = false,
    String? reversesEventId,
    String? note,
  }) {
    // C-02: amount_minor > 0. Zero is rejected, not merely empty — vector
    // V-11a expects `IncomeNotPositive`, and the engine treats it as input
    // rejection rather than a run that produces no lines. Recording an income
    // of nothing is a mistake worth naming, not a no-op worth storing.
    if (amountMinor <= 0) {
      return Failure<IncomeEvent, EntityFailure>(
        NonPositiveAmount(field: 'amount_minor', value: amountMinor),
      );
    }
    return Success<IncomeEvent, EntityFailure>(
      IncomeEvent._(
        id: id,
        amountMinor: amountMinor,
        sourceLabel: sourceLabel,
        occurredAtMs: occurredAtMs,
        recordedAtMs: recordedAtMs,
        evaluatedAtMs: evaluatedAtMs,
        ruleVersionId: ruleVersionId,
        scope: scope,
        overridesJson: overridesJson,
        reversedByEventId: reversedByEventId,
        isReversal: isReversal,
        reversesEventId: reversesEventId,
        note: note,
        sync: sync,
      ),
    );
  }

  /// UUID **v7** — time-sortable, for index locality on a high-volume table.
  final String id;

  /// **The conservation target**: ledger entries for this event must sum to
  /// exactly this (INV-02).
  final int amountMinor;

  /// "Salary", "Sale — order 412".
  final String? sourceLabel;

  /// When the money arrived, per the user.
  final int occurredAtMs;

  /// When the app was told.
  final int recordedAtMs;

  /// The timestamp passed into the engine. Stored so the event is exactly
  /// reproducible (INV-08) — the engine never reads a clock itself.
  final int evaluatedAtMs;

  /// The version actually applied (INV-11).
  final String ruleVersionId;

  final MoneyScope scope;

  /// The manual override map as supplied, or null. JSON of
  /// `{category_id: amount_minor}` with integer values.
  ///
  /// **An input to the event, not an edit of its output** (A-23, closes E-02).
  /// An override changes an event's outcome without changing rules or balances,
  /// so unless it is stored as part of the event's *input*, the event becomes
  /// unreproducible and INV-11's promise breaks. A verbatim record of user
  /// input, never a computed result — the computed result is the ledger
  /// entries.
  final String? overridesJson;

  /// The reversal event that undid this one, if any.
  final String? reversedByEventId;

  /// True when this event *is* a reversal of another.
  final bool isReversal;

  final String? reversesEventId;
  final String? note;
  final SyncFields sync;

  bool get isReversed => reversedByEventId != null;
  bool get hasOverrides => overridesJson != null;

  Result<IncomeEvent, EntityFailure> copyWith({
    int? amountMinor,
    String? sourceLabel,
    int? occurredAtMs,
    int? recordedAtMs,
    int? evaluatedAtMs,
    String? ruleVersionId,
    MoneyScope? scope,
    String? overridesJson,
    String? reversedByEventId,
    bool? isReversal,
    String? reversesEventId,
    String? note,
    SyncFields? sync,
    bool clearSourceLabel = false,
    bool clearOverrides = false,
    bool clearNote = false,
  }) => IncomeEvent.create(
    id: id,
    amountMinor: amountMinor ?? this.amountMinor,
    sourceLabel: clearSourceLabel ? null : (sourceLabel ?? this.sourceLabel),
    occurredAtMs: occurredAtMs ?? this.occurredAtMs,
    recordedAtMs: recordedAtMs ?? this.recordedAtMs,
    evaluatedAtMs: evaluatedAtMs ?? this.evaluatedAtMs,
    ruleVersionId: ruleVersionId ?? this.ruleVersionId,
    scope: scope ?? this.scope,
    overridesJson: clearOverrides
        ? null
        : (overridesJson ?? this.overridesJson),
    reversedByEventId: reversedByEventId ?? this.reversedByEventId,
    isReversal: isReversal ?? this.isReversal,
    reversesEventId: reversesEventId ?? this.reversesEventId,
    note: clearNote ? null : (note ?? this.note),
    sync: sync ?? this.sync,
  );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is IncomeEvent &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          amountMinor == other.amountMinor &&
          sourceLabel == other.sourceLabel &&
          occurredAtMs == other.occurredAtMs &&
          recordedAtMs == other.recordedAtMs &&
          evaluatedAtMs == other.evaluatedAtMs &&
          ruleVersionId == other.ruleVersionId &&
          scope == other.scope &&
          overridesJson == other.overridesJson &&
          reversedByEventId == other.reversedByEventId &&
          isReversal == other.isReversal &&
          reversesEventId == other.reversesEventId &&
          note == other.note &&
          sync == other.sync;

  @override
  int get hashCode => Object.hashAll(<Object?>[
    id,
    amountMinor,
    sourceLabel,
    occurredAtMs,
    recordedAtMs,
    evaluatedAtMs,
    ruleVersionId,
    scope,
    overridesJson,
    reversedByEventId,
    isReversal,
    reversesEventId,
    note,
    sync,
  ]);

  @override
  String toString() =>
      'IncomeEvent($id, $amountMinor, ${scope.wireName}'
      '${isReversal ? ", REVERSAL" : ""})';
}
