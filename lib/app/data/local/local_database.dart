import 'dart:convert';

import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';
import 'package:uuid/uuid.dart';

class LocalDatabase {
  LocalDatabase._();

  static final LocalDatabase instance = LocalDatabase._();

  static const _dbName = 'sigpred_offline.db';
  static const _dbVersion = 1;

  Database? _database;
  final _uuid = const Uuid();

  Future<Database> get database async {
    if (_database != null) return _database!;
    final dbPath = await getDatabasesPath();
    final fullPath = p.join(dbPath, _dbName);
    _database = await openDatabase(
      fullPath,
      version: _dbVersion,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
    return _database!;
  }

  Future<void> _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE offline_records (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        uuid TEXT NOT NULL UNIQUE,
        kind TEXT NOT NULL,
        method TEXT NOT NULL,
        endpoint TEXT NOT NULL,
        payload TEXT NOT NULL,
        status TEXT NOT NULL DEFAULT 'pending',
        attempts INTEGER NOT NULL DEFAULT 0,
        last_error TEXT,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL,
        synced_at TEXT
      )
    ''');

    await db.execute('''
      CREATE TABLE cache_items (
        cache_key TEXT PRIMARY KEY,
        value TEXT NOT NULL,
        updated_at TEXT NOT NULL
      )
    ''');

    await db.execute(
      'CREATE INDEX idx_offline_status ON offline_records(status, created_at)',
    );
    await db.execute('CREATE INDEX idx_offline_kind ON offline_records(kind)');
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    // Reservado para futuras migraciones locales.
  }

  Future<int> insertOfflineRecord({
    required String kind,
    required String method,
    required String endpoint,
    required Map<String, dynamic> payload,
  }) async {
    final db = await database;
    final now = DateTime.now().toIso8601String();
    return db.insert('offline_records', {
      'uuid': _uuid.v4(),
      'kind': kind,
      'method': method.toUpperCase(),
      'endpoint': endpoint.startsWith('/') ? endpoint : '/$endpoint',
      'payload': jsonEncode(payload),
      'status': 'pending',
      'attempts': 0,
      'created_at': now,
      'updated_at': now,
    });
  }

  Future<List<Map<String, dynamic>>> pendingRecords({int limit = 100}) async {
    final db = await database;
    return db.query(
      'offline_records',
      where: 'status = ?',
      whereArgs: ['pending'],
      orderBy: 'created_at ASC',
      limit: limit,
    );
  }

  Future<int> pendingCount() async {
    final db = await database;
    final result = await db.rawQuery(
      "SELECT COUNT(*) AS total FROM offline_records WHERE status = 'pending'",
    );
    final total = result.first['total'];
    if (total is int) return total;
    return int.tryParse(total.toString()) ?? 0;
  }

  Future<List<Map<String, dynamic>>> recordsByKind({
    required String kind,
    List<String>? statuses,
    int limit = 200,
  }) async {
    final db = await database;
    final whereParts = <String>['kind = ?'];
    final whereArgs = <Object?>[kind];

    if (statuses != null && statuses.isNotEmpty) {
      final placeholders = List.filled(statuses.length, '?').join(', ');
      whereParts.add('status IN ($placeholders)');
      whereArgs.addAll(statuses);
    }

    return db.query(
      'offline_records',
      where: whereParts.join(' AND '),
      whereArgs: whereArgs,
      orderBy: 'created_at DESC',
      limit: limit,
    );
  }

  Future<List<Map<String, dynamic>>> offlineRecords({
    List<String>? statuses,
    int limit = 200,
  }) async {
    final db = await database;
    String? where;
    final whereArgs = <Object?>[];

    if (statuses != null && statuses.isNotEmpty) {
      final placeholders = List.filled(statuses.length, '?').join(', ');
      where = 'status IN ($placeholders)';
      whereArgs.addAll(statuses);
    }

    return db.query(
      'offline_records',
      where: where,
      whereArgs: whereArgs.isEmpty ? null : whereArgs,
      orderBy:
          "CASE WHEN status = 'pending' THEN 0 ELSE 1 END, created_at DESC",
      limit: limit,
    );
  }

  Future<void> markSynced(int id) async {
    final db = await database;
    final now = DateTime.now().toIso8601String();
    await db.update(
      'offline_records',
      {
        'status': 'synced',
        'updated_at': now,
        'synced_at': now,
        'last_error': null,
      },
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<void> markFailed(int id, Object error) async {
    final db = await database;
    final now = DateTime.now().toIso8601String();
    await db.rawUpdate(
      '''
      UPDATE offline_records
      SET attempts = attempts + 1,
          last_error = ?,
          updated_at = ?
      WHERE id = ?
      ''',
      [error.toString(), now, id],
    );
  }

  Future<void> saveJson(String key, Object? value) async {
    final db = await database;
    final now = DateTime.now().toIso8601String();
    await db.insert('cache_items', {
      'cache_key': key,
      'value': jsonEncode(value),
      'updated_at': now,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<void> deleteJson(String key) async {
    final db = await database;
    await db.delete('cache_items', where: 'cache_key = ?', whereArgs: [key]);
  }

  Future<T?> readJson<T>(String key) async {
    final db = await database;
    final rows = await db.query(
      'cache_items',
      columns: ['value'],
      where: 'cache_key = ?',
      whereArgs: [key],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    final raw = rows.first['value'];
    if (raw == null) return null;
    final decoded = jsonDecode(raw.toString());
    if (decoded is T) return decoded;
    return decoded as T?;
  }

  Future<void> clearAllOfflineData() async {
    final db = await database;
    await db.delete('offline_records');
    await db.delete('cache_items');
  }
}
