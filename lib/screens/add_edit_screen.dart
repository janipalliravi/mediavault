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
// settings provider not needed for spacing now

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
  final _seasonsCtrl = TextEditingController();
  final _episodesCtrl = TextEditingController();
  final List<String> _extraImages = <String>[];

  static const List<String> _types = ['Movies', 'Anime', 'K-Drama', 'Series'];
  static const List<String> _statuses = AppConstants.statuses;
  static const List<String> _recommendOpts = AppConstants.recommendOptions;

  String _type = _types.first;
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
      _rating = item.rating ?? 0.0;
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
      // Prefill images
      if (item.images != null && item.images!.isNotEmpty) {
        _extraImages.addAll(item.images!);
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
      return Colors.grey.shade600; // dim for low ratings
    }
    return Row(
      children: List.generate(5, (i) {
        final starIndex = i + 1.0;
        final isFilled = _rating >= starIndex;
        return IconButton(
          icon: Icon(isFilled ? Icons.star : Icons.star_border),
          color: starColorFor(_rating == 0 ? starIndex : _rating),
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
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Failed to pick image')));
    }
  }

  Future<void> _pickImagesFromGallery() async {
    try {
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
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Failed to import images')));
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
            ],
          ),
        );
      },
    );
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    final provider = context.read<MediaProvider>();

    // Prevent duplicate titles (case-insensitive). If editing, ignore the current item's id.
    final proposedTitle = _titleCtrl.text.trim();
    final isDuplicate = provider.titleExists(proposedTitle, ignoreId: widget.item?.id, type: _normalizedType(_type));
    if (isDuplicate) {
      if (!mounted) return;
      await showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Duplicate Title'),
          content: Text('An item with the title "$proposedTitle" already exists.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('OK'),
            ),
          ],
        ),
      );
      return;
    }

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
    if (_type == 'Anime' && _isManga) {
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
    // Store chapters vs episodes according to manga flag
    if (_type == 'Anime' && _isManga) {
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
      notes: cleanedNotes.trim().isEmpty ? null : cleanedNotes.trim(),
      recommend: _recommend,
      imagePath: _imagePath,
      extra: extra.isEmpty ? null : extra,
      // Tags removed per request
      images: _extraImages.isEmpty ? null : List<String>.from(_extraImages),
    );

    if (widget.item == null) {
      await provider.addItem(newItem);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$_type added')),
        );
      }
    } else {
      await provider.updateItem(newItem);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Item updated')),
        );
      }
    }

    if (mounted) Navigator.of(context).pop({'type': newItem.type});
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
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          title: Text(isEdit ? 'Edit Item' : 'Add Item'),
          backgroundColor: Theme.of(context).colorScheme.primary,
          actions: [
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
                        t,
                        style: TextStyle(
                          color: Theme.of(context).brightness == Brightness.dark ? Colors.white : Colors.black87,
                          overflow: TextOverflow.ellipsis,
                        ),
                      )
                    )).toList(),
                    onChanged: (v) => setState(() => _type = v!),
                    decoration: _inputDecoration('Type *'),
                  ),
                  if (_type == 'Anime') ...[
                    SizedBox(height: gap),
                    SwitchListTile(
                      value: _isManga,
                      title: const Text('Manga'),
                      subtitle: const Text('Mark as Manga (printed/comic)'),
                      onChanged: (v) => setState(() => _isManga = v),
                    ),
                  ] else if (_type == 'Series') ...[
                    SizedBox(height: gap),
                    DropdownButtonFormField<String>(
                      value: _webSeriesKind,
                      isExpanded: true,
                      style: TextStyle(
                        fontSize: 14,
                        color: Theme.of(context).brightness == Brightness.dark ? Colors.white : Colors.black87,
                      ),
                      dropdownColor: Theme.of(context).brightness == Brightness.dark ? const Color(0xFF2A2A2A) : Colors.white,
                      items: const [
                        'TV / OTT',
                        'Regional series',
                        'Independent',
                      ].map((e) => DropdownMenuItem<String>(value: e, child: Text(e, overflow: TextOverflow.ellipsis))).toList(),
                      onChanged: (v) => setState(() => _webSeriesKind = v),
                      decoration: _inputDecoration('Series kind'),
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
                            decoration: _inputDecoration(_type == 'Anime' && _isManga ? 'Chapter' : 'Episodes'),
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
                      if (_type == 'Anime' && _isManga && !list.contains('Reading')) {
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
                              content: TextField(controller: controller, decoration: const InputDecoration(hintText: 'https://...')),
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
                              content: TextField(controller: controller, decoration: const InputDecoration(hintText: 'Name 1, Name 2, ...')),
                              actions: [
                                TextButton(onPressed: () => Navigator.pop(ctx, null), child: const Text('Cancel')),
                                TextButton(onPressed: () => Navigator.pop(ctx, controller.text.trim()), child: const Text('Save')),
                              ],
                            ),
                          );
                          if (result != null) setState(() => _castText = result);
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  TextFormField(
                    controller: _notesCtrl,
                    style: const TextStyle(fontSize: 14),
                    decoration: _inputDecoration('Notes'),
                    enableInteractiveSelection: true,
                    contextMenuBuilder: (context, editableTextState) =>
                        AdaptiveTextSelectionToolbar.editableText(
                      editableTextState: editableTextState,
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
    );
  }
}