import 'package:pookiebudget/domain/entities/entity_failure.dart';
import 'package:pookiebudget/domain/entities/enums.dart';
import 'package:pookiebudget/domain/entities/headroom.dart';
import 'package:pookiebudget/domain/entities/sync_fields.dart';
import 'package:pookiebudget/domain/result.dart';

/// A category — the thing money actually lands in.
///
/// ## Why amounts are `int` minor units here and not [Money]
///
/// The app holds **exactly one currency**, immutable once any ledger entry
/// exists (SCHEMA V-24). Giving each entity its own `Currency` would store the
/// same value in ten places and create ten ways for them to disagree — the
/// failure mode SCHEMA §3.7 cites when it refuses to carry both a signed amount
/// and a direction. The currency lives once, in `AppSettings`, and use cases
/// pair it with these integers to make `Money` for arithmetic.
///
/// The acceptance criterion — *"no entity exposes a floating point monetary
/// value"* — holds either way, and guard G3 bans `double` from `lib/domain`
/// outright.
final class Category {
  const Category._({
    required this.id,
    required this.groupId,
    required this.name,
    required this.type,
    required this.sortOrder,
    required this.isArchived,
    required this.isSink,
    required this.isSuggestedSeed,
    required this.seedVersion,
    required this.ceilingMinor,
    required this.billAmountMinor,
    required this.periodAnchorDay,
    required this.linkedAccountId,
    required this.ceilingKind,
    required this.redirectMode,
    required this.referenceMonthlyAmountMinor,
    required this.sync,
  });

  /// The only way to build a [Category]. Substage 4.2's `must_not`: *"Do not
  /// allow a public constructor that bypasses validation."*
  ///
  /// Rejects, with a typed failure:
  ///
  /// - an empty or whitespace-only name;
  /// - a ceiling that is zero or negative (V-07);
  /// - a ceiling present without `ACCUMULATING_RESERVE`, or absent with it (V-08);
  /// - a bill amount that is zero or negative (V-17);
  /// - bill fields present without `FIXED_RECURRING`, or absent with it (V-18);
  /// - an anchor day outside 1–31 (V-19);
  /// - a redirect target that is the category itself (V-10);
  /// - a sink that carries a ceiling or is not uncapped (V-13).
  ///
  /// **Not checked here:** that the redirect target exists (V-09), is not
  /// archived (V-11), or forms no cycle (V-12). Those need the whole graph,
  /// which an entity cannot see; they belong to substage 4.8's validator.
  static Result<Category, EntityFailure> create({
    required String id,
    required String groupId,
    required String name,
    required CategoryType type,
    required int sortOrder,
    required SyncFields sync,
    bool isArchived = false,
    bool isSink = false,
    bool isSuggestedSeed = false,
    int? seedVersion,
    int? ceilingMinor,
    int? billAmountMinor,
    int? periodAnchorDay,
    String? linkedAccountId,
    CeilingKind ceilingKind = CeilingKind.absolute,
    RedirectMode redirectMode = RedirectMode.priority,
    int? referenceMonthlyAmountMinor,
  }) {
    final String trimmed = name.trim();
    if (trimmed.isEmpty) {
      return const Failure<Category, EntityFailure>(BlankName('category'));
    }

    // V-08 / C-17 — a ceiling is set iff the type is ACCUMULATING_RESERVE.
    if (type.requiresCeiling != (ceilingMinor != null)) {
      return Failure<Category, EntityFailure>(
        CeilingTypeMismatch(
          typeWireName: type.wireName,
          hasCeiling: ceilingMinor != null,
        ),
      );
    }
    // V-07 — a ceiling, when set, is greater than zero.
    if (ceilingMinor != null && ceilingMinor <= 0) {
      return Failure<Category, EntityFailure>(NonPositiveCeiling(ceilingMinor));
    }

    // V-18 / C-18 — bill amount and anchor day are both set iff FIXED_RECURRING.
    final bool hasBillFields =
        billAmountMinor != null || periodAnchorDay != null;
    if (type.requiresBill) {
      if (billAmountMinor == null || periodAnchorDay == null) {
        return Failure<Category, EntityFailure>(
          BillTypeMismatch(typeWireName: type.wireName, hasBill: false),
        );
      }
    } else if (hasBillFields) {
      return Failure<Category, EntityFailure>(
        BillTypeMismatch(typeWireName: type.wireName, hasBill: true),
      );
    }
    // V-17 — bill amount greater than zero.
    if (billAmountMinor != null && billAmountMinor <= 0) {
      return Failure<Category, EntityFailure>(
        NonPositiveBillAmount(billAmountMinor),
      );
    }
    // V-19 / C-05 — anchor day within 1–31.
    if (periodAnchorDay != null &&
        (periodAnchorDay < 1 || periodAnchorDay > 31)) {
      return Failure<Category, EntityFailure>(
        AnchorDayOutOfRange(periodAnchorDay),
      );
    }

    // C-33 — a reference monthly amount belongs only to a reserve, and only
    // as a positive figure. This is what makes the field safe to store while
    // OQ-19 is open: whichever way that resolves, no row exists that the
    // answer would invalidate.
    if (referenceMonthlyAmountMinor != null) {
      if (type != CategoryType.accumulatingReserve) {
        return Failure<Category, EntityFailure>(
          ReferenceAmountTypeMismatch(type.wireName),
        );
      }
      if (referenceMonthlyAmountMinor <= 0) {
        return Failure<Category, EntityFailure>(
          NonPositiveAmount(
            field: 'reference_monthly_amount_minor',
            value: referenceMonthlyAmountMinor,
          ),
        );
      }
    }

    // NOTE: the self-redirect rule (V-10 / C-29) now lives on RedirectTarget,
    // which is where the source/target pair exists since ADR-006.

    // V-13 / C-19 — the sink is uncapped. INV-07's termination rests on it.
    if (isSink) {
      if (type != CategoryType.uncappedFlow) {
        return Failure<Category, EntityFailure>(SinkNotUncapped(type.wireName));
      }
      if (ceilingMinor != null) {
        return Failure<Category, EntityFailure>(CappedSink(id));
      }
    }

    return Success<Category, EntityFailure>(
      Category._(
        id: id,
        groupId: groupId,
        name: trimmed,
        type: type,
        sortOrder: sortOrder,
        isArchived: isArchived,
        isSink: isSink,
        isSuggestedSeed: isSuggestedSeed,
        seedVersion: seedVersion,
        ceilingMinor: ceilingMinor,
        billAmountMinor: billAmountMinor,
        periodAnchorDay: periodAnchorDay,
        linkedAccountId: linkedAccountId,
        ceilingKind: ceilingKind,
        redirectMode: redirectMode,
        referenceMonthlyAmountMinor: referenceMonthlyAmountMinor,
        sync: sync,
      ),
    );
  }

