/// Why an entity could not be constructed.
///
/// Substage 4.2.7: *"prove each invalid construction is rejected with a typed
/// failure rather than an exception."* A failure is a value the caller must
/// handle; an exception is one they can forget to catch. Every one of these
/// corresponds to a numbered rule in `SCHEMA.md` §6, named in [rule] so that a
/// failure reaching a log or a screen can be traced to the rule that produced
/// it without reading this file.
sealed class EntityFailure {
  const EntityFailure();

  /// The `SCHEMA.md` §6 rule identifier, e.g. `'V-07'`. `null` where the
  /// constraint is structural rather than a numbered validation rule.
  String? get rule;

  /// Plain-language explanation. **Written for the user**, not the developer —
  /// these surface in form errors, and a message that reads as developer output
  /// leaves substage 6.x nothing to render.
  String get describe;

  @override
  String toString() => '${rule ?? "structural"}: $describe';
}

/// A name that is empty or only whitespace.
final class BlankName extends EntityFailure {
  const BlankName(this.entity);

  final String entity;

  @override
  String? get rule => null;

  @override
  String get describe => 'A $entity needs a name.';
}

/// A ceiling that is zero or negative. SCHEMA V-07.
final class NonPositiveCeiling extends EntityFailure {
  const NonPositiveCeiling(this.value);

  final int value;

  @override
  String get rule => 'V-07';

  @override
  String get describe => 'A target amount must be greater than zero.';
}

/// A ceiling present without `ACCUMULATING_RESERVE`, or absent with it.
/// SCHEMA V-08 / C-17.
final class CeilingTypeMismatch extends EntityFailure {
  const CeilingTypeMismatch({
    required this.typeWireName,
    required this.hasCeiling,
  });

  final String typeWireName;
  final bool hasCeiling;

  @override
  String get rule => 'V-08';

  @override
  String get describe => hasCeiling
      ? 'Only a savings goal can have a target amount.'
      : 'A savings goal needs a target amount.';
}

/// A bill amount that is zero or negative. SCHEMA V-17.
final class NonPositiveBillAmount extends EntityFailure {
  const NonPositiveBillAmount(this.value);

  final int value;

  @override
  String get rule => 'V-17';

  @override
  String get describe => 'A bill amount must be greater than zero.';
}

/// Bill fields present without `FIXED_RECURRING`, or absent with it.
/// SCHEMA V-18 / C-18.
final class BillTypeMismatch extends EntityFailure {
  const BillTypeMismatch({required this.typeWireName, required this.hasBill});

  final String typeWireName;
  final bool hasBill;

  @override
  String get rule => 'V-18';

  @override
  String get describe => hasBill
      ? 'Only a recurring bill can have a bill amount and a due day.'
      : 'A recurring bill needs a bill amount and a due day.';
}

/// An anchor day outside 1–31. SCHEMA V-19 / C-05.
///
/// Note that 1–31 is the *stored* range; an anchor of 31 in February is valid
/// and clamps to the last day of the month at read time (SCHEMA V-20). The
/// clamp is a period-boundary concern, not a construction one.
final class AnchorDayOutOfRange extends EntityFailure {
  const AnchorDayOutOfRange(this.value);

  final int value;

  @override
  String get rule => 'V-19';

  @override
  String get describe => 'A due day must be between 1 and 31 (got $value).';
}

/// A category whose redirect target is itself. SCHEMA V-10 / C-20.
///
/// The single-node case of the cycle rule V-12. Caught here because it needs no
/// graph — the whole cycle check lives in substage 4.8, which can see every
/// category; this one is visible from the entity alone.
final class SelfRedirect extends EntityFailure {
  const SelfRedirect(this.categoryId);

  final String categoryId;

  @override
  String get rule => 'V-10';

  @override
  String get describe =>
      'A category cannot send its overflow to itself. Choose a different '
      'category, or leave it empty to use the catch-all.';
}

/// A sink category that carries a ceiling. SCHEMA V-13 / C-19.
///
/// INV-07 — every unit lands somewhere — rests on the sink being able to accept
/// any amount. A capped sink is a terminating guarantee that does not
/// terminate.
final class CappedSink extends EntityFailure {
  const CappedSink(this.categoryId);

