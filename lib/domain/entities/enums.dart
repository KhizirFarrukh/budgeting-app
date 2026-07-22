/// Every enumeration in the schema, with **stable string serialisation**.
///
/// SCHEMA §4: *"All stored as stable TEXT (S-05). Adding a value later is
/// additive; renaming or removing one is a migration. Any value not listed is
/// invalid and rejected at the mapper boundary."*
///
/// Substage 4.2's `must_not`: *"Do not store enums as ordinals."* An ordinal is
/// a position, and positions move — inserting a value alphabetically into
/// `CategoryType` would silently reinterpret every stored row. The wire name is
/// written out explicitly on each value so that reordering this file changes
/// nothing on disk.
library;

/// Shared shape: every enum here exposes [wireName] and a `fromWire` lookup
/// that returns `null` for an unrecognised string rather than throwing or
/// falling back to a default. The mapper decides what an unknown value means;
/// the enum only reports that it does not know it.
abstract interface class WireEnum {
  String get wireName;
}

/// `category_groups.kind` — the three top-level buckets.
enum CategoryGroupKind implements WireEnum {
  spending('SPENDING'),
  savings('SAVINGS'),
  business('BUSINESS');

  const CategoryGroupKind(this.wireName);

  @override
  final String wireName;

  static CategoryGroupKind? fromWire(String value) {
    for (final CategoryGroupKind v in values) {
      if (v.wireName == value) return v;
    }
    return null;
  }
}

/// `categories.type`.
///
/// `UNCAPPED_FLOW` exists because **OQ-03 was answered yes** (SCHEMA §4): most
/// spending categories are neither a goal nor a bill, and six of the nineteen
/// suggested categories are typed this way. Saying no would have meant
/// inventing a target for Groceries.
///
/// Headroom semantics live on this type — see `headroom` in `category.dart`,
/// which the engine calls instead of switching on the type code in three
/// places (substage 4.2.2).
enum CategoryType implements WireEnum {
  /// A bill: needs a set amount each period.
  fixedRecurring('FIXED_RECURRING'),

  /// A goal: fills up to a target, then overflows.
  accumulatingReserve('ACCUMULATING_RESERVE'),

  /// An open envelope: no target, never overflows.
  uncappedFlow('UNCAPPED_FLOW');

  const CategoryType(this.wireName);

  @override
  final String wireName;

  static CategoryType? fromWire(String value) {
    for (final CategoryType v in values) {
      if (v.wireName == value) return v;
    }
    return null;
  }

  /// Whether this type carries a ceiling. SCHEMA V-08: a ceiling is set **iff**
  /// the type is `ACCUMULATING_RESERVE`.
  bool get requiresCeiling => this == CategoryType.accumulatingReserve;

  /// SCHEMA V-18: `bill_amount_minor` and `period_anchor_day` are both set
  /// **iff** the type is `FIXED_RECURRING`.
  bool get requiresBill => this == CategoryType.fixedRecurring;
}

/// `ledger_entries.direction`.
///
/// The amount is always positive and the direction carries the sign — SCHEMA
/// §3.7: *"A signed amount plus a direction gives two ways to express the same
/// thing and eventually they disagree."*
enum LedgerDirection implements WireEnum {
  inbound('IN'),
  outbound('OUT');

  const LedgerDirection(this.wireName);

  @override
  final String wireName;

  static LedgerDirection? fromWire(String value) {
    for (final LedgerDirection v in values) {
      if (v.wireName == value) return v;
    }
    return null;
  }
}

/// `ledger_entries.source_type`.
enum LedgerSourceType implements WireEnum {
  allocation('ALLOCATION'),
  spending('SPENDING'),
  reversal('REVERSAL'),
  adjustment('ADJUSTMENT');

  const LedgerSourceType(this.wireName);

  @override
  final String wireName;

  static LedgerSourceType? fromWire(String value) {
    for (final LedgerSourceType v in values) {
      if (v.wireName == value) return v;
    }
    return null;
  }
}

/// `ledger_entries.reason` — why an allocation landed where it did.
enum AllocationReason implements WireEnum {
  /// Phase A: the category's own share of the income.
  base('BASE'),

  /// Overflow redirected from a full category.
  redirect('REDIRECT'),

  /// A manual override supplied with the income event.
  manualOverride('MANUAL_OVERRIDE'),

  /// The terminal catch-all accepted it. INV-07's guarantee that every unit
  /// lands somewhere ends here.
  sinkTerminal('SINK_TERMINAL');

  const AllocationReason(this.wireName);

