// lib/screens/home_screen.dart

import 'package:flutter/material.dart';
import 'dart:async';
import 'dart:math';
import 'package:provider/provider.dart';
import '../providers/media_provider.dart';
import '../models/media_item.dart';
import '../widgets/stats_card.dart';
import '../constants/app_constants.dart';
import '../widgets/search_filter.dart';
import '../widgets/media_card.dart';
import 'add_edit_screen.dart';
import 'details_screen.dart';
import '../theme/spacing.dart';
import '../providers/settings_provider.dart';
import '../env.dart';
// AutomaticKeepAliveClientMixin is already available via material.dart imports

/// HomeScreen renders tabs, search/filters, optional stats, and the list/grid.
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  late TabController _tabController;
  Timer? _shuffleTimer;
  int _shuffleTick = 0;
  bool _dataReady = false;
  bool _shuffleEnabled = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _tabController = TabController(length: 5, vsync: this);
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!AppEnv.testMode) {
        await Future.delayed(const Duration(milliseconds: 50));
      }
      if (!mounted) return;
      final mp = Provider.of<MediaProvider>(context, listen: false);
      final sp = context.read<SettingsProvider>();
      final defaultGrid = sp.defaultGridView;
      _shuffleEnabled = sp.shuffleCardsEnabled;
      if (!AppEnv.testMode) {
        await mp.warmStart();
      }
      if (!mounted) return;
      if (mp.isGridView != defaultGrid) {
        mp.toggleView();
      }
      setState(() => _dataReady = true);
      _maybeStartShuffle();
    });
  }

  @override
  void dispose() {
    _shuffleTimer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    _tabController.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _maybeStartShuffle();
    } else if (state == AppLifecycleState.paused || state == AppLifecycleState.inactive || state == AppLifecycleState.hidden) {
      // Pause to save battery
      _shuffleTimer?.cancel();
      _shuffleTimer = null;
    }
  }

  void _maybeStartShuffle({bool? enabled}) {
    _shuffleTimer?.cancel();
    if (!mounted) return;
    final shuffleOn = enabled ?? context.read<SettingsProvider>().shuffleCardsEnabled;
    _shuffleEnabled = shuffleOn;
    if (shuffleOn && _dataReady) {
      _shuffleTimer = Timer.periodic(const Duration(seconds: 20), (_) {
        if (!mounted) return;
        setState(() => _shuffleTick++);
      });
    }
  }

  // _getCategoryFromTab no longer used (TabBarView provides explicit mapping)

  Widget _buildBodyFor(String selectedCategory) {
    return Selector2<MediaProvider, SettingsProvider, _HomeTabData>(
      selector: (_, mp, sp) => _HomeTabData(
        category: selectedCategory,
        items: mp.itemsForCategory(selectedCategory),
        isGridView: mp.isGridView,
        showStats: sp.showStats,
        shuffleOn: sp.shuffleCardsEnabled,
        shuffleTick: _shuffleTick,
        isLoading: mp.isLoading,
        hasSearch: mp.hasActiveSearch,
        searchQuery: mp.searchQuery,
        statusFilter: mp.statusFilter,
        languageFilter: mp.languageFilter,
      ),
      shouldRebuild: (prev, next) => prev != next,
      builder: (context, data, _) {
        return _buildBodyContent(data);
      },
    );
  }

  Widget _buildBodyContent(_HomeTabData data) {
    final mediaProvider = Provider.of<MediaProvider>(context, listen: false);
    const double gap = ThemeSpacing.gap12;
    const double headerHeight = 160;

    final List<MediaItem> filteredItems;
    if (data.shuffleOn) {
      filteredItems = List.of(data.items)..shuffle(Random(data.shuffleTick + data.category.hashCode));
    } else {
      filteredItems = List.of(data.items)
        ..sort((a, b) => a.title.toLowerCase().compareTo(b.title.toLowerCase()));
    }

    const int maxItemsToShow = 100;
    final List<MediaItem> displayItems = filteredItems.length > maxItemsToShow
        ? filteredItems.take(maxItemsToShow).toList()
        : filteredItems;

    final Map<String, int> localStats = {
      'Total Items': filteredItems.length,
      'Done': filteredItems.where((it) => it.status == 'Done').length,
      'Watching': filteredItems.where((it) => it.status == 'Watching').length,
      'Watch list': filteredItems.where((it) => it.status == 'Watch list').length,
    };

    void openAddEdit([bool fromEmptyState = false]) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => const AddEditScreen(),
          fullscreenDialog: true,
        ),
      ).then((result) {
        mediaProvider.loadItems();
        if (result is Map && result['type'] is String) {
          final type = result['type'] as String;
          final tabIndex = AppConstants.categories.indexOf(type) + 1;
          if (tabIndex >= 0 && tabIndex < _tabController.length) {
            _tabController.animateTo(tabIndex);
          }
        }
        setState(() {});
      });
    }

    if (!_dataReady || data.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    return CustomScrollView(
      cacheExtent: 600,
      physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
      slivers: [
        const SliverToBoxAdapter(child: SizedBox(height: gap)),
        SliverPersistentHeader(
          pinned: true,
          delegate: _PinnedHeaderDelegate(
            child: const SearchFilter(),
            minExtentHeight: headerHeight,
            maxExtentHeight: headerHeight,
          ),
        ),
        const SliverToBoxAdapter(child: SizedBox(height: gap)),
        if (data.showStats)
          SliverPadding(
            padding: const EdgeInsets.symmetric(vertical: gap, horizontal: 16.0),
            sliver: SliverGrid(
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                childAspectRatio: 2.6,
                crossAxisSpacing: gap,
                mainAxisSpacing: gap,
              ),
              delegate: SliverChildListDelegate([
                StatsCard(label: 'Total Items', count: localStats['Total Items']!, icon: Icons.list, color: Colors.blue),
                StatsCard(label: 'Done', count: localStats['Done']!, icon: Icons.check_circle, color: Colors.green),
                StatsCard(label: 'Watching', count: localStats['Watching']!, icon: Icons.play_circle, color: Colors.orange),
                StatsCard(label: 'Watch list', count: localStats['Watch list']!, icon: Icons.bookmark, color: Colors.blue),
              ]),
            ),
          ),
        if (data.showStats) const SliverToBoxAdapter(child: SizedBox(height: gap)),
        if (filteredItems.isEmpty)
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      data.hasSearch ? Icons.search_off : Icons.tv_off,
                      size: 100,
                      color: const Color(0xFF90CAF9),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      data.hasSearch ? 'No matches found' : 'No items here yet!',
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      data.hasSearch
                          ? 'Clear search or change filters to see your catalog.'
                          : 'Tap below to add your first item.',
                      style: const TextStyle(fontSize: 14, color: Colors.black54),
                      textAlign: TextAlign.center,
                    ),
                    if (data.hasSearch) ...[
                      const SizedBox(height: 12),
                      TextButton.icon(
                        onPressed: () => mediaProvider.clearSearch(),
                        icon: const Icon(Icons.clear),
                        label: const Text('Clear search'),
                      ),
                    ],
                    if (!data.hasSearch) ...[
                      const SizedBox(height: 20),
                      ElevatedButton.icon(
                        icon: const Icon(Icons.add),
                        label: const Text('Add Item'),
                        onPressed: () => openAddEdit(true),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          )
        else if (data.isGridView)
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: gap),
            sliver: SliverGrid(
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                childAspectRatio: 0.8,
                crossAxisSpacing: gap,
                mainAxisSpacing: gap,
              ),
              delegate: SliverChildBuilderDelegate(
                (context, index) {
                  return RepaintBoundary(
                    child: MediaCard(
                      item: displayItems[index],
                    onLongPress: () async {
                      final scaffoldMessenger = ScaffoldMessenger.of(context);
                      final confirm = await showDialog<bool>(
                        context: context,
                        builder: (ctx) => AlertDialog(
                          title: const Text('Delete Item'),
                          content: const Text('Are you sure you want to delete this item?'),
                          actions: [
                            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
                            TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Delete')),
                          ],
                        ),
                      );
                      if (confirm == true) {
                        await mediaProvider.deleteItem(filteredItems[index].id!);
                        scaffoldMessenger.showSnackBar(const SnackBar(content: Text('Item deleted')));
                      }
                    },
                    onTap: () => Navigator.push(
                      context,
                      PageRouteBuilder(
                        pageBuilder: (_, __, ___) => DetailsScreen(item: filteredItems[index]),
                        transitionsBuilder: (_, animation, __, child) => FadeTransition(opacity: animation, child: child),
                        transitionDuration: const Duration(milliseconds: 250),
                      ),
                    ),
                  ),
                );
                },
                childCount: displayItems.length,
              ),
            ),
          )
        else
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: gap),
            sliver: SliverList.builder(
              itemCount: displayItems.length,
              itemBuilder: (context, index) {
                return RepaintBoundary(
                  child: MediaCard(
                    item: displayItems[index],
                    isGrid: false,
                  onLongPress: () async {
                    final scaffoldMessenger = ScaffoldMessenger.of(context);
                    final confirm = await showDialog<bool>(
                      context: context,
                      builder: (ctx) => AlertDialog(
                        title: const Text('Delete Item'),
                        content: const Text('Are you sure you want to delete this item?'),
                        actions: [
                          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
                          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Delete')),
                        ],
                      ),
                    );
                    if (confirm == true) {
                      await mediaProvider.deleteItem(filteredItems[index].id!);
                      scaffoldMessenger.showSnackBar(const SnackBar(content: Text('Item deleted')));
                    }
                  },
                  onTap: () => Navigator.push(
                    context,
                    PageRouteBuilder(
                      pageBuilder: (_, __, ___) => DetailsScreen(item: filteredItems[index]),
                      transitionsBuilder: (_, animation, __, child) => FadeTransition(opacity: animation, child: child),
                      transitionDuration: const Duration(milliseconds: 250),
                    ),
                  ),
                ),
              );
            },
            ),
          ),
        // Show indicator if more items are available
        if (filteredItems.length > maxItemsToShow)
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Center(
                child: Text(
                  'Showing ${displayItems.length} of ${filteredItems.length} items',
                  style: TextStyle(
                    color: Colors.grey[600],
                    fontSize: 12,
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final shuffleOn = context.select<SettingsProvider, bool>((s) => s.shuffleCardsEnabled);
    if (shuffleOn != _shuffleEnabled && _dataReady) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _maybeStartShuffle(enabled: shuffleOn);
      });
    }

    final isLoading = context.select<MediaProvider, bool>((mp) => mp.isLoading);
    final tabsEnabled = _dataReady && !isLoading;

    return Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color(0xFFE3F2FD), Color(0xFFBBDEFB)],
            ),
          ),
          child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          automaticallyImplyLeading: false,
          title: SizedBox(
            height: 40,
            child: Image.asset(
              'assets/images/mediavault_logo.png',
              fit: BoxFit.contain,
              errorBuilder: (_, __, ___) => const SizedBox(height: 40, width: 40),
            ),
          ),
          backgroundColor: Theme.of(context).colorScheme.primary,
          actions: [
            Consumer<MediaProvider>(builder: (context, mp, _) {
              if (mp.selectionMode) {
                return Row(children: [
                  IconButton(
                    tooltip: 'Select all',
                    icon: const Icon(Icons.select_all),
                    onPressed: mp.selectAllCurrent,
                  ),
                  IconButton(
                    tooltip: 'Favorite selected',
                    icon: const Icon(Icons.favorite),
                    onPressed: () => mp.bulkFavoriteSelected(true),
                  ),
                  IconButton(
                    tooltip: 'Unfavorite selected',
                    icon: const Icon(Icons.favorite_border),
                    onPressed: () => mp.bulkFavoriteSelected(false),
                  ),
                  IconButton(
                    tooltip: 'Delete selected',
                    icon: const Icon(Icons.delete),
                    onPressed: mp.bulkDeleteSelected,
                  ),
                  IconButton(
                    tooltip: 'Exit selection',
                    icon: const Icon(Icons.close),
                    onPressed: mp.clearSelection,
                  ),
                ]);
              }
              return Row(children: [
                IconButton(
                  tooltip: 'Multi-select',
                  icon: const Icon(Icons.checklist),
                  onPressed: () => mp.toggleSelectionMode(true),
                ),
                                 IconButton(
                   tooltip: 'Find duplicates',
                   icon: const Icon(Icons.copy_all),
                   onPressed: () => Navigator.of(context).pushNamed('/duplicates'),
                 ),

                IconButton(
                  icon: const Icon(Icons.settings),
                  onPressed: () => Navigator.of(context).pushNamed('/settings'),
                  tooltip: 'Settings',
                )
              ]);
            })
          ],
          bottom: PreferredSize(
            preferredSize: const Size.fromHeight(48),
            child: IgnorePointer(
              ignoring: !tabsEnabled,
              child: TabBar(
                controller: _tabController,
                isScrollable: true,
                tabAlignment: TabAlignment.start,
                labelPadding: const EdgeInsets.symmetric(horizontal: ThemeSpacing.gap12),
                labelStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                labelColor: Theme.of(context).colorScheme.onPrimary,
                unselectedLabelColor: Theme.of(context).colorScheme.onPrimary.withValues(alpha: 0.7),
                indicatorColor: Theme.of(context).colorScheme.onPrimary,
                indicatorWeight: 3,
                tabs: const [
                  Tab(text: 'All'),
                  Tab(text: 'Movies'),
                  Tab(text: 'Anime'),
                  Tab(text: 'K-Drama'),
                  Tab(text: 'Series'),
                ],
              ),
            ),
          ),
        ),
        body: !_dataReady
            ? const Center(child: CircularProgressIndicator())
            : IgnorePointer(
                ignoring: !tabsEnabled,
                child: TabBarView(
                  controller: _tabController,
                  physics: tabsEnabled
                      ? const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics())
                      : const NeverScrollableScrollPhysics(),
                  children: [
                    _KeepAlive(child: _buildBodyFor('All')),
                    _KeepAlive(child: _buildBodyFor('Movies')),
                    _KeepAlive(child: _buildBodyFor('Anime')),
                    _KeepAlive(child: _buildBodyFor('K-Drama')),
                    _KeepAlive(child: _buildBodyFor('Series')),
                  ],
                ),
              ),
        floatingActionButton: FloatingActionButton(
           onPressed: () {
             Navigator.push(
               context,
               MaterialPageRoute(
                 builder: (_) => const AddEditScreen(),
                 fullscreenDialog: true,
               ),
             ).then((_) => setState(() {}));
           },
           backgroundColor: Theme.of(context).colorScheme.primary,
           child: const Icon(Icons.add, color: Colors.white),
         ),
       ),
     );
  }
}

