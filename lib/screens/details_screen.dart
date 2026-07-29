import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/rendering.dart';
import 'package:flutter/material.dart';
import 'package:flutter_rating_bar/flutter_rating_bar.dart';
import 'package:provider/provider.dart';
import '../providers/media_provider.dart';
import '../models/media_item.dart';
import 'add_edit_screen.dart';
import '../theme/spacing.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
// import 'package:url_launcher/url_launcher.dart';
import 'package:url_launcher/url_launcher_string.dart';
import 'package:flutter/services.dart';

/// Displays full details for a given media item with actions such as
/// favorite, share, edit, and delete. Supports share with light/dark background.
class DetailsScreen extends StatefulWidget {
  final MediaItem item;

  const DetailsScreen({super.key, required this.item});

  @override
  State<DetailsScreen> createState() => _DetailsScreenState();
}

class _DetailsScreenState extends State<DetailsScreen> {
  final GlobalKey shareKey = GlobalKey();
  bool _shareOverride = false;
  bool _shareDark = true;
  late MediaItem _currentItem;

  @override
  void initState() {
    super.initState();
    _currentItem = widget.item;
  }

  Future<MediaItem> _reloadItem(MediaProvider provider, int? id) async {
    await provider.loadItems();
    final items = provider.items;
    if (id != null) {
      final found = items.firstWhere((e) => e.id == id, orElse: () => widget.item);
      return found;
    }
    return widget.item;
  }

  String _normalizeUrl(String url) {
    final u = url.trim();
    if (u.isEmpty) return u;
    if (u.startsWith('http://') || u.startsWith('https://')) return u;
    return 'https://$u';
  }

  String? _shareLinkUrl() {
    final t = (_currentItem.extra?['trailer'] ?? '').toString().trim();
    if (t.isNotEmpty) return _normalizeUrl(t);
    final notes = _currentItem.notes ?? '';
    final m = RegExp(r'https?://\S+').firstMatch(notes);
    if (m != null) return _normalizeUrl(m.group(0)!);
    return null;
  }

  Future<void> _shareCapture({required bool dark}) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      setState(() {
        _shareOverride = true;
        _shareDark = dark;
      });
      // Wait longer for images to load before capture
      await Future.delayed(const Duration(milliseconds: 500));
      final boundary = shareKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
      if (boundary == null) return;
      final ui.Image image = await boundary.toImage(pixelRatio: 2.0);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      if (byteData == null) return;
      final pngBytes = byteData.buffer.asUint8List();
      final dir = await getTemporaryDirectory();
      final fname = dark ? 'mediacard_dark' : 'mediacard_light';
      final file = File('${dir.path}/${fname}_${_currentItem.id ?? DateTime.now().millisecondsSinceEpoch}.png');
      await file.writeAsBytes(pngBytes, flush: true);
      
