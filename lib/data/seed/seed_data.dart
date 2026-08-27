/// The nineteen suggested categories, the two sinks, and the default split.
///
/// **Data only. No logic, no database, no queries.** `seeder.dart` reads this
/// and writes rows; nothing here knows a database exists. That separation is
/// substage 4.7.7 — *"externalise every seeded string so localisation is
/// possible later without touching logic"* — and the test of whether it holds
/// is simple: a translator could replace every `name` in this file and the
/// seeder would not change by a character.
///
/// ## These are proposals, not structure
///
/// The manifest is emphatic: *"These ship as suggestions only … The user can
/// rename, retype, re-ceiling, remove, or ignore all of them (FR-08)."*
/// Substage 4.7's `must_not` says the same from the other side: *"do not make
/// any seeded category permanent or uneditable, except the sink's existence."*
///
/// So every row the seeder writes from this file is an ordinary category with
/// `is_suggested_seed = 1` — the flag exists to tell an *untouched suggestion*
/// from a *user's own creation*, not to protect anything.
///
/// ## Why the amounts are in major units
///
/// A ceiling of "50,000" means 5,000,000 minor units in a 2-decimal currency,
/// 50,000 in JPY and 50,000,000 in KWD. Storing minor units here would bake in
/// two decimal places, which the manifest's engineering conventions forbid
/// outright: *"do not hardcode 2 decimal places."* The seeder scales by the
/// configured exponent, so the same seed set is correct in every currency.
library;

import 'package:pookiebudget/domain/entities/enums.dart';

/// Which seed generation produced a row.
///
/// Stored on every seeded category so a later version can tell what it wrote
/// from what a user has since created. Bump it when this file's contents
/// change in a way a running install should be able to detect.
const int kSeedVersion = 1;

/// One suggested category, before it becomes a row.
final class SuggestedCategory {
  const SuggestedCategory({
    required this.key,
    required this.name,
    required this.type,
    this.ceilingMajor,
    this.billMajor,
    this.periodAnchorDay,
    this.isSink = false,
    this.note,
  });

  /// A stable, currency- and language-independent handle.
  ///
  /// Tests and the seeder refer to suggestions by this, never by [name] —
  /// otherwise translating "Groceries" would silently break every reference to
  /// it, which is the failure externalising the strings is meant to prevent.
  final String key;

  /// The user-facing name. **The only field a translator needs to touch.**
  final String name;

  final CategoryType type;

  /// Suggested target, in **major** units. Required by `ACCUMULATING_RESERVE`
  /// (V-08); null on every other type.
  ///
  /// **A placeholder, and openly one.** Nobody can know what a stranger's Hajj
  /// fund should hold, and inventing a figure that looked authoritative would
  /// be worse than one that obviously wants confirming. The row is flagged
  /// `is_suggested_seed`, and Stage 6's onboarding walks the user through each.
  final int? ceilingMajor;

  /// Suggested per-period bill, in **major** units. Required by
  /// `FIXED_RECURRING` (V-18) alongside [periodAnchorDay]; null otherwise. Also
  /// a placeholder.
  final int? billMajor;

  /// 1–31. Set iff [type] is `FIXED_RECURRING`.
  final int? periodAnchorDay;

  /// The group's terminal catch-all (OQ-07). Uncapped by construction.
  final bool isSink;

  /// The manifest's rationale, carried through for Stage 6 to show as help
  /// text. Not stored in the database — it is documentation, not data.
  final String? note;
}

// ---------------------------------------------------------------------------
// Spending — five suggestions plus the personal sink
// ---------------------------------------------------------------------------

