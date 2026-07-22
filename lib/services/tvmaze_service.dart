import 'dart:convert';
import 'package:http/http.dart' as http;

class TVMazeService {
  static const String _baseUrl = 'https://api.tvmaze.com';

  Future<List<Map<String, dynamic>>> searchShows(String query) async {
    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/search/shows?q=${Uri.encodeComponent(query)}'),
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final results = json.decode(response.body) as List;
        return results.map((item) => _parseShowData(item)).toList();
      }
      return [];
    } catch (e) {
      return [];
    }
  }

  Future<Map<String, dynamic>?> getShowDetails(int id) async {
    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/shows/$id?embed=cast'),
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        return _parseShowDetails(json.decode(response.body));
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  Map<String, dynamic> _parseShowData(dynamic item) {
    final show = item['show'];
    return {
      'title': show['name'] ?? '',
      'posterPath': show['image']?['medium'] ?? show['image']?['original'],
      'backdropPath': show['image']?['original'],
      'releaseDate': show['premiered'] ?? '',
      'rating': show['rating']?['average'] != null ? (show['rating']['average'] / 2.0) : null, // Convert 10-point to 5-point
      'genres': (show['genres'] as List?) ?? [],
      'status': show['status'] ?? '',
      'type': show['type'] ?? '',
      'language': show['language'] ?? '',
      'summary': show['summary'] ?? '',
      'network': show['network']?['name'] ?? '',
      'country': show['network']?['country']?['name'] ?? '',
      'tvmaze_id': show['id'],
    };
  }

  Map<String, dynamic> _parseShowDetails(dynamic show) {
    final cast = show['_embedded']?['cast'] as List?;
    final castNames = cast?.map((c) => c['person']?['name']).toList() ?? [];
    
    return {
      'title': show['name'] ?? '',
      'posterPath': show['image']?['medium'] ?? show['image']?['original'],
      'backdropPath': show['image']?['original'],
      'releaseDate': show['premiered'] ?? '',
      'endDate': show['ended'] ?? '',
      'rating': show['rating']?['average'] != null ? (show['rating']['average'] / 2.0) : null,
      'genres': (show['genres'] as List?) ?? [],
      'status': show['status'] ?? '',
      'type': show['type'] ?? '',
      'language': show['language'] ?? '',
      'summary': show['summary'] ?? '',
      'network': show['network']?['name'] ?? '',
      'country': show['network']?['country']?['name'] ?? '',
      'cast': castNames.join(', '),
      'tvmaze_id': show['id'],
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
