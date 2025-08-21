// Single import: ffi package re-exports sqflite API types/functions
import 'package:path/path.dart';
import 'dart:io' show Platform, Directory;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:sqflite/sqflite.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart' show sqfliteFfiInit, databaseFactoryFfi, databaseFactory;
import '../models/media_item.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:encrypt/encrypt.dart' as enc;

class DatabaseService {
  static final DatabaseService _instance = DatabaseService._internal();
  static Database? _database;

  factory DatabaseService() => _instance;
  DatabaseService._internal();

  final _secure = const FlutterSecureStorage();
  static const _kKeyName = 'mv_aes_key_v1';

  Future<enc.Key> _getOrCreateKey() async {
    String? base64Key = await _secure.read(key: _kKeyName);
    if (base64Key == null) {
      final key = enc.Key.fromSecureRandom(32);
      base64Key = key.base64;
      await _secure.write(key: _kKeyName, value: base64Key);
      return key;
    }
    return enc.Key.fromBase64(base64Key);
  }

  Future<String> encryptText(String plain) async {
    final key = await _getOrCreateKey();
    final iv = enc.IV.fromSecureRandom(16);
    final encrypter = enc.Encrypter(enc.AES(key));
    final encrypted = encrypter.encrypt(plain, iv: iv);
    return '${iv.base64}:${encrypted.base64}';
  }

