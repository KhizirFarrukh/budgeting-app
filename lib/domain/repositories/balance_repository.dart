import 'package:pookiebudget/domain/allocation/period.dart';

/// Balances, and the verification that keeps them trustworthy.
///
/// # There is no setter, anywhere in this file
///
/// INV-04: a balance is a **derived value**. Substage 4.6's `must_not` is one
/// line — *"do not expose a setter for a balance"* — and the reason is in the
/// substage's own rationale: *"a stored balance that nobody can re-derive is a
/// number nobody can trust after the first sync merge."*
///
/// [recomputeAll] is not a setter in disguise. A setter takes a number from its
/// caller; `recomputeAll` takes nothing and reads the ledger. The distinction is
/// the whole invariant: every value this interface can produce is a function of
/// `ledger_entries`, and nothing else can put a number into the cache.
///
/// # Why a cache exists at all
///
/// SCHEMA §7.1 chose Option B — a cache table with mandatory verification —
/// on measured grounds. The dashboard shows every category and re-renders on
/// every reactive emit, **including background sync writes**; a grouped scan of
/// the ledger costs 40–80 ms at the Heavy profile, which is affordable per
/// navigation and wasteful per emit.
///
/// The price of that choice is this interface's second half. A cache nobody
/// verifies is the substage's named pitfall: *"a cached balance updated on
/// write but never verified, which drifts after a sync merge and is discovered
/// by a user."*
abstract interface class BalanceRepository {
  // ---------------------------------------------------------------------------
  // Derived — the source of truth
  // ---------------------------------------------------------------------------

  /// A category's balance, computed from `ledger_entries` alone. Serves Q1.
  ///
  /// **May legitimately be negative** — a category can be overspent — so
  /// callers must not treat a negative result as an error.
  Future<int> derivedBalanceOf(String categoryId);

  /// Every category's balance, computed from the ledger in one grouped scan.
  ///
  /// Categories with no entries are present with a balance of zero, rather than
  /// absent. A dashboard that dropped them would silently hide a bucket the
  /// user created and has not funded yet, which reads as the app forgetting it.
  Future<Map<String, int>> derivedBalances();

  /// How much was allocated to a category within [period].
  ///
  /// The headroom input for a `FIXED_RECURRING` category, which caps per period
  /// rather than per balance. The period arrives as an argument — substage
  /// 4.6.2: *"take the period definition as an input rather than computing it
  /// from the system clock here"* — so no derivation reads a clock (INV-09).
  Future<int> allocatedInPeriod(String categoryId, PeriodDefinition period);

  /// An account's total: the sum of the balances of the categories linked to
  /// it. Serves Q12.
  ///
  /// **An account holds no money of its own.** There is no `accounts.balance_minor`
  /// column and there will not be one; adding it would create a second source
  /// of truth (INV-04). This is the derived total the absence implies.
  Future<int> accountTotal(String accountId);

  // ---------------------------------------------------------------------------
  // Cached — the fast path
  // ---------------------------------------------------------------------------

  /// Every cached balance. Fast, and correct only as far as the verifier says.
  Future<Map<String, int>> cachedBalances();

  /// Reactive [cachedBalances] — what the dashboard watches.
  Stream<Map<String, int>> watchCachedBalances();

  // ---------------------------------------------------------------------------
  // Verification
  // ---------------------------------------------------------------------------

  /// Compares the ledger against the cache and **returns** what disagrees.
  ///
  /// Never throws on a discrepancy: substage 4.6.4 requires it to run as a
  /// diagnostic, and a diagnostic that crashes on finding the thing it went
  /// looking for is not one. An empty list means healthy.
  ///
  /// [full] selects the tier (SCHEMA §7.1):
  ///
  /// - **false — cheap.** One grouped `COUNT(*)` per category against the
  ///   cached `entry_count`. Every cold start. Catches the realistic failure:
  ///   entries written without the cache being updated.
  /// - **true — full.** Grouped `SUM` recomputation compared value by value.
  ///   After **every** sync merge, before every export, on user request, and
  ///   whenever the cheap tier disagrees.
  ///
  /// **A merge is never trusted** — S07.6.5 always runs the full tier.
  Future<List<BalanceDiscrepancy>> verify({bool full = true});

  /// Rebuilds every cache row from the ledger, clearing stale flags.
  ///
  /// The repair paired with [verify]. Takes no balance from any caller — see
  /// the class comment on why this is not a setter.
  Future<void> recomputeAll();
}

/// One disagreement between the ledger and the cache.
final class BalanceDiscrepancy {
  const BalanceDiscrepancy({
    required this.categoryId,
    required this.kind,
    required this.derivedMinor,
    required this.cachedMinor,
    required this.derivedEntryCount,
    required this.cachedEntryCount,
  });

  final String categoryId;
  final DiscrepancyKind kind;

  /// What the ledger says. **Always the correct value** — this is the source of
  /// truth, and the cache is what needs fixing.
  final int derivedMinor;

  /// What the cache says. Null when no cache row exists.
  final int? cachedMinor;

  final int derivedEntryCount;

  /// Null when no cache row exists.
  final int? cachedEntryCount;

  /// How far out the cache is, signed. Zero for a composition-only mismatch.
  int get driftMinor => derivedMinor - (cachedMinor ?? 0);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is BalanceDiscrepancy &&
          runtimeType == other.runtimeType &&
          categoryId == other.categoryId &&
          kind == other.kind &&
          derivedMinor == other.derivedMinor &&
          cachedMinor == other.cachedMinor &&
          derivedEntryCount == other.derivedEntryCount &&
          cachedEntryCount == other.cachedEntryCount;

  @override
  int get hashCode => Object.hash(
    categoryId,
    kind,
    derivedMinor,
    cachedMinor,
    derivedEntryCount,
    cachedEntryCount,
  );

  @override
  String toString() =>
      'BalanceDiscrepancy($categoryId, ${kind.name}, '
      'derived $derivedMinor / cached $cachedMinor, '
      'entries $derivedEntryCount / $cachedEntryCount)';
}

/// What kind of disagreement was found.
///
/// Separate values rather than one "mismatch", because they have different
/// causes and a diagnostic screen that cannot tell them apart cannot help
/// anyone.
enum DiscrepancyKind {
  /// The cached total differs from the ledger's. The cache missed a write, or
  /// an incremental update applied the wrong amount.
  balanceMismatch,

  /// The totals agree but the entry counts do not.
  ///
  /// **Two errors that cancel** — the case a balance comparison alone reports
  /// as healthy. A merge that imported one entry and dropped another of equal
  /// magnitude produces exactly this, and it is why `entry_count` exists
  /// (ADR-007).
  entryCountMismatch,

  /// The category has ledger entries but no cache row at all.
  missingCacheRow,

  /// A cache row for a category that no longer exists. Harmless to a balance,
  /// but it means something deleted a category without clearing its cache.
  orphanCacheRow,

  /// The row is flagged stale and has not been recomputed. Not an error —
  /// a merge sets this deliberately — but it is a discrepancy in the sense that
  /// the cached value must not be displayed until it is resolved.
  staleFlagSet,
}
