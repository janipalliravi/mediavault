class MyDramaListService {
  Future<List<Map<String, dynamic>>> searchDramas(String query) async {
    try {
      // Note: MyDramaList doesn't have an official public API
      // This is a placeholder implementation
      // In production, you would need to use a scraping solution or find an alternative
      // For now, we'll return empty list as this requires web scraping
      return [];
    } catch (e) {
      return [];
    }
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
