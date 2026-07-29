// lib/screens/add_edit_screen.dart

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import '../models/media_item.dart';
import '../providers/media_provider.dart';
import '../constants/app_constants.dart';
import '../theme/spacing.dart';
import 'image_crop_screen.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:typed_data';
import 'package:image/image.dart' as img;
import '../services/android_permissions.dart';
import '../services/image_search_service.dart';
import '../services/tmdb_service.dart';
import '../services/anilist_service.dart';
import '../services/tvmaze_service.dart';
import '../utils/snackbar_helper.dart';
import 'package:http/http.dart' as http;
import 'package:cached_network_image/cached_network_image.dart';

/// AddEditScreen allows creating or editing a media item.
/// It supports multi-image import with compression, URL normalization for trailer,
/// and safe notes cleaning. It preserves current flow and side effects.
class AddEditScreen extends StatefulWidget {
  final MediaItem? item;

  const AddEditScreen({super.key, this.item});

  @override
  State<AddEditScreen> createState() => _AddEditScreenState();
}

class _AddEditScreenState extends State<AddEditScreen> {
  final _formKey = GlobalKey<FormState>();

  final _titleCtrl = TextEditingController();
  final _languageCtrl = TextEditingController();
  final _releaseYearCtrl = TextEditingController();
  final _watchedYearCtrl = TextEditingController();
  final _notesCtrl = TextEditingController();
  String? _trailerUrl;
  String? _castText;
  String? _genresText;
  final _seasonsCtrl = TextEditingController();
  final _episodesCtrl = TextEditingController();
  final List<String> _extraImages = <String>[];

  static const List<String> _types = ['Movies', 'Anime', 'Manga', 'K-Drama', 'Series'];
  static const List<String> _seriesSubTypes = ['TV Series', 'Web Series'];
  static const List<String> _statuses = AppConstants.statuses;
  static const List<String> _recommendOpts = AppConstants.recommendOptions;

  String _type = _types.first;
  String _seriesSubType = _seriesSubTypes.first;
  String _status = 'Watch list';
  String _recommend = 'Maybe';
  double _rating = 0.0;
  DateTime? _addedDate;
  String? _imagePath;
  bool _isManga = false;
  String? _webSeriesKind; // TV / OTT, Regional series, Independent

  String _normalizedType(String t) {
    switch (t.trim()) {
      case 'Movies':
      case 'Movie':
        return 'Movies';
      case 'Anime':
        return 'Anime';
      case 'K-Drama':
      case 'Kdrama':
      case 'K Drama':
        return 'K-Drama';
      case 'Series':
      case 'WebSeries':
      case 'Web Series':
        return 'Series';
      default:
        return 'Movies';
    }
  }

  @override
  void initState() {
    super.initState();
    final item = widget.item;
    if (item != null) {
      _titleCtrl.text = item.title;
      _languageCtrl.text = item.language ?? '';
      _releaseYearCtrl.text = item.releaseYear?.toString() ?? '';
      _watchedYearCtrl.text = item.watchedYear?.toString() ?? '';
      _notesCtrl.text = item.notes ?? '';
      _type = _types.contains(item.type) ? item.type : _types.first;
      _status = _statuses.contains(item.status) ? item.status : 'Watch list';
      _rating = item.rating ?? 0.0; // Use existing rating when editing
      _recommend = _recommendOpts.contains(item.recommend ?? '') ? (item.recommend ?? 'Maybe') : 'Maybe';
      _addedDate = item.addedDate ?? DateTime.now();
      _imagePath = item.imagePath;
      // Pre-fill dynamic fields from extra if available
      final extra = item.extra ?? {};
      _seasonsCtrl.text = (extra['seasons'] ?? '').toString();
      _isManga = (extra['manga']?.toString().toLowerCase() == 'true');
      _episodesCtrl.text = (_isManga ? (extra['chapters'] ?? '') : (extra['episodes'] ?? '')).toString();
      _webSeriesKind = (extra['wsKind'] as String?)?.trim();
      _trailerUrl = (extra['trailer'] as String? ?? '').trim().isEmpty ? null : (extra['trailer'] as String).trim();
      _castText = (extra['cast'] as String? ?? '').trim().isEmpty ? null : (extra['cast'] as String).trim();
      _genresText = (extra['genres'] as String? ?? '').trim().isEmpty ? null : (extra['genres'] as String).trim();
      // Prefill images - filter out invalid/blank images
      if (item.images != null && item.images!.isNotEmpty) {
        for (final path in item.images!) {
          if (path.isEmpty) continue;
          if (path.startsWith('http')) {
            _extraImages.add(path);
          } else {
            final file = File(path);
            if (file.existsSync()) {
              _extraImages.add(path);
            }
          }
        }
      }
    } else {
      _addedDate = DateTime.now();
    }
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _languageCtrl.dispose();
    _releaseYearCtrl.dispose();
    _watchedYearCtrl.dispose();
    _notesCtrl.dispose();
    _seasonsCtrl.dispose();
    _episodesCtrl.dispose();
    super.dispose();
  }

  String? _yearValidator(String? v) {
    if (v == null || v.trim().isEmpty) return null;
    final n = int.tryParse(v);
    if (n == null || n < 1888 || n > DateTime.now().year + 2) {
      return 'Enter a valid year';
    }
    return null;
  }
  