const List<SuggestedCategory> kSpendingSuggestions = <SuggestedCategory>[
  SuggestedCategory(
    key: 'groceries',
    name: 'Groceries',
    type: CategoryType.uncappedFlow,
    note: 'Recurring but variable; envelope-style.',
  ),
  SuggestedCategory(
    key: 'eating_out',
    name: 'Eating out',
    type: CategoryType.uncappedFlow,
    note: 'Discretionary; good candidate for a monthly envelope cap.',
  ),
  SuggestedCategory(
    key: 'mobile_internet',
    name: 'Mobile/Internet',
    type: CategoryType.fixedRecurring,
    billMajor: 5000,
    periodAnchorDay: 1,
    note: 'Known monthly bill.',
  ),
  SuggestedCategory(
    key: 'transport_fuel',
    name: 'Transport/Fuel',
    type: CategoryType.uncappedFlow,
    note: 'Variable.',
  ),
  SuggestedCategory(
    key: 'entertainment_subscriptions',
    name: 'Entertainment/Subscriptions',
    type: CategoryType.fixedRecurring,
    billMajor: 2500,
    periodAnchorDay: 1,
    note: 'Sum of known subscription charges.',
  ),
  // OQ-07's personal catch-all. Named for what it holds rather than for what it
  // is — "sink" is a word from the algorithm, not a word a user would choose.
  // ALLOCATION_ALGORITHM §3.7 calls this the requirement's "default Unallocated
  // Surplus bucket".
  SuggestedCategory(
    key: 'unallocated_surplus',
    name: 'Unallocated Surplus',
    type: CategoryType.uncappedFlow,
    isSink: true,
    note: 'Where money lands when everything else is full. Renameable, and '
        'you can spend from it — but it cannot be deleted, because overflow '
        'has to have somewhere to go.',
  ),
];

// ---------------------------------------------------------------------------
// Savings — nine reserves, no sink
// ---------------------------------------------------------------------------

const List<SuggestedCategory> kSavingsSuggestions = <SuggestedCategory>[
  SuggestedCategory(
    key: 'medical_reserve',
    name: 'Medical reserve',
    type: CategoryType.accumulatingReserve,
    ceilingMajor: 100000,
    note: 'Ceiling suggested; refills after a claim is spent.',
  ),
  SuggestedCategory(
    key: 'emergency_fund',
    name: 'Emergency fund',
    type: CategoryType.accumulatingReserve,
    ceilingMajor: 300000,
    note: 'Ceiling commonly expressed as N months of spending-group outflow.',
  ),
  SuggestedCategory(
    key: 'trip_savings',
    name: 'Trip savings',
    type: CategoryType.accumulatingReserve,
    ceilingMajor: 150000,
    note: 'Often date-anchored — see OQ-04, deferred to v1.1.',
  ),
  SuggestedCategory(
    key: 'clothes_reserve',
    name: 'Clothes reserve',
    type: CategoryType.accumulatingReserve,
    ceilingMajor: 50000,
  ),
  SuggestedCategory(
    key: 'eid_qurbani_savings',
    name: 'Eid/Qurbani savings',
    type: CategoryType.accumulatingReserve,
    ceilingMajor: 100000,
    note: 'Date-anchored to a lunar-calendar event; the target date moves '
        'about 11 days earlier each Gregorian year — see OQ-04.',
  ),
  SuggestedCategory(
    key: 'wedding_fund',
    name: 'Wedding fund',
    type: CategoryType.accumulatingReserve,
    ceilingMajor: 500000,
  ),
  SuggestedCategory(
    key: 'hajj_fund',
    name: 'Hajj fund',
    type: CategoryType.accumulatingReserve,
    ceilingMajor: 1500000,
    note: 'Long-horizon, large ceiling.',
  ),
  SuggestedCategory(
    key: 'vehicle_pc_upgrade_reserve',
    name: 'Vehicle/PC upgrade reserve',
    type: CategoryType.accumulatingReserve,
    ceilingMajor: 400000,
    note: 'Drains to near zero on purchase, then refills.',
  ),
  SuggestedCategory(
    key: 'annual_taxes_registration_reserve',
    name: 'Annual taxes/registration reserve',
    type: CategoryType.accumulatingReserve,
    ceilingMajor: 100000,
    note: 'Date-anchored annual obligation.',
  ),
];

// ---------------------------------------------------------------------------
// Business — five, the last of which is the business sink
// ---------------------------------------------------------------------------

