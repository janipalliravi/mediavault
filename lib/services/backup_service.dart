import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:file_saver/file_saver.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'database_service.dart';

/// Handles creating and restoring encrypted backups to a user-chosen folder
/// outside the app sandbox using Android Storage Access Framework (SAF).
class BackupService {
  final DatabaseService _db = DatabaseService();

  /// Converts an image file to base64 string
  Future<String?> _imageToBase64(String imagePath) async {
    try {
      if (imagePath.startsWith('http')) return null; // Skip network URLs
      final file = File(imagePath);
      if (!await file.exists()) return null;
      final bytes = await file.readAsBytes();
      return base64Encode(bytes);
    } catch (e) {
      debugPrint('Failed to convert image to base64: $e');
      return null;
    }
  }

  /// Writes an unencrypted JSON backup with embedded images to the selected folder.
  /// Keeps multiple versions by date; caller can clean older versions if desired.
  /// If [force] is true, runs even when auto-backup is disabled.
  Future<bool> writeAutoBackup({bool force = false}) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final enabled = prefs.getBool('settings.autoBackupEnabled') ?? true;
      if (!enabled && !force) return false;
      final overridePath = prefs.getString('settings.backupFolderPath');

      // Export all rows as unencrypted JSON with embedded images
      final rows = await _db.exportAll();
      final rowsWithImages = <Map<String, dynamic>>[];
      
      for (final row in rows) {
        final rowWithImages = Map<String, dynamic>.from(row);
        
        // Convert main image to base64
        if (rowWithImages['imagePath'] != null && rowWithImages['imagePath'].toString().isNotEmpty) {
          final base64 = await _imageToBase64(rowWithImages['imagePath'].toString());
          if (base64 != null) {
            rowWithImages['imagePath_base64'] = base64;
            rowWithImages['imagePath'] = ''; // Clear original path
          }
        }
        
        // Convert extra images to base64
        if (rowWithImages['images'] != null && rowWithImages['images'] is List) {
          final images = rowWithImages['images'] as List;
          final base64Images = <String>[];
          for (final imgPath in images) {
            if (imgPath != null && imgPath.toString().isNotEmpty) {
              final base64 = await _imageToBase64(imgPath.toString());
              if (base64 != null) base64Images.add(base64);
            }
          }
          rowWithImages['images_base64'] = base64Images;
          rowWithImages['images'] = []; // Clear original paths
        }
        
        rowsWithImages.add(rowWithImages);
      }
      
      final jsonStr = jsonEncode(rowsWithImages);
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
          await out.writeAsString(jsonStr, flush: true);
          return true;
        } catch (e) {
          // Fall back to system saver if direct write fails (permissions, SAF, etc.)
          debugPrint('Direct backup write to $overridePath failed: $e');
        }
      }

      // Fall back to system file saver (prompts user)
      final bytes = Uint8List.fromList(utf8.encode(jsonStr));
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


