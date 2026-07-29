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
        // All TV types (Series, Anime, K-Drama, Web Series) use same TMDB TV search
        final tv = await _tmdb.v3.search.queryTvShows(title);
        debugPrint('TMDB TV search for "$title" with type "$type": ${tv['results']?.length ?? 0} results');
        if (tv['results'] != null && (tv['results'] as List).isNotEmpty) {
          for (var show in (tv['results'] as List).take(10)) {
            debugPrint('Adding show: ${show['name']} (ID: ${show['id']})');
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
        } else {
          debugPrint('No TV results found for "$title"');
        }
      }

      // Get cast, trailer, and seasons/episodes for each result
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
          
          // Get seasons and episodes for TV shows
          final details = await _tmdb.v3.tv.getDetails(id);
          final seasons = details['seasons'] as List?;
          if (seasons != null && seasons.isNotEmpty) {
            // Count total seasons (excluding specials with season number 0)
            final seasonCount = seasons.where((s) => s['season_number'] != 0).length;
            result['seasons'] = seasonCount;
            
            // Get episodes from season 1 only
            final season1 = seasons.firstWhere(
              (s) => s['season_number'] == 1,
              orElse: () => null,
            );
            if (season1 != null && season1['episode_count'] != null) {
              result['episodes'] = season1['episode_count'];
              debugPrint('Season 1 episodes for ${result['title']}: ${season1['episode_count']}');
            } else {
              // Fallback: get episodes from first non-special season
              final firstSeason = seasons.firstWhere(
                (s) => s['season_number'] != 0,
                orElse: () => null,
              );
              if (firstSeason != null && firstSeason['episode_count'] != null) {
                result['episodes'] = firstSeason['episode_count'];
                debugPrint('First season episodes for ${result['title']}: ${firstSeason['episode_count']}');
              }
            }
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
      debugPrint('TMDB search error: $e');
      return [];
    }
  }

  Future<List<Map<String, dynamic>>> searchMulti(String title) async {
    try {
      List<Map<String, dynamic>> results = [];
      
      final multi = await _tmdb.v3.search.queryMulti(title);
      debugPrint('TMDB multi-search for "$title": ${multi['results']?.length ?? 0} results');
      
      if (multi['results'] != null && (multi['results'] as List).isNotEmpty) {
        for (var item in (multi['results'] as List).take(20)) {
          final mediaType = item['media_type']; // 'movie', 'tv', 'person'
          
          if (mediaType == 'movie') {
            results.add({
              'title': item['title'] ?? item['original_title'],
              'overview': item['overview'],
              'releaseDate': item['release_date'],
              'posterPath': item['poster_path'],
              'backdropPath': item['backdrop_path'],
              'rating': item['vote_average'],
              'genres': _extractGenres(item['genre_ids']),
              'type': 'Movies',
              'mediaType': 'movie',
              'id': item['id'],
              'originalLanguage': _getLanguageName(item['original_language']),
            });
          } else if (mediaType == 'tv') {
            results.add({
              'title': item['name'] ?? item['original_name'],
              'overview': item['overview'],
              'firstAirDate': item['first_air_date'],
              'posterPath': item['poster_path'],
              'backdropPath': item['backdrop_path'],
              'rating': item['vote_average'],
              'genres': _extractGenres(item['genre_ids']),
              'type': 'Series',
              'mediaType': 'tv',
              'id': item['id'],
              'originalLanguage': _getLanguageName(item['original_language']),
            });
          }
          // Skip 'person' results
        }
      }
      
      return results;
    } catch (e) {
      debugPrint('TMDB multi-search error: $e');
      return [];
    }
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
