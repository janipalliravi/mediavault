import 'package:flutter/material.dart';
import '../models/media_item.dart';
import '../services/database_service.dart';
import '../services/backup_service.dart';
import 'settings_provider.dart';

class MediaProvider with ChangeNotifier {
  final DatabaseService _databaseService = DatabaseService();
  // Settings reference is not directly available here; BackupService takes settings as arg.
  // Provide a default settings snapshot for auto-backup best-effort.
  final SettingsProvider contextSettings = SettingsProvider();

  List<MediaItem> _items = [];
  String _currentCategory = 'All';
  String _searchQuery = '';
  String _statusFilter = 'All';
  String _languageFilter = 'All';
  bool _isGridView = true;
  final Set<String> _selectedTags = <String>{};
  bool _mangaOnlyFilter = false;
  String _webSeriesKindFilter = 'All';
  bool _selectionMode = false;
  final Set<int> _selectedIds = <int>{};

  // Simple caches
  List<MediaItem>? _filteredCache;
  Map<String, int>? _statsCache;

  void _invalidateCache() {
    _filteredCache = null;
    _statsCache = null;
  }

  MediaProvider() {
    // Firebase services disabled for simplified deployment
  }

  String _normalizeStatusLabel(String status) {
    switch (status) {
      case 'Completed':
        return 'Done';
      case 'Plan to Watch':
        return 'Watch list';
      default:
        return status;
    }
  }

  String _normalizeTypeLabel(String type) {
    switch (type) {
      case 'Web Series':
      case 'WebSeries':
        return 'Series';
      default:
        return type;
    }
  }



  List<MediaItem> get items => _filteredItems();
  String get currentCategory => _currentCategory;
  String get searchQuery => _searchQuery;
  String get statusFilter => _statusFilter;
  String get languageFilter => _languageFilter;
  bool get isGridView => _isGridView;
  List<String> get selectedTags => _selectedTags.toList(growable: false)..sort();
  bool get mangaOnlyFilter => _mangaOnlyFilter;
  String get webSeriesKindFilter => _webSeriesKindFilter;
  bool get selectionMode => _selectionMode;
  Set<int> get selectedIds => _selectedIds;