  final String id;
  final String groupId;
  final String name;
  final CategoryType type;

  /// Display order **and** the first allocation tie-break key
  /// (ALLOCATION_ALGORITHM §5.1).
  final int sortOrder;

  /// Hidden from pickers, history preserved. Distinct from deleted.
  final bool isArchived;

  /// The terminal catch-all. Non-deletable, non-archivable, must be uncapped.
  final bool isSink;

  /// Distinguishes an untouched suggestion from a user creation.
  final bool isSuggestedSeed;

  final int? seedVersion;

  /// Target amount. Set iff [type] is `ACCUMULATING_RESERVE`.
  final int? ceilingMinor;

  /// Per-period bill. Set iff [type] is `FIXED_RECURRING`.
  final int? billAmountMinor;

  /// 1–31. Set iff [type] is `FIXED_RECURRING`. An anchor with no matching date
  /// in a short month clamps to the last day (SCHEMA V-20) — a period-boundary
  /// concern handled in `domain/allocation/period.dart`, not here.
  final int? periodAnchorDay;

  /// How overflow is distributed across this category's redirect targets.
  ///
  /// The targets themselves live in `redirect_targets` (ADR-006), loaded
  /// separately — a category does not carry its own list, because the list is a
  /// repository concern and an entity that held it could disagree with storage.
  final RedirectMode redirectMode;

  /// The user's stated monthly intent for an `ACCUMULATING_RESERVE`, e.g.
  /// 193,000 toward a bike. Null on every other type (C-33).
  ///
  /// **This does not currently drive allocation** — percentages do. Whether it
  /// should is **OQ-19**, raised by ADR-006 because the requirement describes an
  /// absolute figure while FR-02 specifies a percentage, and the two differ
  /// visibly the moment income varies. Stored now so that if the question
  /// resolves toward absolute amounts, the data is already captured.
  ///
  /// Used today for projections: *"at this rate you reach your ceiling in 2
  /// months."*
  final int? referenceMonthlyAmountMinor;

  /// At most one (PRD A-08 — structural, enforced by the column being single).
  final String? linkedAccountId;

  /// **Reserved** (D-02). `ABSOLUTE` is the only value v1 writes.
  final CeilingKind ceilingKind;

  final SyncFields sync;

  // ---------------------------------------------------------------------------
  // Headroom — substage 4.2.2
  // ---------------------------------------------------------------------------

