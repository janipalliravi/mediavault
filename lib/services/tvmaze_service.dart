import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:tmdb_api/tmdb_api.dart';
import 'package:flutter/foundation.dart';

class TVMazeService {
  static const String _baseUrl = 'https://api.tvmaze.com';
  static const String _tmdbApiKey = '2dca580c2a14b55200e784d157207b4d';
  late TMDB _tmdb;

  TVMazeService() {
    _tmdb = TMDB(ApiKeys(_tmdbApiKey, ''));
  }

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
        final showData = _parseShowDetails(json.decode(response.body));
        
        // If trailer or cast is missing, try to fetch from TMDB
        final title = showData['title'] as String;
        if (title.isNotEmpty) {
          // Search TMDB for the show
          try {
            final tmdbResults = await _tmdb.v3.search.queryTvShows(title);
            if (tmdbResults['results'] != null && (tmdbResults['results'] as List).isNotEmpty) {
              final tmdbShow = (tmdbResults['results'] as List).first;
              final tmdbId = tmdbShow['id'];
              
              // Fetch trailer from TMDB if not present
              if (showData['trailer'] == null || showData['trailer'].toString().isEmpty) {
                try {
                  final videos = await _tmdb.v3.tv.getVideos(tmdbId);
                  if (videos['results'] != null) {
                    final trailer = videos['results'].firstWhere(
                      (v) => v['type'] == 'Trailer' && v['site'] == 'YouTube',
                      orElse: () => null,
                    );
                    if (trailer != null) {
                      showData['trailer'] = 'https://www.youtube.com/watch?v=${trailer['key']}';
                      debugPrint('Fetched trailer from TMDB for: $title');
                    }
                  }
                } catch (e) {
                  debugPrint('Error fetching trailer from TMDB: $e');
                }
              }
              
              // Fetch cast from TMDB if not present or empty
              if (showData['cast'] == null || showData['cast'].toString().isEmpty) {
                try {
                  final credits = await _tmdb.v3.tv.getCredits(tmdbId);
                  if (credits['cast'] != null) {
                    final castList = credits['cast'].take(5).map((c) => c['name']).toList();
                    if (castList.isNotEmpty) {
                      showData['cast'] = castList.join(', ');
                      debugPrint('Fetched cast from TMDB for: $title');
                    }
                  }
                } catch (e) {
                  debugPrint('Error fetching cast from TMDB: $e');
                }
              }
            }
          } catch (e) {
            debugPrint('Error searching TMDB for show: $e');
          }
        }
        
        return showData;
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
