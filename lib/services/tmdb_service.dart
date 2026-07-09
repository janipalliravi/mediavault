import 'package:tmdb_api/tmdb_api.dart';
import 'package:flutter/foundation.dart';

class TMDBService {
  static const String _apiKey = '2dca580c2a14b55200e784d157207b4d'; // Free TMDB API key
  late TMDB _tmdb;

  TMDBService() {
    _tmdb = TMDB(ApiKeys(_apiKey, ''));
  }

  Future<Map<String, dynamic>?> searchByTitle(String title, {String? type}) async {
    try {
      Map<String, dynamic> result = {};
      
      if (type == 'Movies' || type == null) {
        final movies = await _tmdb.v3.search.queryMovies(title);
        if (movies['results'] != null && (movies['results'] as List).isNotEmpty) {
          final movie = movies['results'][0];
          result['title'] = movie['title'] ?? movie['original_title'];
          result['overview'] = movie['overview'];
          result['releaseDate'] = movie['release_date'];
          result['posterPath'] = movie['poster_path'];
          result['backdropPath'] = movie['backdrop_path'];
          result['rating'] = movie['vote_average'];
          result['genres'] = _extractGenres(movie['genre_ids']);
          result['type'] = 'Movies';
          result['id'] = movie['id'];
        }
      } else if (type == 'Series' || type == 'Anime' || type == 'K-Drama') {
        final tv = await _tmdb.v3.search.queryTvShows(title);
        if (tv['results'] != null && (tv['results'] as List).isNotEmpty) {
          final show = tv['results'][0];
          result['title'] = show['name'] ?? show['original_name'];
          result['overview'] = show['overview'];
          result['firstAirDate'] = show['first_air_date'];
          result['posterPath'] = show['poster_path'];
          result['backdropPath'] = show['backdrop_path'];
          result['rating'] = show['vote_average'];
          result['genres'] = _extractGenres(show['genre_ids']);
          result['type'] = type;
          result['id'] = show['id'];
        }
      }

      if (result.isNotEmpty) {
        final id = result['id'];
        if (id == null) return result;
        
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

        return result;
      }
    } catch (e) {
      debugPrint('TMDB API Error: $e');
    }
    return null;
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
}