  List<MediaItem> _filteredItems() {
    if (_filteredCache != null) return _filteredCache!;
    final query = _searchQuery.trim().toLowerCase();
    // Detect star rating intent in query, e.g., "5 stars", "4 star", "rating:3"
    int? starQuery;
    final starRegex = RegExp(r'(?:rating\s*[:=]?\s*)?([1-5])\s*stars?');
    final starMatch = starRegex.firstMatch(query);
    if (starMatch != null) {
      starQuery = int.tryParse(starMatch.group(1)!);
    }
    // Detect at-least star query, e.g., "4+"
    int? starAtLeastQuery;
    final starPlus = RegExp(r'(?:rating\s*[:=]?\s*)?([1-5])\s*\+');
    final starPlusMatch = starPlus.firstMatch(query);
    if (starPlusMatch != null) {
      starAtLeastQuery = int.tryParse(starPlusMatch.group(1)!);
    }
    // Parse tag filters like tag:family
    final Iterable<RegExpMatch> tagMatches = RegExp(r'tag:([\w-]+)').allMatches(query);
    final List<String> tagFilters = tagMatches.map((m) => m.group(1)!.toLowerCase()).toList();

    // Derive language tokens from current data to enable language parsing from query
    final Set<String> knownLanguages = _items
        .map((e) => (e.language ?? '').trim().toLowerCase())
        .where((e) => e.isNotEmpty)
        .toSet();

    // Infer status/type/language/year tokens from query
    bool wantsUnwatched = query.contains(RegExp(r'\bunwatched\b'));
    String? statusToken;
    if (query.contains(RegExp(r'\bdone\b'))) statusToken = 'Done';
    if (query.contains(RegExp(r'\bwatching\b'))) statusToken = 'Watching';
    if (query.contains(RegExp(r'\bwatch\s*list\b'))) statusToken = 'Watch list';

    String? typeToken;
    if (query.contains(RegExp(r'\banime\b'))) typeToken = 'Anime';
    if (query.contains(RegExp(r'\bmovies?\b'))) typeToken = 'Movies';
    if (query.contains(RegExp(r'\bk-?drama\b'))) typeToken = 'K-Drama';
    if (query.contains(RegExp(r'\bseries\b'))) typeToken = 'Series';

    String? languageToken;
    for (final lang in knownLanguages) {
      if (lang.isEmpty) continue;
      if (RegExp('\\b${RegExp.escape(lang)}\\b').hasMatch(query)) {
        languageToken = lang;
        break;
      }
    }

    int? yearStart;
    int? yearEnd;
    final decade = RegExp(r'(19|20)\\d0s');
    final singleYear = RegExp(r'(?<!\\d)(19|20)\\d{2}(?!\\d)');
    final range = RegExp(r'(?<!\\d)((?:19|20)\\d{2})\\s*[-to]{1,3}\\s*((?:19|20)\\d{2})(?!\\d)');
    final rangeMatch = range.firstMatch(query);
    if (rangeMatch != null) {
      yearStart = int.tryParse(rangeMatch.group(1)!);
      yearEnd = int.tryParse(rangeMatch.group(2)!);
      if (yearStart != null && yearEnd != null && yearStart > yearEnd) {
        final tmp = yearStart; yearStart = yearEnd; yearEnd = tmp;
      }
    } else {
      final decadeMatch = decade.firstMatch(query);
      if (decadeMatch != null) {
        final base = int.tryParse(decadeMatch.group(0)!.substring(0, 3));
        if (base != null) { yearStart = base * 10; yearEnd = yearStart + 9; }
      } else {
        final yearMatch = singleYear.firstMatch(query);
        if (yearMatch != null) {
          yearStart = int.tryParse(yearMatch.group(0)!);
          yearEnd = yearStart;
        }
      }
    }

    String stripTokens(String q) {
      var out = q;
      // Remove tag: tokens handled separately
      out = out.replaceAll(RegExp(r'tag:[\w-]+'), ' ');
      // Remove rating tokens already parsed
      out = out.replaceAll(starRegex, ' ');
      out = out.replaceAll(starPlus, ' ');
      // Remove status/type/decade/year tokens
      out = out.replaceAll(RegExp(r'\bunwatched\b|\bcompleted\b|\bwatching\b|\bplan(\s*to\s*watch)?\b'), ' ');
      out = out.replaceAll(RegExp(r'\banime\b|\bmovies?\b|\bk-?drama\b|\bweb\s*series\b|\bwebseries\b'), ' ');
      if (languageToken != null) {
        out = out.replaceAll(RegExp('\\b${RegExp.escape(languageToken)}\\b'), ' ');
      }
      out = out.replaceAll(range, ' ');
      out = out.replaceAll(decade, ' ');
      out = out.replaceAll(singleYear, ' ');
      return out.trim();
    }
    bool matchesFuzzy(String haystack, String needle) {
      int i = 0, j = 0;
      while (i < haystack.length && j < needle.length) {
        if (haystack.codeUnitAt(i) == needle.codeUnitAt(j)) j++;
        i++;
      }
      return j == needle.length;
    }

    bool matchesQuery(MediaItem item) {
      if (query.isEmpty) return true;
      final fields = <String?>[
        item.title,
        item.type,
        item.status,
        item.language,
        item.notes,
        item.recommend,
        item.releaseYear?.toString(),
        item.watchedYear?.toString(),
        ...?item.genres,
        ...?item.extra?.entries.map((e) => '${e.key}:${e.value}')
      ];
      bool anyFieldContains(String q) => fields
          .whereType<String>()
          .any((f) => f.toLowerCase().contains(q));

      // Tag filters (AND across tags)
      if (tagFilters.isNotEmpty) {
        final itemTags = (item.tags ?? const <String>[]).map((t) => t.toLowerCase()).toSet();
        if (!tagFilters.every((t) => itemTags.contains(t))) return false;
      }

      bool tokensOk() {
        // Status token logic: includes special unwatched
        if (wantsUnwatched) {
          final isPlan = item.status == 'Watch list';
          final added = item.addedDate;
          final cutoff = DateTime.now().subtract(const Duration(days: 90));
          if (!(isPlan && (added != null && added.isBefore(cutoff)))) return false;
        }
        if (statusToken != null && !wantsUnwatched) {
          if (item.status != statusToken) return false;
        }
        if (typeToken != null && item.type != typeToken) return false;
        if (languageToken != null) {
          final lang = (item.language ?? '').toLowerCase();
          if (lang != languageToken) return false;
        }
        if (yearStart != null) {
          final y = item.releaseYear ?? -1;
          if (y < yearStart || (yearEnd != null && y > yearEnd)) return false;
        }
        return true;
      }

      if (starQuery != null) {
        final cleanedQuery = stripTokens(query);
        final withoutTags = cleanedQuery;
        final ratingMatches = (item.rating?.round() ?? -1) == starQuery;
        if (withoutTags.isEmpty) {
          return (ratingMatches || anyFieldContains(query)) && tokensOk();
        } else {
          return ratingMatches && anyFieldContains(withoutTags) && tokensOk();
        }
      }
      if (starAtLeastQuery != null) {
        final cleanedQuery = stripTokens(query);
        final withoutTags = cleanedQuery;
        final ratingOk = (item.rating?.round() ?? 0) >= starAtLeastQuery;
        if (withoutTags.isEmpty) return ratingOk && tokensOk();
        return ratingOk && anyFieldContains(withoutTags) && tokensOk();
      }
      const fuzzThreshold = 3;
      final cleaned = stripTokens(query);
      if (cleaned.isEmpty) return tokensOk();
      if (anyFieldContains(cleaned)) return tokensOk();
      if (cleaned.length <= fuzzThreshold) {
        final fieldsJoined = fields.whereType<String>().map((e) => e.toLowerCase()).join(' ');
        return matchesFuzzy(fieldsJoined, cleaned) && tokensOk();
      }
      return false;
    }

    _filteredCache = _items
        .where((item) {
          bool matchesCategory;
          if (_currentCategory == 'All') {
            matchesCategory = true;
          } else if (_currentCategory == 'Unwatched') {
            final isPlan = item.status == 'Watch list';
            final added = item.addedDate;
            final cutoff = DateTime.now().subtract(const Duration(days: 90));
            matchesCategory = isPlan && (added != null && added.isBefore(cutoff));
          } else {
            matchesCategory = item.type == _currentCategory;
          }
          bool matchesStatus;
          if (_statusFilter == 'All') {
            matchesStatus = true;
          } else if (_statusFilter == 'Unwatched') {
            final isPlan = item.status == 'Watch list';
            final added = item.addedDate;
            final cutoff = DateTime.now().subtract(const Duration(days: 90));
            matchesStatus = isPlan && (added != null && added.isBefore(cutoff));
          } else {
            matchesStatus = item.status == _statusFilter;
          }
          final matchesLanguage = _languageFilter == 'All' ||
              ((item.language ?? '').toLowerCase() == _languageFilter.toLowerCase());
          final matchesSelectedTags = _selectedTags.isEmpty
              ? true
              : ((_selectedTags).every((t) => (item.tags ?? const <String>[]) 
                  .map((e) => e.toLowerCase())
                  .toSet()
                  .contains(t.toLowerCase())));
          final matchesSearch = matchesQuery(item);
          // Subsection filters (if added)
          bool okManga = true;
          bool okWs = true;
          // We will store subsection filters via setters; defaults allow all
          if (mangaOnlyFilter) {
            okManga = (item.type == 'Anime' && (item.extra?['manga']?.toString().toLowerCase() == 'true'));
          }
          if (webSeriesKindFilter != 'All') {
            okWs = (item.type == 'Series' && (item.extra?['wsKind']?.toString() == webSeriesKindFilter));
          }
          return matchesCategory && matchesSearch && matchesStatus && matchesLanguage && matchesSelectedTags && okManga && okWs;
        })
        .toList(growable: false);
    return _filteredCache!;
  }

