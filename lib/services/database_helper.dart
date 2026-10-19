// ponytail: SQLite helper using sqflite; add cloud schema migrations when multi-device sync is connected.

import 'dart:async';
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';
import '../models/receipt.dart';

class DatabaseHelper {
  static final DatabaseHelper instance = DatabaseHelper._init();
  static Database? _database;

  DatabaseHelper._init();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB('receipt_expenses.db');
    return _database!;
  }

  Future<Database> _initDB(String filePath) async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, filePath);

    return await openDatabase(
      path,
      version: 1,
      onCreate: _createDB,
    );
  }

  Future<void> _createDB(Database db, int version) async {
    await db.execute('''
      CREATE TABLE receipts (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        merchant TEXT NOT NULL,
        amount REAL NOT NULL,
        date TEXT NOT NULL,
        category TEXT NOT NULL,
        image_path TEXT,
        raw_ocr_text TEXT,
        sync_status TEXT NOT NULL DEFAULT 'pending_sync',
        created_at TEXT NOT NULL
      )
    ''');
  }

  Future<int> insertReceipt(Receipt receipt) async {
    final db = await instance.database;
    return await db.insert('receipts', receipt.toMap());
  }

  Future<List<Receipt>> getAllReceipts() async {
    final db = await instance.database;
    final maps = await db.query('receipts', orderBy: 'date DESC, id DESC');
    return maps.map((m) => Receipt.fromMap(m)).toList();
  }

  Future<int> updateReceipt(Receipt receipt) async {
    final db = await instance.database;
    return await db.update(
      'receipts',
      receipt.toMap(),
      where: 'id = ?',
      whereArgs: [receipt.id],
    );
  }

  Future<int> deleteReceipt(int id) async {
    final db = await instance.database;
    return await db.delete(
      'receipts',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<List<Receipt>> getPendingSyncReceipts() async {
    final db = await instance.database;
    final maps = await db.query(
      'receipts',
      where: 'sync_status = ?',
      whereArgs: ['pending_sync'],
    );
    return maps.map((m) => Receipt.fromMap(m)).toList();
  }

  Future<int> markAsSynced(int id) async {
    final db = await instance.database;
    return await db.update(
      'receipts',
      {'sync_status': 'synced'},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<int> markAllAsSynced() async {
    final db = await instance.database;
    return await db.update(
      'receipts',
      {'sync_status': 'synced'},
      where: 'sync_status = ?',
      whereArgs: ['pending_sync'],
    );
  }

  Future<void> close() async {
    final db = _database;
    if (db != null) {
      await db.close();
      _database = null;
    }
  }
}
