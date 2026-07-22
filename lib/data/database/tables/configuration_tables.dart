import 'package:drift/drift.dart';
import 'package:pookiebudget/data/database/tables/sync_columns.dart';

/// The configuration tables: groups, categories, accounts, rules.
///
/// Transcribed from `SCHEMA.md` §3.1–3.5 and §5.4. Every check constraint
/// carries its `C-nn` identifier in a comment so the comparison table in
/// substage 4.3.5 can be built by reading the code, not by remembering.

/// SCHEMA §3.1 — the three top-level buckets.
@DataClassName('CategoryGroupRow')
class CategoryGroups extends Table with SyncColumns {
  @override
  String get tableName => 'category_groups';

  /// UUID v4.
  TextColumn get id => text().named('id')();

  /// `SPENDING` | `SAVINGS` | `BUSINESS`. Unique among non-deleted rows (U-03).
  TextColumn get kind => text().named('kind')();

  /// Display name; user-renameable.
  TextColumn get name => text().named('name')();

  /// Display order, and the deterministic tie-break key for allocation.
  IntColumn get sortOrder => integer().named('sort_order')();

  /// A personal-only user has no BUSINESS row at all; this covers the
  /// transition when business is enabled or disabled.
  BoolColumn get isActive =>
      boolean().named('is_active').withDefault(const Constant(true))();

  @override
  Set<Column<Object>> get primaryKey => <Column<Object>>{id};

  @override
  List<String> get customConstraints => <String>[
    // C-10
    "CHECK (kind IN ('SPENDING','SAVINGS','BUSINESS'))",
    'CHECK (is_deleted IN (0,1) AND (is_deleted = 0 OR deleted_at_ms IS NOT NULL) AND (is_deleted = 1 OR deleted_at_ms IS NULL))',
  ];
}

/// SCHEMA §3.2 — categories, including the six reserved columns.
@DataClassName('CategoryRow')
class Categories extends Table with SyncColumns {
  @override
  String get tableName => 'categories';

  /// UUID v4.
  TextColumn get id => text().named('id')();