  final String categoryId;

  @override
  String get rule => 'V-13';

  @override
  String get describe =>
      'The catch-all category cannot have a target amount — it has to be able '
      'to accept whatever is left over.';
}

/// A sink typed as anything other than `UNCAPPED_FLOW`. SCHEMA V-13 / C-19.
final class SinkNotUncapped extends EntityFailure {
  const SinkNotUncapped(this.typeWireName);

  final String typeWireName;

  @override
  String get rule => 'V-13';

  @override
  String get describe =>
      'The catch-all category must be an open envelope so it can always accept '
      'money.';
}

/// Basis points outside 0–10000. SCHEMA V-01 / C-02.
final class BasisPointsOutOfRange extends EntityFailure {
  const BasisPointsOutOfRange(this.value);

  final int value;

  @override
  String get rule => 'V-01';

  @override
  String get describe => 'A share must be between 0% and 100%.';
}

/// A negative or zero amount where the schema requires a positive one.
final class NonPositiveAmount extends EntityFailure {
  const NonPositiveAmount({required this.field, required this.value});

  final String field;
  final int value;

  @override
  String? get rule => null;

  @override
  String get describe => 'The amount must be greater than zero.';
}

/// A negative amount where the schema requires a non-negative one.
final class NegativeAmount extends EntityFailure {
  const NegativeAmount({required this.field, required this.value});

  final String field;
  final int value;

  @override
  String? get rule => null;

  @override
  String get describe => 'The amount cannot be negative.';
}

/// A `rule_lines` row whose scope and target column disagree.
///
/// `scope = GROUP` requires `group_id` and forbids `category_id`, and the
/// reverse (SCHEMA §3.5, C-21).
final class RuleLineScopeMismatch extends EntityFailure {
  const RuleLineScopeMismatch(this.detail);

  final String detail;

  @override
  String get rule => 'C-21';

  @override
  String get describe => 'This distribution rule is inconsistent: $detail';
}

/// A currency exponent that is not 0, 2 or 3. SCHEMA V-25 / C-12.
final class UnsupportedCurrencyExponent extends EntityFailure {
  const UnsupportedCurrencyExponent(this.value);

  final int value;

  @override
  String get rule => 'V-25';

  @override
  String get describe =>
      'That currency is not supported — this app handles currencies with 0, 2 '
      'or 3 decimal places.';
}

/// An allocation line with `redirected_from` set on a non-redirect reason, or
/// missing it on one that requires it. ALLOCATION_ALGORITHM §2.2.
final class RedirectSourceMismatch extends EntityFailure {
  const RedirectSourceMismatch({
    required this.reasonWireName,
    required this.hasSource,
  });

  final String reasonWireName;
  final bool hasSource;

  @override
  String? get rule => null;

  @override
  String get describe => hasSource
      ? 'An allocation reason of $reasonWireName cannot record where the money '
            'came from.'
      : 'A redirected allocation must record which category it came from.';
}

/// A negative hop count. ALLOCATION_ALGORITHM §2.2: 0 for a base allocation.
final class NegativeHopCount extends EntityFailure {
  const NegativeHopCount(this.value);

  final int value;

  @override
  String? get rule => null;

  @override
  String get describe => 'A redirect hop count cannot be negative.';
}

/// A reserved column written with a value other than its documented default.
/// SCHEMA §6.7.
final class ReservedColumnWritten extends EntityFailure {
  const ReservedColumnWritten(this.column);

  final String column;

  @override
  String get rule => 'V-27';

  @override
  String get describe =>
      'This version of the app does not support $column yet.';
}

/// A ledger entry tombstoned. SCHEMA §3.7 — never valid; INV-03 forbids it.
final class LedgerEntryTombstoned extends EntityFailure {
  const LedgerEntryTombstoned(this.entryId);

  final String entryId;

  @override
  String get rule => 'V-06';

  @override
  String get describe =>
      'A money movement cannot be deleted. Corrections are recorded as new '
      'entries.';
}
