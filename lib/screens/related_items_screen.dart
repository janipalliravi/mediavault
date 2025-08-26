import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/media_provider.dart';
import '../models/media_item.dart';
import '../theme/spacing.dart';
import '../widgets/media_card.dart';
import 'details_screen.dart';

/// RelatedItemsScreen shows items with the same title but different seasons
class RelatedItemsScreen extends StatelessWidget {
  const RelatedItemsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final mp = context.watch<MediaProvider>();
    const double gap = ThemeSpacing.gap12;
    final relatedGroups = mp.findRelatedItemGroups();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Related Items'),
        actions: [
          IconButton(
            icon: const Icon(Icons.info_outline),
            onPressed: () => _showInfoDialog(context),
            tooltip: 'About Related Items',
          ),
        ],
      ),
      body: relatedGroups.isEmpty
          ? const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.link_off, size: 64, color: Colors.grey),
                  SizedBox(height: 16),
                  Text(
                    'No related items found',
                    style: TextStyle(fontSize: 18, color: Colors.grey),
                  ),
                  SizedBox(height: 8),
                  Text(
                    'Items with the same title but different seasons\nwill appear here',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.grey),
                  ),
                ],
              ),
            )
          : ListView.separated(
              padding: const EdgeInsets.all(gap),
              itemCount: relatedGroups.length,
              separatorBuilder: (_, __) => const SizedBox(height: gap * 2),
              itemBuilder: (context, index) {
                final List<MediaItem> group = relatedGroups[index];
                final baseTitle = mp.normalizeTitle(group.first.title);
                final type = group.first.type;
                
                return Card(
                  elevation: 2,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Header with title and type
                      Container(
                        padding: const EdgeInsets.all(gap),
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.primaryContainer,
                          borderRadius: const BorderRadius.only(
                            topLeft: Radius.circular(12),
                            topRight: Radius.circular(12),
                          ),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    baseTitle,
                                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  Text(
                                    '$type • ${group.length} seasons/parts',
                                    style: Theme.of(context).textTheme.bodySmall,
                                  ),
                                ],
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: Theme.of(context).colorScheme.primary,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                '${group.length}',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      
                      // Related items with visual connections
                      ...group.asMap().entries.map((entry) {
                        final index = entry.key;
                        final item = entry.value;
                        final isLast = index == group.length - 1;
                        
                        return Column(
                          children: [
                            // Connection line (except for last item)
                            if (!isLast)
                              Container(
                                height: 20,
                                width: 2,
                                margin: const EdgeInsets.only(left: 20),
                                decoration: BoxDecoration(
                                  color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.3),
                                ),
                              ),
                            
                            // Item card with season indicator
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: gap, vertical: gap / 2),
                              child: Row(
                                children: [
                                  // Season indicator
                                  Container(
                                    width: 40,
                                    height: 40,
                                    decoration: BoxDecoration(
                                      color: Theme.of(context).colorScheme.primary,
                                      shape: BoxShape.circle,
                                    ),
                                    child: Center(
                                      child: Text(
                                        _getSeasonDisplay(item),
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 12,
                                        ),
                                      ),
                                    ),
                                  ),
                                  
                                  const SizedBox(width: gap),
                                  
                                  // Item card
                                  Expanded(
                                    child: MediaCard(
                                      item: item,
                                      isGrid: false,
                                      onTap: () => Navigator.push(
                                        context,
                                        PageRouteBuilder(
                                          pageBuilder: (_, __, ___) => DetailsScreen(item: item),
                                          transitionsBuilder: (_, animation, __, child) => 
                                              FadeTransition(opacity: animation, child: child),
                                          transitionDuration: const Duration(milliseconds: 250),
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            
                            // Connection line (except for last item)
                            if (!isLast)
                              Container(
                                height: 20,
                                width: 2,
                                margin: const EdgeInsets.only(left: 20),
                                decoration: BoxDecoration(
                                  color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.3),
                                ),
                              ),
                          ],
                        );
                      }),
                    ],
                  ),
                );
              },
            ),
    );
  }

  String _getSeasonDisplay(MediaItem item) {
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
        return match.group(1) ?? '?';
      }
    }
    
    // Fallback to release year
    if (item.releaseYear != null) {
      return item.releaseYear.toString();
    }
    
    return '?';
  }

  void _showInfoDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('About Related Items'),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'This screen shows items that share the same title but have different seasons, parts, or volumes.',
              style: TextStyle(fontSize: 16),
            ),
            SizedBox(height: 16),
            Text(
              'Examples:',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            Text('• "Breaking Bad" Season 1, Season 2, etc.'),
            Text('• "One Piece" Volume 1, Volume 2, etc.'),
            Text('• "Harry Potter" Part 1, Part 2, etc.'),
            SizedBox(height: 16),
            Text(
              'These items are not considered duplicates because they represent different parts of the same series.',
              style: TextStyle(fontStyle: FontStyle.italic),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Got it'),
          ),
        ],
      ),
    );
  }
}
