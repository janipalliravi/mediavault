// Removed unused import

class MediaItem {
  final int? id;
  final String title;
  final String type; // Matches one from AppConstants.categories
  final String status; // Matches one from AppConstants.statuses
  final DateTime? addedDate;
  final DateTime? updatedAt;
  final int? releaseYear;
  final int? watchedYear;
  final String? language;
  final double? rating;
  final String? notes;
  final String? recommend;
  final String? imagePath;

  // Genres are stored as a list in memory and as a comma-separated string in DB
  final List<String>? genres;

  // Optional: store extra metadata in a flexible way
  final Map<String, dynamic>? extra;

  // New fields
  final bool favorite;
  final List<String>? tags;
  final List<String>? collections;
  final List<String>? images; // multiple image paths/URLs
  final Map<String, String>? custom; // simple key-value custom fields

  const MediaItem({
    this.id,
    required this.title,
    required this.type,
    required this.status,
    this.addedDate,
    this.updatedAt,
    this.releaseYear,
    this.watchedYear,
    this.language,
    this.rating,
    this.notes,
    this.recommend,
    this.imagePath,
    this.genres,
    this.extra,
    this.favorite = false,
    this.tags,
    this.collections,
    this.images,
    this.custom,
  });

  /// Convert a MediaItem into a Map for database storage
  Map<String, dynamic> toMap() {
    final map = <String, dynamic>{
      'id': id,
      'title': title,
      'type': type,
      'status': status,
      'addedDate': addedDate?.toIso8601String(),
      'updatedAt': updatedAt?.toIso8601String(),
      'releaseYear': releaseYear,
      'watchedYear': watchedYear,
      'language': language,
      'rating': rating,
      'notes': notes,
      'recommend': recommend,
      'imagePath': imagePath,
      'genres': genres?.join(','),
      'extra': extra != null ? _encodeExtra(extra!) : null,
      'favorite': favorite ? 1 : 0,
      'tags': tags?.join(','),
      'collections': collections?.join(','),
      'images': images?.join(','),
      'custom': custom != null ? _encodeMap(custom!) : null,
    };
    return map;
  }

  /// Create a MediaItem from a database Map
  factory MediaItem.fromMap(Map<String, dynamic> map) {
    return MediaItem(
      id: map['id'] as int?,
      title: map['title'] ?? '',
      type: map['type'] ?? '',
      status: map['status'] ?? '',
      addedDate: map['addedDate'] != null ? DateTime.tryParse(map['addedDate']) : null,
      updatedAt: map['updatedAt'] != null ? DateTime.tryParse(map['updatedAt']) : null,
      releaseYear: map['releaseYear'] as int?,
      watchedYear: map['watchedYear'] as int?,
      language: map['language'] as String?,
      rating: (map['rating'] is int) ? (map['rating'] as int).toDouble() : map['rating'] as double?,
      notes: map['notes'] as String?,
      recommend: map['recommend'] as String?,
      imagePath: map['imagePath'] as String?,
      genres: _parseGenres(map['genres']),
      extra: map['extra'] != null ? _decodeExtra(map['extra']) : null,
      favorite: (map['favorite'] ?? 0) == 1,
      tags: _parseCsv(map['tags']),
      collections: _parseCsv(map['collections']),
      images: _parseCsv(map['images']),
      custom: map['custom'] != null ? _decodeMap(map['custom']) : null,
    );
  }

  MediaItem copyWith({
    int? id,
    String? title,
    String? type,
    String? status,
    DateTime? addedDate,
    DateTime? updatedAt,
    int? releaseYear,
    int? watchedYear,
    String? language,
    double? rating,
    String? notes,
    String? recommend,
    String? imagePath,
    Map<String, dynamic>? extra,
    List<String>? genres,
    bool? favorite,
    List<String>? tags,
    List<String>? collections,
    List<String>? images,
    Map<String, String>? custom,
  }) {
    return MediaItem(
      id: id ?? this.id,
      title: title ?? this.title,
      type: type ?? this.type,
      status: status ?? this.status,
      addedDate: addedDate ?? this.addedDate,
      updatedAt: updatedAt ?? this.updatedAt,
      releaseYear: releaseYear ?? this.releaseYear,
      watchedYear: watchedYear ?? this.watchedYear,
      language: language ?? this.language,
      rating: rating ?? this.rating,
      notes: notes ?? this.notes,
      recommend: recommend ?? this.recommend,
      imagePath: imagePath ?? this.imagePath,
      extra: extra ?? this.extra,
      genres: genres ?? this.genres,
      favorite: favorite ?? this.favorite,
      tags: tags ?? this.tags,
      collections: collections ?? this.collections,
      images: images ?? this.images,
      custom: custom ?? this.custom,
    );
  }

  @override
  String toString() => 'MediaItem(id: $id, title: $title, type: $type, status: $status)';

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is MediaItem &&
        other.id == id &&
        other.title == title &&
        other.type == type &&
        other.status == status;
  }

  @override
  int get hashCode => Object.hash(id, title, type, status);

  static String _encodeExtra(Map<String, dynamic> data) {
    return data.entries.map((e) => '${e.key}=${e.value}').join(';');
  }

  static Map<String, dynamic> _decodeExtra(String encoded) {
    final Map<String, dynamic> result = {};
    for (var pair in encoded.split(';')) {
      if (pair.contains('=')) {
        final parts = pair.split('=');
        result[parts[0]] = parts.length > 1 ? parts[1] : '';
      }
    }
    return result;
  }

  static List<String>? _parseGenres(dynamic value) {
    if (value == null) return null;
    if (value is String) {
      if (value.trim().isEmpty) return <String>[];
      return value.split(',').map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
    }
    return null;
  }

  static List<String>? _parseCsv(dynamic value) {
    if (value == null) return null;
    if (value is String) {
      if (value.trim().isEmpty) return <String>[];
      return value.split(',').map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
    }
    return null;
  }

  static String _encodeMap(Map<String, String> data) {
    return data.entries.map((e) => '${e.key}=${e.value}').join(';');
  }

  static Map<String, String> _decodeMap(String encoded) {
    final Map<String, String> result = {};
    for (var pair in encoded.split(';')) {
      if (pair.contains('=')) {
        final parts = pair.split('=');
        result[parts[0]] = parts.length > 1 ? parts[1] : '';
      }
    }
    return result;
  }
}
