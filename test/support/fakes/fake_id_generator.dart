import 'package:pookiebudget/domain/money/id_generator.dart';

/// A deterministic [IdGenerator].
///
/// Substage 3.8.3: *"produces predictable ids, so expected outputs are stable
/// across runs."*
///
/// This is what makes the Stage 5 golden vectors possible. Those fixtures
/// assert exact line items, and a real UUID would differ on every run, so
/// either the ids or the assertions would have to be loosened — and loosening
/// the assertions is how a vector stops catching regressions.
///
/// Ids are obviously synthetic (`cat-000001`), never plausible UUIDs, so a
/// fixture or a log line cannot be mistaken for production data.
class FakeIdGenerator implements IdGenerator {
  FakeIdGenerator({this.prefix = 'id'});

  final String prefix;

  int _timeSortableCount = 0;
  int _randomCount = 0;

  /// Every id handed out, in order — for asserting how many were requested.
  final List<String> issued = <String>[];

  @override
  String newTimeSortableId() {
    _timeSortableCount++;
    // Zero-padded so lexicographic order matches issue order, mirroring the
    // property real UUID v7 provides (ARCHITECTURE §8.6).
    final String id =
        '$prefix-t-${_timeSortableCount.toString().padLeft(6, '0')}';
    issued.add(id);
    return id;
  }

  @override
  String newRandomId() {
    _randomCount++;
    final String id = '$prefix-r-${_randomCount.toString().padLeft(6, '0')}';
    issued.add(id);
    return id;
  }

  /// Restores the generator to its initial state.
  void reset() {
    _timeSortableCount = 0;
    _randomCount = 0;
    issued.clear();
  }
}
