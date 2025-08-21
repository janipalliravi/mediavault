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

  Future<void> _shareCapture({required bool dark}) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      setState(() {
        _shareOverride = true;
        _shareDark = dark;
      });
      await Future.delayed(const Duration(milliseconds: 50));
      final boundary = shareKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
      if (boundary == null) return;
      final ui.Image image = await boundary.toImage(pixelRatio: 2.0);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      if (byteData == null) return;
      final pngBytes = byteData.buffer.asUint8List();
      final dir = await getTemporaryDirectory();
      final fname = dark ? 'mediacard_dark' : 'mediacard_light';
      final file = File('${dir.path}/${fname}_${widget.item.id ?? DateTime.now().millisecondsSinceEpoch}.png');
      await file.writeAsBytes(pngBytes, flush: true);
      await Share.shareXFiles([XFile(file.path)], text: 'Check this out: ${widget.item.title}');
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
    final String? trailerUrl = (() {
      final t = (widget.item.extra?['trailer'] ?? '').toString().trim();
      if (t.isNotEmpty) return t;
      final notes = widget.item.notes ?? '';
      final m = RegExp(r'https?://\S+').firstMatch(notes);
      return m?.group(0);
    })();
    const double gap = ThemeSpacing.gap12;
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.item.title),
        backgroundColor: Theme.of(context).colorScheme.primary,
        actions: [
          IconButton(
            tooltip: 'Favorite',
            icon: Icon(
              widget.item.favorite ? Icons.favorite : Icons.favorite_border,
              color: widget.item.favorite ? Colors.red : Colors.white,
            ),
            onPressed: () async {
              final provider = Provider.of<MediaProvider>(context, listen: false);
              final navigator = Navigator.of(context);
              final updated = widget.item.copyWith(favorite: !widget.item.favorite);
              await provider.updateItem(updated);
              if (navigator.mounted) {
                navigator.pushReplacement(
                  MaterialPageRoute(builder: (_) => DetailsScreen(item: updated)),
                );
              }
            },
          ),
          IconButton(
            tooltip: 'Share',
            icon: const Icon(Icons.share),
            onPressed: () async {
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
                    ],
                  ),
                ),
              );
              if (choice == 'dark') {
                await _shareCapture(dark: true);
              } else if (choice == 'light') {
                await _shareCapture(dark: false);
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
                  builder: (_) => AddEditScreen(item: widget.item),
                  fullscreenDialog: true,
                ),
              );
              final reloaded = await _reloadItem(provider, widget.item.id);
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
                await provider.deleteItem(widget.item.id!);
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
                  if ((widget.item.images != null && widget.item.images!.isNotEmpty) ||
                      (widget.item.imagePath != null && widget.item.imagePath!.isNotEmpty))
                    SizedBox(
                      height: 220,
                      width: double.infinity,
                      child: PageView(
                        children: [
                          if (widget.item.imagePath != null && widget.item.imagePath!.isNotEmpty)
                            Hero(
                              tag: 'media-${widget.item.id ?? widget.item.title}',
                              child: widget.item.imagePath!.startsWith('http')
                                  ? Image.network(
                                      widget.item.imagePath!,
                                      fit: BoxFit.contain,
                                      alignment: Alignment.center,
                                      cacheWidth: 800,
                                      errorBuilder: (_, __, ___) => const Icon(Icons.broken_image, size: 48),
                                    )
                                  : Image.file(
                                      File(widget.item.imagePath!),
                                      fit: BoxFit.contain,
                                      alignment: Alignment.center,
                                      errorBuilder: (_, __, ___) => const Icon(Icons.broken_image, size: 48),
                                    ),
                            ),
                          ...?(widget.item.images?.map(
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
                    ),
                  if (widget.item.imagePath == null || widget.item.imagePath!.isEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 48.0),
                      child: Center(
                        child: Image.asset(
                          'assets/images/mediavault_logo.png',
                          height: 120,
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
                          widget.item.title,
                          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                            color: (_shareOverride && _shareDark)
                                ? Colors.white
                                : Theme.of(context).colorScheme.onSurface,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          softWrap: false,
                        ),
                        if (widget.item.rating != null) ...[
                          const SizedBox(height: 6),
                          RatingBarIndicator(
                            rating: widget.item.rating ?? 0,
                            itemBuilder: (context, _) => const Icon(Icons.star, color: Colors.amber),
                            itemCount: 5,
                            itemSize: 20.0,
                            unratedColor: Colors.grey.shade300,
                          ),
                        ],
                        const SizedBox(height: 6),
                        Wrap(
                          spacing: 8,
                          runSpacing: 6,
                          children: [
                            _chip(context, widget.item.status == 'Completed' ? 'Done' : (widget.item.status == 'Plan to Watch' ? 'Watch list' : widget.item.status), Icons.flag),
                            if ((widget.item.language ?? '').isNotEmpty)
                              _chip(context, widget.item.language!, Icons.language),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Wrap(
                          spacing: 8,
                          runSpacing: 6,
                          children: [
                            if (widget.item.type == 'Series')
                              _chip(context, 'Series', Icons.live_tv),
                            if (widget.item.type == 'Anime' && (widget.item.extra?['manga']?.toString().toLowerCase() == 'true'))
                              _chip(context, 'Manga', Icons.bookmark),
                            if (widget.item.extra?['wsKind'] != null)
                              _chip(context, widget.item.extra!['wsKind'].toString(), Icons.tv),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Wrap(
                          spacing: 8,
                          runSpacing: 6,
                          children: [
                            if (widget.item.extra?['seasons'] != null)
                              _chip(context, 'Season: ${widget.item.extra!['seasons']}', Icons.movie_filter),
                            if (widget.item.type == 'Anime' && (widget.item.extra?['manga']?.toString().toLowerCase() == 'true')) ...[
                              if (widget.item.extra?['chapters'] != null)
                                _chip(context, 'Chapter: ${widget.item.extra!['chapters']}', Icons.menu_book),
                            ] else ...[
                              if (widget.item.extra?['episodes'] != null)
                                _chip(context, 'Episodes: ${widget.item.extra!['episodes']}', Icons.confirmation_num),
                            ],
                          ],
                        ),
                        SizedBox(height: gap),
                        if ((widget.item.extra?['cast'] ?? '')
                            .toString()
                            .trim()
                            .isNotEmpty)
                          _infoRow(context, 'Cast', widget.item.extra!['cast'].toString(), forceWhite: _shareOverride && _shareDark),
                        SizedBox(height: gap),
                        if (widget.item.releaseYear != null)
                          _infoRow(context, 'Release Year', widget.item.releaseYear.toString(), forceWhite: _shareOverride && _shareDark),
                        if (widget.item.watchedYear != null)
                          _infoRow(context, 'Watched Year', widget.item.watchedYear.toString(), forceWhite: _shareOverride && _shareDark),
                        if (widget.item.recommend != null)
                          _infoRow(context, 'Recommend', widget.item.recommend!, forceWhite: _shareOverride && _shareDark),
                        _infoRow(
                          context,
                          'Added',
                          widget.item.addedDate?.toLocal().toString().split(' ')[0] ?? 'N/A',
                          forceWhite: _shareOverride && _shareDark,
                        ),
                        if (widget.item.notes != null)
                          Padding(
                            padding: EdgeInsets.only(top: gap),
                            child: _infoRow(context, 'Notes', widget.item.notes!, forceWhite: _shareOverride && _shareDark),
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