  Map<String, int> getStats() {
    if (_statsCache != null) return _statsCache!;
    _statsCache = {
      'Total Items': _items.length,
      'Done': _items.where((item) => item.status == 'Done').length,
      'Watching': _items.where((item) => item.status == 'Watching').length,
      'Watch list': _items.where((item) => item.status == 'Watch list').length,
    };
    return _statsCache!;
  }

  Future<void> loadItems() async {
    try {
      // Load in chunks to avoid UI jank for very large datasets
      final all = await _databaseService.getItems();
      // Normalize legacy labels (status/type) and persist changes so UI is consistent everywhere
      final List<MediaItem> normalized = [];
      for (final it in all) {
        final newStatus = _normalizeStatusLabel(it.status);
        final newType = _normalizeTypeLabel(it.type);
        if (newStatus != it.status || newType != it.type) {
          final updated = it.copyWith(status: newStatus, type: newType);
          await _databaseService.updateItem(updated);
          normalized.add(updated);
        } else {
          normalized.add(it);
        }
      }
      _items = normalized;
      _invalidateCache();
      notifyListeners();
      _invalidateCache();

      // Cloud sync disabled for simplified deployment
    } catch (e) {
      debugPrint('Error loading items: $e');
    }
  }

  /// Fast, non-blocking initial load to quickly show UI
  Future<void> warmStart() async {
    // Fire and forget
    // In case we want to do any lightweight prefetching later
    try {
      await loadItems();
    } catch (_) {}
  }

