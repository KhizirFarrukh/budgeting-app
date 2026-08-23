/// Thrown when a stored row cannot be turned into a domain entity.
///
/// ## Why this throws rather than returning a failure
///
/// `result.dart` draws the line: *"Exceptions remain appropriate for states
/// that indicate a bug ... or a mapper receiving a row with an impossible enum
/// value."* Every value this mapper reads was written by this application
/// through an entity that validated it, behind database constraints that
/// re-checked it. A row that fails to map means one of those two mechanisms is
/// broken.
///
/// There is no caller-side recovery for that. A `Result` would invite one —
/// most plausibly "skip this row and carry on", which for a category means a
/// dashboard that quietly omits a bucket holding money, and for a rule line
/// means percentages that no longer total 100%. Both look like working software
/// while being wrong about money, which is the failure mode this project treats
/// as worse than a crash.
///
/// Stage 7 changes the calculus and is expected to. A merge imports rows this
/// device did not write, so substage 7.6 validates and repairs them *before*
/// they are stored — the mapper stays strict and the repair happens upstream of
/// it, rather than the mapper becoming lenient.
final class MappingError extends Error {
  MappingError({
    required this.table,
    required this.recordId,
    required this.detail,
  });

  /// An unrecognised value in a column whose domain is a fixed enumeration.
  ///
  /// SCHEMA §4: *"Any value not listed is invalid and rejected at the mapper
  /// boundary."* This is that boundary.
  MappingError.unknownEnum({
    required this.table,
    required this.recordId,
    required String column,
    required String value,
    required List<String> permitted,
  }) : detail =
           'column $column holds "$value", which is not one of '
           '${permitted.join(", ")}';

  /// A row that a domain entity refused to be constructed from.
  ///
  /// Means a database constraint that should have rejected the write did not —
  /// so the message names the entity rule, which is where to start looking.
  MappingError.rejectedByEntity({
    required this.table,
    required this.recordId,
    required Object failure,
  }) : detail = 'the entity rejected it: $failure';

  /// Which table the row came from.
  final String table;

  /// The offending row's primary key, so the row can be found and inspected.
  final String recordId;

  final String detail;

  @override
  String toString() =>
      'MappingError: $table row "$recordId" cannot be read — $detail. '
      'This means a value was stored that neither the entity nor the schema '
      'constraints should have permitted; the row is not skipped, because a '
      'silently missing category is a silently missing balance.';
}