  @override
  final String wireName;

  static AllocationReason? fromWire(String value) {
    for (final AllocationReason v in values) {
      if (v.wireName == value) return v;
    }
    return null;
  }

  /// Whether `redirected_from_category_id` must be set.
  ///
  /// ALLOCATION_ALGORITHM §2.2: *"Set iff `reason = REDIRECT` or
  /// `SINK_TERMINAL`."* This is what lets the UI say where overflow came from.
  bool get carriesRedirectSource =>
      this == AllocationReason.redirect ||
      this == AllocationReason.sinkTerminal;
}

/// `rule_lines.scope` — which level of the two-level split a line belongs to.
enum RuleLineScope implements WireEnum {
  group('GROUP'),
  category('CATEGORY');

  const RuleLineScope(this.wireName);

  @override
  final String wireName;

  static RuleLineScope? fromWire(String value) {
    for (final RuleLineScope v in values) {
      if (v.wireName == value) return v;
    }
    return null;
  }
}

/// `accounts.scope`, `income_events.scope`, `spending_transactions.scope`.
///
/// Keeps a business account out of personal flows — the separation persona P2
/// needs.
enum MoneyScope implements WireEnum {
  personal('PERSONAL'),
  business('BUSINESS');

  const MoneyScope(this.wireName);

  @override
  final String wireName;

  static MoneyScope? fromWire(String value) {
    for (final MoneyScope v in values) {
      if (v.wireName == value) return v;
    }
    return null;
  }
}

/// `app_settings.onboarding_state` — enables resume-where-you-left-off.
enum OnboardingState implements WireEnum {
  notStarted('NOT_STARTED'),
  inProgress('IN_PROGRESS'),
  complete('COMPLETE');

  const OnboardingState(this.wireName);

  @override
  final String wireName;

  static OnboardingState? fromWire(String value) {
    for (final OnboardingState v in values) {
      if (v.wireName == value) return v;
    }
    return null;
  }
}

/// `outbox.operation`.
enum OutboxOperation implements WireEnum {
  upsert('UPSERT'),
  tombstone('TOMBSTONE');

  const OutboxOperation(this.wireName);

  @override
  final String wireName;

  static OutboxOperation? fromWire(String value) {
    for (final OutboxOperation v in values) {
      if (v.wireName == value) return v;
    }
    return null;
  }
}

/// `outbox.state`.
enum OutboxState implements WireEnum {
  pending('PENDING'),
  inFlight('IN_FLIGHT'),
  failed('FAILED');

  const OutboxState(this.wireName);

  @override
  final String wireName;

  static OutboxState? fromWire(String value) {
    for (final OutboxState v in values) {
      if (v.wireName == value) return v;
    }
    return null;
  }
}

/// `categories.ceiling_kind` — **reserved** (SCHEMA D-02).
///
/// `ABSOLUTE` is the only value v1 writes or accepts. Present so that derived
/// ceilings can be added later without a migration; validation rule V-27
/// rejects anything else.
enum CeilingKind implements WireEnum {
  absolute('ABSOLUTE');

  const CeilingKind(this.wireName);

  @override
  final String wireName;

  static CeilingKind? fromWire(String value) {
    for (final CeilingKind v in values) {
      if (v.wireName == value) return v;
    }
    return null;
  }
}

/// `distribution_rule_versions.rule_set` — **reserved** (SCHEMA D-06).
///
/// `DEFAULT` is the only value v1 writes, after OQ-11 was answered *one rule
/// set for all income*.
enum RuleSet implements WireEnum {
  defaultSet('DEFAULT');

  const RuleSet(this.wireName);

  @override
  final String wireName;

  static RuleSet? fromWire(String value) {
    for (final RuleSet v in values) {
      if (v.wireName == value) return v;
    }
    return null;
  }
}

/// `repair_log.kind` — one value per deterministic repair in SCHEMA §6.8.
enum RepairKind implements WireEnum {
  redirectTargetReassigned('REDIRECT_TARGET_REASSIGNED'),
  percentagesRedistributed('PERCENTAGES_REDISTRIBUTED'),
  sinkRestored('SINK_RESTORED'),
  cycleBroken('CYCLE_BROKEN'),
  accountUnlinked('ACCOUNT_UNLINKED'),
  groupShareZeroed('GROUP_SHARE_ZEROED');

  const RepairKind(this.wireName);

  @override
  final String wireName;

  static RepairKind? fromWire(String value) {
    for (final RepairKind v in values) {
      if (v.wireName == value) return v;
    }
    return null;
  }
}
