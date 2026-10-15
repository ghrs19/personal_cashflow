import 'package:sqflite/sqflite.dart';

import '../models/models.dart';
import '../utils/calc.dart';
import 'app_database.dart';

class Repository {
  Future<Database> get _db => AppDatabase.instance();

  // ---------- Accounts ----------
  Future<List<Account>> getAccounts({bool includeDeleted = false}) async {
    final db = await _db;
    final rows = await db.query(
      'accounts',
      where: includeDeleted ? null : 'is_deleted = 0',
      orderBy: 'created_at ASC',
    );
    return rows.map(Account.fromMap).toList();
  }

  Future<int> insertAccount(Account a) async {
    final db = await _db;
    return db.insert('accounts', a.toMap()..remove('id'));
  }

  Future<void> updateAccount(Account a) async {
    final db = await _db;
    await db.update('accounts', a.toMap(), where: 'id = ?', whereArgs: [a.id]);
  }

  /// Soft-deletes the account and all of its entries (restorable via the
  /// recycle bin only while the account still exists, so accounts are
  /// restored together with the account itself).
  Future<void> deleteAccount(int id) async {
    final db = await _db;
    await db.update('accounts', {'is_deleted': 1}, where: 'id = ?', whereArgs: [id]);
  }

  Future<void> restoreAccount(int id) async {
    final db = await _db;
    await db.update('accounts', {'is_deleted': 0}, where: 'id = ?', whereArgs: [id]);
  }

  Future<double> accountBalance(int accountId) async {
    final db = await _db;
    final rows = await db.rawQuery(
      'SELECT COALESCE(SUM(cash_in),0) - COALESCE(SUM(cash_out),0) AS bal '
      'FROM cash_transactions WHERE account_id = ? AND is_deleted = 0',
      [accountId],
    );
    return (rows.first['bal'] as num).toDouble();
  }

  Future<double> totalBalance() async {
    final db = await _db;
    final rows = await db.rawQuery(
      'SELECT COALESCE(SUM(cash_in),0) - COALESCE(SUM(cash_out),0) AS bal '
      'FROM cash_transactions t JOIN accounts a ON a.id = t.account_id '
      'WHERE t.is_deleted = 0 AND a.is_deleted = 0',
    );
    return (rows.first['bal'] as num).toDouble();
  }

  // ---------- Entries ----------
  Future<List<EntryWithBalance>> getEntriesWithBalance(int accountId) async {
    final db = await _db;
    final rows = await db.query(
      'cash_transactions',
      where: 'account_id = ? AND is_deleted = 0',
      whereArgs: [accountId],
      orderBy: 'date ASC, id ASC',
    );
    final entries = rows.map(CashEntry.fromMap).toList();
    return attachRunningBalances(entries);
  }

  Future<List<CashEntry>> getAllEntries({
    DateTime? from,
    DateTime? to,
    bool includeTransfers = true,
  }) async {
    final db = await _db;
    final where = StringBuffer('t.is_deleted = 0 AND a.is_deleted = 0');
    final args = <Object?>[];
    if (from != null) {
      where.write(' AND t.date >= ?');
      args.add(from.toIso8601String());
    }
    if (to != null) {
      where.write(' AND t.date < ?');
      args.add(to.toIso8601String());
    }
    if (!includeTransfers) {
      where.write(' AND t.transaction_type = 0');
    }
    final rows = await db.rawQuery(
      'SELECT t.* FROM cash_transactions t JOIN accounts a ON a.id = t.account_id '
      'WHERE $where ORDER BY t.date ASC, t.id ASC',
      args,
    );
    return rows.map(CashEntry.fromMap).toList();
  }

  Future<int> insertEntry(CashEntry e) async {
    final db = await _db;
    return db.insert('cash_transactions', e.toMap()..remove('id'));
  }

  Future<void> updateEntry(CashEntry e) async {
    final db = await _db;
    await db.update('cash_transactions', e.toMap(), where: 'id = ?', whereArgs: [e.id]);
  }

  /// Soft delete; when the entry is a transfer leg, its counterpart is
  /// deleted as well so balances never go one-sided.
  Future<void> softDeleteEntry(CashEntry e) async {
    final db = await _db;
    final now = DateTime.now().toIso8601String();
    await db.update(
      'cash_transactions',
      {'is_deleted': 1, 'deleted_at': now},
      where: 'id = ?',
      whereArgs: [e.id],
    );
    if (e.transferGroup != null) {
      await db.update(
        'cash_transactions',
        {'is_deleted': 1, 'deleted_at': now},
        where: 'transfer_group = ? AND id != ?',
        whereArgs: [e.transferGroup, e.id],
      );
    }
  }

  Future<List<CashEntry>> getDeletedEntries() async {
    final db = await _db;
    final rows = await db.query(
      'cash_transactions',
      where: 'is_deleted = 1',
      orderBy: 'deleted_at DESC',
    );
    return rows.map(CashEntry.fromMap).toList();
  }