  /// How much this category can still accept in the current run.
  ///
  /// Substage 4.2.2: *"The engine asks the category for its headroom rather
  /// than switching on a type code in three places."* Three switches on a type
  /// code are three places to forget a case when `UNCAPPED_FLOW` was added; one
  /// method is one place, and the `switch` below is exhaustive so the compiler
  /// catches a fourth type.
  ///
  /// [currentBalanceMinor] is the category's balance for an
  /// `ACCUMULATING_RESERVE`; [allocatedInPeriodMinor] is the amount already
  /// allocated this period for a `FIXED_RECURRING`. [acceptedSoFarMinor] is the
  /// running total accepted **within this run** — ALLOCATION_ALGORITHM §3.2
  /// requires it because a category can be reached twice in one run, once in
  /// phase A and again by a redirect. Computing headroom once at the start and
  /// reusing it would let both parcels see the same room and double-fill.
  Headroom headroom({
    required int currentBalanceMinor,
    required int allocatedInPeriodMinor,
    int acceptedSoFarMinor = 0,
  }) {
    // C-19 guarantees the sink is uncapped, but stating it first means the
    // guarantee does not depend on the sink also having been typed correctly.
    if (isSink) return const Headroom.unbounded();

    return switch (type) {
      CategoryType.uncappedFlow => const Headroom.unbounded(),
      CategoryType.accumulatingReserve => Headroom.bounded(
        (ceilingMinor ?? 0) - currentBalanceMinor - acceptedSoFarMinor,
      ),
      CategoryType.fixedRecurring => Headroom.bounded(
        (billAmountMinor ?? 0) - allocatedInPeriodMinor - acceptedSoFarMinor,
      ),
    };
  }

  /// Whether this category can overflow at all. `UNCAPPED_FLOW` and the sink
  /// never do.
  bool get canOverflow => !isSink && type != CategoryType.uncappedFlow;

  // ---------------------------------------------------------------------------

  /// Re-validates, so a valid category cannot be copied into an invalid one.
  ///
  /// The `common_pitfalls` entry names exactly this: *"copyWith that allows a
  /// valid entity to be copied into an invalid one."* Returning `Result` rather
  /// than `Category` is what makes that impossible — a caller changing the type
  /// without clearing the ceiling gets a failure, not a broken object.
  ///
  /// Nullable fields use a sentinel-free approach: pass `clearCeiling: true` to
  /// set one to null, since `ceilingMinor: null` is indistinguishable from
  /// omitting it.
  Result<Category, EntityFailure> copyWith({
    String? groupId,
    String? name,
    CategoryType? type,
    int? sortOrder,
    bool? isArchived,
    bool? isSink,
    bool? isSuggestedSeed,
    int? seedVersion,
    int? ceilingMinor,
    int? billAmountMinor,
    int? periodAnchorDay,
    String? linkedAccountId,
    CeilingKind? ceilingKind,
    RedirectMode? redirectMode,
    int? referenceMonthlyAmountMinor,
    SyncFields? sync,
    bool clearCeiling = false,
    bool clearBill = false,
    bool clearLinkedAccount = false,
    bool clearReferenceAmount = false,
  }) => Category.create(
    id: id,
    groupId: groupId ?? this.groupId,
    name: name ?? this.name,
    type: type ?? this.type,
    sortOrder: sortOrder ?? this.sortOrder,
    isArchived: isArchived ?? this.isArchived,
    isSink: isSink ?? this.isSink,
    isSuggestedSeed: isSuggestedSeed ?? this.isSuggestedSeed,
    seedVersion: seedVersion ?? this.seedVersion,
    ceilingMinor: clearCeiling ? null : (ceilingMinor ?? this.ceilingMinor),
    billAmountMinor: clearBill
        ? null
        : (billAmountMinor ?? this.billAmountMinor),
    periodAnchorDay: clearBill
        ? null
        : (periodAnchorDay ?? this.periodAnchorDay),
    linkedAccountId: clearLinkedAccount
        ? null
        : (linkedAccountId ?? this.linkedAccountId),
    ceilingKind: ceilingKind ?? this.ceilingKind,
    redirectMode: redirectMode ?? this.redirectMode,
    referenceMonthlyAmountMinor: clearReferenceAmount
        ? null
        : (referenceMonthlyAmountMinor ?? this.referenceMonthlyAmountMinor),
    sync: sync ?? this.sync,
  );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Category &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          groupId == other.groupId &&
          name == other.name &&
          type == other.type &&
          sortOrder == other.sortOrder &&
          isArchived == other.isArchived &&
          isSink == other.isSink &&
          isSuggestedSeed == other.isSuggestedSeed &&
          seedVersion == other.seedVersion &&
          ceilingMinor == other.ceilingMinor &&
          billAmountMinor == other.billAmountMinor &&
          periodAnchorDay == other.periodAnchorDay &&
          linkedAccountId == other.linkedAccountId &&
          ceilingKind == other.ceilingKind &&
          redirectMode == other.redirectMode &&
          referenceMonthlyAmountMinor == other.referenceMonthlyAmountMinor &&
          sync == other.sync;

  @override
  int get hashCode => Object.hashAll(<Object?>[
    id,
    groupId,
    name,
    type,
    sortOrder,
    isArchived,
    isSink,
    isSuggestedSeed,
    seedVersion,
    ceilingMinor,
    billAmountMinor,
    periodAnchorDay,
    linkedAccountId,
    ceilingKind,
    redirectMode,
    referenceMonthlyAmountMinor,
    sync,
  ]);

  @override
  String toString() =>
      'Category($id, "$name", ${type.wireName}${isSink ? ", SINK" : ""})';
}
