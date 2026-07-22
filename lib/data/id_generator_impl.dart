import 'package:pookiebudget/domain/money/id_generator.dart';
import 'package:uuid/uuid.dart';

/// The real [IdGenerator], backed by `package:uuid`.
///
/// ARCHITECTURE §8.6 assigns versions by record class:
///
/// - **v7** for ledger entries and income events. Time-sortable, giving index
///   locality where it matters — PRD §7.2 shows these are **80–89% of all rows**
///   at the Heavy profile, so insert locality on that table is the difference
///   between an append and a page split.
/// - **v4** for configuration records. Low volume, no ordering benefit, and v4
///   avoids embedding record-creation times into the sync payload.
///
/// The v4/v7 distinction is why `uuid` 4.x is a hard requirement, and why
/// `riverpod_lint` and `custom_lint` were dropped at substage 3.3 rather than
/// downgrading it — they force `uuid ^3.0.6`, which has no v7. Recorded in
/// `DEPENDENCIES.md` §4.3.
class UuidIdGenerator implements IdGenerator {
  UuidIdGenerator([Uuid? uuid]) : _uuid = uuid ?? const Uuid();

  final Uuid _uuid;

  @override
  String newTimeSortableId() => _uuid.v7();

  @override
  String newRandomId() => _uuid.v4();
}