  Future<void> restoreEntry(CashEntry e) async {
    final db = await _db;
    await db.update(
      'cash_transactions',
      {'is_deleted': 0, 'deleted_at': null},
      where: 'id = ?',
      whereArgs: [e.id],
    );
    if (e.transferGroup != null) {
      await db.update(
        'cash_transactions',
        {'is_deleted': 0, 'deleted_at': null},
        where: 'transfer_group = ? AND id != ?',
        whereArgs: [e.transferGroup, e.id],
      );
    }
  }

  Future<void> purgeEntry(int id) async {
    final db = await _db;
    await db.delete('cash_transactions', where: 'id = ?', whereArgs: [id]);
  }

  Future<void> emptyRecycleBin() async {
    final db = await _db;
    await db.delete('cash_transactions', where: 'is_deleted = 1');
  }

  /// Creates the two legs of a transfer between accounts.
  Future<void> transfer({
    required int fromAccountId,
    required int toAccountId,
    required double amount,
    required DateTime date,
    String notes = '',
    required String outLabel,
    required String inLabel,
  }) async {
    final db = await _db;
    final group = 'tr-${DateTime.now().microsecondsSinceEpoch}';
    await db.transaction((txn) async {
      await txn.insert(
        'cash_transactions',
        CashEntry(
          accountId: fromAccountId,
          date: date,
          cashOut: amount,
          notes: notes,
          category: outLabel,
          transactionType: 1,
          transferGroup: group,
        ).toMap()..remove('id'),
      );
      await txn.insert(
        'cash_transactions',
        CashEntry(
          accountId: toAccountId,
          date: date,
          cashIn: amount,
          notes: notes,
          category: inLabel,
          transactionType: 2,
          transferGroup: group,
        ).toMap()..remove('id'),
      );
    });
  }

  // ---------- Categories ----------
  Future<List<CategoryItem>> getCategories({required bool income}) async {
    final db = await _db;
    final rows = await db.query(
      'categories',
      where: 'is_income = ?',
      whereArgs: [income ? 1 : 0],
      orderBy: 'name ASC',
    );
    return rows.map(CategoryItem.fromMap).toList();
  }

  Future<int> insertCategory(CategoryItem c) async {
    final db = await _db;
    return db.insert('categories', c.toMap()..remove('id'));
  }

  Future<void> deleteCategory(int id) async {
    final db = await _db;
    await db.delete('categories', where: 'id = ?', whereArgs: [id]);
  }

  // ---------- Notebook ----------
  Future<List<NoteItem>> getNotes() async {
    final db = await _db;
    final rows = await db.query('notebook', orderBy: 'completed ASC, date DESC, id DESC');
    return rows.map(NoteItem.fromMap).toList();
  }

  Future<int> insertNote(NoteItem n) async {
    final db = await _db;
    return db.insert('notebook', n.toMap()..remove('id'));
  }

  Future<void> updateNote(NoteItem n) async {
    final db = await _db;
    await db.update('notebook', n.toMap(), where: 'id = ?', whereArgs: [n.id]);
  }

  Future<void> deleteNote(int id) async {
    final db = await _db;
    await db.delete('notebook', where: 'id = ?', whereArgs: [id]);
  }

  // ---------- Denominations ----------
  Future<List<Denomination>> getDenominations(String currency) async {
    final db = await _db;
    final rows = await db.query(
      'currency_notes',
      where: 'currency = ? AND show = 1',
      whereArgs: [currency],
      orderBy: 'denomination DESC',
    );
    return rows.map(Denomination.fromMap).toList();
  }

  Future<void> setDenominationCount(int id, int count) async {
    final db = await _db;
    await db.update('currency_notes', {'count': count}, where: 'id = ?', whereArgs: [id]);
  }

  Future<int> insertDenomination(Denomination d) async {
    final db = await _db;
    return db.insert('currency_notes', d.toMap()..remove('id'));
  }

  Future<void> deleteDenomination(int id) async {
    final db = await _db;
    await db.delete('currency_notes', where: 'id = ?', whereArgs: [id]);
  }

  Future<void> resetDenominationCounts(String currency) async {
    final db = await _db;
    await db.update('currency_notes', {'count': 0}, where: 'currency = ?', whereArgs: [currency]);
  }

  // ---------- Settings ----------
  Future<String?> getSetting(String key) async {
    final db = await _db;
    final rows = await db.query('settings', where: 'key = ?', whereArgs: [key]);
    if (rows.isEmpty) return null;
    return rows.first['value'] as String?;
  }

  Future<void> setSetting(String key, String value) async {
    final db = await _db;
    await db.insert(
      'settings',
      {'key': key, 'value': value},
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }
}