  Future<void> addItem(MediaItem item) async {
    try {
      final now = DateTime.now();
      final toSave = item.copyWith(addedDate: item.addedDate ?? now, updatedAt: now);
      // Prevent duplicate merge across different types (e.g., Anime vs Movies)
      final exists = _items.any((e) =>
          e.title.trim().toLowerCase() == item.title.trim().toLowerCase() &&
          (e.releaseYear ?? -1) == (item.releaseYear ?? -1) &&
          e.type == item.type);
      if (exists) {
        throw Exception('Duplicate exists for same type and year');
      }
      final id = await _databaseService.insertItem(toSave);
      final saved = toSave.copyWith(id: id);
      _items.insert(0, saved);
      _invalidateCache();
      // Cloud sync disabled for simplified deployment
      notifyListeners();
      // Fire-and-forget auto backup
      // Auto backup is best-effort; run via service that reads settings internally
      // Defer to BackupService; if settings not available, it will no-op
      try { await BackupService().writeAutoBackup(); } catch (_) {}
    } catch (e) {
      debugPrint('Error adding item: $e');
    }
  }

  Future<void> updateItem(MediaItem item) async {
    if (item.id == null) {
      debugPrint('Error: Cannot update an item without an ID.');
      return;
    }
    try {
      final updated = item.copyWith(updatedAt: DateTime.now());
      await _databaseService.updateItem(updated);
      final index = _items.indexWhere((it) => it.id == updated.id);
      if (index != -1) {
        _items[index] = updated;
      } else {
        // If item not found in memory, reload from DB to ensure list sync
        await loadItems();
      }
      _invalidateCache();
      // Cloud sync disabled for simplified deployment
      notifyListeners();
      try { await BackupService().writeAutoBackup(); } catch (_) {}
    } catch (e) {
      debugPrint('Error updating item: $e');
    }
  }

  Future<void> deleteItem(int id) async {
    try {
      await _databaseService.deleteItem(id);
      _items.removeWhere((e) => e.id == id);
      // Cloud sync disabled for simplified deployment
      _invalidateCache();
      notifyListeners();
      try { await BackupService().writeAutoBackup(); } catch (_) {}
    } catch (e) {
      debugPrint('Error deleting item: $e');
    }
  }

  void setCategory(String category) {
    if (_currentCategory != category) {
      _currentCategory = category;
      _invalidateCache();
      notifyListeners();
    }
  }

  void setSearchQuery(String query) {
    _searchQuery = query;
    _invalidateCache();
    notifyListeners();
  }

  void setStatusFilter(String filter) {
    if (_statusFilter != filter) {
      _statusFilter = filter;
      _invalidateCache();
      notifyListeners();
    }
  }

  void setLanguageFilter(String filter) {
    if (_languageFilter != filter) {
      _languageFilter = filter;
      _invalidateCache();
      notifyListeners();
    }
  }

  void toggleView() {
    _isGridView = !_isGridView;
    notifyListeners();
  }

  void resetFilters() {
    _currentCategory = 'All';
    _searchQuery = '';
    _statusFilter = 'All';
    _languageFilter = 'All';
    _selectedTags.clear();
    _selectionMode = false;
    _selectedIds.clear();
    notifyListeners();
  }

