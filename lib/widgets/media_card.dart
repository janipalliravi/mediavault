import 'package:flutter/material.dart';
import 'dart:async';
import 'package:flutter_rating_bar/flutter_rating_bar.dart';
import 'package:share_plus/share_plus.dart';
import '../models/media_item.dart';
import 'dart:io';
import '../theme/spacing.dart';
import 'package:provider/provider.dart';
import '../providers/settings_provider.dart' as sp;
import '../providers/media_provider.dart';
import 'package:marquee/marquee.dart';
import 'package:palette_generator/palette_generator.dart';
import 'package:cached_network_image/cached_network_image.dart';

/// MediaCard renders a single media item as either a grid card or a list tile.
/// Grid shows an image carousel, title marquee, type/status and progress pills, and rating.
/// List shows a compact title, rating under title, then the same pills.
class MediaCard extends StatefulWidget {
  final MediaItem item;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final bool isGrid;

  const MediaCard({
    super.key,
    required this.item,
    this.onTap,
    this.onLongPress,
    this.isGrid = true,
  });

  @override
  State<MediaCard> createState() => _MediaCardState();
}

class _MediaCardState extends State<MediaCard> {

  final PageController _pageController = PageController();
  Timer? _autoTimer;
  int _currentPage = 0;
  Color? _accent;
  static final Map<String, Color> _paletteCache = <String, Color>{};

  List<String> _imagePaths() => [
        if (widget.item.imagePath != null && widget.item.imagePath!.isNotEmpty)
          widget.item.imagePath!,
        ...?widget.item.images,
      ].where((p) => p.trim().isNotEmpty).toList(growable: false);

  Widget _imageErrorPlaceholder() {
    return Container(
      color: Colors.grey[300],
      child: const FittedBox(child: Icon(Icons.image_not_supported, size: 40, color: Colors.black26)),
    );
  }

  @override
  void initState() {
    super.initState();
    _startOrStopTimer();
    _computePalette();
  }

