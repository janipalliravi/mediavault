import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SettingsProvider with ChangeNotifier {
  static const _kDarkKey = 'settings.dark';
  static const _kNameKey = 'settings.name';
  static const _kPhotoKey = 'settings.photo';
  static const _kCarouselSecKey = 'settings.carouselSec';
  static const _kRecentSearchesKey = 'settings.recentSearches';
  static const _kSavedSearchesKey = 'settings.savedSearches';
  static const _kAmoledKey = 'settings.amoled';
  static const _kAccentKey = 'settings.accent';
  static const _kFontScaleKey = 'settings.fontScale';
  static const _kShowStatsKey = 'settings.showStats';
  static const _kDefaultGridKey = 'settings.defaultGrid';
  static const _kThemeVariantKey = 'settings.themeVariant';
  static const _kBackupUriKey = 'settings.backupFolderUri';
  static const _kAutoBackupKey = 'settings.autoBackupEnabled';
  static const _kBackupPathKey = 'settings.backupFolderPath';
  static const _kShuffleCardsKey = 'settings.shuffleCards';

  bool _isDarkMode = true; // Default aligns with AMOLED variant
  String _name = '';
  String? _photoPath;
  int _carouselIntervalSec = 3;
  List<String> _recentSearches = const [];
  List<String> _savedSearches = const [];
  bool _useAmoled = true;
  int _accentSeed = 0xFF1877F2;
  double _fontScale = 1.0;
  bool _showStats = true;
  bool _defaultGridView = true;
  String _themeVariant = 'AMOLED'; // Light / Dark / AMOLED
  String? _backupFolderUri;
  bool _autoBackupEnabled = true;
  String? _backupFolderPath;
  bool _shuffleCardsEnabled = true;

  bool get isDarkMode => _isDarkMode;
  String get name => _name;
  String? get photoPath => _photoPath;
  int get carouselIntervalSec => _carouselIntervalSec;
  List<String> get recentSearches => List.unmodifiable(_recentSearches);
  List<String> get savedSearches => List.unmodifiable(_savedSearches);
  bool get useAmoled => _useAmoled;
  Color get accentColor => Color(_accentSeed);
  double get fontScale => _fontScale;
  bool get showStats => _showStats;
  bool get defaultGridView => _defaultGridView;
  String get themeVariant => _themeVariant;
  String? get backupFolderUri => _backupFolderUri;
  bool get autoBackupEnabled => _autoBackupEnabled;
  String? get backupFolderPath => _backupFolderPath;
  bool get shuffleCardsEnabled => _shuffleCardsEnabled;

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    _isDarkMode = prefs.getBool(_kDarkKey) ?? false;
    _name = prefs.getString(_kNameKey) ?? '';
    _photoPath = prefs.getString(_kPhotoKey);
    _carouselIntervalSec = prefs.getInt(_kCarouselSecKey) ?? 3;
    _recentSearches = prefs.getStringList(_kRecentSearchesKey) ?? const [];
    _savedSearches = prefs.getStringList(_kSavedSearchesKey) ?? const [];
    _useAmoled = prefs.getBool(_kAmoledKey) ?? false;
    _accentSeed = prefs.getInt(_kAccentKey) ?? 0xFF1877F2;
    _fontScale = prefs.getDouble(_kFontScaleKey) ?? 1.0;
    _showStats = prefs.getBool(_kShowStatsKey) ?? true;
    _defaultGridView = prefs.getBool(_kDefaultGridKey) ?? true;
    _themeVariant = prefs.getString(_kThemeVariantKey) ?? 'AMOLED';
    _backupFolderUri = prefs.getString(_kBackupUriKey);
    _autoBackupEnabled = prefs.getBool(_kAutoBackupKey) ?? true;
    _backupFolderPath = prefs.getString(_kBackupPathKey);
    _shuffleCardsEnabled = prefs.getBool(_kShuffleCardsKey) ?? true;

    // Reconcile effective flags from theme variant to ensure consistency across app
    if (_themeVariant == 'Light') {
      _isDarkMode = false;
      _useAmoled = false;
    } else if (_themeVariant == 'Dark') {
      _isDarkMode = true;
      _useAmoled = false;
    } else if (_themeVariant == 'AMOLED') {
      _isDarkMode = true;
      _useAmoled = true;
    }
    notifyListeners();
  }

  Future<void> setDarkMode(bool value) async {
    _isDarkMode = value;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kDarkKey, value);
  }

  Future<void> setName(String value) async {
    _name = value;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kNameKey, value);
  }

  Future<void> setPhotoPath(String? value) async {
    _photoPath = value;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    if (value == null || value.isEmpty) {
      await prefs.remove(_kPhotoKey);
    } else {
      await prefs.setString(_kPhotoKey, value);
    }
  }

  Future<void> setCarouselIntervalSec(int seconds) async {
    // Allow 0 (Off) through 10 seconds
    if (seconds < 0) seconds = 0;
    if (seconds > 10) seconds = 10;
    _carouselIntervalSec = seconds;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_kCarouselSecKey, _carouselIntervalSec);
  }

  Future<void> addRecentSearch(String query) async {
    final q = query.trim();
    if (q.isEmpty) return;
    final List<String> updated = [q, ..._recentSearches.where((e) => e.toLowerCase() != q.toLowerCase())];
    // Limit to 10
    _recentSearches = updated.take(10).toList(growable: false);
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_kRecentSearchesKey, _recentSearches);
  }

  Future<void> clearRecentSearches() async {
    _recentSearches = const [];
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_kRecentSearchesKey);
  }

  Future<void> saveCurrentSearch(String query) async {
    final q = query.trim();
    if (q.isEmpty) return;
    if (_savedSearches.any((e) => e.toLowerCase() == q.toLowerCase())) return;
    _savedSearches = [..._savedSearches, q];
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_kSavedSearchesKey, _savedSearches);
  }

  Future<void> removeSavedSearch(String query) async {
    _savedSearches = _savedSearches.where((e) => e.toLowerCase() != query.toLowerCase()).toList(growable: false);
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_kSavedSearchesKey, _savedSearches);
  }

  Future<void> removeRecentSearch(String query) async {
    _recentSearches = _recentSearches.where((e) => e.toLowerCase() != query.toLowerCase()).toList(growable: false);
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_kRecentSearchesKey, _recentSearches);
  }

  Future<void> clearSavedSearches() async {
    _savedSearches = const [];
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_kSavedSearchesKey);
  }

  Future<void> clearAllSearchHistory() async {
    await clearRecentSearches();
    await clearSavedSearches();
  }

  Future<void> setAmoled(bool value) async {
    _useAmoled = value;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kAmoledKey, value);
  }

  Future<void> setAccentColor(Color color) async {
    _accentSeed = color.toARGB32();
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_kAccentKey, _accentSeed);
  }

  Future<void> setFontScale(double scale) async {
    _fontScale = scale.clamp(0.8, 1.4);
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(_kFontScaleKey, _fontScale);
  }

  // Grid controls removed

  Future<void> setShowStats(bool value) async {
    _showStats = value;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kShowStatsKey, _showStats);
  }

  Future<void> setDefaultGridView(bool grid) async {
    _defaultGridView = grid;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kDefaultGridKey, _defaultGridView);
  }

  // Layout preset removed

  Future<void> setThemeVariant(String value) async {
    _themeVariant = value;
    // Drive dark/amoled flags from variant for global consistency
    if (value == 'Light') {
      _isDarkMode = false;
      _useAmoled = false;
    } else if (value == 'Dark') {
      _isDarkMode = true;
      _useAmoled = false;
    } else {
      _isDarkMode = true;
      _useAmoled = true;
    }
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kThemeVariantKey, value);
    await prefs.setBool(_kDarkKey, _isDarkMode);
    await prefs.setBool(_kAmoledKey, _useAmoled);
  }

  Future<void> setBackupFolderUri(String? uri) async {
    _backupFolderUri = uri;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    if (uri == null || uri.isEmpty) {
      await prefs.remove(_kBackupUriKey);
    } else {
      await prefs.setString(_kBackupUriKey, uri);
    }
  }

  Future<void> setAutoBackupEnabled(bool enabled) async {
    _autoBackupEnabled = enabled;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kAutoBackupKey, enabled);
  }

  Future<void> setBackupFolderPath(String? path) async {
    _backupFolderPath = path;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    if (path == null || path.isEmpty) {
      await prefs.remove(_kBackupPathKey);
    } else {
      await prefs.setString(_kBackupPathKey, path);
    }
  }

  Future<void> setShuffleCardsEnabled(bool enabled) async {
    _shuffleCardsEnabled = enabled;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kShuffleCardsKey, enabled);
  }

  // Section density removed

  Future<void> resetToDefaults() async {
    // Reset appearance and layout to sane defaults
    await setThemeVariant('Light');
    await setAccentColor(const Color(0xFF1877F2));
    await setFontScale(1.0);
    await setShowStats(true);
    await setDefaultGridView(true);
    await setCarouselIntervalSec(3);
    await setAutoBackupEnabled(true);
    await setShuffleCardsEnabled(true);
  }
}


