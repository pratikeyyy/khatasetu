import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

class LocalDatabase {
  static Database? _database;

  static Future<Database> get database async {
    if (_database != null) return _database!;

    final dbPath = await getDatabasesPath();
    final path = join(dbPath, 'khatasetu.db');

    _database = await openDatabase(
      path,
      version: 1,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE customers (
            id INTEGER PRIMARY KEY,
            shop_id INTEGER NOT NULL,
            name TEXT NOT NULL,
            normalized_name TEXT NOT NULL,
            phone TEXT,
            address TEXT,
            notes TEXT,
            credit_balance REAL NOT NULL DEFAULT 0,
            total_credit REAL NOT NULL DEFAULT 0,
            total_payment REAL NOT NULL DEFAULT 0,
            is_active INTEGER NOT NULL DEFAULT 1,
            created_at TEXT,
            updated_at TEXT,
            transaction_count INTEGER NOT NULL DEFAULT 0
          )
        ''');

        await db.execute('''
          CREATE TABLE transactions (
            id INTEGER PRIMARY KEY,
            shop_id INTEGER NOT NULL,
            customer_id INTEGER NOT NULL,
            customer_name TEXT NOT NULL,
            scan_entry_id INTEGER,
            amount REAL NOT NULL,
            transaction_type TEXT NOT NULL,
            date TEXT NOT NULL,
            notes TEXT,
            payment_mode TEXT,
            source TEXT NOT NULL,
            created_at TEXT
          )
        ''');

        await db.execute('''
          CREATE TABLE reminders (
            id INTEGER PRIMARY KEY,
            customer_id INTEGER,
            message TEXT,
            due_date TEXT,
            is_sent INTEGER NOT NULL DEFAULT 0
          )
        ''');

        await db.execute('''
          CREATE TABLE scan_entries (
            id INTEGER PRIMARY KEY,
            customer_id INTEGER,
            image_path TEXT,
            raw_text TEXT,
            created_at TEXT
          )
        ''');
      },
    );

    return _database!;
  }
}
