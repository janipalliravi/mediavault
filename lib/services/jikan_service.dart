import 'dart:convert';
import 'package:http/http.dart' as http;

class JikanService {
  static const String _baseUrl = 'https://api.jikan.moe/v4';

  Future<List<Map<String, dynamic>>> searchAnime(String query) async {
    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/anime?q=${Uri.encodeComponent(query)}&limit=10'),
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final results = data['data'] as List;
        return results.map((item) => _parseAnimeData(item)).toList();
      } else if (response.statusCode == 504) {
        throw Exception('Jikan API is currently unavailable (504). Please try again later.');
      } else {
        throw Exception('Jikan API returned error ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Failed to search anime: ${e.toString()}');
    }
  }

  Future<List<Map<String, dynamic>>> searchManga(String query) async {
    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/manga?q=${Uri.encodeComponent(query)}&limit=10'),
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final results = data['data'] as List;
        return results.map((item) => _parseMangaData(item)).toList();
      } else if (response.statusCode == 504) {
        throw Exception('Jikan API is currently unavailable (504). Please try again later.');
      } else {
        throw Exception('Jikan API returned error ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Failed to search manga: ${e.toString()}');
    }
  }

  Map<String, dynamic> _parseAnimeData(dynamic item) {
    return {
      'title': item['title'] ?? '',
      'title_japanese': item['title_japanese'] ?? '',
      'title_english': item['title_english'] ?? '',
      'synopsis': item['synopsis'] ?? '',
      'posterPath': item['images']?['jpg']?['large_image_url'] ?? item['images']?['jpg']?['image_url'],
      'backdropPath': item['images']?['jpg']?['large_image_url'],
      'releaseDate': item['aired']?['from'] ?? '',
      'endDate': item['aired']?['to'] ?? '',
      'rating': item['score'] != null ? (item['score'] / 2.0) : null, // Convert 10-point to 5-point
      'episodes': item['episodes'],
      'status': item['status'],
      'type': item['type'],
      'genres': (item['genres'] as List?)?.map((g) => g['name']).toList() ?? [],
      'studios': (item['studios'] as List?)?.map((s) => s['name']).toList() ?? [],
      'source': item['source'],
      'duration': item['duration'],
      'season': item['season'],
      'year': item['year'],
      'mal_id': item['mal_id'],
    };
  }

  Map<String, dynamic> _parseMangaData(dynamic item) {
    return {
      'title': item['title'] ?? '',
      'title_japanese': item['title_japanese'] ?? '',
      'title_english': item['title_english'] ?? '',
      'synopsis': item['synopsis'] ?? '',
      'posterPath': item['images']?['jpg']?['large_image_url'] ?? item['images']?['jpg']?['image_url'],
      'backdropPath': item['images']?['jpg']?['large_image_url'],
      'releaseDate': item['published']?['from'] ?? '',
      'endDate': item['published']?['to'] ?? '',
      'rating': item['score'] != null ? (item['score'] / 2.0) : null, // Convert 10-point to 5-point
      'chapters': item['chapters'],
      'volumes': item['volumes'],
      'status': item['status'],
      'type': item['type'],
      'genres': (item['genres'] as List?)?.map((g) => g['name']).toList() ?? [],
      'authors': (item['authors'] as List?)?.map((a) => a['name']).toList() ?? [],
      'source': item['source'],
      'mal_id': item['mal_id'],
    };
  }

  String getPosterUrl(String? path) {
    if (path == null || path.isEmpty) return '';
    return path;
  }

  String getBackdropUrl(String? path) {
    if (path == null || path.isEmpty) return '';
    return path;
  }
}
