import 'package:tmdb_api/tmdb_api.dart';
import 'package:flutter/foundation.dart';

class TMDBService {
  static const String _apiKey = '2dca580c2a14b55200e784d157207b4d'; // Free TMDB API key
  late TMDB _tmdb;

  TMDBService() {
    _tmdb = TMDB(ApiKeys(_apiKey, ''));
  }

  Future<List<Map<String, dynamic>>> searchByTitle(String title, {String? type}) async {
    try {
      List<Map<String, dynamic>> results = [];
      
      if (type == 'Movies' || type == null) {
        final movies = await _tmdb.v3.search.queryMovies(title);
        if (movies['results'] != null && (movies['results'] as List).isNotEmpty) {
          for (var movie in (movies['results'] as List).take(10)) {
            results.add({
              'title': movie['title'] ?? movie['original_title'],
              'overview': movie['overview'],
              'releaseDate': movie['release_date'],
              'posterPath': movie['poster_path'],
              'backdropPath': movie['backdrop_path'],
              'rating': movie['vote_average'],
              'genres': _extractGenres(movie['genre_ids']),
              'type': 'Movies',
              'id': movie['id'],
              'originalLanguage': _getLanguageName(movie['original_language']),
            });
          }
        }
      }
      
      if (type == 'Series' || type == 'Anime' || type == 'K-Drama' || type == 'Web Series') {
        final tv = await _tmdb.v3.search.queryTvShows(title);
        debugPrint('TMDB TV search results for "$title" (type: $type): ${tv['results']?.length ?? 0} results');
        if (tv['results'] != null && (tv['results'] as List).isNotEmpty) {
          for (var show in (tv['results'] as List).take(10)) {
            results.add({
              'title': show['name'] ?? show['original_name'],
              'overview': show['overview'],
              'firstAirDate': show['first_air_date'],
              'posterPath': show['poster_path'],
              'backdropPath': show['backdrop_path'],
              'rating': show['vote_average'],
              'genres': _extractGenres(show['genre_ids']),
              'type': type,
              'id': show['id'],
              'originalLanguage': _getLanguageName(show['original_language']),
            });
          }
        }
      }

      // Get cast and trailer for each result
      for (var result in results) {
        final id = result['id'];
        if (id == null) continue;
        
        // Get cast information
        if (result['type'] == 'Movies') {
          final credits = await _tmdb.v3.movies.getCredits(id);
          if (credits['cast'] != null) {
            final castList = credits['cast'].take(5).map((c) => c['name']).toList();
            result['cast'] = castList.join(', ');
          }
        } else {
          final credits = await _tmdb.v3.tv.getCredits(id);
          if (credits['cast'] != null) {
            final castList = credits['cast'].take(5).map((c) => c['name']).toList();
            result['cast'] = castList.join(', ');
          }
        }

        // Get trailer
        if (result['type'] == 'Movies') {
          final videos = await _tmdb.v3.movies.getVideos(id);
          if (videos['results'] != null) {
            final trailer = videos['results'].firstWhere(
              (v) => v['type'] == 'Trailer' && v['site'] == 'YouTube',
              orElse: () => null,
            );
            if (trailer != null) {
              result['trailer'] = 'https://www.youtube.com/watch?v=${trailer['key']}';
            }
          }
        } else {
          final videos = await _tmdb.v3.tv.getVideos(id);
          if (videos['results'] != null) {
            final trailer = videos['results'].firstWhere(
              (v) => v['type'] == 'Trailer' && v['site'] == 'YouTube',
              orElse: () => null,
            );
            if (trailer != null) {
              result['trailer'] = 'https://www.youtube.com/watch?v=${trailer['key']}';
            }
          }
        }
      }

      return results;
    } catch (e) {
      debugPrint('TMDB API Error: $e');
    }
    return [];
  }

  List<String> _extractGenres(List<dynamic> genreIds) {
    // Common genre IDs from TMDB
    const genreMap = {
      28: 'Action',
      12: 'Adventure',
      16: 'Animation',
      35: 'Comedy',
      80: 'Crime',
      99: 'Documentary',
      18: 'Drama',
      10751: 'Family',
      14: 'Fantasy',
      36: 'History',
      27: 'Horror',
      10402: 'Music',
      9648: 'Mystery',
      10749: 'Romance',
      878: 'Sci-Fi',
      10770: 'TV Movie',
      53: 'Thriller',
      10752: 'War',
      37: 'Western',
    };

    return genreIds
        .map((id) => genreMap[id] ?? '')
        .where((genre) => genre.isNotEmpty)
        .toList();
  }

  String getPosterUrl(String? path) {
    if (path == null || path.isEmpty) return '';
    return 'https://image.tmdb.org/t/p/w500$path';
  }

  String getBackdropUrl(String? path) {
    if (path == null || path.isEmpty) return '';
    return 'https://image.tmdb.org/t/p/w780$path';
  }

  String _getLanguageName(String? code) {
    if (code == null || code.isEmpty) return '';
    const languageMap = {
      'en': 'English',
      'ja': 'Japanese',
      'ko': 'Korean',
      'zh': 'Chinese',
      'es': 'Spanish',
      'fr': 'French',
      'de': 'German',
      'it': 'Italian',
      'pt': 'Portuguese',
      'ru': 'Russian',
      'ar': 'Arabic',
      'hi': 'Hindi',
      'th': 'Thai',
      'vi': 'Vietnamese',
      'id': 'Indonesian',
      'ms': 'Malay',
      'tr': 'Turkish',
      'pl': 'Polish',
      'nl': 'Dutch',
      'sv': 'Swedish',
      'no': 'Norwegian',
      'da': 'Danish',
      'fi': 'Finnish',
      'uk': 'Ukrainian',
      'cs': 'Czech',
      'el': 'Greek',
      'he': 'Hebrew',
      'bn': 'Bengali',
      'ta': 'Tamil',
      'te': 'Telugu',
      'mr': 'Marathi',
      'ur': 'Urdu',
    };
    return languageMap[code] ?? code;
  }
}
