import 'package:drift/drift.dart';
import 'package:pookiebudget/data/database/tables/configuration_tables.dart';
import 'package:pookiebudget/data/database/tables/local_tables.dart';
import 'package:pookiebudget/data/database/tables/movement_tables.dart';
import 'package:pookiebudget/data/database/tables/sync_columns.dart';

part 'database.g.dart';

/// The database schema version. **One constant, three homes** (SCHEMA §7.4):
///
/// | Home | Read by |
/// |---|---|
/// | `app_settings.schema_version` | the migration runner at startup |
/// | the remote manifest file | every device before merging (S07.8.2) |
/// | the export file header | the import path (S04.9.5) |
///
/// **Newer-than-expected is always refused, never partially parsed**, in all
/// three cases — partially parsing an unknown format is how data gets silently
/// corrupted.
const int kSchemaVersion = 1;

/// The unique constraints of SCHEMA §5.3.
///
/// Most are **partial** unique indexes, because uniqueness applies among live
/// rows only: an archived category must not block reusing its name, and a
/// tombstoned row must not block re-creation. Drift's `uniqueKeys` cannot
/// express a `WHERE` clause, so these are raw SQL — which also keeps them
/// textually comparable to `SCHEMA.md`.
///
/// Each is a named constant rather than an anonymous list entry, so a failing
/// `CREATE INDEX` names the rule it came from.

/// U-01 — category name unique within its group, among live rows.
const String uCategoryNamePerGroup =
    'CREATE UNIQUE INDEX u_01_category_name_per_group ON categories (group_id, name) WHERE is_archived = 0 AND is_deleted = 0';

/// U-02 — account name unique among live rows.
const String uAccountName =
    'CREATE UNIQUE INDEX u_02_account_name ON accounts (name) WHERE is_archived = 0 AND is_deleted = 0';

/// U-03 — one group row per kind.
const String uGroupKind =
    'CREATE UNIQUE INDEX u_03_group_kind ON category_groups (kind) WHERE is_deleted = 0';

/// U-04 — at most one editable (unsealed) rule version at a time.
const String uOneUnsealedVersion =
    'CREATE UNIQUE INDEX u_04_one_unsealed_version ON distribution_rule_versions (rule_set) WHERE sealed_at_ms IS NULL AND is_deleted = 0';

/// U-05 — rule versions do not share an effective instant.
const String uVersionEffectiveInstant =
    'CREATE UNIQUE INDEX u_05_version_effective_instant ON distribution_rule_versions (rule_set, effective_from_ms) WHERE is_deleted = 0';

/// U-06 — one group-level rule line per group per version.
const String uGroupLinePerVersion =
    "CREATE UNIQUE INDEX u_06_group_line_per_version ON rule_lines (rule_version_id, group_id) WHERE scope = 'GROUP' AND is_deleted = 0";

/// U-07 — one category-level rule line per category per version.
const String uCategoryLinePerVersion =
    "CREATE UNIQUE INDEX u_07_category_line_per_version ON rule_lines (rule_version_id, category_id) WHERE scope = 'CATEGORY' AND is_deleted = 0";

/// U-08 — at most one sink per group. INV-07 depends on the sink being singular
/// as well as uncapped.
const String uOneSinkPerGroup =
    'CREATE UNIQUE INDEX u_08_one_sink_per_group ON categories (group_id) WHERE is_sink = 1 AND is_deleted = 0';

/// U-11 — one redirect row per source/target pair, among live rows (ADR-006).
const String uRedirectPair =
    'CREATE UNIQUE INDEX u_11_redirect_pair ON redirect_targets (source_category_id, target_category_id) WHERE is_deleted = 0';

/// U-12 — one row per source at each priority, so the offer order is total.
const String uRedirectPriority =
    'CREATE UNIQUE INDEX u_12_redirect_priority ON redirect_targets (source_category_id, priority) WHERE is_deleted = 0';

const List<String> kUniqueIndexStatements = <String>[
  uCategoryNamePerGroup,
  uAccountName,
  uGroupKind,
  uOneUnsealedVersion,
  uVersionEffectiveInstant,
  uGroupLinePerVersion,
  uCategoryLinePerVersion,
  uOneSinkPerGroup,
  uRedirectPair,
  uRedirectPriority,
];

/// IX-01 — Q1 balance derivation, Q2 category history, Q9 allocated-in-period.
const String ixLedgerCategoryTime =
    'CREATE INDEX ix_01_ledger_category_time ON ledger_entries (category_id, occurred_at_ms)';

/// IX-02 — Q3 global history with date range, Q4 report aggregation.
const String ixLedgerTime =
    'CREATE INDEX ix_02_ledger_time ON ledger_entries (occurred_at_ms)';

/// IX-03 — Q5 entries belonging to an event; reversal and drill-down.
const String ixLedgerSource =
    'CREATE INDEX ix_03_ledger_source ON ledger_entries (source_id)';

/// IX-04 — Q6 has this entry been reversed.
const String ixLedgerReverses =
    'CREATE INDEX ix_04_ledger_reverses ON ledger_entries (reverses_entry_id) WHERE reverses_entry_id IS NOT NULL';

