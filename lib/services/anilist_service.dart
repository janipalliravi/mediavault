import 'dart:convert';
import 'package:http/http.dart' as http;

class AniListService {
  static const String _baseUrl = 'https://graphql.anilist.co';

  Future<List<Map<String, dynamic>>> searchAnime(String query) async {
    try {
      final response = await http.post(
        Uri.parse(_baseUrl),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'query': '''
            query {
              Page(page: 1, perPage: 10) {
                media(search: "$query", type: ANIME) {
                  title { english romaji }
                  description
                  coverImage { large medium }
                  bannerImage
                  startDate { year month day }
                  endDate { year month day }
                  averageScore
                  episodes
                  status
                  format
                  genres
                  studios { nodes { name } }
                  source
                  duration
                  season
                  seasonYear
                }
              }
            }
          '''
        }),
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final mediaList = data['data']['Page']['media'] as List;
        return mediaList.map((item) => _parseAnimeData(item)).toList();
      } else {
        throw Exception('AniList API returned error ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Failed to search anime: ${e.toString()}');
    }
  }

  Future<List<Map<String, dynamic>>> searchManga(String query) async {
    try {
      final response = await http.post(
        Uri.parse(_baseUrl),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'query': '''
            query {
              Page(page: 1, perPage: 10) {
                media(search: "$query", type: MANGA) {
                  title { english romaji }
                  description
                  coverImage { large medium }
                  startDate { year month day }
                  endDate { year month day }
                  averageScore
                  chapters
                  volumes
                  status
                  format
                  genres
                  authors { nodes { name } }
                  source
                }
              }
            }
          '''
        }),
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final mediaList = data['data']['Page']['media'] as List;
        return mediaList.map((item) => _parseMangaData(item)).toList();
      } else {
        throw Exception('AniList API returned error ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Failed to search manga: ${e.toString()}');
    }
  }

  Map<String, dynamic> _parseAnimeData(dynamic item) {
    final title = item['title'];
    final startDate = item['startDate'];
    final endDate = item['endDate'];
    
    // Format release date
    String releaseDate = '';
    if (startDate != null) {
      final year = startDate['year'] ?? '';
      final month = startDate['month'] ?? '';
      final day = startDate['day'] ?? '';
      releaseDate = '$year-$month-$day'.replaceAll('null', '').replaceAll('--', '-').replaceAll('- ', '');
    }
    
    return {
      'title': title['english'] ?? title['romaji'] ?? '',
      'title_japanese': title['romaji'] ?? '',
      'title_english': title['english'] ?? '',
      'synopsis': item['description'] ?? '',
      'posterPath': item['coverImage']?['large'] ?? item['coverImage']?['medium'],
      'backdropPath': item['bannerImage'],
      'releaseDate': releaseDate,
      'endDate': _formatDate(endDate),
      'rating': item['averageScore'] != null ? (item['averageScore'] / 20.0) : null, // Convert 100-point to 5-point
      'episodes': item['episodes'],
      'status': item['status'],
      'type': item['format'],
      'genres': (item['genres'] as List?) ?? [],
      'studios': (item['studios']?['nodes'] as List?)?.map((s) => s['name']).toList() ?? [],
      'source': item['source'],
      'duration': item['duration'] != null ? '${item['duration']} min' : null,
      'season': item['season'],
      'year': item['seasonYear'],
    };
  }

  Map<String, dynamic> _parseMangaData(dynamic item) {
    final title = item['title'];
    final startDate = item['startDate'];
    final endDate = item['endDate'];
    
    // Format release date
    String releaseDate = '';
    if (startDate != null) {
      final year = startDate['year'] ?? '';
      final month = startDate['month'] ?? '';
      final day = startDate['day'] ?? '';
      releaseDate = '$year-$month-$day'.replaceAll('null', '').replaceAll('--', '-').replaceAll('- ', '');
    }
    
    return {
      'title': title['english'] ?? title['romaji'] ?? '',
      'title_japanese': title['romaji'] ?? '',
      'title_english': title['english'] ?? '',
      'synopsis': item['description'] ?? '',
      'posterPath': item['coverImage']?['large'] ?? item['coverImage']?['medium'],
      'backdropPath': null,
      'releaseDate': releaseDate,
      'endDate': _formatDate(endDate),
      'rating': item['averageScore'] != null ? (item['averageScore'] / 20.0) : null, // Convert 100-point to 5-point
      'chapters': item['chapters'],
      'volumes': item['volumes'],
      'status': item['status'],
      'type': item['format'],
      'genres': (item['genres'] as List?) ?? [],
      'authors': (item['authors']?['nodes'] as List?)?.map((a) => a['name']).toList() ?? [],
      'source': item['source'],
    };
  }

  String _formatDate(dynamic date) {
    if (date == null) return '';
    final year = date['year'] ?? '';
    final month = date['month'] ?? '';
    final day = date['day'] ?? '';
    return '$year-$month-$day'.replaceAll('null', '').replaceAll('--', '-').replaceAll('- ', '');
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