      // Share only the image card
      await Share.shareXFiles(
        [XFile(file.path)],
      );
    } catch (_) {
      if (messenger.mounted) {
        messenger.showSnackBar(const SnackBar(content: Text('Failed to share')));
      }
    } finally {
      if (mounted) setState(() => _shareOverride = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final String? trailerUrl = _shareLinkUrl();
    const double gap = ThemeSpacing.gap12;
    return Scaffold(
      appBar: AppBar(
        title: Text(_currentItem.title),
        backgroundColor: Theme.of(context).colorScheme.primary,
        actions: [
          IconButton(
            tooltip: 'Favorite',
            icon: Icon(
              _currentItem.favorite ? Icons.favorite : Icons.favorite_border,
              color: _currentItem.favorite ? Colors.red : Theme.of(context).colorScheme.onSurface,
            ),
            onPressed: () async {
              final provider = Provider.of<MediaProvider>(context, listen: false);
              final updated = _currentItem.copyWith(favorite: !_currentItem.favorite);
              await provider.updateItem(updated);
              // Reload items to ensure UI updates
              await provider.loadItems();
              // Update the current item
              final reloadedItem = await _reloadItem(provider, _currentItem.id);
              if (mounted) {
                setState(() {
                  _currentItem = reloadedItem;
                });
              }
            },
          ),
          // Related items indicator
          Consumer<MediaProvider>(
            builder: (context, mp, _) {
              final relatedGroups = mp.findRelatedItemGroups();
              final hasRelated = relatedGroups.any((group) => 
                group.any((item) => 
                  mp.normalizeTitle(item.title) == mp.normalizeTitle(_currentItem.title) &&
                  item.type == _currentItem.type &&
                  item.id != _currentItem.id
                )
              );
              
              if (!hasRelated) return const SizedBox.shrink();
              
              return IconButton(
                tooltip: 'Related Items',
                icon: Icon(Icons.link, color: Theme.of(context).colorScheme.onSurface),
                onPressed: () => Navigator.of(context).pushNamed('/related'),
              );
            },
          ),
          IconButton(
            tooltip: 'Share',
            icon: const Icon(Icons.share),
            onPressed: () async {
              final linkUrl = _shareLinkUrl();
              final choice = await showModalBottomSheet<String>(
                context: context,
                showDragHandle: true,
                builder: (ctx) => SafeArea(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      ListTile(
                        leading: const Icon(Icons.dark_mode),
                        title: const Text('Share (black background)'),
                        onTap: () => Navigator.pop(ctx, 'dark'),
                      ),
                      ListTile(
                        leading: const Icon(Icons.light_mode),
                        title: const Text('Share (white background)'),
                        onTap: () => Navigator.pop(ctx, 'light'),
                      ),
                      if (linkUrl != null && linkUrl.trim().isNotEmpty)
                        ListTile(
                          leading: const Icon(Icons.link),
                          title: const Text('Share link only'),
                          onTap: () => Navigator.pop(ctx, 'link'),
                        ),
                    ],
                  ),
                ),
              );
              if (choice == 'dark') {
                await _shareCapture(dark: true);
              } else if (choice == 'light') {
                await _shareCapture(dark: false);
              } else if (choice == 'link' && linkUrl != null) {
                await Share.share(linkUrl);
              }
            },
          ),
          IconButton(
            icon: const Icon(Icons.edit),
            onPressed: () async {
              final navigator = Navigator.of(context);
              final provider = Provider.of<MediaProvider>(context, listen: false);
              await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => AddEditScreen(item: _currentItem),
                  fullscreenDialog: true,
                ),
              );
              final reloaded = await _reloadItem(provider, _currentItem.id);
              if (navigator.mounted) {
                // Replace current route safely without using context after await
                navigator.pushReplacement(
                  MaterialPageRoute(builder: (_) => DetailsScreen(item: reloaded)),
                );
              }
            },
          ),
          IconButton(
            icon: const Icon(Icons.delete, color: Colors.red),
            onPressed: () async {
              final provider = Provider.of<MediaProvider>(context, listen: false);
              final navigator = Navigator.of(context);
              final confirm = await showDialog<bool>(
                context: context,
                builder: (ctx) => AlertDialog(
                  title: const Text('Delete Item'),
                  content: const Text(
                    'Are you sure you want to delete this item?',
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(ctx, false),
                      child: const Text('Cancel'),
                    ),
                    TextButton(
                      onPressed: () => Navigator.pop(ctx, true),
                      child: const Text('Delete'),
                    ),
                  ],
                ),
              );
              if (confirm == true) {
                await provider.deleteItem(_currentItem.id!);
                if (navigator.mounted) navigator.pop();
              }
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: RepaintBoundary(
          key: shareKey,
          child: Container(
            color: _shareOverride
                ? (_shareDark ? const Color(0xFF000000) : const Color(0xFFFFFFFF))
                : (Theme.of(context).brightness == Brightness.dark
                    ? const Color(0xFF000000)
                    : const Color(0xFFFFFFFF)),
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if ((_currentItem.images != null && _currentItem.images!.isNotEmpty) ||
                      (_currentItem.imagePath != null && _currentItem.imagePath!.isNotEmpty))
                    SizedBox(
                      height: 220,
                      width: double.infinity,
                      child: Stack(
                        children: [
                          // Blur background using first image
                          if (_currentItem.imagePath != null && _currentItem.imagePath!.isNotEmpty)
                            Positioned.fill(
                              child: _currentItem.imagePath!.startsWith('http')
                                  ? Image.network(
                                      _currentItem.imagePath!,
                                      fit: BoxFit.cover,
                                      cacheWidth: 200,
                                      errorBuilder: (_, __, ___) => Container(color: Theme.of(context).colorScheme.surfaceContainerHighest),
                                    )
                                  : Image.file(
                                      File(_currentItem.imagePath!),
                                      fit: BoxFit.cover,
                                      errorBuilder: (_, __, ___) => Container(color: Theme.of(context).colorScheme.surfaceContainerHighest),
                                    ),
                            ),
                          // Blur effect
                          if (_currentItem.imagePath != null && _currentItem.imagePath!.isNotEmpty)
                            Positioned.fill(
                              child: BackdropFilter(
                                filter: ui.ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                                child: Container(color: Colors.black.withValues(alpha: 0.3)),
                              ),
                            ),
                          PageView(
                            children: [
                              if (_currentItem.imagePath != null && _currentItem.imagePath!.isNotEmpty)
                                Hero(
                                  tag: 'media-${_currentItem.id ?? _currentItem.title}',
                                  child: _currentItem.imagePath!.startsWith('http')
                                      ? Image.network(
                                          _currentItem.imagePath!,
                                          fit: BoxFit.contain,
                                          alignment: Alignment.center,
                                          cacheWidth: 800,
                                          errorBuilder: (_, __, ___) => const Icon(Icons.broken_image, size: 48),
                                        )
                                      : Image.file(
                                          File(_currentItem.imagePath!),
                                          fit: BoxFit.contain,
                                          alignment: Alignment.center,
                                          errorBuilder: (_, __, ___) => const Icon(Icons.broken_image, size: 48),
                                        ),
                                ),
                              ...?(_currentItem.images?.map(
                                (p) => p.startsWith('http')
                                    ? Image.network(
                                        p,
                                        fit: BoxFit.contain,
                                        cacheWidth: 800,
                                        errorBuilder: (_, __, ___) => const Icon(Icons.broken_image, size: 48),
                                      )
                                    : Image.file(File(p), fit: BoxFit.contain, errorBuilder: (_, __, ___) => const Icon(Icons.broken_image, size: 48)),
                              )),
                            ],
                          ),
                        ],
                      ),
                    ),
                  if (_currentItem.imagePath == null || _currentItem.imagePath!.isEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 48.0),
                      child: Center(
                        child: Column(
                          children: [
                            Image.asset(
                              'assets/images/mediavault_logo.png',
                              height: 120,
                            ),
                            const SizedBox(height: 16),
                            Text(
                              _currentItem.title,
                              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                                color: (_shareOverride && _shareDark)
                                    ? Colors.white
                                    : Theme.of(context).colorScheme.onSurface,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      ),
                    ),
                  SizedBox(height: gap + 8),
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: ThemeSpacing.gap16,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _currentItem.title,
                          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                            color: (_shareOverride && _shareDark)
                                ? Colors.white
                                : Theme.of(context).colorScheme.onSurface,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          softWrap: false,
                        ),
                        if (_currentItem.rating != null) ...[
                          const SizedBox(height: 6),
                          RatingBarIndicator(
                            rating: _currentItem.rating ?? 0,
                            itemBuilder: (context, _) => const Icon(Icons.star, color: Colors.amber),
                            itemCount: 5,
                            itemSize: 20.0,
                            unratedColor: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.3),
                          ),
                        ],
                        const SizedBox(height: 6),
                        Wrap(
                          spacing: 8,
                          runSpacing: 6,
                          children: [
                            _chip(context, _currentItem.status, Icons.flag),
                            if ((_currentItem.language ?? '').isNotEmpty)
                              _chip(context, _currentItem.language!, Icons.language),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Wrap(
                          spacing: 8,
                          runSpacing: 6,
                          children: [
                            if (_currentItem.type == 'Movies')
                              _chip(context, 'Movie', Icons.movie),
                            if (_currentItem.type == 'Series')
                              _chip(context, 'Series', Icons.live_tv),
                            if (_currentItem.type == 'Anime' && (_currentItem.extra?['manga']?.toString().toLowerCase() == 'true'))
                              _chip(context, 'Manga', Icons.bookmark),
                            if (_currentItem.type == 'Anime' && (_currentItem.extra?['manga']?.toString().toLowerCase() != 'true'))
                              _chip(context, 'Anime', Icons.animation),
                            if (_currentItem.type == 'K-Drama')
                              _chip(context, 'K-Drama', Icons.tv),
                            if (_currentItem.extra?['wsKind'] != null)
                              _chip(context, _currentItem.extra!['wsKind'].toString(), Icons.tv),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Wrap(
                          spacing: 8,
                          runSpacing: 6,
                          children: [
                            if (_currentItem.extra?['seasons'] != null)
                              _chip(context, 'Season: ${_currentItem.extra!['seasons']}', Icons.movie_filter),
                            if (_currentItem.type == 'Anime' && (_currentItem.extra?['manga']?.toString().toLowerCase() == 'true')) ...[
                              if (_currentItem.extra?['chapters'] != null)
                                _chip(context, 'Chapter: ${_currentItem.extra!['chapters']}', Icons.menu_book),
                            ] else ...[
                              if (_currentItem.extra?['episodes'] != null)
                                _chip(context, 'Episodes: ${_currentItem.extra!['episodes']}', Icons.confirmation_num),
                            ],
                          ],
                        ),
                        SizedBox(height: gap),
                        if ((_currentItem.extra?['cast'] ?? '')
                            .toString()
                            .trim()
                            .isNotEmpty)
                          _infoRow(context, 'Cast', _currentItem.extra!['cast'].toString(), forceWhite: _shareOverride && _shareDark),
                        if ((_currentItem.extra?['genres'] ?? '')
                            .toString()
                            .trim()
                            .isNotEmpty)
                          _infoRow(context, 'Genres', _currentItem.extra!['genres'].toString(), forceWhite: _shareOverride && _shareDark),
                        SizedBox(height: gap),
                        if (_currentItem.releaseYear != null)
                          _infoRow(context, 'Release Year', _currentItem.releaseYear.toString(), forceWhite: _shareOverride && _shareDark),
                        if (_currentItem.watchedYear != null)
                          _infoRow(context, 'Watched Year', _currentItem.watchedYear.toString(), forceWhite: _shareOverride && _shareDark),
                        _infoRow(
                          context,
                          'Added',
                          _currentItem.addedDate?.toLocal().toString().split(' ')[0] ?? 'N/A',
                          forceWhite: _shareOverride && _shareDark,
                        ),
                        if (_currentItem.notes != null)
                          Padding(
                            padding: EdgeInsets.only(top: gap),
                            child: _infoRow(context, 'Notes', _currentItem.notes!, forceWhite: _shareOverride && _shareDark),
                          ),
                        SizedBox(height: gap),
                        if (trailerUrl != null && trailerUrl.trim().isNotEmpty)
                          Center(
                            child: FilledButton.icon(
                              onPressed: () async {
                                final normalized = _normalizeUrl(trailerUrl);
                                bool ok = false;
                                final messenger = ScaffoldMessenger.of(context);
                                try {
                                  ok = await launchUrlString(normalized, mode: LaunchMode.externalApplication);
                                  if (!ok) {
                                    ok = await launchUrlString(normalized, mode: LaunchMode.platformDefault);
                                  }
                                } catch (_) {
                                  ok = false;
                                }
                                if (!ok && messenger.mounted) {
                                  await Clipboard.setData(ClipboardData(text: normalized));
                                  messenger.showSnackBar(const SnackBar(content: Text("Couldn't open link. URL copied to clipboard.")));
                                }
                              },
                              icon: const Icon(Icons.ondemand_video),
                              label: const Text('Watch trailer / Open link'),
                            ),
                          ),
                        const SizedBox(height: ThemeSpacing.gap8),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
    );
  }

  Widget _chip(BuildContext context, String text, IconData icon) {
    final Color primary = Theme.of(context).colorScheme.primary;
    return Chip(
      avatar: Icon(icon, size: 16, color: primary),
      label: Text(text, style: TextStyle(color: primary)),
      backgroundColor: primary.withValues(alpha: 0.08),
      side: BorderSide(color: primary.withValues(alpha: 0.15)),
    );
  }

  Widget _infoRow(BuildContext context, String label, String value, {bool forceWhite = false}) {
    final onSurface = forceWhite ? Colors.white : Theme.of(context).colorScheme.onSurface;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: TextStyle(fontWeight: FontWeight.bold, color: onSurface),
            ),
          ),
          Expanded(
            child: Text(value, style: TextStyle(color: onSurface)),
          ),
        ],
      ),
    );
  }

  // Widget _infoRowWidget removed as unused after reordering
}

// _NotesText removed; display raw notes as typed
// _NumberStepper removed (progress UI removed)
