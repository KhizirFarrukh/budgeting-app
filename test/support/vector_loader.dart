import 'dart:convert';
import 'dart:io';

/// Loads golden allocation vectors from JSON fixtures.
///
/// Substage 3.8.5: *"reads JSON fixtures from a directory and yields cases"*,
/// and critically — **adding a fixture must require no code change.**
///
/// Substage 3.8's `common_pitfalls` names what this avoids:
///
/// > *"A fixture loader hardcoded to a list of filenames, which then requires a
/// > code change per vector in Stage 5."*
///
/// So the loader globs the directory. Stage 5 substage 5.9.5 also adds a
/// permanent vector for every shrunk property-test failure, which would be
/// intolerable if each needed a code edit.
///
/// The fixture format is `ALLOCATION_ALGORITHM.md` §9.1.
class VectorLoader {
  const VectorLoader._();

  /// Where the fixtures live, relative to the package root.
  static const String defaultDirectory = 'test/fixtures/allocation';

  /// Every vector in [directory], sorted by id so runs are reproducible.
  ///
  /// Sorting matters: an unordered directory listing makes failure output
  /// differ between machines, which makes a CI failure harder to reproduce
  /// locally than it needs to be.
  static List<AllocationVector> loadAll({String directory = defaultDirectory}) {
    final Directory dir = Directory(directory);
    if (!dir.existsSync()) {
      throw StateError(
        'Vector directory not found: $directory\n'
        'Stage 5 substage 5.8 populates it with V-01..V-15.',
      );
    }

    final List<File> files =
        dir
            .listSync()
            .whereType<File>()
            .where((File f) => f.path.endsWith('.json'))
            .toList()
          ..sort((File a, File b) => a.path.compareTo(b.path));

    final List<AllocationVector> vectors =
        files.map((File f) => AllocationVector.fromFile(f)).toList()..sort(
          (AllocationVector a, AllocationVector b) => a.id.compareTo(b.id),
        );

    return vectors;
  }

  /// One vector by id, e.g. `'V-05'`.
  static AllocationVector load(
    String id, {
    String directory = defaultDirectory,
  }) {
    final List<AllocationVector> all = loadAll(directory: directory);
    return all.firstWhere(
      (AllocationVector v) => v.id == id,
      orElse: () => throw StateError(
        'No vector with id "$id" in $directory. '
        'Found: ${all.map((AllocationVector v) => v.id).join(', ')}',
      ),
    );
  }
}

/// One golden vector, as defined in `ALLOCATION_ALGORITHM.md` §9.1.
class AllocationVector {
  const AllocationVector({
    required this.id,
    required this.description,
    required this.request,
    required this.expectedAllocations,
    required this.expectedTotalMinor,
    required this.expectedFailure,
    required this.notes,
    required this.sourcePath,
  });

  factory AllocationVector.fromFile(File file) {
    final Object? decoded = jsonDecode(file.readAsStringSync());
    if (decoded is! Map<String, Object?>) {
      throw FormatException('Vector is not a JSON object', file.path);
    }
    return AllocationVector.fromJson(decoded, file.path);
  }

  factory AllocationVector.fromJson(Map<String, Object?> json, String path) {
    final Object? allocations = json['expected_allocations'];
    final Object? failure = json['expected_failure'];

    // §9.1: "Exactly one of expected_allocations and expected_failure is
    // non-null." A fixture format that cannot express an expected failure
    // causes the rejection cases to be quietly omitted — substage 5.8's
    // pitfall — so the loader enforces the rule rather than trusting it.
    if (allocations == null && failure == null) {
      throw FormatException(
        'Vector must declare either expected_allocations or expected_failure',
        path,
      );
    }
    if (allocations != null && failure != null) {
      throw FormatException(
        'Vector declares both expected_allocations and expected_failure; '
        'exactly one is permitted (ALLOCATION_ALGORITHM §9.1)',
        path,
      );
    }

    return AllocationVector(
      id: json['id']! as String,
      description: json['description']! as String,
      request: json['request']! as Map<String, Object?>,
      expectedAllocations: allocations == null
          ? null
          : (allocations as List<Object?>).cast<Map<String, Object?>>(),
      expectedTotalMinor: json['expected_total_minor'] as int?,
      expectedFailure: failure as String?,
      notes: json['notes'] as String? ?? '',
      sourcePath: path,
    );
  }

  final String id;
  final String description;
  final Map<String, Object?> request;

  /// Null when this vector expects a failure.
  final List<Map<String, Object?>>? expectedAllocations;

  /// Asserted **in addition to** the per-item amounts, so conservation is
  /// checked even if a future edit changes the line-item shape (§9.1).
  final int? expectedTotalMinor;

  /// Null when this vector expects success.
  final String? expectedFailure;

  final String notes;
  final String sourcePath;

  bool get expectsFailure => expectedFailure != null;

  @override
  String toString() => '$id: $description';
}
