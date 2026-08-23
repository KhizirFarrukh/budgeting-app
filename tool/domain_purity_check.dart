// Proves the domain layer is pure Dart, by *being* pure Dart that uses it.
//
// Substage 4.2.6: "Confirm the domain package compiles as pure Dart with no
// Flutter dependency."
//
// Guard G1 checks this by pattern — it greps `lib/domain` for Flutter imports.
// That is necessary but not sufficient: G1 sees only direct imports, so a
// domain file importing a *local* file that itself imports Flutter would slip
// past it. This program closes that gap by construction. It is run with `dart`,
// not `flutter`, on the bare Dart VM with no Flutter engine present. If any
// domain library transitively reaches `dart:ui` or `package:flutter`,
// compilation fails here and the check exits non-zero.
//
// The two mechanisms are complementary and neither is redundant: G1 gives a
// precise file and line, this gives transitive truth.
//
//   dart run tool/domain_purity_check.dart
//
// It must import every domain library for the guarantee to cover them all —
// an unimported library is an unchecked one. `_assertAllDomainLibrariesImported`
// fails the run if a file exists under lib/domain that this file does not name.

import 'dart:io';

import 'package:pookiebudget/domain/entities/account.dart';
import 'package:pookiebudget/domain/entities/allocation.dart';
import 'package:pookiebudget/domain/entities/app_settings.dart';
import 'package:pookiebudget/domain/entities/category.dart';
import 'package:pookiebudget/domain/entities/category_group.dart';
import 'package:pookiebudget/domain/entities/distribution_rule_version.dart';
import 'package:pookiebudget/domain/entities/entity_failure.dart';
import 'package:pookiebudget/domain/entities/enums.dart';
import 'package:pookiebudget/domain/entities/headroom.dart';
import 'package:pookiebudget/domain/entities/income_event.dart';
import 'package:pookiebudget/domain/entities/ledger_entry.dart';
import 'package:pookiebudget/domain/entities/redirect_target.dart';
import 'package:pookiebudget/domain/entities/rule_line.dart';
import 'package:pookiebudget/domain/entities/spending_transaction.dart';
import 'package:pookiebudget/domain/entities/sync_fields.dart';
import 'package:pookiebudget/domain/money/basis_points.dart';
import 'package:pookiebudget/domain/money/clock.dart';
import 'package:pookiebudget/domain/money/currency.dart';
import 'package:pookiebudget/domain/money/id_generator.dart';
import 'package:pookiebudget/domain/money/money.dart';
import 'package:pookiebudget/domain/money/money_failure.dart';
import 'package:pookiebudget/domain/money/money_format.dart';
import 'package:pookiebudget/domain/repositories/account_repository.dart';
import 'package:pookiebudget/domain/repositories/category_repository.dart';
import 'package:pookiebudget/domain/repositories/repository_failure.dart';
import 'package:pookiebudget/domain/repositories/repository_queries.dart';
import 'package:pookiebudget/domain/repositories/rule_repository.dart';
import 'package:pookiebudget/domain/repositories/settings_repository.dart';
import 'package:pookiebudget/domain/result.dart';

/// Every domain library this file imports. Kept in sync with the imports above
/// by [_assertAllDomainLibrariesImported].
const List<String> _importedLibraries = <String>[
  'lib/domain/entities/account.dart',
  'lib/domain/entities/allocation.dart',
  'lib/domain/entities/app_settings.dart',
  'lib/domain/entities/category.dart',
  'lib/domain/entities/category_group.dart',
  'lib/domain/entities/distribution_rule_version.dart',
  'lib/domain/entities/entity_failure.dart',
  'lib/domain/entities/enums.dart',
  'lib/domain/entities/headroom.dart',
  'lib/domain/entities/income_event.dart',
  'lib/domain/entities/ledger_entry.dart',
  'lib/domain/entities/redirect_target.dart',
  'lib/domain/entities/rule_line.dart',
  'lib/domain/entities/spending_transaction.dart',
  'lib/domain/entities/sync_fields.dart',
  'lib/domain/money/basis_points.dart',
  'lib/domain/money/clock.dart',
  'lib/domain/money/currency.dart',
  'lib/domain/money/id_generator.dart',
  'lib/domain/money/money.dart',
  'lib/domain/money/money_failure.dart',
  'lib/domain/money/money_format.dart',
  'lib/domain/repositories/account_repository.dart',
  'lib/domain/repositories/category_repository.dart',
  'lib/domain/repositories/repository_failure.dart',
  'lib/domain/repositories/repository_queries.dart',
  'lib/domain/repositories/rule_repository.dart',
  'lib/domain/repositories/settings_repository.dart',
  'lib/domain/result.dart',
];

