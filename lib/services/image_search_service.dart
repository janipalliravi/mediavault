import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

/// Service for searching and fetching movie/anime/series poster images
/// Uses TMDB API (The Movie Database) and OMDb API - free tier available
class ImageSearchService {
  // TMDB API key (public demo key - for production, user should get their own)
  static const String _tmdbApiKey = '2dca580c2a14b55200e784d157207b4d';
  static const String _tmdbBaseUrl = 'https://api.themoviedb.org/3';
  static const String _tmdbImageBaseUrl = 'https://image.tmdb.org/t/p/w342';
  
  // OMDb API key (public demo key - for production, user should get their own)
  static const String _omdbApiKey = 'b9a5e69d';
  static const String _omdbBaseUrl = 'http://www.omdbapi.com';

  /// Search for movies/series by title - fetches from multiple sources with year filter
  Future<List<ImageSearchResult>> searchMedia(String query, {String type = 'movie', int? year}) async {
    try {
      final results = <ImageSearchResult>[];

      // Search TMDB (2 pages) with year filter if provided
      final tmdbEndpoint = type == 'movie' ? '/search/movie' : '/search/tv';
      for (int page = 1; page <= 2; page++) {
        var urlStr = '$_tmdbBaseUrl$tmdbEndpoint?api_key=$_tmdbApiKey&query=$query&page=$page';
        if (year != null) {
          urlStr += '&year=$year';
        }
        final url = Uri.parse(urlStr);
        final response = await http.get(url).timeout(
          const Duration(seconds: 8),
          onTimeout: () => http.Response('Timeout', 408),
        );

        if (response.statusCode == 200) {
          final data = jsonDecode(response.body);
          final pageResults = data['results'] as List;
          results.addAll(pageResults.map((item) => ImageSearchResult.fromJson(item, source: 'tmdb')).toList());
          if (pageResults.isEmpty) break;
        }
      }

      // Search OMDb (additional source) with year filter if provided
      var omdbUrlStr = '$_omdbBaseUrl/?apikey=$_omdbApiKey&s=$query&type=${type == 'movie' ? 'movie' : 'series'}';
      if (year != null) {
        omdbUrlStr += '&y=$year';
      }
      final omdbUrl = Uri.parse(omdbUrlStr);
      final omdbResponse = await http.get(omdbUrl).timeout(
        const Duration(seconds: 8),
        onTimeout: () => http.Response('Timeout', 408),
      );

      if (omdbResponse.statusCode == 200) {
        final data = jsonDecode(omdbResponse.body);
        if (data['Search'] != null) {
          final omdbResults = data['Search'] as List;
          results.addAll(omdbResults.map((item) => ImageSearchResult.fromJson(item, source: 'omdb')).toList());
        }
      }

      // Remove duplicates based on title
      final uniqueResults = <ImageSearchResult>[];
      final seenTitles = <String>{};
      for (final result in results) {
        final titleKey = result.title?.toLowerCase() ?? '';
        if (titleKey.isNotEmpty && !seenTitles.contains(titleKey)) {
          seenTitles.add(titleKey);
          uniqueResults.add(result);
        }
      }

      return uniqueResults;
    } catch (e) {
      debugPrint('Image search error: $e');
      return [];
    }
  }

  /// Get full image URL from poster path
  String getImageUrl(String? posterPath, {String source = 'tmdb'}) {
    if (posterPath == null || posterPath.isEmpty) return '';
    if (source == 'omdb') {
      return posterPath.startsWith('http') ? posterPath : 'https://image.tmdb.org/t/p/w342$posterPath';
    }
    return '$_tmdbImageBaseUrl$posterPath';
  }
}

class ImageSearchResult {
  final String? posterPath;
  final String? title;
  final String? overview;
  final double? voteAverage;
  final String? releaseDate;
  final String source;

  ImageSearchResult({
    this.posterPath,
    this.title,
    this.overview,
    this.voteAverage,
    this.releaseDate,
    this.source = 'tmdb',
  });

  factory ImageSearchResult.fromJson(Map<String, dynamic> json, {String source = 'tmdb'}) {
    if (source == 'omdb') {
      final rating = (json['imdbRating'] as String?) != null 
          ? double.tryParse(json['imdbRating']!)?.clamp(0, 10) 
          : null;
      return ImageSearchResult(
        posterPath: json['Poster'] as String?,
        title: json['Title'] as String?,
        overview: json['Plot'] as String?,
        voteAverage: rating != null ? rating / 2 : null,
        releaseDate: json['Year'] as String?,
        source: 'omdb',
      );
    }
    return ImageSearchResult(
      posterPath: json['poster_path'] as String?,
      title: json['title'] as String? ?? json['name'] as String?,
      overview: json['overview'] as String?,
      voteAverage: (json['vote_average'] as num?)?.toDouble(),
      releaseDate: json['release_date'] as String? ?? json['first_air_date'] as String?,
      source: 'tmdb',
    );
  }
}