  Future<Map<String, int>> importFromJsonDynamic(List<dynamic> payload) async {
    int inserted = 0;
    int updated = 0;
    int skipped = 0;
    try {
      // Build existing index by normalized title + type + releaseYear
      final List<MediaItem> current = await _databaseService.getItems();
      Map<String, MediaItem> keyToItem = {
        for (final it in current)
          _compositeKey(it.title, it.type, it.releaseYear): it
      };

      for (final rec in payload) {
        if (rec is! Map) { skipped++; continue; }
        final Map<String, dynamic> m = Map<String, dynamic>.from(rec.cast<String, dynamic>());
        final String rawTitle = (m['title'] ?? '').toString().trim();
        if (rawTitle.isEmpty) { skipped++; continue; }
        final String rawType = (m['type'] ?? '').toString().trim();
        final String type = _normalizeTypeLabel(rawType.isEmpty ? 'Movies' : rawType);
        final String status = _normalizeStatusLabel((m['status'] ?? 'Watch list').toString());
        final int? releaseYear = _toInt(m['releaseYear']);
        final int? watchedYear = _toInt(m['watchedYear']);
        final String? language = _toStr(m['language']);
        final double? rating = _toDouble(m['rating']);
        final String? notes = _toStr(m['notes']);
        final String? recommend = _toStr(m['recommend']);
        final String? imagePath = _toStr(m['imagePath']);
        final List<String>? genres = _toStringList(m['genres']);
        final Map<String, dynamic>? extra = _toStringDynamicMap(m['extra']);
        final bool favorite = _toBool(m['favorite']);
        final List<String>? tags = _toStringList(m['tags']);
        final List<String>? collections = _toStringList(m['collections']);
        final List<String>? images = _toStringList(m['images']);
        final Map<String, String>? custom = _toStringStringMap(m['custom']);
        final DateTime? addedDate = _toDateTime(m['addedDate']);
        final DateTime? updatedAt = _toDateTime(m['updatedAt']);

        final String key = _compositeKey(rawTitle, type, releaseYear);
        final now = DateTime.now();
        final candidate = MediaItem(
          title: rawTitle,
          type: type,
          status: status,
          addedDate: addedDate ?? now,
          updatedAt: updatedAt ?? now,
          releaseYear: releaseYear,
          watchedYear: watchedYear,
          language: language,
          rating: rating,
          notes: notes,
          recommend: recommend,
          imagePath: imagePath,
          genres: genres,
          extra: extra,
          favorite: favorite,
          tags: tags,
          collections: collections,
          images: images,
          custom: custom,
        );

        final existing = keyToItem[key];
        if (existing == null) {
          final id = await _databaseService.insertItem(candidate);
          keyToItem[key] = candidate.copyWith(id: id);
          inserted++;
        } else {
          // Merge: prefer non-null incoming values, union lists, preserve existing where incoming is null
          MediaItem merged = existing.copyWith(
            title: candidate.title.isNotEmpty ? candidate.title : existing.title,
            status: candidate.status.isNotEmpty ? candidate.status : existing.status,
            releaseYear: candidate.releaseYear ?? existing.releaseYear,
            watchedYear: candidate.watchedYear ?? existing.watchedYear,
            language: candidate.language ?? existing.language,
            rating: candidate.rating ?? existing.rating,
            notes: candidate.notes ?? existing.notes,
            recommend: candidate.recommend ?? existing.recommend,
            imagePath: candidate.imagePath ?? existing.imagePath,
            genres: {
              ...?existing.genres,
              ...?candidate.genres,
            }.toList(),
            extra: {
              ...?existing.extra,
              ...?candidate.extra,
            },
            favorite: existing.favorite || candidate.favorite,
            tags: {
              ...?existing.tags,
              ...?candidate.tags,
            }.toList(),
            collections: {
              ...?existing.collections,
              ...?candidate.collections,
            }.toList(),
            images: {
              ...?existing.images,
              ...?candidate.images,
            }.toList(),
            custom: {
              ...?existing.custom,
              ...?candidate.custom,
            },
            addedDate: existing.addedDate ?? candidate.addedDate,
            updatedAt: (candidate.updatedAt ?? existing.updatedAt ?? existing.addedDate) ?? DateTime.now(),
          );
          await _databaseService.updateItem(merged);
          keyToItem[key] = merged;
          updated++;
        }
      }

      // Refresh in-memory list
      _items = await _databaseService.getItems();
      _invalidateCache();
      notifyListeners();
    } catch (_) {
      // On any critical error, surface minimal info via counts
    }
    return {
      'inserted': inserted,
      'updated': updated,
      'skipped': skipped,
    };
  }

  String _compositeKey(String title, String type, int? releaseYear) {
    final t = title.trim().toLowerCase();
    final yr = releaseYear ?? -1;
    return '$t::$type::$yr';
  }

  int? _toInt(dynamic v) {
    if (v == null) return null;
    if (v is int) return v;
    return int.tryParse(v.toString());
  }

  double? _toDouble(dynamic v) {
    if (v == null) return null;
    if (v is double) return v;
    if (v is int) return v.toDouble();
    return double.tryParse(v.toString());
  }

  String? _toStr(dynamic v) => v?.toString();

  bool _toBool(dynamic v) {
    if (v == null) return false;
    if (v is bool) return v;
    if (v is int) return v != 0;
    final s = v.toString().toLowerCase();
    return s == 'true' || s == '1' || s == 'yes';
  }

  DateTime? _toDateTime(dynamic v) {
    if (v == null) return null;
    if (v is DateTime) return v;
    return DateTime.tryParse(v.toString());
  }

  List<String>? _toStringList(dynamic v) {
    if (v == null) return null;
    if (v is List) {
      return v.map((e) => e.toString()).where((e) => e.trim().isNotEmpty).toList();
    }
    if (v is String) {
      if (v.trim().isEmpty) return <String>[];
      return v.split(',').map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
    }
    return null;
  }

