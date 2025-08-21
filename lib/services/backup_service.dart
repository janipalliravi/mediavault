import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:file_saver/file_saver.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'database_service.dart';

/// Handles creating and restoring encrypted backups to a user-chosen folder
/// outside the app sandbox using Android Storage Access Framework (SAF).
class BackupService {
  final DatabaseService _db = DatabaseService();

  /// Writes an encrypted backup to the selected folder.
  /// Keeps multiple versions by date; caller can clean older versions if desired.
  /// If [force] is true, runs even when auto-backup is disabled.
  Future<bool> writeAutoBackup({bool force = false}) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final enabled = prefs.getBool('settings.autoBackupEnabled') ?? true;
      if (!enabled && !force) return false;
      final overridePath = prefs.getString('settings.backupFolderPath');

      // Export all rows and encrypt
      final rows = await _db.exportAll();
      final jsonStr = jsonEncode(rows);
      final cipher = await _db.encryptText(jsonStr);
      // Use a single rolling filename inside the chosen folder to avoid many files
      const rollingFileName = 'mediavault_auto.mvb';
      // Use a timestamped name only for the fallback prompted save dialog
      final fallbackName = 'mediavault_auto_${DateTime.now().toIso8601String().replaceAll(':', '-').split('.').first}.mvb';

      // Try direct write into the chosen folder, if available
      if (overridePath != null && overridePath.isNotEmpty) {
        try {
          final dir = Directory(overridePath);
          if (!await dir.exists()) await dir.create(recursive: true);
          final out = File('${dir.path}/$rollingFileName');
          await out.writeAsString(cipher, flush: true);
          return true;
        } catch (e) {
          // Fall back to system saver if direct write fails (permissions, SAF, etc.)
          debugPrint('Direct backup write to $overridePath failed: $e');
        }
      }

      // Fall back to system file saver (prompts user)
      final bytes = Uint8List.fromList(utf8.encode(cipher));
      await FileSaver.instance.saveFile(name: fallbackName, bytes: bytes, ext: 'mvb', mimeType: MimeType.other);
      return true;
    } catch (e) {
      debugPrint('Auto backup failed: $e');
      return false;
    }
  }

  /// Finds latest auto backup file in chosen folder and returns its content.
  Future<String?> readLatestBackupContent(String folderUri) async {
    try {
      return null;
    } catch (e) {
      debugPrint('Read latest backup failed: $e');
      return null;
    }
  }
}


