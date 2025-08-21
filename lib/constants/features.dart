import 'dart:convert';
import 'package:http/http.dart' as http;

class AppFeatures {
  static const List<String> items = [
    'Local-first storage with optional encrypted backups',
    'Protect notes with device-kept AES key',
    'Export/Import library as JSON',
    'Encrypted backup/restore (.mvb)',
    'Beautiful themes (light/dark) and Poppins typography',
    'Add items with image picker and in-app cropper',
    'Automatic image compression for smooth performance',
    'Multiple images per item with auto-rotating carousel',
    'Configurable carousel interval (including Off)',
    'Favorites with quick toggle on cards and details',
    'Star ratings with enhanced visual scale',
    'Search with intents (e.g., "5 stars", rating:N)',
    'Fuzzy-like text search across title, status, language, notes, etc.',
    'Tags from Notes using #hashtags; popular tag chips and tag filters',
    'Status, Language filters; Unwatched via Status (>90 days Plan to Watch)',
    'Anime subsection: Manga flag with quick filter',
    'Web Series subsections: TV/OTT, Regional series, Independent with quick filter',
    'Grid/List view with one-tap toggle',
    'Multi-select mode for bulk delete/favorite/tag',
    'Duplicate finder screen with keep-newest cleanup',
    'Share media card as image (WhatsApp/FB/Instagram)',
  ];
  static Future<List<String>> fetchFromRemote(Uri url) async {
    try {
      final resp = await http.get(url).timeout(const Duration(seconds: 5));
      if (resp.statusCode == 200) {
        final data = jsonDecode(resp.body);
        if (data is List) {
          return data.map((e) => e.toString()).toList();
        }
      }
    } catch (_) {}
    return items;
  }
}


