import 'package:pookiebudget/domain/entities/sync_fields.dart';

/// The read half of the five sync columns, shared by all ten synced tables.
///
/// Drift generates a separate row class and a separate companion per table with
/// no common supertype, so the *write* half cannot be factored out the same way
/// — each mapper sets its own companion's five fields. That asymmetry is the
/// pitfall this substage names: *"a mapping function updated for writes but not
/// for reads, losing a field silently."*
///
/// Two things close it. The `kSyncColumnNames` runtime check from substage 4.3
/// proves the columns exist on every synced table; the per-entity round-trip
/// tests prove each mapper actually carries them through. A field dropped from
/// one direction fails the round trip on the entity that dropped it, naming it.
///
/// C-13 — `deleted_at_ms` present exactly when `is_deleted` is 1 — is not
/// re-checked here. It is a database constraint, which SCHEMA §6.1 calls the
/// absolute enforcement point: it holds against every code path including a
/// sync merge, so a write that breaks it is refused by SQLite and surfaces as
/// `ConstraintViolation`. Re-checking it in the mapper would add a second
/// answer to a question already settled.
SyncFields readSyncFields({
  required int updatedAtMs,
  required String updatedByDevice,
  required String hlc,
  required bool isDeleted,
  required int? deletedAtMs,
}) => SyncFields(
  updatedAtMs: updatedAtMs,
  updatedByDevice: updatedByDevice,
  hlc: hlc,
  isDeleted: isDeleted,
  deletedAtMs: deletedAtMs,
);