  TextColumn get groupId => text()
      .named('group_id')
      .references(CategoryGroups, #id, onDelete: KeyAction.restrict)();

  /// Unique within its group among non-archived, non-deleted rows (U-01).
  TextColumn get name => text().named('name')();

  /// `FIXED_RECURRING` | `ACCUMULATING_RESERVE` | `UNCAPPED_FLOW`.
  TextColumn get type => text().named('type')();

  /// Display order **and** the first allocation tie-break key.
  IntColumn get sortOrder => integer().named('sort_order')();

  /// Hidden from pickers, history preserved. Distinct from deleted.
  BoolColumn get isArchived =>
      boolean().named('is_archived').withDefault(const Constant(false))();

  /// The terminal catch-all. Non-deletable, non-archivable, must be uncapped.
  BoolColumn get isSink =>
      boolean().named('is_sink').withDefault(const Constant(false))();

  /// Distinguishes an untouched suggestion from a user creation.
  BoolColumn get isSuggestedSeed =>
      boolean().named('is_suggested_seed').withDefault(const Constant(false))();

  /// Which seed generation produced it; null for user creations.
  IntColumn get seedVersion => integer().named('seed_version').nullable()();

  /// Target amount. Required when `type = ACCUMULATING_RESERVE`, null otherwise.
  IntColumn get ceilingMinor => integer().named('ceiling_minor').nullable()();

  /// Per-period bill. Required when `type = FIXED_RECURRING`, null otherwise.
  IntColumn get billAmountMinor =>
      integer().named('bill_amount_minor').nullable()();

  /// 1–31. Required when `type = FIXED_RECURRING`, null otherwise.
  IntColumn get periodAnchorDay =>
      integer().named('period_anchor_day').nullable()();

  /// How overflow is distributed across this category's `redirect_targets`
  /// rows: `PRIORITY` | `SPLIT` (ADR-006).
  TextColumn get redirectMode =>
      text().named('redirect_mode').withDefault(const Constant('PRIORITY'))();

  /// The user's stated monthly intent for an `ACCUMULATING_RESERVE`, e.g.
  /// 193,000 toward a bike. Permitted only on that type (C-33).
  ///
  /// **Does not currently drive allocation** — percentages do. Whether it
  /// should is OQ-19; stored now so the data exists either way.
  IntColumn get referenceMonthlyAmountMinor =>
      integer().named('reference_monthly_amount_minor').nullable()();

  /// At most one (PRD A-08) — structural, the column is single.
  @ReferenceName('linkedCategories')
  TextColumn get linkedAccountId => text()
      .named('linked_account_id')
      .nullable()
      .references(Accounts, #id, onDelete: KeyAction.restrict)();

  // ---------------------------------------------------------------------------
  // The six RESERVED columns — PRD §3.4's promised accommodations.
  //
  // Documented as reserved, validated as unused by C-21, and carried in exports
  // so a v1.1 client reading a v1.0 backup finds them present. A v1 build
  // cannot write a non-default value even by mistake, so a v1.1 client can
  // trust that every v1.0 row carries the defaults.
  // ---------------------------------------------------------------------------

  /// **RESERVED, UNUSED in v1.** Deferral D-01 (OQ-04), deadline-driven goals.
  IntColumn get targetDateMs => integer().named('target_date_ms').nullable()();

  /// **RESERVED.** `ABSOLUTE` is the only value v1 writes. D-02.
  TextColumn get ceilingKind =>
      text().named('ceiling_kind').withDefault(const Constant('ABSOLUTE'))();

  /// **RESERVED, UNUSED in v1.** D-02's parameter.
  TextColumn get ceilingParam => text().named('ceiling_param').nullable()();

  /// **RESERVED, UNUSED in v1.** D-03 (nesting; OQ-12 answered *flat*).
  @ReferenceName('childCategories')
  TextColumn get parentCategoryId => text()
      .named('parent_category_id')
      .nullable()
      .references(Categories, #id, onDelete: KeyAction.restrict)();

  /// **RESERVED, UNUSED in v1.** D-05, soft envelope budgets.
  IntColumn get softBudgetMinor =>
      integer().named('soft_budget_minor').nullable()();

  /// **RESERVED, UNUSED in v1.** Companion to the above.
  TextColumn get softBudgetPeriod =>
      text().named('soft_budget_period').nullable()();

  @override
  Set<Column<Object>> get primaryKey => <Column<Object>>{id};

  @override
  List<String> get customConstraints => <String>[
    // C-09
    "CHECK (type IN ('FIXED_RECURRING','ACCUMULATING_RESERVE','UNCAPPED_FLOW'))",
    // C-03
    'CHECK (ceiling_minor IS NULL OR ceiling_minor > 0)',
    // C-04
    'CHECK (bill_amount_minor IS NULL OR bill_amount_minor > 0)',
    // C-05
    'CHECK (period_anchor_day IS NULL OR period_anchor_day BETWEEN 1 AND 31)',
    // C-17 — type/field agreement. Written as an equality of two boolean
    // expressions so both directions hold: a reserve must have a ceiling, and
    // nothing else may.
    "CHECK ((type = 'ACCUMULATING_RESERVE') = (ceiling_minor IS NOT NULL))",
    // C-18
    "CHECK ((type = 'FIXED_RECURRING') = (bill_amount_minor IS NOT NULL AND period_anchor_day IS NOT NULL))",
    // C-19 — a sink is never capped. This protects INV-07's termination
    // guarantee at database level, so no code path including a sync merge can
    // produce a capped sink.
    'CHECK (is_sink = 0 OR (ceiling_minor IS NULL AND bill_amount_minor IS NULL))',
    // C-33 — mode is one of the two, and a reference amount belongs only to a
    // reserve, only as a positive figure. (C-20's self-redirect rule moved to
    // redirect_targets as C-29 when the single column was removed — ADR-006.)
    "CHECK (redirect_mode IN ('PRIORITY','SPLIT'))",
    "CHECK (reference_monthly_amount_minor IS NULL OR (type = 'ACCUMULATING_RESERVE' AND reference_monthly_amount_minor > 0))",
    // C-21 — the reserved columns hold only their v1 values.
    "CHECK (ceiling_kind = 'ABSOLUTE')",
    'CHECK (target_date_ms IS NULL)',
    'CHECK (ceiling_param IS NULL)',
    'CHECK (parent_category_id IS NULL)',
    'CHECK (soft_budget_minor IS NULL)',
    'CHECK (soft_budget_period IS NULL)',
    'CHECK (is_deleted IN (0,1) AND (is_deleted = 0 OR deleted_at_ms IS NOT NULL) AND (is_deleted = 1 OR deleted_at_ms IS NULL))',
  ];
}

/// SCHEMA §3.3 — a **label with a derived total**, not a balance.
///
/// **No `balance_minor` column exists, deliberately.** Adding one would create a
/// second source of truth for money and break INV-04. The account's total is
/// the sum of its linked categories' balances.
@DataClassName('AccountRow')
class Accounts extends Table with SyncColumns {
  @override
  String get tableName => 'accounts';

  /// UUID v4.
  TextColumn get id => text().named('id')();

  /// Unique among non-archived, non-deleted rows (U-02).
  TextColumn get name => text().named('name')();

  /// Bank name, free text.
  TextColumn get institution => text().named('institution').nullable()();

  /// Last four digits, free text, purely a memory aid.
  TextColumn get lastFour => text().named('last_four').nullable()();

  /// `PERSONAL` | `BUSINESS`. Keeps a business account out of personal flows.
  TextColumn get scope =>
      text().named('scope').withDefault(const Constant('PERSONAL'))();

  IntColumn get sortOrder => integer().named('sort_order')();

  BoolColumn get isArchived =>
      boolean().named('is_archived').withDefault(const Constant(false))();

  @override
  Set<Column<Object>> get primaryKey => <Column<Object>>{id};

  @override
  List<String> get customConstraints => <String>[
    // C-11
    "CHECK (scope IN ('PERSONAL','BUSINESS'))",
    'CHECK (is_deleted IN (0,1) AND (is_deleted = 0 OR deleted_at_ms IS NOT NULL) AND (is_deleted = 1 OR deleted_at_ms IS NULL))',
  ];
}

/// SCHEMA §3.4 — a snapshot of the percentages, effective from an instant.
///
/// `sealed_at_ms` is load-bearing: once an income event references a version,
/// that version's lines can never change, or history would silently re-derive
/// and INV-11 would break.
@DataClassName('DistributionRuleVersionRow')
class DistributionRuleVersions extends Table with SyncColumns {
  @override
  String get tableName => 'distribution_rule_versions';

  /// UUID v4.
  TextColumn get id => text().named('id')();

  /// When this version became active.
  IntColumn get effectiveFromMs => integer().named('effective_from_ms')();

  /// When it was written.
  IntColumn get createdAtMs => integer().named('created_at_ms')();

  /// When it stopped being editable — set by the first income event that
  /// references it.
  IntColumn get sealedAtMs => integer().named('sealed_at_ms').nullable()();

  /// Optional user note: "raised savings to 35%".
  TextColumn get note => text().named('note').nullable()();

  /// **RESERVED.** `DEFAULT` is the only value v1 writes. D-06, after OQ-11 was
  /// answered *one rule set for all income*.
  TextColumn get ruleSet =>
      text().named('rule_set').withDefault(const Constant('DEFAULT'))();

  @override
  Set<Column<Object>> get primaryKey => <Column<Object>>{id};

  @override
  List<String> get customConstraints => <String>[
    // C-22
    "CHECK (rule_set = 'DEFAULT')",
    'CHECK (is_deleted IN (0,1) AND (is_deleted = 0 OR deleted_at_ms IS NOT NULL) AND (is_deleted = 1 OR deleted_at_ms IS NULL))',
  ];
}

/// SCHEMA §3.5 — one share in the two-level split (PRD A-16).
///
/// Both levels live in one table, discriminated by `scope`.
@DataClassName('RuleLineRow')
class RuleLines extends Table with SyncColumns {
  @override
  String get tableName => 'rule_lines';

  /// UUID v4.
  TextColumn get id => text().named('id')();

  TextColumn get ruleVersionId => text()
      .named('rule_version_id')
      .references(
        DistributionRuleVersions,
        #id,
        onDelete: KeyAction.restrict,
      )();

  /// `GROUP` | `CATEGORY`.
  TextColumn get scope => text().named('scope')();

  /// Set when `scope = GROUP`; null otherwise.
  @ReferenceName('groupRuleLines')
  TextColumn get groupId => text()
      .named('group_id')
      .nullable()
      .references(CategoryGroups, #id, onDelete: KeyAction.restrict)();

  /// Set when `scope = CATEGORY`; null otherwise.
  @ReferenceName('categoryRuleLines')
  TextColumn get categoryId => text()
      .named('category_id')
      .nullable()
      .references(Categories, #id, onDelete: KeyAction.restrict)();

  /// 0–10000.
  IntColumn get basisPoints => integer().named('basis_points')();

  @override
  Set<Column<Object>> get primaryKey => <Column<Object>>{id};

  @override
  List<String> get customConstraints => <String>[
    // C-01
    'CHECK (basis_points BETWEEN 0 AND 10000)',
    "CHECK (scope IN ('GROUP','CATEGORY'))",
    // Scope/target agreement. SCHEMA §3.5 states this in prose; expressed here
    // because a GROUP line carrying a category_id would be counted in neither
    // total — the group pass skips it for having a category, the category pass
    // skips it for being group-scoped. A share summed nowhere looks correct on
    // screen while breaking V-01.
    "CHECK ((scope = 'GROUP') = (group_id IS NOT NULL))",
    "CHECK ((scope = 'CATEGORY') = (category_id IS NOT NULL))",
    'CHECK (is_deleted IN (0,1) AND (is_deleted = 0 OR deleted_at_ms IS NOT NULL) AND (is_deleted = 1 OR deleted_at_ms IS NULL))',
  ];
}

/// SCHEMA §3.14 — where a full category's overflow goes (ADR-006).
///
/// Replaces the single `categories.redirect_target_category_id` column. One
/// target is the one-row case of many; keeping both a column and a table would
/// give two places to read the same fact, which is the shape §3.7 rejects when
/// it refuses to store a signed amount alongside a direction.
///
/// **Targets are explicit, never inferred** (FR-16). A category with no rows
/// here sends its overflow to the sink, which is the documented terminal
/// (INV-07), not a guess.
@DataClassName('RedirectTargetRow')
class RedirectTargets extends Table with SyncColumns {
  @override
  String get tableName => 'redirect_targets';

  /// UUID v4.
  TextColumn get id => text().named('id')();

  /// The category that is full.
  @ReferenceName('redirectTargetsFromCategory')
  TextColumn get sourceCategoryId => text()
      .named('source_category_id')
      .references(Categories, #id, onDelete: KeyAction.restrict)();

  /// Where its overflow goes.
  @ReferenceName('redirectTargetsToCategory')
  TextColumn get targetCategoryId => text()
      .named('target_category_id')
      .references(Categories, #id, onDelete: KeyAction.restrict)();

  /// Order of offer under `PRIORITY`; lower first. **Also the deterministic
  /// tie-break under `SPLIT`** — two equal shares must still split a leftover
  /// minor unit reproducibly (ALLOCATION_ALGORITHM §5.1). A tie-break key that
  /// can be absent is not a tie-break key, which is why this is NOT NULL.
  IntColumn get priority => integer().named('priority')();

  /// Share under `SPLIT`; null under `PRIORITY`.
  ///
  /// Nullable rather than defaulting to 0 because **0 is a meaningful share** —
  /// "this target gets nothing" is a different statement from "this target is
  /// not weighted".
  IntColumn get basisPoints => integer().named('basis_points').nullable()();

  @override
  Set<Column<Object>> get primaryKey => <Column<Object>>{id};

  @override
  List<String> get customConstraints => <String>[
    // C-29 — the old C-20, relocated with the column it guarded. The one-node
    // case of the cycle rule, and the case a sync merge most easily produces.
    'CHECK (source_category_id <> target_category_id)',
    // C-31
    'CHECK (basis_points IS NULL OR basis_points BETWEEN 0 AND 10000)',
    // C-32
    'CHECK (priority >= 0)',
    'CHECK (is_deleted IN (0,1) AND (is_deleted = 0 OR deleted_at_ms IS NOT NULL) AND (is_deleted = 1 OR deleted_at_ms IS NULL))',
  ];
}