  @override
  void dispose() {
    _autoTimer?.cancel();
    _pageController.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant MediaCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.item.imagePath != widget.item.imagePath ||
        (oldWidget.item.images ?? const []).join(',') != (widget.item.images ?? const []).join(',')) {
      _currentPage = 0;
      if (_pageController.hasClients) {
        _pageController.jumpToPage(0);
      }
      _startOrStopTimer();
      _computePalette();
    }
  }

  void _startOrStopTimer() {
    _autoTimer?.cancel();
    final paths = _imagePaths();
    if (paths.length > 1) {
      final interval = context.read<sp.SettingsProvider>().carouselIntervalSec;
      if (interval == 0) return; // off
      _autoTimer = Timer.periodic(Duration(seconds: interval), (timer) {
        if (!mounted) return;
        final total = _imagePaths().length;
        if (total <= 1) return;
        _currentPage = (_currentPage + 1) % total;
        if (_pageController.hasClients) {
          _pageController.animateToPage(
            _currentPage,
            duration: const Duration(milliseconds: 240),
            curve: Curves.easeOutCubic,
          );
        }
      });
    }
  }

  Future<void> _computePalette() async {
    try {
      final paths = _imagePaths();
      if (paths.isEmpty) return;
      final imgPath = paths.first;
      // Use cached palette if present to avoid repeated decoding
      final cached = _paletteCache[imgPath];
      if (cached != null) {
        if (!mounted) return;
        setState(() => _accent = cached);
        return;
      }
      // Performance optimization: Skip palette computation for large lists
      if (_paletteCache.length > 50) return; // Limit cache size
      
      // Stagger computation slightly to avoid burst on first frame
      await Future.delayed(Duration(milliseconds: 200 + (widget.hashCode % 200)));
      PaletteGenerator gen;
      if (imgPath.startsWith('http')) {
        gen = await PaletteGenerator.fromImageProvider(NetworkImage(imgPath), maximumColorCount: 3);
      } else {
        gen = await PaletteGenerator.fromImageProvider(FileImage(File(imgPath)), maximumColorCount: 3);
      }
      if (!mounted) return;
      final color = gen.dominantColor?.color;
      if (color != null) {
        _paletteCache[imgPath] = color;
      }
      setState(() => _accent = color);
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final heroTag = 'media-${widget.item.id ?? widget.item.title}';
    final currentFitPref = (widget.item.extra != null && widget.item.extra!['fit'] is String)
        ? (widget.item.extra!['fit'] as String)
        : 'cover';
    final BoxFit imageFit = currentFitPref == 'contain' ? BoxFit.contain : BoxFit.cover;

    // Decorative border based on rating
    final double rating = (widget.item.rating ?? 0).toDouble();
    Color? borderColor;
    if (rating >= 5) {
      borderColor = const Color(0xFFFFD700); // Gold
    } else if (rating >= 4 && rating < 5) {
      borderColor = const Color(0xFFC0C0C0); // Silver
    } else if (rating >= 3 && rating < 4) {
      borderColor = const Color(0xFFCD7F32); // Bronze
    }
    final BorderSide cardBorderSide = borderColor != null
        ? BorderSide(color: borderColor, width: 2)
        : BorderSide.none;

    final Color border = _accent ?? Theme.of(context).colorScheme.primary.withValues(alpha: 0.2);
    final double gap = ThemeSpacing.gap12;

    return RepaintBoundary(
      child: Card(
        margin: EdgeInsets.symmetric(vertical: gap),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(ThemeSpacing.radius12),
          side: cardBorderSide == BorderSide.none ? BorderSide(color: border, width: 1) : cardBorderSide,
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () {
            final mp = context.read<MediaProvider>();
            final id = widget.item.id;
            if (mp.selectionMode && id != null) {
              mp.toggleSelect(id);
            } else {
              widget.onTap?.call();
            }
          },
          onLongPress: () {
            final mp = context.read<MediaProvider>();
            final id = widget.item.id;
            if (id != null) {
              if (!mp.selectionMode) mp.toggleSelectionMode(true);
              mp.toggleSelect(id);
            } else {
              widget.onLongPress?.call();
            }
          },
          child: widget.isGrid
              ? LayoutBuilder(
                  builder: (context, constraints) {
                    double imageFraction = 0.62;
                    int imageFlex = (imageFraction * 100).round().clamp(30, 80);
                    int infoFlex = 100 - imageFlex;
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Flexible(
                          flex: imageFlex,
                          child: Padding(
                            padding: const EdgeInsets.only(bottom: 8.0),
                            child: Stack(
                              fit: StackFit.expand,
                              children: [
                                Hero(
                                  tag: heroTag,
                                  child: _buildImagePager(imageFit),
                                ),
                                Positioned(
                                  top: 6,
                                  left: 6,
                                  child: Row(
                                    children: [
                                      GestureDetector(
                                        onTap: () async {
                                          final mp = context.read<MediaProvider>();
                                          final updated = widget.item.copyWith(favorite: !widget.item.favorite);
                                          await mp.updateItem(updated);
                                        },
                                        child: Container(
                                          decoration: BoxDecoration(
                                            color: Colors.black.withValues(alpha: 0.3),
                                            shape: BoxShape.circle,
                                          ),
                                          padding: const EdgeInsets.all(4),
                                          child: Icon(
                                            widget.item.favorite ? Icons.favorite : Icons.favorite_border,
                                            color: widget.item.favorite ? Colors.red : Colors.white,
                                            size: 16,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 4),
                                      // Related items indicator
                                      Consumer<MediaProvider>(
                                        builder: (context, mp, _) {
                                          final relatedGroups = mp.findRelatedItemGroups();
                                          final hasRelated = relatedGroups.any((group) => 
                                            group.any((item) => 
                                              mp.normalizeTitle(item.title) == mp.normalizeTitle(widget.item.title) &&
                                              item.type == widget.item.type &&
                                              item.id != widget.item.id
                                            )
                                          );
                                          
                                          if (!hasRelated) return const SizedBox.shrink();
                                          
                                          return GestureDetector(
                                            onTap: () => Navigator.of(context).pushNamed('/related'),
                                            child: Container(
                                              decoration: BoxDecoration(
                                                color: Colors.blue.withValues(alpha: 0.8),
                                                shape: BoxShape.circle,
                                              ),
                                              padding: const EdgeInsets.all(4),
                                              child: const Icon(
                                                Icons.link,
                                                color: Colors.white,
                                                size: 16,
                                              ),
                                            ),
                                          );
                                        },
                                      ),
                                    ],
                                  ),
                                ),
                                Positioned(
                                  top: 6,
                                  right: 6,
                                  child: Consumer<MediaProvider>(
                                    builder: (context, mp, _) {
                                      final selected = widget.item.id != null && mp.isSelected(widget.item.id!);
                                      return AnimatedOpacity(
                                        opacity: mp.selectionMode ? 1.0 : 0.0,
                                        duration: const Duration(milliseconds: 150),
                                        child: CircleAvatar(
                                          radius: 12,
                                          backgroundColor: selected ? Colors.blue : Colors.white,
                                          child: Icon(
                                            selected ? Icons.check : Icons.circle_outlined,
                                            size: 16,
                                            color: selected ? Colors.white : Colors.blue,
                                          ),
                                        ),
                                      );
                                    },
                                  ),
                                ),
                                Container(
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      begin: Alignment.bottomCenter,
                                      end: Alignment.topCenter,
                                      colors: [
                                        Colors.black.withValues(alpha: 0.7),
                                        Colors.transparent,
                                      ],
                                    ),
                                  ),
                                ),
                                Positioned(
                                  left: 8,
                                  right: 8,
                                  bottom: 6,
                                  child: _buildTitleMarquee(widget.item.title),
                                ),
                              ],
                            ),
                          ),
                        ),
                        Flexible(
                          flex: infoFlex,
                          child: Padding(
                            padding: EdgeInsets.symmetric(horizontal: gap, vertical: gap / 3),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.max,
                              children: [
                                Builder(builder: (context) {
                                  final bool isManga = widget.item.type == 'Anime' &&
                                      (widget.item.extra?['manga']?.toString().toLowerCase() == 'true');
                                                                     final String displayType = isManga ? 'Manga' : (widget.item.type == 'Movies' ? 'Movie' : widget.item.type);
                                  final String statusLabel = widget.item.status == 'Completed'
                                      ? 'Done'
                                      : (widget.item.status == 'Plan to Watch' ? 'Watch list' : widget.item.status);
                                  return Wrap(
                                    spacing: gap / 2,
                                    runSpacing: 0,
                                    children: [
                                      _buildPill(context, displayType, fontSize: 11.0, padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4)),
                                      _buildPill(context, statusLabel, fontSize: 11.0, padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4)),
                                    ],
                                  );
                                }),
                                const SizedBox(height: 2),
                                Builder(builder: (context) {
                                  final bool isManga = widget.item.type == 'Anime' &&
                                      (widget.item.extra?['manga']?.toString().toLowerCase() == 'true');
                                  final String? seasons = widget.item.extra?['seasons']?.toString();
                                  final String? chapters = widget.item.extra?['chapters']?.toString();
                                  final String? episodes = widget.item.extra?['episodes']?.toString();
                                  final List<String> pills = [
                                    if (seasons != null && seasons.trim().isNotEmpty) 'Season: $seasons',
                                    if (isManga && chapters != null && chapters.trim().isNotEmpty)
                                      'Chapter: $chapters'
                                    else if (!isManga && episodes != null && episodes.trim().isNotEmpty)
                                      'Episode: $episodes',
                                  ];
                                  if (pills.isEmpty) return const SizedBox.shrink();
                                  final EdgeInsets pad = const EdgeInsets.symmetric(horizontal: 8, vertical: 3);
                                  const double font = 10.0;
                                  return Wrap(
                                    spacing: gap / 2,
                                    runSpacing: 0,
                                    children: pills.map((t) => _buildPill(context, t, fontSize: font, padding: pad)).toList(),
                                  );
                                }),
                                const SizedBox(height: 2),
                                if (widget.item.rating != null)
                                  RatingBarIndicator(
                                    rating: widget.item.rating ?? 0,
                                    itemBuilder: (context, index) => Icon(
                                      Icons.star,
                                      color: _getStarColorByRating(widget.item.rating ?? 0),
                                    ),
                                    itemCount: 5,
                                    itemSize: 18.0,
                                    unratedColor: Colors.grey.shade500,
                                  ),
                                const Spacer(),
                              ],
                            ),
                          ),
                        ),
                      ],
                    );
                  },
                )
              : Container(
                  height: 120, // Fixed height for list view items
                  padding: EdgeInsets.symmetric(horizontal: 12, vertical: gap / 1.25),
                  child: InkWell(
                    onTap: widget.onTap,
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: Container(
                            width: 96,
                            decoration: BoxDecoration(
                              image: DecorationImage(
                                image: (() {
                                  final paths = _imagePaths();
                                  if (paths.isNotEmpty) {
                                    final p = paths.first;
                                    return p.startsWith('http')
                                        ? NetworkImage(p)
                                        : FileImage(File(p)) as ImageProvider;
                                  }
                                  return const AssetImage('assets/images/mediavault_logo.png');
                                })(),
                                fit: BoxFit.cover,
                              ),
                              color: Colors.grey[300],
                            ),
                          ),
                        ),
                        SizedBox(width: gap),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                widget.item.title,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                softWrap: false,
                                style: const TextStyle(fontWeight: FontWeight.w600),
                              ),
                              if (widget.item.rating != null)
                                Padding(
                                  padding: const EdgeInsets.only(top: 2.0),
                                  child: RatingBarIndicator(
                                    rating: widget.item.rating ?? 0,
                                    itemBuilder: (context, index) => Icon(
                                      Icons.star,
                                      color: _getStarColorByRating(widget.item.rating ?? 0),
                                    ),
                                    itemCount: 5,
                                    itemSize: 14.0,
                                    unratedColor: Colors.grey.shade500,
                                  ),
                                ),
                              SizedBox(height: gap / 3),
                              Wrap(
                                spacing: gap / 1.5,
                                runSpacing: gap / 2,
                                children: [
                                  _buildPill(
                                    context,
                                                                         (widget.item.type == 'Anime' &&
                                             (widget.item.extra?['manga']?.toString().toLowerCase() == 'true'))
                                         ? 'Manga'
                                         : (widget.item.type == 'Movies' ? 'Movie' : widget.item.type),
                                  ),
                                  _buildPill(
                                    context,
                                    widget.item.status == 'Completed'
                                        ? 'Done'
                                        : (widget.item.status == 'Plan to Watch' ? 'Watch list' : widget.item.status),
                                  ),
                                ],
                              ),
                              SizedBox(height: gap / 4),
                              Wrap(
                                spacing: gap / 1.5,
                                runSpacing: gap / 2,
                                children: [
                                  if (widget.item.extra != null && widget.item.extra!['seasons'] != null)
                                    _buildPill(
                                      context,
                                      'Season: ${widget.item.extra!['seasons']}',
                                    ),
                                  if (widget.item.type == 'Anime' &&
                                      (widget.item.extra?['manga']?.toString().toLowerCase() == 'true')) ...[
                                    if (widget.item.extra?['chapters'] != null)
                                      _buildPill(
                                        context,
                                        'Chapter: ${widget.item.extra!['chapters']}',
                                      ),
                                  ] else ...[
                                    if (widget.item.extra?['episodes'] != null)
                                      _buildPill(
                                        context,
                                        'Episode: ${widget.item.extra!['episodes']}',
                                      ),
                                  ],
                                ],
                              ),
                              const Spacer(),
                            ],
                          ),
                        ),
                        PopupMenuButton<String>(
                          onSelected: (value) => _handleMenu(value, context, currentFitPref),
                          itemBuilder: (ctx) => [
                            const PopupMenuItem(value: 'edit', child: Text('Edit')),
                            const PopupMenuItem(value: 'share', child: Text('Share')),
                            PopupMenuItem(
                              value: 'toggle_fit',
                              child: Text(currentFitPref == 'contain' ? 'Fit to width' : 'Fit to height'),
                            ),
                            PopupMenuItem(
                              value: 'toggle_favorite',
                              child: Row(
                                children: [
                                  Icon(widget.item.favorite ? Icons.favorite : Icons.favorite_border,
                                      color: widget.item.favorite ? Colors.red : null, size: 18),
                                  const SizedBox(width: 8),
                                  Text(widget.item.favorite ? 'Unfavorite' : 'Favorite'),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
        ),
      ),
    );
  }

  Widget _buildImageOrPlaceholder(BoxFit fit) {
    if (widget.item.imagePath != null && widget.item.imagePath!.isNotEmpty) {
      if (widget.item.imagePath!.startsWith('http')) {
        return CachedNetworkImage(
          imageUrl: widget.item.imagePath!,
          fit: fit,
          memCacheWidth: widget.isGrid ? 600 : 300,
          fadeInDuration: const Duration(milliseconds: 180),
          placeholder: (context, url) => _imageErrorPlaceholder(),
          errorWidget: (context, url, error) => _imageErrorPlaceholder(),
        );
      }
      try {
        return Image.file(
          File(widget.item.imagePath!),
          fit: fit,
          cacheWidth: widget.isGrid ? 600 : 300,
          errorBuilder: (_, __, ___) => _imageErrorPlaceholder(),
        );
      } catch (_) {
        return _imageErrorPlaceholder();
      }
    }
    return Container(
      color: Colors.grey[300],
      child: const FittedBox(child: Icon(Icons.image, size: 40, color: Colors.black26)),
    );
  }

  Widget _buildImagePager(BoxFit fit) {
    final paths = _imagePaths();
    if (paths.isEmpty) return _buildImageOrPlaceholder(fit);
    if (paths.length == 1) {
      final p = paths.first;
      return ClipRRect(
        borderRadius: BorderRadius.circular(0),
        child: p.startsWith('http')
            ? CachedNetworkImage(
                imageUrl: p,
                fit: fit,
                memCacheWidth: widget.isGrid ? 600 : 300,
                fadeInDuration: const Duration(milliseconds: 180),
                placeholder: (context, url) => _imageErrorPlaceholder(),
                errorWidget: (context, url, error) => _imageErrorPlaceholder(),
              )
            : Image.file(File(p), fit: fit, cacheWidth: widget.isGrid ? 600 : 300, errorBuilder: (_, __, ___) => _imageErrorPlaceholder()),
      );
    }
    return PageView.builder(
      controller: _pageController,
      itemCount: paths.length,
      onPageChanged: (index) => _currentPage = index,
      itemBuilder: (context, index) {
        final p = paths[index];
        return ClipRRect(
          borderRadius: BorderRadius.circular(0),
          child: p.startsWith('http')
              ? CachedNetworkImage(
                  imageUrl: p,
                  fit: fit,
                  memCacheWidth: widget.isGrid ? 600 : 300,
                  fadeInDuration: const Duration(milliseconds: 180),
                  placeholder: (context, url) => _imageErrorPlaceholder(),
                  errorWidget: (context, url, error) => _imageErrorPlaceholder(),
                )
              : Image.file(File(p), fit: fit, cacheWidth: widget.isGrid ? 600 : 300, errorBuilder: (_, __, ___) => _imageErrorPlaceholder()),
        );
      },
    );
  }

  Color _getStarColorByRating(double rating) {
    final double normalized = rating.clamp(0, 5);
    if (normalized >= 5) {
      return const Color(0xFFFFD700); // Bright gold for 5 stars
    } else if (normalized >= 4) {
      return const Color(0xFFE6C200); // Slightly darker gold for 4+
    } else if (normalized >= 3) {
      return const Color(0xFFCCAA00); // Dark gold/bronze for 3+
    } else if (normalized > 0) {
      return const Color(0xFFB38F00); // Dim bronze for 1-2
    }
    return Colors.grey.shade500; // Unrated
  }
  Widget _buildPill(BuildContext context, String text, {double fontSize = 11, EdgeInsets? padding}) {
    // Respect DetailsScreen share override by inheriting Theme; for cards we just use theme colors
    final Color primary = Theme.of(context).colorScheme.primary;
    return Container(
      padding: padding ?? const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: primary.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: primary.withValues(alpha: 0.15)),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: primary,
          fontSize: fontSize,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  void _handleMenu(String value, BuildContext context, String currentFitPref) {
    switch (value) {
      case 'share':
        Share.share('Check this out: ${widget.item.title}');
        break;
      case 'edit':
        if (widget.onTap != null) widget.onTap!();
        break;
      case 'toggle_fit':
        final newFit = currentFitPref == 'contain' ? 'cover' : 'contain';
        final newExtra = Map<String, dynamic>.from(widget.item.extra ?? {});
        newExtra['fit'] = newFit;
        final updated = widget.item.copyWith(extra: newExtra);
        context.read<MediaProvider>().updateItem(updated);
        break;
      case 'toggle_favorite':
        final updated = widget.item.copyWith(favorite: !widget.item.favorite);
        context.read<MediaProvider>().updateItem(updated);
        break;
    }
  }

  Widget _buildTitleMarquee(String title) {
    // If short enough, no need to scroll
    if (title.length <= 22) {
      return Text(
        title,
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.bold,
          fontSize: 14,
        ),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      );
    }
    return SizedBox(
      height: 18,
      child: Marquee(
        text: title,
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.bold,
          fontSize: 14,
        ),
        velocity: 25.0,
        blankSpace: 40.0,
        pauseAfterRound: const Duration(milliseconds: 600),
        startPadding: 0.0,
        fadingEdgeStartFraction: 0.05,
        fadingEdgeEndFraction: 0.05,
      ),
    );
  }
}