/// IX-05 — Q7 dashboard rows and every category picker.
const String ixCategoriesGroupArchivedSort =
    'CREATE INDEX ix_05_categories_group_archived_sort ON categories (group_id, is_archived, sort_order)';

/// IX-06 — Q8 sync worker draining pending changes.
const String ixOutboxStateTime =
    'CREATE INDEX ix_06_outbox_state_time ON outbox (state, created_at_ms)';

/// IX-07 — Q10 recent income, history listing.
const String ixIncomeTime =
    'CREATE INDEX ix_07_income_time ON income_events (occurred_at_ms)';

/// IX-08 — Q11 loading a rule version's percentages.
const String ixRuleLinesVersion =
    'CREATE INDEX ix_08_rule_lines_version ON rule_lines (rule_version_id)';

/// IX-09 — Q12 per-account total.
const String ixCategoriesAccount =
    'CREATE INDEX ix_09_categories_account ON categories (linked_account_id) WHERE linked_account_id IS NOT NULL';

/// IX-10 — Q14 spending history per category.
const String ixSpendingCategoryTime =
    'CREATE INDEX ix_10_spending_category_time ON spending_transactions (category_id, occurred_at_ms)';

/// IX-12 — Q15 unread repairs for the Diagnostics badge and list.
const String ixRepairLogUnread =
    'CREATE INDEX ix_12_repair_log_unread ON repair_log (acknowledged_at_ms, occurred_at_ms)';

/// IX-13 — Q16 loading a category's redirect chain. Read once per full
/// category on **every** income event, so it is on the allocation hot path.
const String ixRedirectSourcePriority =
    'CREATE INDEX ix_13_redirect_source_priority ON redirect_targets (source_category_id, priority)';

/// The performance indexes of SCHEMA §5.5. **Every one names the query it
/// serves** — an index with no named query does not belong in this design.
///
/// IX-11 is generated separately, one per synced table.
///
/// **Not created, deliberately:** a composite
/// `ledger_entries (category_id, source_type, occurred_at_ms)` for Q9. IX-01
/// already narrows to one category — roughly 1,675 rows at the Heavy profile —
/// and filtering `source_type` across that is cheap. `ledger_entries` is the
/// highest-volume table, so every extra index is paid on every allocation
/// write. Recorded in SCHEMA §5.5 so Stage 4 does not add it speculatively; a
/// test asserts it is absent.
const List<String> kPerformanceIndexStatements = <String>[
  ixLedgerCategoryTime,
  ixLedgerTime,
  ixLedgerSource,
  ixLedgerReverses,
  ixCategoriesGroupArchivedSort,
  ixOutboxStateTime,
  ixIncomeTime,
  ixRuleLinesVersion,
  ixCategoriesAccount,
  ixSpendingCategoryTime,
  ixRepairLogUnread,
  ixRedirectSourcePriority,
];

/// IX-11 — `(hlc)` on each of the nine synced tables, serving Q13: records
/// changed since a given clock value.
List<String> get kHlcIndexStatements => <String>[
  for (final String table in kSyncedTableNames)
    'CREATE INDEX ix_11_${table}_hlc ON $table (hlc)',
];

/// The PookieBudget database — thirteen tables transcribed from `SCHEMA.md`.
@DriftDatabase(
  tables: <Type>[
    // Configuration
    CategoryGroups,
    Categories,
    Accounts,
    DistributionRuleVersions,
    RuleLines,
    RedirectTargets,
    // Movement
    IncomeEvents,
    LedgerEntries,
    SpendingTransactions,
    // Settings and device-local
    AppSettingsTable,
    SyncMetadata,
    Outbox,
    BalanceCache,
    RepairLog,
  ],
)
class PookieDatabase extends _$PookieDatabase {
  PookieDatabase(super.e);

  @override
  int get schemaVersion => kSchemaVersion;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (Migrator m) async {
      await m.createAll();
      for (final String statement in <String>[
        ...kUniqueIndexStatements,
        ...kPerformanceIndexStatements,
        ...kHlcIndexStatements,
      ]) {
        await customStatement(statement);
      }
    },
    beforeOpen: (OpeningDetails details) async {
      // SCHEMA §5.1: foreign key enforcement MUST be switched on explicitly.
      //
      // SQLite defaults it OFF for backwards compatibility, and many
      // configurations leave it that way — which silently permits orphan rows
      // until a report breaks months later. Substage 4.3's `must_not` is
      // blunt: "Do not assume foreign keys are enforced." It is set per
      // connection, so it belongs here rather than in onCreate.
      await customStatement('PRAGMA foreign_keys = ON');

      // Assert rather than trust. A PRAGMA that silently failed to apply would
      // leave every RESTRICT in the schema decorative.
      final QueryRow row = await customSelect(
        'PRAGMA foreign_keys',
      ).getSingle();
      final int enabled = row.data.values.first as int;
      if (enabled != 1) {
        throw StateError(
          'Foreign key enforcement is OFF after being switched on. Every '
          'ON DELETE RESTRICT in the schema is decorative until this is '
          'fixed; refusing to open the database (SCHEMA.md §5.1).',
        );
      }
    },
  );
}