class _HomeTabData {
  final String category;
  final List<MediaItem> items;
  final bool isGridView;
  final bool showStats;
  final bool shuffleOn;
  final int shuffleTick;
  final bool isLoading;
  final bool hasSearch;
  final String searchQuery;
  final String statusFilter;
  final String languageFilter;

  const _HomeTabData({
    required this.category,
    required this.items,
    required this.isGridView,
    required this.showStats,
    required this.shuffleOn,
    required this.shuffleTick,
    required this.isLoading,
    required this.hasSearch,
    required this.searchQuery,
    required this.statusFilter,
    required this.languageFilter,
  });

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is _HomeTabData &&
        other.category == category &&
        other.isGridView == isGridView &&
        other.showStats == showStats &&
        other.shuffleOn == shuffleOn &&
        other.shuffleTick == shuffleTick &&
        other.isLoading == isLoading &&
        other.hasSearch == hasSearch &&
        other.searchQuery == searchQuery &&
        other.statusFilter == statusFilter &&
        other.languageFilter == languageFilter &&
        other.items.length == items.length;
  }

  @override
  int get hashCode => Object.hash(
        category,
        items.length,
        isGridView,
        showStats,
        shuffleOn,
        shuffleTick,
        isLoading,
        hasSearch,
        searchQuery,
        statusFilter,
        languageFilter,
      );
}

