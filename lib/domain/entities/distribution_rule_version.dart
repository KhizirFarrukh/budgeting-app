import 'package:pookiebudget/domain/entities/entity_failure.dart';
import 'package:pookiebudget/domain/entities/enums.dart';
import 'package:pookiebudget/domain/entities/sync_fields.dart';
import 'package:pookiebudget/domain/result.dart';

/// A snapshot of the distribution percentages, effective from a moment in time.
///
/// INV-11: a historical income event must stay explainable against the rules in
/// force when it was applied, even after the user changes their percentages.
/// That is what versioning buys.
final class DistributionRuleVersion {
  const DistributionRuleVersion._({
    required this.id,
    required this.effectiveFromMs,
    required this.createdAtMs,
    required this.sealedAtMs,
    required this.note,
    required this.ruleSet,
    required this.sync,
  });

  static Result<DistributionRuleVersion, EntityFailure> create({
    required String id,
    required int effectiveFromMs,
    required int createdAtMs,
    required SyncFields sync,
    int? sealedAtMs,
    String? note,
    RuleSet ruleSet = RuleSet.defaultSet,
  }) => Success<DistributionRuleVersion, EntityFailure>(
    DistributionRuleVersion._(
      id: id,
      effectiveFromMs: effectiveFromMs,
      createdAtMs: createdAtMs,
      sealedAtMs: sealedAtMs,
      note: note,
      ruleSet: ruleSet,
      sync: sync,
    ),
  );

  final String id;

  /// When this version became active.
  final int effectiveFromMs;

  /// When it was written.
  final int createdAtMs;

  /// When it stopped being editable — set the moment its first income event is
  /// recorded.
  ///
  /// **Load-bearing.** Once an income event references a version, that
  /// version's lines can never change, or history would silently re-derive and
  /// INV-11 would break. Editing percentages after that point creates a **new**
  /// version; it never mutates the sealed one.
  final int? sealedAtMs;

  /// Optional user note: "raised savings to 35%".
  final String? note;

  /// **Reserved** (D-06). `DEFAULT` is the only value v1 writes, after OQ-11
  /// was answered *one rule set for all income*.
  final RuleSet ruleSet;

  final SyncFields sync;

  /// Whether this version's lines are frozen.
  bool get isSealed => sealedAtMs != null;

  /// Seals the version at [atMs]. Idempotent — sealing an already-sealed
  /// version keeps the original timestamp, because the moment history became
  /// fixed is the moment of the *first* income event, not the latest.
  DistributionRuleVersion sealedAt(int atMs) => isSealed
      ? this
      : DistributionRuleVersion._(
          id: id,
          effectiveFromMs: effectiveFromMs,
          createdAtMs: createdAtMs,
          sealedAtMs: atMs,
          note: note,
          ruleSet: ruleSet,
          sync: sync,
        );

  Result<DistributionRuleVersion, EntityFailure> copyWith({
    int? effectiveFromMs,
    int? createdAtMs,
    int? sealedAtMs,
    String? note,
    RuleSet? ruleSet,
    SyncFields? sync,
    bool clearNote = false,
  }) => DistributionRuleVersion.create(
    id: id,
    effectiveFromMs: effectiveFromMs ?? this.effectiveFromMs,
    createdAtMs: createdAtMs ?? this.createdAtMs,
    sealedAtMs: sealedAtMs ?? this.sealedAtMs,
    note: clearNote ? null : (note ?? this.note),
    ruleSet: ruleSet ?? this.ruleSet,
    sync: sync ?? this.sync,
  );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is DistributionRuleVersion &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          effectiveFromMs == other.effectiveFromMs &&
          createdAtMs == other.createdAtMs &&
          sealedAtMs == other.sealedAtMs &&
          note == other.note &&
          ruleSet == other.ruleSet &&
          sync == other.sync;

  @override
  int get hashCode => Object.hash(
    id,
    effectiveFromMs,
    createdAtMs,
    sealedAtMs,
    note,
    ruleSet,
    sync,
  );

  @override
  String toString() =>
      'DistributionRuleVersion($id, effective: $effectiveFromMs, '
      'sealed: $sealedAtMs)';
}
