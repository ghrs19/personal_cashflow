import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';

/// SQLite storage. The table layout keeps the proven shape of the
/// reference cash book (accounts / cash_transactions / currency_notes /
/// notebook) and adds categories + a settings key-value table.
class AppDatabase {
  static Database? _db;
  static const fileName = 'cashbook.db';

  static Future<String> dbPath() async {
    final dir = await getApplicationDocumentsDirectory();
    return p.join(dir.path, fileName);
  }

  static Future<Database> instance() async {
    _db ??= await _open();
    return _db!;
  }

  static Future<Database> _open() async {
    final path = await dbPath();
    return openDatabase(
      path,
      version: 1,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE accounts(
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            name TEXT NOT NULL,
            icon TEXT,
            color INTEGER,
            created_at TEXT NOT NULL,
            is_deleted INTEGER NOT NULL DEFAULT 0
          )''');
        await db.execute('''
          CREATE TABLE cash_transactions(
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            account_id INTEGER NOT NULL,
            date TEXT NOT NULL,
            cash_in REAL NOT NULL DEFAULT 0,
            cash_out REAL NOT NULL DEFAULT 0,
            notes TEXT,
            description TEXT,
            category TEXT,
            bill TEXT,
            bill2 TEXT,
            bill3 TEXT,
            is_deleted INTEGER NOT NULL DEFAULT 0,
            deleted_at TEXT,
            transaction_type INTEGER NOT NULL DEFAULT 0,
            transfer_group TEXT
          )''');
        await db.execute(
            'CREATE INDEX idx_tx_account_date ON cash_transactions(account_id, date)');
        await db.execute('''
          CREATE TABLE categories(
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            name TEXT NOT NULL,
            is_income INTEGER NOT NULL DEFAULT 0
          )''');
        await db.execute('''
          CREATE TABLE notebook(
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            date TEXT NOT NULL,
            note TEXT NOT NULL,
            completed INTEGER NOT NULL DEFAULT 0
          )''');
        await db.execute('''
          CREATE TABLE currency_notes(
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            denomination REAL NOT NULL,
            currency TEXT NOT NULL DEFAULT 'IDR',
            count INTEGER NOT NULL DEFAULT 0,
            show INTEGER NOT NULL DEFAULT 1
          )''');
        await db.execute('''
          CREATE TABLE settings(
            key TEXT PRIMARY KEY,
            value TEXT
          )''');
        await _seed(db);
      },
    );
  }

  static Future<void> _seed(Database db) async {
    final now = DateTime.now().toIso8601String();
    await db.insert('accounts', {
      'name': 'Kas Utama',
      'icon': '💰',
      'color': 0xFF0E7C66,
      'created_at': now,
      'is_deleted': 0,
    });
    const income = ['Penjualan', 'Gaji', 'Bonus', 'Hadiah', 'Lainnya'];
    const expense = [
      'Makanan',
      'Transportasi',
      'Belanja',
      'Tagihan',
      'Kesehatan',
      'Hiburan',
      'Lainnya',
    ];
    for (final c in income) {
      await db.insert('categories', {'name': c, 'is_income': 1});
    }
    for (final c in expense) {
      await db.insert('categories', {'name': c, 'is_income': 0});
    }
    const idrDenoms = [100000.0, 75000.0, 50000.0, 20000.0, 10000.0, 5000.0, 2000.0, 1000.0, 500.0, 200.0, 100.0];
    for (final d in idrDenoms) {
      await db.insert('currency_notes', {
        'denomination': d,
        'currency': 'IDR',
        'count': 0,
        'show': 1,
      });
    }
  }

  /// Closes the database so the underlying file can be replaced
  /// (used by restore-from-backup).
  static Future<void> close() async {
    await _db?.close();
    _db = null;
  }
}
