import 'package:flutter_test/flutter_test.dart';
import 'package:pookiebudget/domain/entities/redirect_target.dart';
import 'package:pookiebudget/domain/validation/cycle_detection.dart';

import '../../support/builders/config_builders.dart';

/// Substage 4.8.2 — SCHEMA V-12.
///
/// The named pitfall is *"cycle detection that only checks the direct target,
/// missing a three-node loop."* Every test below that grows the loop is aimed
/// at it: a pair check passes the two-node test and fails everything after it.
void main() {
  /// Builds a graph from `{source: [targets]}`.
  ///
  /// Priorities are assigned by position so U-12 (one row per source at each
  /// priority) is respected — a fixture that violated a unique index would be
  /// testing a graph the database could never hold.
  Map<String, List<RedirectTarget>> graphOf(Map<String, List<String>> edges) =>
      <String, List<RedirectTarget>>{
        for (final MapEntry<String, List<String>> entry in edges.entries)
          entry.key: <RedirectTarget>[
            for (int i = 0; i < entry.value.length; i++)
              buildRedirectTarget(
                id: '${entry.key}->${entry.value[i]}',
                sourceCategoryId: entry.key,
                targetCategoryId: entry.value[i],
                priority: i,
              ),
          ],
      };

  group('acyclic graphs are accepted', () {
    test('an empty graph has no cycle', () {
      expect(findAnyCycle(<String, List<RedirectTarget>>{}), isNull);
    });

    test('a simple chain has no cycle', () {
      expect(
        findAnyCycle(graphOf(<String, List<String>>{
          'a': <String>['b'],
          'b': <String>['c'],
          'c': <String>['sink'],
        })),
        isNull,
      );
    });

    test('A DIAMOND IS NOT A CYCLE', () {
      // a → b → d and a → c → d. `d` is reached twice, which a naive "have I
      // seen this node" check calls a cycle. It is not one: no path returns to
      // a node it came from.
      expect(
        findAnyCycle(graphOf(<String, List<String>>{
          'a': <String>['b', 'c'],
          'b': <String>['d'],
          'c': <String>['d'],
        })),
        isNull,
      );
    });

    test('two categories pointing at one sink is not a cycle', () {
      expect(
        findAnyCycle(graphOf(<String, List<String>>{
          'bike': <String>['sink'],
          'hajj': <String>['sink'],
        })),
        isNull,
      );
    });
  });

  group('cycles are found, at every length', () {
    test('A SELF-REFERENCE', () {
      final RedirectCyclePath? cycle = findAnyCycle(
        graphOf(<String, List<String>>{
          'a': <String>['a'],
        }),
      );
      expect(cycle, isNotNull);
      expect(cycle!.path, <String>['a', 'a']);
      expect(cycle.members, <String>['a']);
    });

    test('A TWO-NODE CYCLE', () {
      final RedirectCyclePath? cycle = findAnyCycle(
        graphOf(<String, List<String>>{
          'a': <String>['b'],
          'b': <String>['a'],
        }),
      );
      expect(cycle, isNotNull);
      expect(cycle!.members.toSet(), <String>{'a', 'b'});
      expect(
        cycle.path.first,
        cycle.path.last,
        reason: 'the path closes on itself, so it reads as the loop it is',
      );
    });

    test('A THREE-NODE CYCLE — the pitfall a pair check walks past', () {
      final RedirectCyclePath? cycle = findAnyCycle(
        graphOf(<String, List<String>>{
          'a': <String>['b'],
          'b': <String>['c'],
          'c': <String>['a'],
        }),
      );
      expect(cycle, isNotNull);
      expect(cycle!.members.toSet(), <String>{'a', 'b', 'c'});
    });

    test('a five-node cycle', () {
      final RedirectCyclePath? cycle = findAnyCycle(
        graphOf(<String, List<String>>{
          'a': <String>['b'],
          'b': <String>['c'],
          'c': <String>['d'],
          'd': <String>['e'],
          'e': <String>['a'],
        }),
      );
      expect(cycle, isNotNull);
      expect(cycle!.members, hasLength(5));
    });

    test('A CYCLE REACHABLE ONLY THROUGH THE SECOND TARGET', () {
      // The defect ADR-006 created room for. Before the cascade model a
      // category had one target, so following `next` sufficed. Here `a`'s
      // first target is a dead end and the loop hides behind its second — a
      // traversal that stopped at the first edge would report this graph clean.
      final RedirectCyclePath? cycle = findAnyCycle(
        graphOf(<String, List<String>>{
          'a': <String>['sink', 'b'],
          'b': <String>['c'],
          'c': <String>['a'],
        }),
      );
      expect(cycle, isNotNull);
      expect(cycle!.members.toSet(), <String>{'a', 'b', 'c'});
    });

    test('the reported path excludes the tail that led into the loop', () {
      // `x → a → b → a`. The loop is {a, b}; `x` is upstream of it and changing
      // `x` would not fix anything, so naming it would send the user to the
      // wrong screen.
      final RedirectCyclePath? cycle = findCycleFrom(
        'x',
        graphOf(<String, List<String>>{
          'x': <String>['a'],
          'a': <String>['b'],
          'b': <String>['a'],
        }),
      );
      expect(cycle, isNotNull);
      expect(cycle!.members.toSet(), <String>{'a', 'b'});
      expect(cycle.members, isNot(contains('x')));
    });

    test('a cycle in a component not reachable from the first node', () {
      // `findAnyCycle` starts somewhere; the loop is elsewhere entirely. A
      // walk that only explored the first source would miss it — and after a
      // merge the offending edge is routinely on a node no local save touched.
      final RedirectCyclePath? cycle = findAnyCycle(
        graphOf(<String, List<String>>{
          'clean': <String>['sink'],
          'p': <String>['q'],
          'q': <String>['p'],
        }),
      );
      expect(cycle, isNotNull);
      expect(cycle!.members.toSet(), <String>{'p', 'q'});
    });
  });

  group('wouldCreateCycle answers before the edge is written', () {
    final Map<String, List<RedirectTarget>> graph = graphOf(
      <String, List<String>>{
        'b': <String>['c'],
        'c': <String>['sink'],
      },
    );

    test('an edge that closes a loop is refused', () {
      // sink → ... no. c → a where a → b → c already exists:
      final Map<String, List<RedirectTarget>> chain = graphOf(
        <String, List<String>>{
          'a': <String>['b'],
          'b': <String>['c'],
        },
      );
      expect(
        wouldCreateCycle(
          sourceCategoryId: 'c',
          targetCategoryId: 'a',
          graph: chain,
        ),
        isTrue,
      );
    });

    test('an edge that does not is permitted', () {
      expect(
        wouldCreateCycle(
          sourceCategoryId: 'a',
          targetCategoryId: 'b',
          graph: graph,
        ),
        isFalse,
      );
    });

    test('a self-edge is refused even though no row exists yet', () {
      // C-29 and `RedirectTarget.create` both reject this, but a merge writes
      // rows without constructing entities — so the graph walk handles it
      // rather than assuming it away.
      expect(
        wouldCreateCycle(
          sourceCategoryId: 'a',
          targetCategoryId: 'a',
          graph: graph,
        ),
        isTrue,
      );
    });
  });

  test('a large acyclic graph does not blow up', () {
    // Without the settled set, a diamond lattice re-walks every subtree once
    // per route in — exponential on a graph that is perfectly valid. 24 layers
    // of diamonds is instant with it and will not finish without it.
    final Map<String, List<String>> edges = <String, List<String>>{};
    for (int i = 0; i < 24; i++) {
      edges['top$i'] = <String>['left$i', 'right$i'];
      edges['left$i'] = <String>['top${i + 1}'];
      edges['right$i'] = <String>['top${i + 1}'];
    }
    expect(findAnyCycle(graphOf(edges)), isNull);
  });
}