  Future<String> decryptText(String cipher) async {
    try {
      final parts = cipher.split(':');
      final iv = enc.IV.fromBase64(parts[0]);
      final data = parts[1];
      final key = await _getOrCreateKey();
      final encrypter = enc.Encrypter(enc.AES(key));
      return encrypter.decrypt(enc.Encrypted.fromBase64(data), iv: iv);
    } catch (_) {
      return cipher; // fallback: return as-is
    }
  }

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  /// Initialize DB
  Future<Database> _initDatabase() async {
    if (!kIsWeb && (Platform.isWindows || Platform.isLinux || Platform.isMacOS)) {
      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfi;
    }
    final path = await getDatabasesPath();
    // Ensure directory exists on desktop platforms
    final dir = Directory(path);
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    final databasePath = join(path, 'media_vault.db');

    return await openDatabase(
      databasePath,
      version: 7,
      onCreate: (db, version) async {
        await db.execute(_createTableSQL());
        await _ensureIndexes(db);
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 2) {
          await _safeAddColumns(db);
        }
        if (oldVersion < 3) {
          await _addGenresColumn(db);
        }
        if (oldVersion < 4) {
          await _addExtraColumn(db);
        }
        if (oldVersion < 5) {
          await _addV5Columns(db);
        }
        if (oldVersion < 6) {
          await _addV6Columns(db);
        }
        if (oldVersion < 7) {
          // No schema change; ensure pragmas and indexes
          await _ensureIndexes(db);
        }
        await _ensureIndexes(db);
      },
      onOpen: (db) async {
        // Ensure schema and performance pragmas after opening (outside tx)
        await _addV6Columns(db); // includes updatedAt/images/collections/custom
        await _ensureIndexes(db);
        await _configureDatabase(db);
      },
    );
  }

  /// Create table SQL
  String _createTableSQL() {
    return '''
      CREATE TABLE media_items (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        title TEXT NOT NULL,
        type TEXT NOT NULL,
        status TEXT NOT NULL,
        addedDate TEXT,
        updatedAt TEXT,
        releaseYear INTEGER,
        watchedYear INTEGER,
        language TEXT,
        rating REAL,
        notes TEXT,
        recommend TEXT,
        imagePath TEXT,
        genres TEXT,
        extra TEXT,
        favorite INTEGER DEFAULT 0,
        tags TEXT,
        collections TEXT,
        images TEXT,
        custom TEXT
      )
    ''';
  }

  Future<void> _ensureIndexes(Database db) async {
    // Create helpful indexes if they do not exist
    await db.execute('CREATE INDEX IF NOT EXISTS idx_media_title ON media_items(title)');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_media_type ON media_items(type)');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_media_status ON media_items(status)');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_media_language ON media_items(language)');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_media_added ON media_items(addedDate)');
  }

  Future<void> _configureDatabase(Database db) async {
    // Apply PRAGMAs safely using rawQuery per sqflite requirements
    Future<void> safePragma(String sql) async {
      try {
        await db.rawQuery(sql);
      } catch (_) {
        // Ignore if not supported on platform/Android version
      }
    }
    await safePragma('PRAGMA foreign_keys=ON');
    await safePragma('PRAGMA journal_mode=WAL');
    await safePragma('PRAGMA synchronous=NORMAL');
    await safePragma('PRAGMA temp_store=MEMORY');
  }

  /// Safely add columns if they don't exist (migration)
  Future<void> _safeAddColumns(Database db) async {
    final columnNames = (await db.rawQuery('PRAGMA table_info(media_items)'))
        .map((row) => row['name'] as String)
        .toSet();

    Future<void> addColumn(String name, String type) async {
      if (!columnNames.contains(name)) {
        await db.execute('ALTER TABLE media_items ADD COLUMN $name $type');
      }
    }

    await addColumn('addedDate', 'TEXT');
    await addColumn('releaseYear', 'INTEGER');
    await addColumn('watchedYear', 'INTEGER');
    await addColumn('language', 'TEXT');
    await addColumn('rating', 'REAL');
    await addColumn('notes', 'TEXT');
    await addColumn('recommend', 'TEXT');
    await addColumn('imagePath', 'TEXT');
    await addColumn('genres', 'TEXT');
    await addColumn('extra', 'TEXT');
  }

  Future<void> _addGenresColumn(Database db) async {
    final columnNames = (await db.rawQuery('PRAGMA table_info(media_items)'))
        .map((row) => row['name'] as String)
        .toSet();
    if (!columnNames.contains('genres')) {
      await db.execute('ALTER TABLE media_items ADD COLUMN genres TEXT');
    }
  }

  Future<void> _addExtraColumn(Database db) async {
    final columnNames = (await db.rawQuery('PRAGMA table_info(media_items)'))
        .map((row) => row['name'] as String)
        .toSet();
    if (!columnNames.contains('extra')) {
      await db.execute('ALTER TABLE media_items ADD COLUMN extra TEXT');
    }
  }

  Future<void> _addV5Columns(Database db) async {
    final columnNames = (await db.rawQuery('PRAGMA table_info(media_items)'))
        .map((row) => row['name'] as String)
        .toSet();
    if (!columnNames.contains('favorite')) {
      await db.execute('ALTER TABLE media_items ADD COLUMN favorite INTEGER DEFAULT 0');
    }
    if (!columnNames.contains('tags')) {
      await db.execute('ALTER TABLE media_items ADD COLUMN tags TEXT');
    }
  }

  Future<void> _addV6Columns(Database db) async {
    final columnNames = (await db.rawQuery('PRAGMA table_info(media_items)'))
        .map((row) => row['name'] as String)
        .toSet();
    if (!columnNames.contains('collections')) {
      await db.execute('ALTER TABLE media_items ADD COLUMN collections TEXT');
    }
    if (!columnNames.contains('images')) {
      await db.execute('ALTER TABLE media_items ADD COLUMN images TEXT');
    }
    if (!columnNames.contains('custom')) {
      await db.execute('ALTER TABLE media_items ADD COLUMN custom TEXT');
    }
    if (!columnNames.contains('updatedAt')) {
      await db.execute('ALTER TABLE media_items ADD COLUMN updatedAt TEXT');
    }
  }

  /// CRUD Operations
  Future<List<MediaItem>> getItems() async {
    final db = await database;
    final maps = await db.query('media_items', orderBy: 'addedDate DESC');
    return maps.map((map) => MediaItem.fromMap(map)).toList();
  }

  Future<int> insertItem(MediaItem item) async {
    final db = await database;
    return await db.insert(
      'media_items',
      item.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<int> updateItem(MediaItem item) async {
    if (item.id == null) {
      throw ArgumentError('Cannot update an item without an ID.');
    }
    final db = await database;
    return await db.update(
      'media_items',
      item.toMap(),
      where: 'id = ?',
      whereArgs: [item.id],
    );
  }

  Future<void> deleteItem(int id) async {
    final db = await database;
    await db.delete(
      'media_items',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  /// For debugging: Clear all data
  Future<void> clearAllItems() async {
    final db = await database;
    await db.delete('media_items');
  }

  Future<List<Map<String, dynamic>>> exportAll() async {
    final db = await database;
    return db.query('media_items');
  }

  Future<void> importFrom(List<Map<String, dynamic>> rows) async {
    final db = await database;
    final batch = db.batch();
    for (final row in rows) {
      batch.insert('media_items', row, conflictAlgorithm: ConflictAlgorithm.replace);
    }
    await batch.commit(noResult: true);
  }
}