  Map<String, dynamic>? _toStringDynamicMap(dynamic v) {
    if (v == null) return null;
    if (v is Map) {
      return Map<String, dynamic>.from(v.map((key, value) => MapEntry(key.toString(), value)));
    }
    if (v is String) {
      final Map<String, dynamic> out = {};
      for (final part in v.split(';')) {
        if (part.contains('=')) {
          final idx = part.indexOf('=');
          final k = part.substring(0, idx);
          final val = part.substring(idx + 1);
          out[k] = val;
        }
      }
      return out;
    }
    return null;
  }

  Map<String, String>? _toStringStringMap(dynamic v) {
    final d = _toStringDynamicMap(v);
    if (d == null) return null;
    return d.map((key, value) => MapEntry(key, value?.toString() ?? ''));
  }

  /// Check if a title already exists with the SAME TYPE (case-insensitive).
  /// Duplicates are allowed across different types.
  bool titleExists(String title, {int? ignoreId, String? type}) {
    final normalized = title.trim().toLowerCase();
    return _items.any((item) {
      final sameTitle = item.title.trim().toLowerCase() == normalized;
      final sameType = type == null || item.type == type;
      final notIgnored = ignoreId == null || item.id != ignoreId;
      return sameTitle && sameType && notIgnored;
    });
  }

  void toggleTag(String tag) {
    final normalized = tag.trim();
    if (normalized.isEmpty) return;
    if (_selectedTags.contains(normalized)) {
      _selectedTags.remove(normalized);
    } else {
      _selectedTags.add(normalized);
    }
    _invalidateCache();
    notifyListeners();
  }

  void clearSelectedTags() {
    if (_selectedTags.isEmpty) return;
    _selectedTags.clear();
    _invalidateCache();
    notifyListeners();
  }

  // Selection & bulk actions
  void toggleSelectionMode([bool? value]) {
    _selectionMode = value ?? !_selectionMode;
    if (!_selectionMode) {
      _selectedIds.clear();
    }
    notifyListeners();
  }

  void toggleSelect(int id) {
    if (_selectedIds.contains(id)) {
      _selectedIds.remove(id);
    } else {
      _selectedIds.add(id);
    }
    notifyListeners();
  }

  bool isSelected(int id) => _selectedIds.contains(id);

  void clearSelection() {
    _selectedIds.clear();
    _selectionMode = false;
    notifyListeners();
  }

  void selectAllCurrent() {
    final ids = _filteredItems().map((e) => e.id).whereType<int>();
    _selectedIds
      ..clear()
      ..addAll(ids);
    _selectionMode = true;
    notifyListeners();
  }

  Future<void> bulkDeleteSelected() async {
    final ids = List<int>.from(_selectedIds);
    for (final id in ids) {
      await deleteItem(id);
    }
    _selectedIds.clear();
    _selectionMode = false;
    notifyListeners();
  }

  Future<void> bulkFavoriteSelected(bool favorite) async {
    final targets = _items.where((e) => e.id != null && _selectedIds.contains(e.id!));
    for (final it in targets) {
      final updated = it.copyWith(favorite: favorite);
      await updateItem(updated);
    }
    notifyListeners();
  }

  Future<void> bulkAddTagSelected(String tag) async {
    final normalized = tag.trim();
    if (normalized.isEmpty) return;
    final targets = _items.where((e) => e.id != null && _selectedIds.contains(e.id!));
    for (final it in targets) {
      final current = (it.tags ?? const <String>[]).toList();
      if (!current.map((e) => e.toLowerCase()).contains(normalized.toLowerCase())) {
        current.add(normalized);
        final updated = it.copyWith(tags: current);
        await updateItem(updated);
      }
    }
    notifyListeners();
  }

  // Subsection filter setters
  void toggleMangaOnly() {
    _mangaOnlyFilter = !_mangaOnlyFilter;
    _invalidateCache();
    notifyListeners();
  }

  void setWebSeriesKindFilter(String? kind) {
    _webSeriesKindFilter = (kind == null || kind.trim().isEmpty) ? 'All' : kind;
    _invalidateCache();
    notifyListeners();
  }

