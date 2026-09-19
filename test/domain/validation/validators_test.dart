import 'package:flutter_test/flutter_test.dart';
import 'package:pookiebudget/domain/entities/account.dart';
import 'package:pookiebudget/domain/entities/category.dart';
import 'package:pookiebudget/domain/entities/category_group.dart';
import 'package:pookiebudget/domain/entities/enums.dart';
import 'package:pookiebudget/domain/entities/redirect_target.dart';
import 'package:pookiebudget/domain/entities/rule_line.dart';
import 'package:pookiebudget/domain/validation/validation_failure.dart';
import 'package:pookiebudget/domain/validation/validators.dart';

import '../../support/builders/config_builders.dart';

/// Substage 4.8.6 — *"a test for every rule with both a passing and a failing
/// case."*
///
/// Pure, with no database anywhere: the validators are functions over a
/// snapshot, which is what lets the write path, the post-merge pass and
/// onboarding all call the same code.
void main() {
  CategoryGroup spending({String id = 'g-spending'}) =>
      buildGroup(id: id, kind: CategoryGroupKind.spending, name: 'Spending');

  CategoryGroup savings({String id = 'g-savings'}) => buildGroup(
    id: id,
    kind: CategoryGroupKind.savings,
    name: 'Savings',
    sortOrder: 1,
  );

  RuleLine groupLine(String groupId, int bp, {String? id}) => buildGroupLine(
    id: id ?? 'line-g-$groupId',
    groupId: groupId,
    basisPoints: bp,
  );

  RuleLine categoryLine(String categoryId, int bp) => buildCategoryLine(
    id: 'line-c-$categoryId',
    categoryId: categoryId,
    basisPoints: bp,
  );

  /// A configuration that passes everything — the baseline each failing case
  /// perturbs by exactly one thing, so a failure names the change that caused
  /// it rather than the noise around it.
  ConfigurationSnapshot healthy() => ConfigurationSnapshot(
    groups: <CategoryGroup>[spending()],
    categories: <Category>[
      buildCategory(id: 'c-food', name: 'Food', groupId: 'g-spending'),
      buildSink(id: 'c-sink', groupId: 'g-spending'),
    ],
    ruleLines: <RuleLine>[
      groupLine('g-spending', 10000),
      categoryLine('c-food', 10000),
      categoryLine('c-sink', 0),
    ],
    redirectGraph: const <String, List<RedirectTarget>>{},
  );

  List<String> rulesOf(List<ValidationFailure> failures) =>
      failures.map((ValidationFailure f) => f.rule).toList();

  test('the baseline configuration is valid', () {
    expect(validateConfiguration(healthy()), isEmpty);
  });

  // ===========================================================================
  // V-01, V-02, V-03, V-04
  // ===========================================================================

  group('percentages', () {
    test('V-01 passes at exactly 10000 across groups', () {
      final ConfigurationSnapshot snapshot = ConfigurationSnapshot(
        groups: <CategoryGroup>[spending(), savings()],
        categories: <Category>[
          buildCategory(id: 'c-food', name: 'Food', groupId: 'g-spending'),
          buildCategory(id: 'c-hajj', name: 'Hajj', groupId: 'g-savings'),
        ],
        ruleLines: <RuleLine>[
          groupLine('g-spending', 6000),
          groupLine('g-savings', 4000),
          categoryLine('c-food', 10000),
          categoryLine('c-hajj', 10000),
        ],
        redirectGraph: const <String, List<RedirectTarget>>{},
      );
      expect(
        validatePercentages(snapshot).where(
          (ValidationFailure f) => f.rule == 'V-01',
        ),
        isEmpty,
      );
    });

    test('V-01 REJECTS 9999 AND 10001 ALIKE', () {
      for (final int total in <int>[9999, 10001]) {
        final ConfigurationSnapshot snapshot = ConfigurationSnapshot(
          groups: <CategoryGroup>[spending()],
          categories: <Category>[
            buildCategory(id: 'c-food', name: 'Food', groupId: 'g-spending'),
          ],
          ruleLines: <RuleLine>[
            groupLine('g-spending', total),
            categoryLine('c-food', 10000),
          ],
          redirectGraph: const <String, List<RedirectTarget>>{},
        );
        final List<ValidationFailure> failures = validatePercentages(snapshot);
        expect(rulesOf(failures), contains('V-01'), reason: 'total $total');

        final GroupSharesDoNotTotal failure =
            failures.whereType<GroupSharesDoNotTotal>().single;
        expect(failure.actualTotal, total);
        expect(failure.difference, total - 10000);
        // SCHEMA §6.9: the message names the offending value and what to
        // change. A bare "invalid percentages" leaves the user hunting.
        expect(failure.describe, contains('100%'));
      }
    });

    test('V-02 rejects a within-group total that is off by one', () {
      final ConfigurationSnapshot snapshot = ConfigurationSnapshot(
        groups: <CategoryGroup>[spending()],
        categories: <Category>[
          buildCategory(id: 'c-food', name: 'Food', groupId: 'g-spending'),
          buildCategory(
            id: 'c-fuel',
            name: 'Fuel',
            groupId: 'g-spending',
            sortOrder: 1,
          ),
        ],
        ruleLines: <RuleLine>[
          groupLine('g-spending', 10000),
          categoryLine('c-food', 5000),
          categoryLine('c-fuel', 4999),
        ],
        redirectGraph: const <String, List<RedirectTarget>>{},
      );
      final CategorySharesDoNotTotal failure = validatePercentages(snapshot)
          .whereType<CategorySharesDoNotTotal>()
          .single;
      expect(failure.actualTotal, 9999);
      expect(failure.groupName, 'Spending');
    });

    test('V-02 counts live categories only', () {
      // An archived category still holding a share would make the total look
      // right while a slice of the income had nowhere to land.
      final ConfigurationSnapshot snapshot = ConfigurationSnapshot(
        groups: <CategoryGroup>[spending()],
        categories: <Category>[
          buildCategory(id: 'c-food', name: 'Food', groupId: 'g-spending'),
          buildCategory(
            id: 'c-old',
            name: 'Old',
            groupId: 'g-spending',
            sortOrder: 1,
            isArchived: true,
          ),
        ],
        ruleLines: <RuleLine>[
          groupLine('g-spending', 10000),
          categoryLine('c-food', 6000),
          categoryLine('c-old', 4000),
        ],
        redirectGraph: const <String, List<RedirectTarget>>{},
      );
      expect(
        rulesOf(validatePercentages(snapshot)),
        contains('V-02'),
        reason: 'only 6000 of the 10000 can actually be allocated',
      );
    });

    test('V-03 — a group with a ZERO share may be empty', () {
      // The personal-only case (PRD A-20). Permitted, so it must produce
      // nothing at all — not a warning, not a failure.
      final ConfigurationSnapshot snapshot = ConfigurationSnapshot(
        groups: <CategoryGroup>[spending(), savings()],
        categories: <Category>[
          buildCategory(id: 'c-food', name: 'Food', groupId: 'g-spending'),
        ],
        ruleLines: <RuleLine>[
          groupLine('g-spending', 10000),
          groupLine('g-savings', 0),
          categoryLine('c-food', 10000),
        ],
        redirectGraph: const <String, List<RedirectTarget>>{},
      );
      expect(validatePercentages(snapshot), isEmpty);
    });

    test('V-04 — a group with a NON-zero share must have a category', () {
      final ConfigurationSnapshot snapshot = ConfigurationSnapshot(
        groups: <CategoryGroup>[spending(), savings()],
        categories: <Category>[
          buildCategory(id: 'c-food', name: 'Food', groupId: 'g-spending'),
        ],
        ruleLines: <RuleLine>[
          groupLine('g-spending', 7000),
          groupLine('g-savings', 3000),
          categoryLine('c-food', 10000),
        ],
        redirectGraph: const <String, List<RedirectTarget>>{},
      );
      final GroupHasNoCategories failure = validatePercentages(snapshot)
          .whereType<GroupHasNoCategories>()
          .single;
      expect(failure.groupName, 'Savings');
      expect(failure.describe, contains('30%'));
    });

    test('an unconfigured version reports nothing', () {
      // "Not configured yet" is not "configured wrongly". Failing every fresh
      // install teaches people to ignore the result.
      final ConfigurationSnapshot snapshot = ConfigurationSnapshot(
        groups: <CategoryGroup>[spending()],
        categories: const <Category>[],
        ruleLines: const <RuleLine>[],
        redirectGraph: const <String, List<RedirectTarget>>{},
      );
      expect(validatePercentages(snapshot), isEmpty);
    });
  });

  // ===========================================================================
  // V-09, V-11, V-12, V-28, V-29, V-30
  // ===========================================================================

  group('redirects', () {
    ConfigurationSnapshot withGraph(
      Map<String, List<RedirectTarget>> graph, {
      List<Category>? categories,
    }) => ConfigurationSnapshot(
      groups: <CategoryGroup>[spending()],
      categories:
          categories ??
          <Category>[
            buildCategory(id: 'c-bike', name: 'Bike', groupId: 'g-spending'),
            buildCategory(
              id: 'c-hajj',
              name: 'Hajj',
              groupId: 'g-spending',
              sortOrder: 1,
            ),
            buildSink(id: 'c-sink', groupId: 'g-spending'),
          ],
      ruleLines: const <RuleLine>[],
      redirectGraph: graph,
    );

    test('a live target passes', () {
      expect(
        validateRedirects(
          withGraph(<String, List<RedirectTarget>>{
            'c-bike': <RedirectTarget>[
              buildRedirectTarget(
                sourceCategoryId: 'c-bike',
                targetCategoryId: 'c-sink',
              ),
            ],
          }),
        ),
        isEmpty,
      );
    });

    test('V-28 — a target that no longer exists is reported', () {
      final RedirectTargetMissing failure = validateRedirects(
        withGraph(<String, List<RedirectTarget>>{
          'c-bike': <RedirectTarget>[
            buildRedirectTarget(
              sourceCategoryId: 'c-bike',
              targetCategoryId: 'c-gone',
            ),
          ],
        }),
      ).whereType<RedirectTargetMissing>().single;
      expect(failure.sourceName, 'Bike');
      expect(failure.rule, 'V-28');
    });

    test('V-11 — an archived target is reported, and named', () {
      final RedirectTargetArchived failure = validateRedirects(
        withGraph(
          <String, List<RedirectTarget>>{
            'c-bike': <RedirectTarget>[
              buildRedirectTarget(
                sourceCategoryId: 'c-bike',
                targetCategoryId: 'c-hajj',
              ),
            ],
          },
          categories: <Category>[
            buildCategory(id: 'c-bike', name: 'Bike', groupId: 'g-spending'),
            buildCategory(
              id: 'c-hajj',
              name: 'Hajj',
              groupId: 'g-spending',
              sortOrder: 1,
              isArchived: true,
            ),
          ],
        ),
      ).whereType<RedirectTargetArchived>().single;
      expect(failure.targetName, 'Hajj');
      expect(failure.describe, contains('Hajj'));
    });

    test('V-12 — A CYCLE IS REPORTED, AND THE MESSAGE NAMES IT', () {
      final RedirectCycle failure = validateRedirects(
        withGraph(<String, List<RedirectTarget>>{
          'c-bike': <RedirectTarget>[
            buildRedirectTarget(
              id: 'r1',
              sourceCategoryId: 'c-bike',
              targetCategoryId: 'c-hajj',
            ),
          ],
          'c-hajj': <RedirectTarget>[
            buildRedirectTarget(
              id: 'r2',
              sourceCategoryId: 'c-hajj',
              targetCategoryId: 'c-bike',
            ),
          ],
        }),
      ).whereType<RedirectCycle>().single;

      // SCHEMA V-12's disposition: "block; name the cycle by listing the
      // categories in it". Names, not ids — the user cannot look up an id.
      expect(failure.categoryNames, contains('Bike'));
      expect(failure.categoryNames, contains('Hajj'));
      expect(failure.describe, contains('Bike'));
    });

    test('V-29 — a SPLIT whose live shares miss 10000 is reported', () {
      final RedirectSplitDoesNotTotal failure = validateRedirects(
        withGraph(
          <String, List<RedirectTarget>>{
            'c-bike': <RedirectTarget>[
              buildRedirectTarget(
                id: 'r1',
                sourceCategoryId: 'c-bike',
                targetCategoryId: 'c-hajj',
                basisPoints: 6000,
              ),
              buildRedirectTarget(
                id: 'r2',
                sourceCategoryId: 'c-bike',
                targetCategoryId: 'c-sink',
                priority: 1,
                basisPoints: 3000,
              ),
            ],
          },
          categories: <Category>[
            buildCategory(
              id: 'c-bike',
              name: 'Bike',
              groupId: 'g-spending',
              redirectMode: RedirectMode.split,
            ),
            buildCategory(
              id: 'c-hajj',
              name: 'Hajj',
              groupId: 'g-spending',
              sortOrder: 1,
            ),
            buildSink(id: 'c-sink', groupId: 'g-spending'),
          ],
        ),
      ).whereType<RedirectSplitDoesNotTotal>().single;
      expect(failure.actualTotal, 9000);
    });

    test('V-30 — shares under PRIORITY are reported', () {
      final RedirectModeInconsistent failure = validateRedirects(
        withGraph(<String, List<RedirectTarget>>{
          'c-bike': <RedirectTarget>[
            buildRedirectTarget(
              sourceCategoryId: 'c-bike',
              targetCategoryId: 'c-sink',
              basisPoints: 10000,
            ),
          ],
        }),
      ).whereType<RedirectModeInconsistent>().single;
      expect(failure.modeWireName, 'PRIORITY');
    });
  });

  // ===========================================================================
  // V-13, V-14, V-15
  // ===========================================================================

  group('the sink', () {
    test('V-13 passes when a usable sink exists', () {
      expect(validateSinks(healthy()), isEmpty);
    });

    test('V-13 — a group with categories but no sink is reported', () {
      final ConfigurationSnapshot snapshot = ConfigurationSnapshot(
        groups: <CategoryGroup>[spending()],
        categories: <Category>[
          buildCategory(id: 'c-food', name: 'Food', groupId: 'g-spending'),
        ],
        ruleLines: const <RuleLine>[],
        redirectGraph: const <String, List<RedirectTarget>>{},
      );
      expect(validateSinks(snapshot).whereType<SinkUnusable>().single.rule,
          'V-13');
    });

    test('V-13 — an archived sink is reported', () {
      final ConfigurationSnapshot snapshot = ConfigurationSnapshot(
        groups: <CategoryGroup>[spending()],
        categories: <Category>[
          buildCategory(id: 'c-food', name: 'Food', groupId: 'g-spending'),
          buildSink(id: 'c-sink', groupId: 'g-spending').copyWith(
            isArchived: true,
          ).valueOrNull!,
        ],
        ruleLines: const <RuleLine>[],
        redirectGraph: const <String, List<RedirectTarget>>{},
      );
      expect(
        validateSinks(snapshot).whereType<SinkUnusable>().single.describe,
        contains('hidden'),
      );
    });

    test('an empty group needs no sink', () {
      // Demanding one of a group with no categories would fail every install
      // before its first category.
      final ConfigurationSnapshot snapshot = ConfigurationSnapshot(
        groups: <CategoryGroup>[spending(), savings()],
        categories: <Category>[
          buildCategory(id: 'c-food', name: 'Food', groupId: 'g-spending'),
          buildSink(id: 'c-sink', groupId: 'g-spending'),
        ],
        ruleLines: const <RuleLine>[],
        redirectGraph: const <String, List<RedirectTarget>>{},
      );
      expect(validateSinks(snapshot), isEmpty);
    });

    test('V-15 — the sink can be neither deleted nor hidden', () {
      expect(
        validateCanDelete(healthy(), 'c-sink').single,
        isA<SinkNotRemovable>(),
      );
      expect(
        validateCanArchive(healthy(), 'c-sink').single,
        isA<SinkNotRemovable>(),
      );
      expect(validateCanDelete(healthy(), 'c-food'), isEmpty);
    });

    test('V-14 — ARCHIVING A REDIRECT TARGET IS REFUSED, NAMING THE DEPENDANT',
        () {
      final ConfigurationSnapshot snapshot = ConfigurationSnapshot(
        groups: <CategoryGroup>[spending()],
        categories: <Category>[
          buildCategory(id: 'c-bike', name: 'Bike', groupId: 'g-spending'),
          buildCategory(
            id: 'c-hajj',
            name: 'Hajj',
            groupId: 'g-spending',
            sortOrder: 1,
          ),
        ],
        ruleLines: const <RuleLine>[],
        redirectGraph: <String, List<RedirectTarget>>{
          'c-bike': <RedirectTarget>[
            buildRedirectTarget(
              sourceCategoryId: 'c-bike',
              targetCategoryId: 'c-hajj',
            ),
          ],
        },
      );

      final RedirectTargetStillDependedOn failure =
          validateCanArchive(snapshot, 'c-hajj')
              .whereType<RedirectTargetStillDependedOn>()
              .single;
      // Substage 4.8.3 requires the error to name the dependant. Saying only
      // "cannot hide" leaves the user searching thirty categories for it.
      expect(failure.dependantNames, <String>['Bike']);
      expect(failure.describe, contains('Bike'));

      // And the other direction is fine — nothing points at Bike.
      expect(validateCanArchive(snapshot, 'c-bike'), isEmpty);
    });
  });

  // ===========================================================================
  // V-21, V-24
  // ===========================================================================

  group('accounts and currency', () {
    test('V-21 — an account with linked categories names them', () {
      final ConfigurationSnapshot snapshot = ConfigurationSnapshot(
        groups: <CategoryGroup>[spending()],
        categories: <Category>[
          buildCategory(
            id: 'c-food',
            name: 'Food',
            groupId: 'g-spending',
            linkedAccountId: 'acc-1',
          ),
        ],
        ruleLines: const <RuleLine>[],
        redirectGraph: const <String, List<RedirectTarget>>{},
        accounts: <Account>[buildAccount(id: 'acc-1', name: 'Current')],
      );
      final AccountStillLinked failure =
          validateCanDeleteAccount(snapshot, 'acc-1')
              .whereType<AccountStillLinked>()
              .single;
      expect(failure.linkedCategoryNames, <String>['Food']);
      expect(failure.describe, contains('Food'));
    });

    test('V-21 — an unlinked account is deletable', () {
      final ConfigurationSnapshot snapshot = ConfigurationSnapshot(
        groups: <CategoryGroup>[spending()],
        categories: <Category>[
          buildCategory(id: 'c-food', name: 'Food', groupId: 'g-spending'),
        ],
        ruleLines: const <RuleLine>[],
        redirectGraph: const <String, List<RedirectTarget>>{},
        accounts: <Account>[buildAccount(id: 'acc-1', name: 'Current')],
      );
      expect(validateCanDeleteAccount(snapshot, 'acc-1'), isEmpty);
    });

    test('V-24 — the exponent is free to change while no money exists', () {
      expect(
        validateCurrencyChange(
          stored: buildSettings(currencyMinorExponent: 2),
          incoming: buildSettings(
            currencyCode: 'JPY',
            currencyMinorExponent: 0,
          ),
          ledgerEntryCount: 0,
        ),
        isEmpty,
      );
    });

    test('V-24 — and locked once it does', () {
      final CurrencyNotImmutable failure = validateCurrencyChange(
        stored: buildSettings(currencyMinorExponent: 2),
        incoming: buildSettings(currencyCode: 'JPY', currencyMinorExponent: 0),
        ledgerEntryCount: 7,
      ).whereType<CurrencyNotImmutable>().single;
      expect(failure.ledgerEntryCount, 7);
      expect(failure.storedExponent, 2);
      expect(failure.attemptedExponent, 0);
    });

    test('V-24 — renaming the currency is not a change to the exponent', () {
      // Only the exponent reinterprets stored integers. Renaming PKR to RS is
      // cosmetic, so it stays permitted even with money recorded.
      expect(
        validateCurrencyChange(
          stored: buildSettings(currencyCode: 'PKR'),
          incoming: buildSettings(currencyCode: 'RS'),
          ledgerEntryCount: 500,
        ),
        isEmpty,
      );
    });
  });

  // ===========================================================================
  // Scoping
  // ===========================================================================

  test('scopes narrow what is checked', () {
    final ConfigurationSnapshot broken = ConfigurationSnapshot(
      groups: <CategoryGroup>[spending()],
      categories: <Category>[
        buildCategory(id: 'c-food', name: 'Food', groupId: 'g-spending'),
      ],
      ruleLines: <RuleLine>[
        groupLine('g-spending', 9999),
        categoryLine('c-food', 10000),
      ],
      redirectGraph: const <String, List<RedirectTarget>>{},
    );

    // Percentages are wrong AND the sink is missing. A redirect-scoped write
    // must not be blocked by either — it broke neither.
    expect(
      validateConfiguration(
        broken,
        scopes: const <ValidationScope>{ValidationScope.redirects},
      ),
      isEmpty,
    );
    expect(
      rulesOf(
        validateConfiguration(
          broken,
          scopes: const <ValidationScope>{ValidationScope.percentages},
        ),
      ),
      <String>['V-01'],
    );
    // Everything, which is what the post-merge pass uses.
    expect(
      rulesOf(validateConfiguration(broken)),
      containsAll(<String>['V-01', 'V-13']),
    );
  });
}
