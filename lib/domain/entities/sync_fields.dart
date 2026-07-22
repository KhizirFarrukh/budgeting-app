/// The five sync columns every synced table carries (SCHEMA §2.1, S-07).
///
/// Grouped into one value object rather than repeated as five fields on ten
/// entities. The grouping is not only tidiness: it puts [hlc] and
/// [updatedAtMs] side by side with the comment explaining why merge logic must
/// read one and never the other.
final class SyncFields {
  const SyncFields({
    required this.updatedAtMs,
    required this.updatedByDevice,
    required this.hlc,
    this.isDeleted = false,
    this.deletedAtMs,
  });

  /// A row that has never been synced — used when constructing a record
  /// locally before the HLC is stamped.
  const SyncFields.local({
    required this.updatedAtMs,
    required this.updatedByDevice,
  }) : hlc = '',
       isDeleted = false,
       deletedAtMs = null;

  /// Wall-clock time of the last write, UTC epoch ms.
  ///
  /// **For display and diagnostics only — never for ordering.** A device with a
  /// wrong clock produces a misleading value here but still orders correctly by
  /// [hlc]. Substage 7.4's rule *"never compare raw wall-clock timestamps in
  /// merge logic"* is why these are two fields and not one.
  final int updatedAtMs;

  final String updatedByDevice;

  /// Hybrid logical clock, lexicographically sortable.
  ///
  /// **This is what orders concurrent edits** (R-08). Empty only for a row
  /// built locally that has not yet been stamped.
  final String hlc;

  final bool isDeleted;

  /// When the tombstone was set; null when [isDeleted] is false.
  final int? deletedAtMs;

  SyncFields copyWith({
    int? updatedAtMs,
    String? updatedByDevice,
    String? hlc,
    bool? isDeleted,
    int? deletedAtMs,
  }) => SyncFields(
    updatedAtMs: updatedAtMs ?? this.updatedAtMs,
    updatedByDevice: updatedByDevice ?? this.updatedByDevice,
    hlc: hlc ?? this.hlc,
    isDeleted: isDeleted ?? this.isDeleted,
    deletedAtMs: deletedAtMs ?? this.deletedAtMs,
  );

  /// Tombstones the row. INV-10: deletion is soft everywhere except the ledger,
  /// which never calls this.
  SyncFields tombstoned(int atMs) =>
      copyWith(isDeleted: true, deletedAtMs: atMs, updatedAtMs: atMs);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SyncFields &&
          runtimeType == other.runtimeType &&
          updatedAtMs == other.updatedAtMs &&
          updatedByDevice == other.updatedByDevice &&
          hlc == other.hlc &&
          isDeleted == other.isDeleted &&
          deletedAtMs == other.deletedAtMs;

  @override
  int get hashCode =>
      Object.hash(updatedAtMs, updatedByDevice, hlc, isDeleted, deletedAtMs);

  @override
  String toString() =>
      'SyncFields(hlc: $hlc, device: $updatedByDevice, '
      'deleted: $isDeleted)';
}
