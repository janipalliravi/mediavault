import 'dart:convert';
import 'package:http/http.dart' as http;

/// Service for searching and fetching movie/anime/series poster images
/// Uses TMDB API (The Movie Database) - free tier available
class ImageSearchService {
  // TMDB API key (public demo key - for production, user should get their own)
  static const String _apiKey = '2dca580c2a14b55200e784d157207b4d';
  static const String _baseUrl = 'https://api.themoviedb.org/3';
  static const String _imageBaseUrl = 'https://image.tmdb.org/t/p/w500';

  /// Search for movies/series by title - fetches multiple pages for more results
  Future<List<ImageSearchResult>> searchMedia(String query, {String type = 'movie'}) async {
    try {
      final endpoint = type == 'movie' ? '/search/movie' : '/search/tv';
      final results = <ImageSearchResult>[];

      // Fetch first 3 pages to get more results
      for (int page = 1; page <= 3; page++) {
        final url = Uri.parse('$_baseUrl$endpoint?api_key=$_apiKey&query=$query&page=$page');
        final response = await http.get(url).timeout(
          const Duration(seconds: 10),
          onTimeout: () => http.Response('Timeout', 408),
        );

        if (response.statusCode == 200) {
          final data = jsonDecode(response.body);
          final pageResults = data['results'] as List;
          results.addAll(pageResults.map((item) => ImageSearchResult.fromJson(item)).toList());

          // If no more results, stop fetching
          if (pageResults.isEmpty) break;
        }
      }

      return results;
    } catch (e) {
      print('Image search error: $e');
      return [];
    }
  }

  /// Get full image URL from poster path
  String getImageUrl(String? posterPath) {
    if (posterPath == null || posterPath.isEmpty) return '';
    return '$_imageBaseUrl$posterPath';
  }
}

class ImageSearchResult {
  final String? posterPath;
  final String? title;
  final String? overview;
  final double? voteAverage;
  final String? releaseDate;

  ImageSearchResult({
    this.posterPath,
    this.title,
    this.overview,
    this.voteAverage,
    this.releaseDate,
  });

  factory ImageSearchResult.fromJson(Map<String, dynamic> json) {
    return ImageSearchResult(
      posterPath: json['poster_path'] as String?,
      title: json['title'] as String? ?? json['name'] as String?,
      overview: json['overview'] as String?,
      voteAverage: (json['vote_average'] as num?)?.toDouble(),
      releaseDate: json['release_date'] as String? ?? json['first_air_date'] as String?,
    );
  }
}