  // Smart duplicate finder that considers seasons as different items
  List<List<MediaItem>> findDuplicateGroups() {
    final Map<String, List<MediaItem>> grouped = {};
    for (final it in _items) {
      // Extract season information from title or extra data
      final baseTitle = normalizeTitle(it.title);
      
      // Create key that excludes season information for duplicate detection
      final key = '$baseTitle|${it.releaseYear ?? -1}|${it.type}';
      grouped.putIfAbsent(key, () => []).add(it);
    }
    
    // Filter groups that are actual duplicates (same title, year, type, AND season)
    final duplicateGroups = <List<MediaItem>>[];
    for (final group in grouped.values) {
      if (group.length > 1) {
        // Check if items in group have different seasons
        final seasonGroups = <String, List<MediaItem>>{};
        for (final item in group) {
          final seasonKey = _getSeasonKey(item);
          seasonGroups.putIfAbsent(seasonKey, () => []).add(item);
        }
        
        // Only consider as duplicates if same season has multiple items
        for (final seasonGroup in seasonGroups.values) {
          if (seasonGroup.length > 1) {
            seasonGroup.sort((a, b) => (b.addedDate ?? DateTime.fromMillisecondsSinceEpoch(0))
                .compareTo(a.addedDate ?? DateTime.fromMillisecondsSinceEpoch(0)));
            duplicateGroups.add(seasonGroup);
          }
        }
      }
    }
    
    duplicateGroups.sort((a, b) => b.length.compareTo(a.length));
    return duplicateGroups;
  }

  // Find related items (same title, different seasons)
  List<List<MediaItem>> findRelatedItemGroups() {
    final Map<String, List<MediaItem>> grouped = {};
    for (final it in _items) {
      final baseTitle = normalizeTitle(it.title);
      final key = '$baseTitle|${it.type}';
      grouped.putIfAbsent(key, () => []).add(it);
    }
    
    final relatedGroups = <List<MediaItem>>[];
    for (final group in grouped.values) {
      if (group.length > 1) {
        // Sort by season number if available, otherwise by release year
        group.sort((a, b) {
          final seasonA = _extractSeasonNumber(a);
          final seasonB = _extractSeasonNumber(b);
          
          if (seasonA != null && seasonB != null) {
            return seasonA.compareTo(seasonB);
          } else if (seasonA != null) {
            return -1; // Items with season come first
          } else if (seasonB != null) {
            return 1;
          } else {
            // Fallback to release year
            final yearA = a.releaseYear ?? 0;
            final yearB = b.releaseYear ?? 0;
            return yearA.compareTo(yearB);
          }
        });
        relatedGroups.add(group);
      }
    }
    
    return relatedGroups;
  }

  // Extract season information from title or extra data
  String _extractSeasonInfo(MediaItem item) {
    // Check extra data first
    if (item.extra != null) {
      final seasons = item.extra!['seasons']?.toString();
      if (seasons != null && seasons.trim().isNotEmpty) {
        return seasons.trim();
      }
    }
    
    // Check title for season patterns
    final title = item.title.toLowerCase();
    final seasonPatterns = [
      RegExp(r'season\s*(\d+)', caseSensitive: false),
      RegExp(r's(\d+)', caseSensitive: false),
      RegExp(r'part\s*(\d+)', caseSensitive: false),
      RegExp(r'volume\s*(\d+)', caseSensitive: false),
      RegExp(r'vol\.?\s*(\d+)', caseSensitive: false),
    ];
    
    for (final pattern in seasonPatterns) {
      final match = pattern.firstMatch(title);
      if (match != null) {
        return match.group(1) ?? '';
      }
    }
    
    return '';
  }

  // Extract season number for sorting
  int? _extractSeasonNumber(MediaItem item) {
    final seasonInfo = _extractSeasonInfo(item);
    if (seasonInfo.isEmpty) return null;
    return int.tryParse(seasonInfo);
  }

  // Get season key for grouping
  String _getSeasonKey(MediaItem item) {
    return _extractSeasonInfo(item);
  }

  // Normalize title by removing season information
  String normalizeTitle(String title) {
    final normalized = title.trim().toLowerCase();
    
    // Remove season patterns from title for comparison
    final seasonPatterns = [
      RegExp(r'\s*season\s*\d+.*', caseSensitive: false),
      RegExp(r'\s*s\d+.*', caseSensitive: false),
      RegExp(r'\s*part\s*\d+.*', caseSensitive: false),
      RegExp(r'\s*volume\s*\d+.*', caseSensitive: false),
      RegExp(r'\s*vol\.?\s*\d+.*', caseSensitive: false),
    ];
    
    String result = normalized;
    for (final pattern in seasonPatterns) {
      result = result.replaceAll(pattern, '');
    }
    
    return result.trim();
  }

  // Delete all items in group except the first (newest)
  Future<void> deleteDuplicatesKeepFirst(List<MediaItem> group) async {
    if (group.isEmpty) return;
    final toDelete = group.skip(1).where((e) => e.id != null).map((e) => e.id!).toList();
    for (final id in toDelete) {
      await deleteItem(id);
    }
    await loadItems();
  }

