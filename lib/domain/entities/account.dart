import 'package:pookiebudget/domain/entities/entity_failure.dart';
import 'package:pookiebudget/domain/entities/enums.dart';
import 'package:pookiebudget/domain/entities/sync_fields.dart';
import 'package:pookiebudget/domain/result.dart';

/// A **label with a derived total** — not a balance.
///
/// Under OQ-02's answer there is no account balance field and no transfer
/// table. The account's total is computed as the sum of its linked categories'
/// balances.
///
/// **There is deliberately no `balanceMinor` here.** Adding one would create a
/// second source of truth for money and break INV-04. If OQ-02 is ever
/// revisited toward real account balances, the accommodation already exists:
/// `LedgerEntry.accountId` records which account each movement touched, so
/// per-account movement is derivable from v1.0 without a migration (PRD §3.4
/// D-14).
final class Account {
  const Account._({
    required this.id,
    required this.name,
    required this.institution,
    required this.lastFour,
    required this.scope,
    required this.sortOrder,
    required this.isArchived,
    required this.sync,
  });

  static Result<Account, EntityFailure> create({
    required String id,
    required String name,
    required int sortOrder,
    required SyncFields sync,
    String? institution,
    String? lastFour,
    MoneyScope scope = MoneyScope.personal,
    bool isArchived = false,
  }) {
    final String trimmed = name.trim();
    if (trimmed.isEmpty) {
      return const Failure<Account, EntityFailure>(BlankName('account'));
    }
    return Success<Account, EntityFailure>(
      Account._(
        id: id,
        name: trimmed,
        institution: institution,
        lastFour: lastFour,
        scope: scope,
        sortOrder: sortOrder,
        isArchived: isArchived,
        sync: sync,
      ),
    );
  }

  final String id;

  /// Unique among non-archived, non-deleted rows (U-02).
  final String name;

  /// Bank name, free text.
  final String? institution;

  /// Last four digits, free text, **purely a memory aid** — never used to
  /// identify or contact anything.
  final String? lastFour;

  /// Keeps a business account from appearing in personal flows.
  final MoneyScope scope;

  final int sortOrder;
  final bool isArchived;
  final SyncFields sync;

  Result<Account, EntityFailure> copyWith({
    String? name,
    String? institution,
    String? lastFour,
    MoneyScope? scope,
    int? sortOrder,
    bool? isArchived,
    SyncFields? sync,
    bool clearInstitution = false,
    bool clearLastFour = false,
  }) => Account.create(
    id: id,
    name: name ?? this.name,
    institution: clearInstitution ? null : (institution ?? this.institution),
    lastFour: clearLastFour ? null : (lastFour ?? this.lastFour),
    scope: scope ?? this.scope,
    sortOrder: sortOrder ?? this.sortOrder,
    isArchived: isArchived ?? this.isArchived,
    sync: sync ?? this.sync,
  );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Account &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          name == other.name &&
          institution == other.institution &&
          lastFour == other.lastFour &&
          scope == other.scope &&
          sortOrder == other.sortOrder &&
          isArchived == other.isArchived &&
          sync == other.sync;

  @override
  int get hashCode => Object.hash(
    id,
    name,
    institution,
    lastFour,
    scope,
    sortOrder,
    isArchived,
    sync,
  );

  @override
  String toString() => 'Account($id, "$name", ${scope.wireName})';
}