  InputDecoration _inputDecoration(String label) {
    return InputDecoration(
      labelText: label,
      filled: true,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(ThemeSpacing.radius10)),
    );
  }

  Widget _buildStarRow() {
    Color starColorFor(double rating) {
      if (rating >= 5) return const Color(0xFFFFD700); // bright gold
      if (rating >= 4) return const Color(0xFFE6C200); // gold
      if (rating >= 3) return const Color(0xFFCCAA00); // dark gold/bronze
      if (rating >= 2) return Colors.grey.shade400; // grey for 2 stars
      if (rating >= 1) return Colors.grey.shade600; // dark grey for 1 star
      return Colors.grey.shade700; // darkest for 0 stars
    }
    return Row(
      children: List.generate(5, (i) {
        final starIndex = i + 1.0;
        final isFilled = _rating >= starIndex;
        return IconButton(
          icon: Icon(isFilled ? Icons.star : Icons.star_border),
          color: starColorFor(_rating),
          onPressed: () {
            setState(() {
              _rating = starIndex;
            });
          },
        );
      }),
    );
  }

  Future<void> _pickImage(ImageSource source) async {
    try {
      final ok = await AndroidPermissions.ensureForImagePicker(
        fromCamera: source == ImageSource.camera,
      );
      if (!ok) {
        if (!mounted) return;
        SnackbarHelper.showError(context, 'Permission required to access photos or camera');
        return;
      }
      final picker = ImagePicker();
      final pickedFile = await picker.pickImage(source: source);
      if (pickedFile != null) {
        // Read bytes and navigate to crop screen
        final bytes = await pickedFile.readAsBytes();
        if (!mounted) return;
        final cropped = await Navigator.push<Uint8List>(
          context,
          MaterialPageRoute(
            builder: (_) => ImageCropScreen(imageBytes: bytes),
            fullscreenDialog: true,
          ),
        );
        if (cropped != null) {
          // Save cropped image to app documents and use that path
          final dir = await getApplicationDocumentsDirectory();
          // Compress cropped bytes
          final decoded = img.decodeImage(cropped);
          final jpg = decoded != null ? img.encodeJpg(decoded, quality: 80) : cropped;
          final file = File('${dir.path}/mv_${DateTime.now().millisecondsSinceEpoch}.jpg');
          await file.writeAsBytes(jpg, flush: true);
          if (!mounted) return;
          setState(() {
            _imagePath = file.path;
          });
        }
      }
    } catch (_) {
      if (!mounted) return;
      SnackbarHelper.showError(context, 'Failed to pick image');
    }
  }

  Future<void> _pickImagesFromGallery() async {
    try {
      final ok = await AndroidPermissions.ensureForImagePicker(fromCamera: false);
      if (!ok) {
        if (!mounted) return;
        SnackbarHelper.showError(context, 'Permission required to access photos');
        return;
      }
      final picker = ImagePicker();
      final files = await picker.pickMultiImage();
      if (files.isEmpty) return;
      final dir = await getApplicationDocumentsDirectory();
      final List<String> savedPaths = [];
      for (final f in files) {
        final raw = await f.readAsBytes();
        // Downscale and compress to ~1080px max dimension, jpeg quality 80
        final decoded = img.decodeImage(raw);
        if (decoded != null) {
          final resized = img.copyResize(decoded, width: decoded.width > decoded.height ? 1080 : null, height: decoded.height >= decoded.width ? 1080 : null);
          final jpg = img.encodeJpg(resized, quality: 80);
          final file = File('${dir.path}/mv_${DateTime.now().millisecondsSinceEpoch}_${f.name}.jpg');
          await file.writeAsBytes(jpg, flush: true);
          savedPaths.add(file.path);
        } else {
          final file = File('${dir.path}/mv_${DateTime.now().millisecondsSinceEpoch}_${f.name}');
          await file.writeAsBytes(raw, flush: true);
          savedPaths.add(file.path);
        }
      }
      if (!mounted) return;
      setState(() {
        _imagePath = savedPaths.first;
        _extraImages
          ..clear()
          ..addAll(savedPaths.skip(1));
      });
    } catch (_) {
      if (!mounted) return;
      SnackbarHelper.showError(context, 'Failed to import images');
    }
  }

  void _chooseImageSource() {
    showModalBottomSheet(
      context: context,
      builder: (ctx) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.photo_library),
                title: const Text('Choose from Gallery'),
                onTap: () {
                  Navigator.pop(ctx);
                  _pickImagesFromGallery();
                },
              ),
              ListTile(
                leading: const Icon(Icons.photo_camera),
                title: const Text('Take a Photo'),
                onTap: () {
                  Navigator.pop(ctx);
                  _pickImage(ImageSource.camera);
                },
              ),
              ListTile(
                leading: const Icon(Icons.search),
                title: const Text('Search Online'),
                onTap: () {
                  Navigator.pop(ctx);
                  _searchOnlineImage();
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _autoFillFromTMDB() async {
    final title = _titleCtrl.text.trim();
    if (title.isEmpty) {
      if (!mounted) return;
      SnackbarHelper.showWarning(context, 'Please enter a title first');
      return;
    }

    if (!mounted) return;
    SnackbarHelper.showInfo(context, 'Fetching data...');

    try {
      List<Map<String, dynamic>> results = [];
      String apiName = '';

      // Choose appropriate API based on type
      debugPrint('Auto-fill called with type: "$_type", title: "$title"');
      if (_type == 'Anime') {
        final anilistService = AniListService();
        results = await anilistService.searchAnime(title);
        apiName = 'AniList (Anime)';
      } else if (_type == 'Manga') {
        final anilistService = AniListService();
        results = await anilistService.searchManga(title);
        apiName = 'AniList (Manga)';
      } else if (_type == 'Series') {
        // Series uses TVMaze for TV Series, TMDB for Web Series
        debugPrint('Series type detected, sub-type: "$_seriesSubType"');
        if (_seriesSubType == 'Web Series') {
          final tmdbService = TMDBService();
          results = await tmdbService.searchByTitle(title, type: 'Web Series');
          apiName = 'TMDB';
        } else {
          final tvmazeService = TVMazeService();
          results = await tvmazeService.searchShows(title);
          apiName = 'TVMaze';
        }
      } else if (_type == 'K-Drama') {
        // K-Drama uses TMDB TV search (treat as Series since TMDB has no K-Drama type)
        debugPrint('K-Drama type detected, calling TMDB with type: Series');
        final tmdbService = TMDBService();
        results = await tmdbService.searchByTitle(title, type: 'Series');
        apiName = 'TMDB';
      } else {
        // Movies use TMDB
        final tmdbService = TMDBService();
        results = await tmdbService.searchByTitle(title, type: _type);
        apiName = 'TMDB';
      }
      debugPrint('API call completed. Results count: ${results.length}, API: $apiName');

      if (results.isEmpty && mounted) {
        SnackbarHelper.showWarning(context, 'No results found on $apiName. Try a different title or check spelling.');
        return;
      }

      Map<String, dynamic>? selectedData;

      if (results.length == 1) {
        selectedData = results.first;
      } else {
        // Show selection dialog for multiple results
        if (!mounted) return;
        selectedData = await showDialog<Map<String, dynamic>>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: Text('Select $_type'),
            content: SizedBox(
              width: double.maxFinite,
              height: 400,
              child: ListView.builder(
                itemCount: results.length,
                itemBuilder: (context, index) {
                  final result = results[index];
                  String year = 'N/A';
                  String subtitle = '';
                  String? posterUrl;

                  if (_type == 'Anime' || _type == 'Manga') {
                    year = result['year']?.toString() ?? 
                           result['releaseDate']?.toString().split('-').first ?? 'N/A';
                    posterUrl = result['posterPath'];
                    subtitle = '${result['type'] ?? 'N/A'} • ${result['status'] ?? 'N/A'}';
                  } else if (_type == 'Series' || _type == 'K-Drama') {
                    year = result['releaseDate']?.toString().split('-').first ?? 'N/A';
                    posterUrl = result['posterPath'];
                    if (_type == 'Series') {
                      subtitle = '${result['network'] ?? 'N/A'} • ${result['language'] ?? 'N/A'}';
                    } else {
                      subtitle = '${result['originalLanguage'] ?? 'N/A'} • ${result['firstAirDate']?.toString().split('-').first ?? 'N/A'}';
                    }
                  } else {
                    // TMDB
                    year = result['releaseDate']?.toString().split('-').first ?? 
                           result['firstAirDate']?.toString().split('-').first ?? 'N/A';
                    final tmdbService = TMDBService();
                    posterUrl = result['posterPath'] != null 
                        ? tmdbService.getPosterUrl(result['posterPath'])
                        : null;
                    subtitle = result['originalLanguage'] ?? 'N/A';
                  }
                  
                  return ListTile(
                    leading: posterUrl != null && posterUrl.isNotEmpty
                        ? ClipRRect(
                            borderRadius: BorderRadius.circular(4),
                            child: Image.network(
                              posterUrl,
                              width: 50,
                              height: 75,
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) => const Icon(Icons.broken_image, size: 50),
                            ),
                          )
                        : const Icon(Icons.movie, size: 50),
                    title: Text(result['title'] ?? 'Unknown'),
                    subtitle: Text('$year • $subtitle'),
                    onTap: () => Navigator.pop(ctx, result),
                  );
                },
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, null),
                child: const Text('Cancel'),
              ),
            ],
          ),
        );
      }

      if (selectedData != null && mounted) {
        setState(() {
          // Fill title if better match found
          if (selectedData?['title'] != null && selectedData!['title'].toString().isNotEmpty) {
            _titleCtrl.text = selectedData['title'];
          }

          // Fill release year
          String? dateStr = selectedData?['releaseDate']?.toString() ?? 
                           selectedData?['firstAirDate']?.toString() ??
                           selectedData?['year']?.toString();
          if (dateStr != null && dateStr.isNotEmpty) {
            if (dateStr.contains('-')) {
              final year = dateStr.split('-').first;
              _releaseYearCtrl.text = year;
            } else {
              _releaseYearCtrl.text = dateStr;
            }
          }

          // Rating is not auto-filled - user must enter manually

          // Fill cast
          if (selectedData?['cast'] != null && selectedData!['cast'].toString().isNotEmpty) {
            _castText = selectedData['cast'];
          } else if (selectedData?['studios'] != null && (selectedData!['studios'] as List).isNotEmpty) {
            // For anime, use studios as cast
            _castText = (selectedData['studios'] as List).join(', ');
          } else if (selectedData?['authors'] != null && (selectedData!['authors'] as List).isNotEmpty) {
            // For manga, use authors as cast
            _castText = (selectedData['authors'] as List).join(', ');
          }

          // Fill genres (will be saved in extra field)
          if (selectedData?['genres'] != null && (selectedData!['genres'] as List).isNotEmpty) {
            _genresText = (selectedData['genres'] as List).join(', ');
          }

          // Fill trailer (only TMDB has trailer)
          if (selectedData?['trailer'] != null && selectedData!['trailer'].toString().isNotEmpty) {
            _trailerUrl = selectedData['trailer'];
          }

          // Fill language
          if (selectedData?['originalLanguage'] != null && selectedData!['originalLanguage'].toString().isNotEmpty) {
            _languageCtrl.text = selectedData['originalLanguage'];
          } else if (selectedData?['language'] != null && selectedData!['language'].toString().isNotEmpty) {
            // TVMaze uses 'language' instead of 'originalLanguage'
            _languageCtrl.text = selectedData['language'];
          }

          // Fill episodes for anime/series/k-drama
          if (selectedData?['episodes'] != null) {
            final episodes = selectedData!['episodes'];
            _episodesCtrl.text = episodes.toString();
            debugPrint('Auto-filled episodes: $episodes');
          } else {
            debugPrint('No episodes data in selectedData');
          }

          // Fill seasons for series/k-drama
          if (selectedData?['seasons'] != null && (_type == 'Series' || _type == 'K-Drama')) {
            final seasons = selectedData!['seasons'];
            _seasonsCtrl.text = seasons.toString();
            debugPrint('Auto-filled seasons: $seasons');
          } else {
            debugPrint('No seasons data in selectedData or type not matching');
          }

          // Fill chapters for manga
          if (selectedData?['chapters'] != null && _type == 'Manga') {
            _episodesCtrl.text = selectedData!['chapters'].toString();
          }

          // Download and set poster image
          String? imageUrl;
          if (selectedData?['posterPath'] != null && selectedData!['posterPath'].toString().isNotEmpty) {
            if (_type == 'Anime' || _type == 'Manga') {
              // Jikan returns full URLs
              imageUrl = selectedData['posterPath'];
            } else if (_type == 'Series') {
              // TVMaze returns full URLs for TV Series
              if (_seriesSubType == 'TV Series') {
                imageUrl = selectedData['posterPath'];
              } else {
                // Web Series uses TMDB (relative paths)
                final tmdbService = TMDBService();
                imageUrl = tmdbService.getPosterUrl(selectedData['posterPath']);
              }
            } else if (_type == 'K-Drama') {
              // K-Drama uses TMDB (relative paths)
              final tmdbService = TMDBService();
              imageUrl = tmdbService.getPosterUrl(selectedData['posterPath']);
            } else {
              // Movies use TMDB (relative paths)
              final tmdbService = TMDBService();
              imageUrl = tmdbService.getPosterUrl(selectedData['posterPath']);
            }
            if (imageUrl != null && imageUrl.isNotEmpty) {
              _downloadAndSetImage(imageUrl);
            }
          }
        });

        if (!mounted) return;
        SnackbarHelper.showSuccess(context, 'Data auto-filled successfully');
      }
    } catch (e) {
      if (!mounted) return;
      SnackbarHelper.showError(context, 'Error fetching data: $e');
    }
  }

  Future<void> _downloadAndSetImage(String imageUrl) async {
    if (imageUrl.isEmpty) return;
    try {
      final response = await http.get(Uri.parse(imageUrl)).timeout(
        const Duration(seconds: 15),
      );
      if (response.statusCode == 200) {
        final dir = await getApplicationDocumentsDirectory();
        final file = File('${dir.path}/mv_${DateTime.now().millisecondsSinceEpoch}.jpg');
        await file.writeAsBytes(response.bodyBytes, flush: true);
        if (mounted) {
          setState(() {
            _imagePath = file.path;
          });
        }
      }
    } catch (e) {
      debugPrint('Failed to download image: $e');
    }
  }

  Future<void> _searchOnlineImage() async {
    final searchController = TextEditingController(text: _titleCtrl.text);
    final imageSearchService = ImageSearchService();
    List<ImageSearchResult> searchResults = [];
    final Set<int> selectedIndices = {};

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) {
          // Auto-trigger search if title is not empty
          WidgetsBinding.instance.addPostFrameCallback((_) async {
            if (searchController.text.trim().isNotEmpty && searchResults.isEmpty) {
              final type = _type == 'Movies' ? 'movie' : 'tv';
              final year = _releaseYearCtrl.text.trim().isEmpty ? null : int.tryParse(_releaseYearCtrl.text.trim());
              final results = await imageSearchService.searchMedia(
                searchController.text.trim(),
                type: type,
                year: year,
              );
              if (ctx.mounted) {
                setDialogState(() => searchResults = results);
              }
            }
          });

          return AlertDialog(
            title: const Text('Search for Posters (Select Multiple)'),
            content: SizedBox(
              width: double.maxFinite,
              height: 500,
              child: Column(
                children: [
                  TextField(
                    controller: searchController,
                    decoration: InputDecoration(
                      hintText: 'Enter movie/anime/series name',
                      suffixIcon: IconButton(
                        icon: const Icon(Icons.search),
                        onPressed: () async {
                          if (searchController.text.trim().isEmpty) return;
                          setDialogState(() {
                            searchResults = [];
                            selectedIndices.clear();
                          });
                          final type = _type == 'Movies' ? 'movie' : 'tv';
                          final year = _releaseYearCtrl.text.trim().isEmpty ? null : int.tryParse(_releaseYearCtrl.text.trim());
                          final results = await imageSearchService.searchMedia(
                            searchController.text.trim(),
                            type: type,
                            year: year,
                          );
                          if (mounted) {
                            setDialogState(() => searchResults = results);
                          }
                        },
                      ),
                    ),
                    onSubmitted: (value) async {
                      if (value.trim().isEmpty) return;
                      setDialogState(() {
                        searchResults = [];
                        selectedIndices.clear();
                      });
                      final type = _type == 'Movies' ? 'movie' : 'tv';
                      final year = _releaseYearCtrl.text.trim().isEmpty ? null : int.tryParse(_releaseYearCtrl.text.trim());
                      final results = await imageSearchService.searchMedia(
                        value.trim(),
                        type: type,
                        year: year,
                      );
                      if (mounted) {
                        setDialogState(() => searchResults = results);
                      }
                    },
                  ),
                  const SizedBox(height: 8),
                  Text('Selected: ${selectedIndices.length} image(s)'),
                  const SizedBox(height: 8),
                  Expanded(
                    child: searchResults.isEmpty
                        ? const Center(child: Text('Search for images above'))
                        : GridView.builder(
                            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: 3,
                              crossAxisSpacing: 8,
                              mainAxisSpacing: 8,
                              childAspectRatio: 2 / 3,
                            ),
                            itemCount: searchResults.length,
                            itemBuilder: (context, index) {
                              final result = searchResults[index];
                              final imageUrl = imageSearchService.getImageUrl(result.posterPath, source: result.source);
                              final isSelected = selectedIndices.contains(index);
                              return GestureDetector(
                                onTap: () {
                                  setDialogState(() {
                                    if (isSelected) {
                                      selectedIndices.remove(index);
                                    } else {
                                      selectedIndices.add(index);
                                    }
                                  });
                                },
                                child: Stack(
                                  children: [
                                    CachedNetworkImage(
                                      imageUrl: imageUrl,
                                      fit: BoxFit.cover,
                                      placeholder: (context, url) => const Center(child: CircularProgressIndicator()),
                                      errorWidget: (context, url, error) => const Icon(Icons.error),
                                    ),
                                    if (isSelected)
                                      Positioned(
                                        top: 4,
                                        right: 4,
                                        child: Container(
                                          decoration: BoxDecoration(
                                            color: Colors.blue,
                                            shape: BoxShape.circle,
                                          ),
                                          child: const Icon(Icons.check, color: Colors.white, size: 20),
                                        ),
                                      ),
                                  ],
                                ),
                              );
                            },
                          ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: selectedIndices.isEmpty
                    ? null
                    : () async {
                        // Download and save selected images
                        final sortedIndices = selectedIndices.toList()..sort();
                        if (sortedIndices.isNotEmpty) {
                          try {
                            final dir = await getApplicationDocumentsDirectory();
                            final downloadedPaths = <String>[];
                            
                            for (final idx in sortedIndices) {
                              final imageUrl = imageSearchService.getImageUrl(searchResults[idx].posterPath, source: searchResults[idx].source);
                              if (imageUrl.isEmpty) continue;
                              
                              try {
                                final response = await http.get(Uri.parse(imageUrl)).timeout(
                                  const Duration(seconds: 10),
                                );
                                if (response.statusCode == 200) {
                                  final file = File('${dir.path}/mv_${DateTime.now().millisecondsSinceEpoch}.jpg');
                                  await file.writeAsBytes(response.bodyBytes, flush: true);
                                  downloadedPaths.add(file.path);
                                }
                              } catch (e) {
                                debugPrint('Failed to download image: $e');
                              }
                            }
                            
                            if (downloadedPaths.isNotEmpty) {
                              setState(() {
                                _imagePath = downloadedPaths.first;
                                _extraImages.clear();
                                _extraImages.addAll(downloadedPaths.skip(1));
                              });
                            }
                          } catch (e) {
                            debugPrint('Error downloading images: $e');
                          }
                        }
                        if (ctx.mounted) Navigator.pop(ctx);
                      },
                child: const Text('Done'),
              ),
            ],
          );
        },
      ),
    );
    searchController.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    final provider = context.read<MediaProvider>();

    final releaseYear = _releaseYearCtrl.text.trim().isEmpty ? null : int.parse(_releaseYearCtrl.text.trim());
    final watchedYear = _watchedYearCtrl.text.trim().isEmpty ? null : int.parse(_watchedYearCtrl.text.trim());

    // Build extra metadata conditionally for non-movie types
    final Map<String, dynamic> extra = {};
    final seasonsStr = _seasonsCtrl.text.trim();
    final episodesStr = _episodesCtrl.text.trim();
    if (_type != 'Movies') {
      if (seasonsStr.isNotEmpty) extra['seasons'] = int.tryParse(seasonsStr) ?? seasonsStr;
      if (episodesStr.isNotEmpty) extra['episodes'] = int.tryParse(episodesStr) ?? episodesStr;
    }
    if (_type == 'Manga') {
      extra['manga'] = true;
    }
    if (_type == 'Series' && (_webSeriesKind != null && _webSeriesKind!.isNotEmpty)) {
      extra['wsKind'] = _webSeriesKind;
    }
    String normalizeUrl(String url) {
      final u = url.trim();
      if (u.isEmpty) return u;
      if (u.startsWith('http://') || u.startsWith('https://')) return u;
      return 'https://$u';
    }
    if ((_trailerUrl ?? '').trim().isNotEmpty) extra['trailer'] = normalizeUrl(_trailerUrl!);
    if ((_castText ?? '').trim().isNotEmpty) extra['cast'] = _castText!.trim();
    if ((_genresText ?? '').trim().isNotEmpty) extra['genres'] = _genresText!.trim();
    // Store chapters vs episodes according to type
    if (_type == 'Manga') {
      final ch = _episodesCtrl.text.trim();
      if (ch.isNotEmpty) extra['chapters'] = int.tryParse(ch) ?? ch;
    } else {
      final ep = _episodesCtrl.text.trim();
      if (ep.isNotEmpty) extra['episodes'] = int.tryParse(ep) ?? ep;
    }

    // Clean notes: strip URLs entirely (to avoid saving trailer in notes)
    String cleanedNotes = _notesCtrl.text;
    final urlRegex = RegExp(r'(https?:\/\/\S+|www\.\S+|youtu\.be\/\S+|youtube\.com\S+)', caseSensitive: false);
    cleanedNotes = cleanedNotes.replaceAll(urlRegex, '').replaceAll(RegExp(r'\s{2,}'), ' ').trim();

    // Validate and clean image paths - remove invalid/blank images
    String? validImagePath = _imagePath;
    if (validImagePath != null && validImagePath.isNotEmpty) {
      if (validImagePath.startsWith('http')) {
        // Keep network URLs as-is
      } else {
        // Validate local file exists
        final file = File(validImagePath);
        if (!file.existsSync()) {
          validImagePath = null;
        }
      }
    }

    List<String> validExtraImages = [];
    for (final path in _extraImages) {
      if (path.isEmpty) continue;
      if (path.startsWith('http')) {
        validExtraImages.add(path);
      } else {
        final file = File(path);
        if (file.existsSync()) {
          validExtraImages.add(path);
        }
      }
    }

    final newItem = MediaItem(
      id: widget.item?.id,
      title: _titleCtrl.text.trim(),
      type: _normalizedType(_type),
      status: _status,
      addedDate: _addedDate ?? DateTime.now(),
      releaseYear: releaseYear,
      watchedYear: watchedYear,
      language: _languageCtrl.text.trim().isEmpty ? null : _languageCtrl.text.trim(),
      rating: _rating,
      notes: _notesCtrl.text.trim().isEmpty ? null : _notesCtrl.text.trim(),
      recommend: _recommend,
      imagePath: validImagePath,
      extra: extra.isEmpty ? null : extra,
      // Tags removed per request
      images: validExtraImages.isEmpty ? null : List<String>.from(validExtraImages),
    );

    if (widget.item == null) {
      // Check for duplicates only when adding new items
      final existingItems = provider.items;
      final titleLower = newItem.title.toLowerCase();
      final isSeries = newItem.type == 'Series' || newItem.type == 'Anime' || newItem.type == 'K-Drama';
      final currentSeason = extra['seasons']?.toString();
      
      // Find potential duplicates
      final duplicates = existingItems.where((item) {
        if (item.id == newItem.id) return false; // Skip self if editing
        if (item.title.toLowerCase() != titleLower) return false;
        
        // For series, check if it's a different season (allowed)
        if (isSeries) {
          final existingSeason = item.extra?['seasons']?.toString();
          if (existingSeason != currentSeason) return false; // Different season, not a duplicate
        }
        
        // For movies or same season series, it's a duplicate
        return true;
      }).toList();

      if (duplicates.isNotEmpty) {
        // Show duplicate warning dialog
        final shouldSave = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Duplicate Detected'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isSeries 
                    ? 'An item with the title "${newItem.title}" already exists in your library.'
                    : 'A movie with the title "${newItem.title}" already exists in your library.',
                ),
                const SizedBox(height: 12),
                if (isSeries && currentSeason != null)
                  Text(
                    'Current season: $currentSeason',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                if (isSeries)
                  const Text(
                    'Note: Different seasons of the same series are allowed.',
                    style: TextStyle(color: Colors.grey, fontSize: 12),
                  ),
                const SizedBox(height: 8),
                const Text('Do you want to save this as a duplicate?'),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('Save Anyway'),
              ),
            ],
          ),
        );
        
        if (shouldSave != true) return; // User cancelled
      }

      await provider.addItem(newItem);
      if (mounted) {
        SnackbarHelper.showSuccess(context, '$_type added');
      }
    } else {
      await provider.updateItem(newItem);
      // Reload items to ensure UI reflects the changes
      await provider.loadItems();
      if (mounted) {
        SnackbarHelper.showSuccess(context, 'Item updated');
      }
    }

    if (mounted) Navigator.of(context).pop({'type': newItem.type});
  }

  Future<bool> _showBackConfirmation() async {
    return await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Unsaved Changes'),
        content: const Text('You have unsaved changes. Are you sure you want to go back?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Leave'),
          ),
        ],
      ),
    ) ?? false;
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.item != null;
    const double gap = ThemeSpacing.gap12;

    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFFE3F2FD), Color(0xFFBBDEFB)],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
      ),
      child: PopScope(
        canPop: false,
        onPopInvokedWithResult: (didPop, result) async {
          if (didPop) return;
          final shouldPop = await _showBackConfirmation();
          if (shouldPop && context.mounted) {
            Navigator.of(context).pop();
          }
        },
        child: Scaffold(
          backgroundColor: Colors.transparent,
          appBar: AppBar(
            title: Text(isEdit ? 'Edit Item' : 'Add Item'),
            backgroundColor: Theme.of(context).colorScheme.primary,
            actions: [
              IconButton(
                tooltip: 'Auto-fill from TMDB',
                icon: const Icon(Icons.auto_awesome, color: Colors.white),
                onPressed: _autoFillFromTMDB,
              ),
              TextButton.icon(
                onPressed: _save,
                icon: const Icon(Icons.save, color: Colors.white),
              label: const Text('Save', style: TextStyle(color: Colors.white)),
              style: TextButton.styleFrom(
                foregroundColor: Colors.white,
              ),
            ),
          ],
        ),
        body: SafeArea(
          child: SingleChildScrollView(
            padding: ThemeSpacing.pagePadding,
            child: Form(
              key: _formKey,
              child: Column(
                children: [
                  GestureDetector(
                    onTap: _chooseImageSource,
                    child: _imagePath == null
                        ? Container(
                            height: 150,
                            width: double.infinity,
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.8),
                              borderRadius: BorderRadius.circular(ThemeSpacing.radius12),
                              border: Border.all(color: Colors.grey.shade300),
                            ),
                            child: const Icon(Icons.add_a_photo, size: 50, color: Colors.grey),
                          )
                        : ClipRRect(
                            borderRadius: BorderRadius.circular(ThemeSpacing.radius12),
                            child: Image.file(
                              File(_imagePath!),
                              height: 150,
                              width: double.infinity,
                              fit: BoxFit.contain,
                              errorBuilder: (_, __, ___) => const SizedBox(height: 150, child: Center(child: Icon(Icons.broken_image)) ),
                            ),
                          ),
                  ),
                  SizedBox(height: gap),
                  SizedBox(height: gap + 8),
                  
                  TextFormField(
                    controller: _titleCtrl,
                    style: const TextStyle(fontSize: 14),
                    decoration: _inputDecoration('Title *'),
                    validator: (v) => v == null || v.trim().isEmpty ? 'Title is required' : null,
                    enableInteractiveSelection: true,
                    textCapitalization: TextCapitalization.sentences,
                    contextMenuBuilder: (context, editableTextState) => AdaptiveTextSelectionToolbar.editableText(
                      editableTextState: editableTextState,
                    ),
                  ),
                  SizedBox(height: gap + 8),
                  DropdownButtonFormField<String>(
                    value: _type,
                    style: TextStyle(
                      fontSize: 14,
                      color: Theme.of(context).brightness == Brightness.dark ? Colors.white : Colors.black87,
                    ),
                    items: ([..._types]..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase())))
                        .map((t) => DropdownMenuItem(
                      value: t, 
                      child: Text(
                        t == 'Movies' ? 'Movie' : t,
                        style: TextStyle(
                          color: Theme.of(context).brightness == Brightness.dark ? Colors.white : Colors.black87,
                          overflow: TextOverflow.ellipsis,
                        ),
                      )
                    )).toList(),
                    onChanged: (v) => setState(() => _type = v!),
                    decoration: _inputDecoration('Type *'),
                  ),
                  // Series sub-type dropdown
                  if (_type == 'Series') ...[
                    SizedBox(height: gap + 8),
                    DropdownButtonFormField<String>(
                      value: _seriesSubType,
                      style: TextStyle(
                        fontSize: 14,
                        color: Theme.of(context).brightness == Brightness.dark ? Colors.white : Colors.black87,
                      ),
                      items: _seriesSubTypes.map((t) => DropdownMenuItem(
                        value: t,
                        child: Text(
                          t,
                          style: TextStyle(
                            color: Theme.of(context).brightness == Brightness.dark ? Colors.white : Colors.black87,
                            overflow: TextOverflow.ellipsis,
                          ),
                        )
                      )).toList(),
                      onChanged: (v) => setState(() => _seriesSubType = v!),
                      decoration: _inputDecoration('Series Type *'),
                    ),
                  ],
                  // Move Season/Episodes (or Chapter for Manga) above Status
                  if (_type != 'Movies') ...[
                    SizedBox(height: gap + 8),
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: _seasonsCtrl,
                            style: const TextStyle(fontSize: 14),
                            keyboardType: TextInputType.number,
                            textCapitalization: TextCapitalization.sentences,
                            decoration: _inputDecoration('Season'),
                            enableInteractiveSelection: true,
                            contextMenuBuilder: (context, editableTextState) => AdaptiveTextSelectionToolbar.editableText(
                              editableTextState: editableTextState,
                            ),
                          ),
                        ),
                        SizedBox(width: gap + 8),
                        Expanded(
                          child: TextFormField(
                            controller: _episodesCtrl,
                            style: const TextStyle(fontSize: 14),
                            keyboardType: TextInputType.number,
                            textCapitalization: TextCapitalization.sentences,
                            decoration: _inputDecoration(_type == 'Manga' ? 'Chapter' : 'Episodes'),
                            enableInteractiveSelection: true,
                            contextMenuBuilder: (context, editableTextState) => AdaptiveTextSelectionToolbar.editableText(
                              editableTextState: editableTextState,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                  SizedBox(height: gap + 8),
                  DropdownButtonFormField<String>(
                    value: _status,
                    style: TextStyle(
                      fontSize: 14,
                      color: Theme.of(context).brightness == Brightness.dark ? Colors.white : Colors.black87,
                    ),
                    items: (() {
                      final list = [..._statuses];
                      if (_type == 'Manga' && !list.contains('Reading')) {
                        list.add('Reading');
                      }
                      list.sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
                      return list;
                    })()
                        .map((s) => DropdownMenuItem(
                      value: s, 
                      child: Text(
                        s,
                        style: TextStyle(
                          color: Theme.of(context).brightness == Brightness.dark ? Colors.white : Colors.black87,
                          overflow: TextOverflow.ellipsis,
                        ),
                      )
                    )).toList(),
                    onChanged: (v) => setState(() => _status = v!),
                    decoration: _inputDecoration('Status *'),
                  ),
                  SizedBox(height: gap + 8),
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: _releaseYearCtrl,
                          style: const TextStyle(fontSize: 14),
                          keyboardType: TextInputType.number,
                          decoration: _inputDecoration('Release Year'),
                          validator: _yearValidator,
                        ),
                      ),
                      SizedBox(width: gap + 8),
                      Expanded(
                        child: TextFormField(
                          controller: _watchedYearCtrl,
                          style: const TextStyle(fontSize: 14),
                          keyboardType: TextInputType.number,
                          decoration: _inputDecoration('Watched Year'),
                          validator: _yearValidator,
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: gap + 8),
                  TextFormField(
                    controller: _languageCtrl,
                    style: const TextStyle(fontSize: 14),
                    decoration: _inputDecoration('Language'),
                    textCapitalization: TextCapitalization.sentences,
                    enableInteractiveSelection: true,
                    contextMenuBuilder: (context, editableTextState) => AdaptiveTextSelectionToolbar.editableText(
                      editableTextState: editableTextState,
                    ),
                  ),
                  SizedBox(height: gap + 8),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'Rating',
                      style: Theme.of(context)
                          .textTheme
                          .titleMedium
                          ?.copyWith(
                            color: Theme.of(context).brightness == Brightness.dark
                                ? Colors.white
                                : Colors.black87,
                          ),
                    ),
                  ),
                  _buildStarRow(),
                  SizedBox(height: gap + 8),
                  Row(
                    children: [
                      Expanded(
                        child: Align(
                          alignment: Alignment.centerLeft,
                          child: Text(
                            'Notes',
                            style: Theme.of(context)
                                .textTheme
                                .titleMedium
                                ?.copyWith(
                                  color: Theme.of(context).brightness == Brightness.dark
                                      ? Colors.white
                                      : Colors.black87,
                                ),
                          ),
                        ),
                      ),
                      IconButton(
                        tooltip: _trailerUrl == null || _trailerUrl!.isEmpty ? 'Add trailer/link' : 'Edit trailer/link',
                        icon: const Icon(Icons.ondemand_video),
                        onPressed: () async {
                          final controller = TextEditingController(text: _trailerUrl ?? '');
                          final result = await showDialog<String?>(
                            context: context,
                            builder: (ctx) => AlertDialog(
                              title: const Text('Trailer / Link (URL)'),
                              content: TextField(controller: controller, decoration: const InputDecoration(hintText: 'https://...'), textCapitalization: TextCapitalization.sentences),
                              actions: [
                                TextButton(onPressed: () => Navigator.pop(ctx, null), child: const Text('Cancel')),
                                TextButton(onPressed: () => Navigator.pop(ctx, controller.text.trim()), child: const Text('Save')),
                              ],
                            ),
                          );
                          if (result != null) setState(() => _trailerUrl = result);
                        },
                      ),
                      IconButton(
                        tooltip: _castText == null || _castText!.isEmpty ? 'Add cast' : 'Edit cast',
                        icon: const Icon(Icons.groups_2_outlined),
                        onPressed: () async {
                          final controller = TextEditingController(text: _castText ?? '');
                          final result = await showDialog<String?>(
                            context: context,
                            builder: (ctx) => AlertDialog(
                              title: const Text('Cast (comma separated)'),
                              content: TextField(controller: controller, decoration: const InputDecoration(hintText: 'Name 1, Name 2, ...'), textCapitalization: TextCapitalization.sentences),
                              actions: [
                                TextButton(onPressed: () => Navigator.pop(ctx, null), child: const Text('Cancel')),
                                TextButton(onPressed: () => Navigator.pop(ctx, controller.text.trim()), child: const Text('Save')),
                              ],
                            ),
                          );
                          if (result != null) setState(() => _castText = result);
                        },
                      ),
                      IconButton(
                        tooltip: _genresText == null || _genresText!.isEmpty ? 'Add genres' : 'Edit genres',
                        icon: const Icon(Icons.movie_filter_outlined),
                        onPressed: () async {
                          final controller = TextEditingController(text: _genresText ?? '');
                          final result = await showDialog<String?>(
                            context: context,
                            builder: (ctx) => AlertDialog(
                              title: const Text('Genres (comma separated)'),
                              content: TextField(controller: controller, decoration: const InputDecoration(hintText: 'Action, Drama, Comedy, ...'), textCapitalization: TextCapitalization.sentences),
                              actions: [
                                TextButton(onPressed: () => Navigator.pop(ctx, null), child: const Text('Cancel')),
                                TextButton(onPressed: () => Navigator.pop(ctx, controller.text.trim()), child: const Text('Save')),
                              ],
                            ),
                          );
                          if (result != null) setState(() => _genresText = result);
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Container(
                    height: 150,
                    decoration: BoxDecoration(
                      color: Theme.of(context).brightness == Brightness.dark 
                          ? Colors.grey.shade800 
                          : Colors.white,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: Theme.of(context).brightness == Brightness.dark 
                            ? Colors.grey.shade600 
                            : Colors.grey.shade300,
                        width: 1,
                      ),
                    ),
                    child: TextField(
                      controller: _notesCtrl,
                      maxLines: null,
                      expands: true,
                      decoration: const InputDecoration(
                        hintText: 'Add your notes or comments here...',
                        border: InputBorder.none,
                        contentPadding: EdgeInsets.all(12),
                      ),
                      style: const TextStyle(fontSize: 14),
                    ),
                  ),
                  const SizedBox(height: ThemeSpacing.gap16),
                  const SizedBox.shrink(),
                ],
              ),
            ),
          ),
        ),
      ),
      ),
    );
  }
}