const List<SuggestedCategory> kBusinessSuggestions = <SuggestedCategory>[
  SuggestedCategory(
    key: 'inventory_stock_purchases',
    name: 'Inventory/stock purchases',
    type: CategoryType.accumulatingReserve,
    ceilingMajor: 200000,
    note: 'Highest-churn business bucket.',
  ),
  SuggestedCategory(
    key: 'advertising_marketing',
    name: 'Advertising/marketing',
    type: CategoryType.uncappedFlow,
  ),
  SuggestedCategory(
    key: 'business_subscriptions_tools',
    name: 'Business subscriptions/tools',
    type: CategoryType.fixedRecurring,
    billMajor: 5000,
    periodAnchorDay: 1,
  ),
  SuggestedCategory(
    key: 'shipping_packaging_supplies',
    name: 'Shipping/packaging supplies',
    type: CategoryType.uncappedFlow,
  ),
  // OQ-07's second catch-all, so overflowing business money stays in the
  // business rather than landing in a personal category — the separation
  // persona P2 needs. The manifest already nominates this one:
  // "Suitable default sink for the business group."
  SuggestedCategory(
    key: 'business_miscellaneous',
    name: 'Business miscellaneous',
    type: CategoryType.uncappedFlow,
    isSink: true,
  ),
];

/// The suggestions for a group.
List<SuggestedCategory> suggestionsFor(CategoryGroupKind kind) =>
    switch (kind) {
      CategoryGroupKind.spending => kSpendingSuggestions,
      CategoryGroupKind.savings => kSavingsSuggestions,
      CategoryGroupKind.business => kBusinessSuggestions,
    };

/// The display name of each group.
const Map<CategoryGroupKind, String> kGroupNames = <CategoryGroupKind, String>{
  CategoryGroupKind.spending: 'Spending',
  CategoryGroupKind.savings: 'Savings',
  CategoryGroupKind.business: 'Business',
};

// ---------------------------------------------------------------------------
// The default split
// ---------------------------------------------------------------------------

/// Group-level shares when business scope is **off**.
///
/// An even split, because the honest default between "spend" and "save" is not
/// a recommendation this app is qualified to make. The user changes it in
/// onboarding, and the app's whole point is that they can.
const Map<CategoryGroupKind, int> kPersonalGroupShares =
    <CategoryGroupKind, int>{
      CategoryGroupKind.spending: 5000,
      CategoryGroupKind.savings: 5000,
    };

/// Group-level shares when business scope is **on**.
const Map<CategoryGroupKind, int> kBusinessGroupShares =
    <CategoryGroupKind, int>{
      CategoryGroupKind.spending: 4000,
      CategoryGroupKind.savings: 3000,
      CategoryGroupKind.business: 3000,
    };

/// Splits [totalBasisPoints] across [parts] shares that sum to it **exactly**.
///
/// The remainder goes to the earliest shares, one unit each — largest-remainder
/// distribution, the same rule the allocation engine uses (ALLOCATION_ALGORITHM
/// §2.4) so the app never rounds two different ways.
///
/// This function is the answer to substage 4.7's named pitfall: *"default
/// percentages that total 9999 because of a hand-computed split, which blocks
/// onboarding."* Nothing here is hand-computed. Nine categories at 1111 total
/// 9999 and a user who accepts the defaults cannot get past onboarding; nine
/// computed shares total 10000 by construction, and adding a twentieth
/// suggestion later cannot break it either.
List<int> distributeEvenly(int totalBasisPoints, int parts) {
  if (parts <= 0) return <int>[];
  final int base = totalBasisPoints ~/ parts;
  final int remainder = totalBasisPoints - base * parts;
  return <int>[
    for (int i = 0; i < parts; i++) i < remainder ? base + 1 : base,
  ];
}

/// The category-level shares for one group's suggestions.
///
/// **The sink gets zero.** It is the terminal for overflow, not a destination
/// in its own right: money should reach it because everything else is full,
/// which is a fact about the run, not a percentage the user chose. A sink with
/// a base share would quietly divert income away from the goals the user
/// actually set.
///
/// Zero is a legal share (C-01 permits 0–10000), and it is meaningfully
/// different from absent — the line exists, so the sink appears in the
/// percentage editor at 0% rather than being missing from it.
Map<String, int> categoryShares(List<SuggestedCategory> suggestions) {
  final List<SuggestedCategory> funded = suggestions
      .where((SuggestedCategory s) => !s.isSink)
      .toList();
  final List<int> shares = distributeEvenly(10000, funded.length);

  return <String, int>{
    for (int i = 0; i < funded.length; i++) funded[i].key: shares[i],
    for (final SuggestedCategory sink
        in suggestions.where((SuggestedCategory s) => s.isSink))
      sink.key: 0,
  };
}