  List<String> _unionStringLists(List<String>? a, List<String>? b) {
    final set = <String>{};
    if (a != null) set.addAll(a.where((e) => e.trim().isNotEmpty));
    if (b != null) set.addAll(b.where((e) => e.trim().isNotEmpty));
    return set.toList(growable: false);
  }

  Map<String, dynamic> _mergeExtraMaps(Map<String, dynamic>? a, Map<String, dynamic>? b) {
    final result = <String, dynamic>{};
    if (a != null) result.addAll(a);
    if (b != null) {
      for (final entry in b.entries) {
        result.putIfAbsent(entry.key, () => entry.value);
      }
    }
    return result;
  }

  Map<String, String> _mergeStringMaps(Map<String, String>? a, Map<String, String>? b) {
    final result = <String, String>{};
    if (a != null) result.addAll(a);
    if (b != null) {
      for (final entry in b.entries) {
        result.putIfAbsent(entry.key, () => entry.value);
      }
    }
    return result;
  }

  /// Merge a duplicate group into the newest item:
  /// - Keep newest as base
  /// - rating = max
  /// - favorite = true if any
  /// - lists (tags, collections, images, genres) = union
  /// - extra/custom maps = additive (keep base on conflict)
  /// - fill missing scalar fields from older if base has null
  Future<void> mergeDuplicateGroup(List<MediaItem> group) async {
    if (group.isEmpty) return;
    // Ensure newest first
    final sorted = [...group]
      ..sort((a, b) => (b.addedDate ?? DateTime.fromMillisecondsSinceEpoch(0))
          .compareTo(a.addedDate ?? DateTime.fromMillisecondsSinceEpoch(0)));
    final MediaItem base = sorted.first;
    double? maxRating = base.rating;
    bool anyFavorite = base.favorite;
    List<String>? mergedTags = base.tags;
    List<String>? mergedCollections = base.collections;
    List<String>? mergedImages = base.images;
    List<String>? mergedGenres = base.genres;
    Map<String, dynamic>? mergedExtra = base.extra;
    Map<String, String>? mergedCustom = base.custom;
    String? language = base.language;
    int? releaseYear = base.releaseYear;
    int? watchedYear = base.watchedYear;
    String? recommend = base.recommend;
    String? imagePath = base.imagePath;
    String? notes = base.notes;

    for (final it in sorted.skip(1)) {
      // Scalars: fill if missing
      language ??= it.language;
      releaseYear ??= it.releaseYear;
      watchedYear ??= it.watchedYear;
      recommend ??= it.recommend;
      imagePath ??= it.imagePath;
      notes ??= it.notes;

      // Rating/favorite
      if (it.rating != null) {
        if (maxRating == null || it.rating! > maxRating) maxRating = it.rating;
      }
      if (it.favorite) anyFavorite = true;

      // Collections
      mergedTags = _unionStringLists(mergedTags, it.tags);
      mergedCollections = _unionStringLists(mergedCollections, it.collections);
      mergedGenres = _unionStringLists(mergedGenres, it.genres);
      // Ensure imagePath is represented in images; merge multi-images
      final itImages = it.images ?? const <String>[];
      final withPrimary = {
        ...?mergedImages,
        ...itImages,
        if (it.imagePath != null && it.imagePath!.trim().isNotEmpty) it.imagePath!,
        if (base.imagePath != null && base.imagePath!.trim().isNotEmpty) base.imagePath!,
      }..removeWhere((e) => e.trim().isEmpty);
      mergedImages = withPrimary.toList(growable: false);

      // Maps
      mergedExtra = _mergeExtraMaps(mergedExtra, it.extra);
      mergedCustom = _mergeStringMaps(mergedCustom, it.custom);
    }

    final updated = base.copyWith(
      rating: maxRating,
      favorite: anyFavorite,
      tags: mergedTags,
      collections: mergedCollections,
      genres: mergedGenres,
      images: mergedImages,
      extra: mergedExtra,
      custom: mergedCustom,
      language: language,
      releaseYear: releaseYear,
      watchedYear: watchedYear,
      recommend: recommend,
      imagePath: imagePath,
      notes: notes,
    );

    await updateItem(updated);
    // Delete others
    for (final it in sorted.skip(1)) {
      if (it.id != null) {
        await deleteItem(it.id!);
      }
    }
    await loadItems();
  }

  /// Merge all duplicate groups in the library
  Future<void> mergeAllDuplicateGroups() async {
    final groups = findDuplicateGroups();
    for (final g in groups) {
      await mergeDuplicateGroup(g);
    }
    await loadItems();
  }
}