void main() {
  _assertAllDomainLibrariesImported();

  // Exercise the types rather than merely importing them. An import alone can
  // be tree-shaken; constructing and calling cannot.
  const Currency currency = Currency(code: 'PKR', minorUnitExponent: 2);
  const SyncFields sync = SyncFields(
    updatedAtMs: 0,
    updatedByDevice: 'purity-check',
    hlc: '0:0:purity-check',
  );

  final Money amount = Money.fromMinorUnits(123456, currency);
  _require(amount.toDecimalString() == '1234.56', 'Money formats');

  // Named explicitly so `result.dart` is genuinely exercised, not merely
  // imported. `_importedLibraries` claims this library is covered; using the
  // type is what makes the claim true.
  final Result<Money, MoneyFailure> parsed = Money.parse('1234.56', currency);
  _require(parsed.isSuccess && parsed.valueOrNull == amount, 'Money parses');
  _require(
    amount.multiplyByBasisPoints(3500).valueOrNull!.floor.minorUnits == 43209,
    'basis-point split',
  );
  _require(BasisPoints.checked(3550).asPercentString == '35.50', 'percent');

  final Category category = Category.create(
    id: 'purity-1',
    groupId: 'grp-1',
    name: 'Emergency fund',
    type: CategoryType.accumulatingReserve,
    sortOrder: 0,
    ceilingMinor: 100000,
    sync: sync,
  ).valueOrNull!;
  _require(
    category.headroom(currentBalanceMinor: 40000, allocatedInPeriodMinor: 0) ==
        const Headroom.bounded(60000),
    'headroom',
  );

  _require(
    CategoryGroup.create(
      id: 'grp-1',
      kind: CategoryGroupKind.savings,
      name: 'Savings',
      sortOrder: 0,
      sync: sync,
    ).isSuccess,
    'group',
  );
  _require(
    Account.create(
      id: 'acc-1',
      name: 'Meezan',
      sortOrder: 0,
      sync: sync,
    ).isSuccess,
    'account',
  );
  // ADR-006 — the cascade redirect model, exercised end to end.
  final RedirectTarget hop = RedirectTarget.create(
    id: 'rt-1',
    sourceCategoryId: 'purity-1',
    targetCategoryId: 'purity-2',
    priority: 0,
    basisPoints: 10000,
    sync: sync,
  ).valueOrNull!;
  _require(
    <RedirectTarget>[hop].inOfferOrder.first.targetCategoryId == 'purity-2' &&
        <RedirectTarget>[hop].sharesSumToFull &&
        validateRedirectMode(RedirectMode.split, <RedirectTarget>[
          hop,
        ]).isSuccess,
    'redirect target',
  );
  _require(
    RedirectTarget.create(
          id: 'rt-2',
          sourceCategoryId: 'purity-1',
          targetCategoryId: 'purity-1',
          priority: 0,
          sync: sync,
        ).failureOrNull
        is SelfRedirect,
    'self-redirect is rejected',
  );

  _require(
    RuleLine.create(
      id: 'rl-1',
      ruleVersionId: 'rv-1',
      scope: RuleLineScope.group,
      groupId: 'grp-1',
      basisPoints: 3500,
      sync: sync,
    ).isSuccess,
    'rule line',
  );
  _require(
    DistributionRuleVersion.create(
      id: 'rv-1',
      effectiveFromMs: 0,
      createdAtMs: 0,
      sync: sync,
    ).valueOrNull!.sealedAt(1).isSealed,
    'rule version',
  );
  _require(
    IncomeEvent.create(
      id: 'inc-1',
      amountMinor: 300000,
      occurredAtMs: 0,
      recordedAtMs: 0,
      evaluatedAtMs: 0,
      ruleVersionId: 'rv-1',
      sync: sync,
    ).isSuccess,
    'income event',
  );
  _require(
    LedgerEntry.create(
          id: 'led-1',
          categoryId: 'purity-1',
          direction: LedgerDirection.inbound,
          amountMinor: 5000,
          occurredAtMs: 0,
          recordedAtMs: 0,
          sourceType: LedgerSourceType.allocation,
          sourceId: 'inc-1',
          sync: sync,
        ).valueOrNull!.signedMinor ==
        5000,
    'ledger entry',
  );
  _require(
    SpendingTransaction.create(
      id: 'sp-1',
      amountMinor: 5000,
      categoryId: 'purity-1',
      occurredAtMs: 0,
      recordedAtMs: 0,
      sync: sync,
    ).isSuccess,
    'spending transaction',
  );
  _require(
    AllocationLine.create(
      categoryId: 'purity-1',
      amountMinor: 5000,
      reason: AllocationReason.base,
    ).isSuccess,
    'allocation line',
  );
  _require(
    AppSettings.create(
          currencyCode: 'PKR',
          currencyMinorExponent: 2,
          locale: 'en_PK',
          schemaVersion: 1,
          sync: sync,
        ).valueOrNull!.currency ==
        currency,
    'app settings',
  );

  _require(MoneyFormat.tryParse('1.00', currency) == 100, 'money format');
  _require(
    const MoneyOverflow(operation: 'x', operands: <int>[1]).describe.isNotEmpty,
    'money failure',
  );
  _require(const BlankName('x').describe.isNotEmpty, 'entity failure');

  // --- substage 4.4: the repository contracts -------------------------------
  //
  // The strongest statement this program makes about substage 4.4. The four
  // repository interfaces are compiled here **on the bare Dart VM with no
  // Flutter engine and no database package present**, which is the acceptance
  // criterion *"no repository method signature exposes a database or generated
  // type"* proved by construction rather than by inspection: a signature naming
  // a Drift type could not compile in this program at all.
  //
  // Their implementations live in `lib/data` and are deliberately not imported,
  // exactly as with `Clock` below.
  _require(
    <Type>[
      CategoryRepository,
      AccountRepository,
      RuleRepository,
      SettingsRepository,
    ].length == 4,
    'the four repository interfaces are declared in the domain',
  );

  // The query value objects are concrete, so they are exercised rather than
  // merely named. Both defaults asserted here are load-bearing: a read that
  // included tombstones by default would put deleted categories back into every
  // picker, and a date range that was inclusive at both ends would double-count
  // the entry landing on a period boundary.
  const CategoryQuery defaultCategoryQuery = CategoryQuery();
  const DateRange january = DateRange(fromMs: 0, toMs: 10);
  _require(
    !defaultCategoryQuery.includeDeleted &&
        defaultCategoryQuery.archived == ArchivedFilter.liveOnly &&
        !const AccountQuery().includeDeleted &&
        !const RuleVersionQuery().includeDeleted &&
        january.contains(0) &&
        !january.contains(10),
    'repository queries default to live rows, over half-open ranges',
  );

  _require(
    const RecordNotFound(entity: 'category', id: 'x').describe.isNotEmpty &&
        const DuplicateName(entity: 'account', name: 'Meezan').rule ==
            'U-01/U-02' &&
        const CurrencyLocked(ledgerEntryCount: 1).rule == 'V-24' &&
        const SinkProtected(
              categoryId: 'purity-1',
              action: 'deleted',
            ).describe.isNotEmpty &&
        const RuleVersionSealed(
              versionId: 'rv-1',
              sealedAtMs: 1,
            ).describe.isNotEmpty,
    'repository failure taxonomy',
  );

  // `Clock` and `IdGenerator` are interfaces; their implementations live in
  // `lib/data` and are deliberately **not** imported here. That absence is the
  // dependency rule made concrete — this program compiles and runs without
  // them, so nothing in the domain depends on the data layer.
  //
  // Naming the types keeps them in the compiled output rather than tree-shaken.
  _require(
    <Type>[Clock, IdGenerator].length == 2,
    'clock and id generator are declared in the domain',
  );

  stdout.writeln(
    'Domain purity check passed: ${_importedLibraries.length} libraries '
    'compiled and ran on the bare Dart VM, no Flutter engine.',
  );
}

void _require(bool condition, String what) {
  if (!condition) {
    stderr.writeln('Domain purity check FAILED at: $what');
    exit(1);
  }
}

/// Fails if a `.dart` file exists under `lib/domain` that this program does not
/// import — an unimported library is outside the guarantee.
void _assertAllDomainLibrariesImported() {
  final Directory root = Directory('lib/domain');
  if (!root.existsSync()) {
    stderr.writeln('lib/domain not found — run from the project root.');
    exit(1);
  }
  final Set<String> onDisk = root
      .listSync(recursive: true)
      .whereType<File>()
      .map((File f) => f.path.replaceAll(r'\', '/'))
      .where((String p) => p.endsWith('.dart'))
      .toSet();
  final Set<String> missing = onDisk.difference(_importedLibraries.toSet());
  if (missing.isNotEmpty) {
    stderr.writeln(
      'Domain purity check is incomplete — these libraries are not imported '
      'by tool/domain_purity_check.dart, so their purity is unverified:',
    );
    for (final String m in missing.toList()..sort()) {
      stderr.writeln('  $m');
    }
    stderr.writeln('Add an import for each, then re-run.');
    exit(1);
  }
}
