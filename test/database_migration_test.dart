import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:mediavault/services/database_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Database migration', () {
    setUpAll(() {
      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfi;
    });

    test('adds missing updatedAt column on open', () async {
      final tempDir = await Directory.systemTemp.createTemp('mv_db_test');
      // Point factory to temp directory so we do not touch real app data
      await databaseFactory.setDatabasesPath(tempDir.path);

      final dbPath = p.join(await getDatabasesPath(), 'media_vault.db');
      // Create an old schema without updatedAt column
      final oldDb = await openDatabase(
        dbPath,
        version: 5,
        onCreate: (db, version) async {
          await db.execute('''
            CREATE TABLE media_items (
              id INTEGER PRIMARY KEY AUTOINCREMENT,
              title TEXT NOT NULL,
              type TEXT NOT NULL,
              status TEXT NOT NULL,
              addedDate TEXT,
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
              tags TEXT
            )
          ''');
        },
      );
      await oldDb.close();

      // Open via app service to trigger onOpen configuration/migration
      final svc = DatabaseService();
      final realDb = await svc.database;
      final columns = await realDb.rawQuery('PRAGMA table_info(media_items)');
      final names = columns.map((e) => e['name']).toSet();

      expect(names.contains('updatedAt'), isTrue);
      expect(names.contains('images'), isTrue);
      expect(names.contains('collections'), isTrue);
      expect(names.contains('custom'), isTrue);

      await realDb.close();
    });
  });
}