class _PinnedHeaderDelegate extends SliverPersistentHeaderDelegate {
  final Widget child;
  final double minExtentHeight;
  final double maxExtentHeight;

  _PinnedHeaderDelegate({required this.child, required this.minExtentHeight, required this.maxExtentHeight});

  @override
  double get minExtent => minExtentHeight;

  @override
  double get maxExtent => maxExtentHeight.clamp(minExtentHeight, maxExtentHeight);

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) {
    final double h = maxExtent;
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFFE3F2FD), Color(0xFFBBDEFB)],
        ),
      ),
      child: Material(
        elevation: overlapsContent ? 2 : 0,
        color: Colors.transparent,
        child: SizedBox(height: h, width: double.infinity, child: child),
      ),
    );
  }

  @override
  bool shouldRebuild(covariant _PinnedHeaderDelegate oldDelegate) {
    return oldDelegate.child != child ||
        oldDelegate.minExtentHeight != minExtentHeight ||
        oldDelegate.maxExtentHeight != maxExtentHeight;
  }
}

class _KeepAlive extends StatefulWidget {
  final Widget child;
  const _KeepAlive({required this.child});
  @override
  State<_KeepAlive> createState() => _KeepAliveState();
}

class _KeepAliveState extends State<_KeepAlive>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return widget.child;
  }
}