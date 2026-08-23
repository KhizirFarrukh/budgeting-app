/// Row ↔ entity for `accounts`.
///
/// **No balance crosses this boundary in either direction**, because the table
/// has no balance column and the entity has no balance field. An account's
/// total is the sum of its linked categories' balances, derived from the ledger
/// (INV-04). A mapper is exactly where a convenience field like that gets added
/// "just for the UI", so its absence is stated rather than left to be noticed.
library;

import 'package:drift/drift.dart';
import 'package:pookiebudget/data/database/database.dart';
import 'package:pookiebudget/data/mappers/mapping_error.dart';
import 'package:pookiebudget/data/mappers/sync_field_mapper.dart';
import 'package:pookiebudget/domain/entities/account.dart';
import 'package:pookiebudget/domain/entities/entity_failure.dart';
import 'package:pookiebudget/domain/entities/enums.dart';
import 'package:pookiebudget/domain/result.dart';

Account accountFromRow(AccountRow row) {
  final MoneyScope? scope = MoneyScope.fromWire(row.scope);
  if (scope == null) {
    throw MappingError.unknownEnum(
      table: 'accounts',
      recordId: row.id,
      column: 'scope',
      value: row.scope,
      permitted: MoneyScope.values.map((MoneyScope v) => v.wireName).toList(),
    );
  }

  final Result<Account, EntityFailure> result = Account.create(
    id: row.id,
    name: row.name,
    sortOrder: row.sortOrder,
    institution: row.institution,
    lastFour: row.lastFour,
    scope: scope,
    isArchived: row.isArchived,
    sync: readSyncFields(
      updatedAtMs: row.updatedAtMs,
      updatedByDevice: row.updatedByDevice,
      hlc: row.hlc,
      isDeleted: row.isDeleted,
      deletedAtMs: row.deletedAtMs,
    ),
  );

  return switch (result) {
    Success<Account, EntityFailure>(:final Account value) => value,
    Failure<Account, EntityFailure>(:final EntityFailure failure) =>
      throw MappingError.rejectedByEntity(
        table: 'accounts',
        recordId: row.id,
        failure: failure,
      ),
  };
}

AccountsCompanion accountToCompanion(Account account) => AccountsCompanion(
  id: Value<String>(account.id),
  name: Value<String>(account.name),
  institution: Value<String?>(account.institution),
  lastFour: Value<String?>(account.lastFour),
  scope: Value<String>(account.scope.wireName),
  sortOrder: Value<int>(account.sortOrder),
  isArchived: Value<bool>(account.isArchived),
  updatedAtMs: Value<int>(account.sync.updatedAtMs),
  updatedByDevice: Value<String>(account.sync.updatedByDevice),
  hlc: Value<String>(account.sync.hlc),
  isDeleted: Value<bool>(account.sync.isDeleted),
  deletedAtMs: Value<int?>(account.sync.deletedAtMs),
);
