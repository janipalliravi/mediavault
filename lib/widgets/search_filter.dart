import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/media_provider.dart';
import '../providers/settings_provider.dart';
import '../theme/spacing.dart';

/// SearchFilter includes the search field, history chips, and two dropdown filters.
class SearchFilter extends StatelessWidget {
  const SearchFilter({super.key});

  @override
  Widget build(BuildContext context) {
    final mediaProvider = Provider.of<MediaProvider>(context);
    const double gap = ThemeSpacing.gap12;

    final languages = [
      'All',
      ...mediaProvider.items
          .map((e) => (e.language ?? '').trim())
          .where((e) => e.isNotEmpty)
          .toSet()
          .toList()
        ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase())),
    ];

    // Tags and web series quick filters removed per request

    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 16.0, vertical: gap / 2),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            style: const TextStyle(fontSize: 14),
            decoration: InputDecoration(
              hintText: 'Search your catalog...',
              prefixIcon: Icon(Icons.search, color: Theme.of(context).colorScheme.primary),
              contentPadding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
              filled: true,
            ),
            onChanged: (q) {
              mediaProvider.setSearchQuery(q);
            },
            onSubmitted: (q) async {
              try {
                await Provider.of<SettingsProvider>(context, listen: false).addRecentSearch(q);
              } catch (_) {}
            },
          ),
          if (Provider.of<SettingsProvider>(context).recentSearches.isNotEmpty ||
              Provider.of<SettingsProvider>(context).savedSearches.isNotEmpty) ...[
            SizedBox(height: gap / 2),
            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 40),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    ...Provider.of<SettingsProvider>(context).recentSearches.map((q) => Padding(
                          padding: EdgeInsets.only(right: gap / 2),
                          child: InputChip(
                            label: Text(q, overflow: TextOverflow.ellipsis, maxLines: 1, softWrap: false),
                            avatar: const Icon(Icons.history, size: 18),
                            onPressed: () => mediaProvider.setSearchQuery(q),
                            onDeleted: () => Provider.of<SettingsProvider>(context, listen: false).removeRecentSearch(q),
                          ),
                        )),
                    ...Provider.of<SettingsProvider>(context).savedSearches.map((q) => Padding(
                          padding: EdgeInsets.only(right: gap / 2),
                          child: InputChip(
                            label: Text(q, overflow: TextOverflow.ellipsis, maxLines: 1, softWrap: false),
                            avatar: const Icon(Icons.bookmark, size: 18),
                            onPressed: () => mediaProvider.setSearchQuery(q),
                            onDeleted: () => Provider.of<SettingsProvider>(context, listen: false).removeSavedSearch(q),
                          ),
                        )),
                    if (Provider.of<SettingsProvider>(context).recentSearches.isNotEmpty)
                      Padding(
                        padding: EdgeInsets.only(right: gap / 2),
                        child: TextButton.icon(
                          onPressed: () => Provider.of<SettingsProvider>(context, listen: false).clearRecentSearches(),
                          icon: const Icon(Icons.clear),
                          label: const Text('Clear recent'),
                        ),
                      ),
                    if (Provider.of<SettingsProvider>(context).savedSearches.isNotEmpty)
                      Padding(
                        padding: EdgeInsets.only(right: gap / 2),
                        child: TextButton.icon(
                          onPressed: () => Provider.of<SettingsProvider>(context, listen: false).clearSavedSearches(),
                          icon: const Icon(Icons.clear_all),
                          label: const Text('Clear saved'),
                        ),
                      ),
                    if (Provider.of<SettingsProvider>(context).recentSearches.isNotEmpty ||
                        Provider.of<SettingsProvider>(context).savedSearches.isNotEmpty)
                      Padding(
                        padding: EdgeInsets.only(right: gap / 2),
                        child: TextButton.icon(
                          onPressed: () => Provider.of<SettingsProvider>(context, listen: false).clearAllSearchHistory(),
                          icon: const Icon(Icons.delete_forever),
                          label: const Text('Clear all'),
                        ),
                      ),
                    if (mediaProvider.searchQuery.trim().isNotEmpty)
                      TextButton.icon(
                        onPressed: () => Provider.of<SettingsProvider>(context, listen: false)
                            .saveCurrentSearch(mediaProvider.searchQuery),
                        icon: const Icon(Icons.bookmark_add_outlined),
                        label: const Text('Save search'),
                      ),
                  ],
                ),
              ),
            ),
          ],
          SizedBox(height: gap),
          Row(
            children: [
              Expanded(
                child: DropdownButtonFormField<String>(
                  value: mediaProvider.statusFilter,
                  isDense: true,
                  isExpanded: true,
                  style: TextStyle(
                    fontSize: 14,
                    color: Theme.of(context).brightness == Brightness.dark ? Colors.white : Colors.black87,
                  ),
                  decoration: InputDecoration(
                    labelText: 'Status',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                    filled: true,
                    contentPadding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
                  ),
                  items: (['All', 'Unwatched', 'Done', 'Watch list', 'Watching']
                        ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase())))
                      .map((status) => DropdownMenuItem(
                        value: status, 
                        child: Text(
                          status, 
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: Theme.of(context).brightness == Brightness.dark ? Colors.white : Colors.black87,
                          ),
                        )
                      ))
                      .toList(),
                  onChanged: (value) => mediaProvider.setStatusFilter(value!),
                ),
              ),
              const SizedBox(width: ThemeSpacing.gap12),
              Expanded(
                child: DropdownButtonFormField<String>(
                  value: mediaProvider.languageFilter,
                  isDense: true,
                  isExpanded: true,
                  style: TextStyle(
                    fontSize: 14,
                    color: Theme.of(context).brightness == Brightness.dark ? Colors.white : Colors.black87,
                  ),
                  decoration: InputDecoration(
                    labelText: 'Language',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                    filled: true,
                    contentPadding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
                  ),
                  items: languages.map((l) => DropdownMenuItem(
                    value: l, 
                    child: Text(
                      l, 
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: Theme.of(context).brightness == Brightness.dark ? Colors.white : Colors.black87,
                      ),
                    )
                  )).toList(),
                  onChanged: (value) => mediaProvider.setLanguageFilter(value!),
                ),
              ),
              const SizedBox(width: ThemeSpacing.gap12),
              SizedBox(
                width: 44,
                height: 44,
                child: IconButton(
                  style: IconButton.styleFrom(
                    side: BorderSide(color: Theme.of(context).colorScheme.primary),
                  ),
                  onPressed: mediaProvider.toggleView,
                  icon: Icon(
                    mediaProvider.isGridView ? Icons.grid_view : Icons.list,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  tooltip: 'Toggle view',
                ),
              ),
            ],
          ),
          SizedBox(height: gap),
          // Removed tag chips and web series kind quick filters
        ],
      ),
    );
  }
}