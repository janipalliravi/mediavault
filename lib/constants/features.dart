import 'dart:convert';
import 'package:http/http.dart' as http;

class AppFeatures {
  static const List<String> items = [
    '📱 **MediaVault** - Your Personal Media Library Manager',
    '🎯 **Purpose**: Organize and track your movies, anime, K-dramas, and series in one beautiful app',
    '',
    '💾 **Data Management**',
    '• Local-first storage with automatic encrypted backups',
    '• Export/Import library as JSON with enhanced reliability',
    '• Encrypted backup/restore (.mvb) with device-kept AES key',
    '• Automatic folder backup to prevent data loss',
    '• "Back up now" option for immediate data protection',
    '',
    '🎨 **User Interface**',
    '• Beautiful themes (light/dark) with modern typography',
    '• Grid/List view with smooth scrolling and performance optimization',
    '• Dynamic stats cards that update based on selected category',
    '• Auto-shuffle data cards with on/off toggle in settings',
    '• Responsive design with optimized image loading',
    '',
    '📝 **Content Management**',
    '• Add items with image picker and in-app cropper',
    '• Multiple images per item with auto-rotating carousel',
    '• Configurable carousel interval (including Off)',
    '• Favorites with quick toggle on cards and details',
    '• Star ratings with enhanced visual scale',
    '• Smart duplicate detection (same title, different seasons allowed)',
    '• Related items view for items with same title but different seasons',
    '',
    '🔍 **Search & Filtering**',
    '• Advanced search with intents (e.g., "5 stars", rating:N)',
    '• Fuzzy text search across title, status, language, notes, etc.',
    '• Status, Language filters; Unwatched via Status (>90 days Plan to Watch)',
    '• Category-based filtering (All, Movies, Anime, K-Drama, Series)',
    '• Alphabetical sorting when auto-shuffle is disabled',
    '',
    '📊 **Organization**',
    '• Anime subsection: Manga flag with quick filter',
    '• Web Series subsections: TV/OTT, Regional series, Independent',
    '• Multi-select mode for bulk delete/favorite operations',
    '• Duplicate finder screen with keep-newest cleanup',
    '• Tags from Notes using #hashtags; popular tag chips and tag filters',
    '',
    '🔄 **Sharing & Export**',
    '• Share media card as image (WhatsApp/FB/Instagram)',
    '• Black/white background options for shared images',
    '• High-contrast text for better readability in shared images',
    '• Export library data in multiple formats',
    '',
    '⚡ **Performance & Battery**',
    '• Optimized scrolling for large datasets (100+ items)',
    '• Automatic image compression for smooth performance',
    '• Cached network images for faster loading',
    '• Battery-efficient background processing',
    '• RepaintBoundary optimization for smooth animations',
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


