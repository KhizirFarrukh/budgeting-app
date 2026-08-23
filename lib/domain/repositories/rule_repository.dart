import 'package:pookiebudget/domain/entities/distribution_rule_version.dart';
import 'package:pookiebudget/domain/entities/enums.dart';
import 'package:pookiebudget/domain/entities/rule_line.dart';
import 'package:pookiebudget/domain/repositories/repository_failure.dart';
import 'package:pookiebudget/domain/repositories/repository_queries.dart';
import 'package:pookiebudget/domain/result.dart';

/// Storage for the distribution percentages and their version history.
///
/// ## Sealing is the whole point of this interface
///
/// INV-11 requires a historical income event to stay explainable against the
/// rules that were in force when it was applied. That holds only if a version's
/// lines become immutable the moment an income event references it — otherwise
/// changing a percentage today silently re-derives what last March's salary
/// did.
///
/// So every mutating method here refuses a sealed version with
/// [RuleVersionSealed], and [sealVersion] is idempotent: the instant history
/// became fixed is the moment of the *first* income event, not the latest.
/// Substage 4.5 calls it inside the same transaction as the income event that
/// triggers it, so no window exists where an event exists against an unsealed
/// version.
abstract interface class RuleRepository {
  // ---------------------------------------------------------------------------
  // Versions
  // ---------------------------------------------------------------------------

  /// Versions matching [query], newest `effective_from_ms` first.
  Future<List<DistributionRuleVersion>> versions({
    RuleVersionQuery query = const RuleVersionQuery(),
  });

  /// Reactive [versions].
  Stream<List<DistributionRuleVersion>> watchVersions({
    RuleVersionQuery query = const RuleVersionQuery(),
  });

  /// One version, or null when it does not exist or is tombstoned.
  Future<DistributionRuleVersion?> versionById(
    String id, {
    bool includeDeleted = false,
  });

  /// The editable version, if one exists. U-04 permits at most one unsealed
  /// version at a time, so this is a single value rather than a list.
  Future<DistributionRuleVersion?> draftVersion();

  /// The version in force at [atMs] — the newest whose `effective_from_ms` is
  /// at or before it.
  ///
  /// **This is what an income event resolves against**, and why the answer is a
  /// query rather than `app_settings.active_rule_version_id`: recording income
  /// that arrived last week must use last week's percentages, not today's.
  Future<DistributionRuleVersion?> versionEffectiveAt(int atMs);

  Future<Result<void, RepositoryFailure>> createVersion(
    DistributionRuleVersion version,
  );

  /// Fails with [RuleVersionSealed] once the version has been used.
  Future<Result<void, RepositoryFailure>> updateVersion(
    DistributionRuleVersion version,
  );

  /// Freezes the version's lines at [atMs]. Idempotent — sealing an
  /// already-sealed version keeps its original timestamp and reports success.
  Future<Result<void, RepositoryFailure>> sealVersion(
    String id, {
    required int atMs,
  });

  /// Tombstones the version. Fails with [RuleVersionSealed] for a sealed one:
  /// a sealed version is referenced by income events, and hiding it would make
  /// their history unexplainable.
  Future<Result<void, RepositoryFailure>> deleteVersion(String id);

  // ---------------------------------------------------------------------------
  // Lines
  // ---------------------------------------------------------------------------

  /// A version's shares. Serves Q11, read on every allocation.
  ///
  /// Ordered by `scope` then `id` so two devices holding the same version read
  /// it in the same order — the engine's group pass and category pass both
  /// depend on a stable iteration (INV-08).
  Future<List<RuleLine>> linesFor(
    String versionId, {
    RuleLineScope? scope,
    bool includeDeleted = false,
  });

  /// Reactive [linesFor], for the percentage editor.
  Stream<List<RuleLine>> watchLinesFor(String versionId);

  Future<Result<void, RepositoryFailure>> createLine(RuleLine line);

  Future<Result<void, RepositoryFailure>> updateLine(RuleLine line);

  Future<Result<void, RepositoryFailure>> deleteLine(String id);

  /// Replaces a draft version's entire line set **atomically**.
  ///
  /// The percentage editor's real operation. V-01 and V-02 require the shares
  /// to total exactly 10000, which no sequence of single-line writes can
  /// preserve: between "savings drops to 30" and "spending rises to 45" the
  /// stored configuration totals 95, and a background sync push or a crash in
  /// that window persists a set that no validator would have accepted.
  ///
  /// One transaction, one valid state before and after. Fails with
  /// [RuleVersionSealed] if the version has been used.
  Future<Result<void, RepositoryFailure>> replaceLines(
    String versionId,
    List<RuleLine> lines,
  );
}
