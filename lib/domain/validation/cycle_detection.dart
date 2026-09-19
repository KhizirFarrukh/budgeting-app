/// Redirect-graph cycle detection. SCHEMA V-12.
///
/// # Why a traversal and not a pair check
///
/// The substage's named pitfall is exact: *"cycle detection that only checks
/// the direct target, missing a three-node loop."* Refusing `A → B` when
/// `B → A` exists feels like cycle detection and is not — `A → B → C → A`
/// walks straight past it, and the user's money then circles a loop that no
/// save ever rejected.
///
/// # Why the graph branches
///
/// Before ADR-006 a category had **one** redirect target, so the graph was a
/// set of chains and following `next` repeatedly would have sufficed. ADR-006
/// replaced that column with a `redirect_targets` table, so a node has many
/// successors. A traversal that followed only the first would miss a cycle
/// reachable through the second — the same defect one level up.
///
/// So every edge of every node is explored, and the visited set is carried
/// across the whole walk.
///
/// # This does not replace the engine's runtime defence
///
/// A merge can produce a cycle from two independently valid edits made on
/// different devices, so the stored configuration may genuinely be cyclic when
/// allocation runs. `ALLOCATION_ALGORITHM` §3.5 keeps its own visited set and
/// hop limit for that case. The two mechanisms cover different situations and
/// **neither is redundant**: this one refuses to create a cycle, that one
/// survives finding one.
library;

import 'package:pookiebudget/domain/entities/redirect_target.dart';

/// One cycle, as the path that closes it.
///
/// [path] lists the categories in traversal order with **the first repeated at
/// the end**, so `[A, B, C, A]` reads as the loop it is rather than as a set
/// the reader has to close mentally.
final class RedirectCyclePath {
  const RedirectCyclePath(this.path);

  final List<String> path;

  /// The categories in the loop, without the repeated closing node.
  List<String> get members => path.sublist(0, path.length - 1);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is RedirectCyclePath &&
          runtimeType == other.runtimeType &&
          path.length == other.path.length &&
          _sameOrder(path, other.path);

  static bool _sameOrder(List<String> a, List<String> b) {
    for (int i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }

  @override
  int get hashCode => Object.hashAll(path);

  @override
  String toString() => 'RedirectCyclePath(${path.join(" → ")})';
}

/// Finds a cycle reachable from [startCategoryId], or null if there is none.
///
/// [graph] maps a source category to its redirect targets — the whole live
/// graph, as `CategoryRepository.redirectGraph()` returns it.
///
/// Depth-first, carrying two sets:
///
/// - **`onPath`** — nodes on the current descent. Re-reaching one of these is a
///   cycle, and the path back to it is the cycle to report.
/// - **`settled`** — nodes already fully explored with no cycle found below
///   them. Without this, a diamond (`A → B`, `A → C`, `B → D`, `C → D`) would
///   re-walk `D`'s whole subtree once per route in, which is exponential on a
///   graph that is perfectly acyclic.
///
/// Returns the **first** cycle found. One is enough to refuse the save, and
/// reporting every cycle in a graph that has one is a list the user cannot act
/// on any better than the first entry.
RedirectCyclePath? findCycleFrom(
  String startCategoryId,
  Map<String, List<RedirectTarget>> graph,
) {
  final Set<String> settled = <String>{};
  return _walk(startCategoryId, graph, <String>[], <String>{}, settled);
}

/// Finds a cycle anywhere in [graph], or null if it is acyclic.
///
/// What the post-merge pass uses (§6.8): after a merge nothing is trusted, and
/// the edit that closed a loop may have arrived on a node no local save ever
/// touched.
RedirectCyclePath? findAnyCycle(Map<String, List<RedirectTarget>> graph) {
  final Set<String> settled = <String>{};
  for (final String source in graph.keys) {
    if (settled.contains(source)) continue;
    final RedirectCyclePath? cycle = _walk(
      source,
      graph,
      <String>[],
      <String>{},
      settled,
    );
    if (cycle != null) return cycle;
  }
  return null;
}

/// Whether adding `source → target` would close a loop.
///
/// The question a save actually asks, and it is asked **before** the edge is
/// stored — so the edge is added to a copy of the graph rather than written
/// and rolled back. A validator that needed its subject persisted first could
/// not be called from a `must_not`-respecting write path.
bool wouldCreateCycle({
  required String sourceCategoryId,
  required String targetCategoryId,
  required Map<String, List<RedirectTarget>> graph,
}) {
  // The one-node case. C-29 and `RedirectTarget.create` both reject it already,
  // but a merge writes rows without constructing entities, so the graph walk
  // must handle it rather than assume it away.
  if (sourceCategoryId == targetCategoryId) return true;

  // Can the target already reach the source? If so, closing source → target
  // completes the loop.
  final Set<String> settled = <String>{};
  return _reaches(targetCategoryId, sourceCategoryId, graph, settled);
}

/// Whether [from] can reach [goal] by any path.
bool _reaches(
  String from,
  String goal,
  Map<String, List<RedirectTarget>> graph,
  Set<String> seen,
) {
  if (from == goal) return true;
  if (!seen.add(from)) return false;
  for (final RedirectTarget edge in graph[from] ?? const <RedirectTarget>[]) {
    if (_reaches(edge.targetCategoryId, goal, graph, seen)) return true;
  }
  return false;
}

RedirectCyclePath? _walk(
  String node,
  Map<String, List<RedirectTarget>> graph,
  List<String> path,
  Set<String> onPath,
  Set<String> settled,
) {
  if (onPath.contains(node)) {
    // Report the loop only, not the tail that led into it: a walk
    // `X → A → B → A` is a cycle among A and B, and including X would name a
    // category the user does not need to change.
    final int start = path.indexOf(node);
    return RedirectCyclePath(<String>[...path.sublist(start), node]);
  }
  if (settled.contains(node)) return null;

  onPath.add(node);
  path.add(node);

  for (final RedirectTarget edge in graph[node] ?? const <RedirectTarget>[]) {
    final RedirectCyclePath? found = _walk(
      edge.targetCategoryId,
      graph,
      path,
      onPath,
      settled,
    );
    if (found != null) return found;
  }

  onPath.remove(node);
  path.removeLast();
  settled.add(node);
  return null;
}
