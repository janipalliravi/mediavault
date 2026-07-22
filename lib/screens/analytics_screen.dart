import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:fl_chart/fl_chart.dart';
import '../providers/media_provider.dart';
import '../models/media_item.dart';

class AnalyticsScreen extends StatefulWidget {
  const AnalyticsScreen({super.key});

  @override
  State<AnalyticsScreen> createState() => _AnalyticsScreenState();
}

class _AnalyticsScreenState extends State<AnalyticsScreen> {
  String _watchedYearFilter = 'All';

  @override
  Widget build(BuildContext context) {
    final mediaProvider = Provider.of<MediaProvider>(context);
    // Get all items without filters for analytics
    final allItems = mediaProvider.itemsForCategory('All');
    
    // Filter by watched year if selected
    List<MediaItem> items = allItems;
    if (_watchedYearFilter != 'All') {
      items = allItems.where((item) => item.watchedYear?.toString() == _watchedYearFilter).toList();
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Analytics'),
        backgroundColor: Theme.of(context).colorScheme.primary,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildYearFilter(allItems),
            const SizedBox(height: 24),
            _buildOverviewCards(items),
            const SizedBox(height: 24),
            _buildTypeDistributionChart(items),
            const SizedBox(height: 24),
            _buildStatusDistributionChart(items),
            const SizedBox(height: 24),
            _buildGenreDistributionChart(items),
            const SizedBox(height: 24),
            _buildMonthlyActivityChart(items),
            const SizedBox(height: 24),
            _buildStreakInfo(items),
          ],
        ),
      ),
    );
  }

  Widget _buildYearFilter(List<MediaItem> allItems) {
    // Extract unique watched years from all items
    final Set<String> watchedYears = allItems
        .map((item) => item.watchedYear?.toString())
        .where((year) => year != null)
        .cast<String>()
        .toSet();
    
    final sortedYears = watchedYears.toList()..sort();
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Filter by Watched Year',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        DropdownButton<String>(
          value: _watchedYearFilter,
          isExpanded: true,
          items: [
            const DropdownMenuItem(value: 'All', child: Text('All Years')),
            ...sortedYears.map((year) => DropdownMenuItem(value: year, child: Text(year))),
          ],
          onChanged: (value) {
            setState(() {
              _watchedYearFilter = value ?? 'All';
            });
          },
        ),
      ],
    );
  }

  Widget _buildOverviewCards(List<MediaItem> items) {
    final totalItems = items.length;
    final doneItems = items.where((i) => i.status == 'Done').length;
    final watchingItems = items.where((i) => i.status == 'Watching').length;
    final favoriteItems = items.where((i) => i.favorite).length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Overview',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: _StatCard(
                label: 'Total',
                value: totalItems.toString(),
                icon: Icons.list,
                color: Colors.blue,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _StatCard(
                label: 'Done',
                value: doneItems.toString(),
                icon: Icons.check_circle,
                color: Colors.green,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _StatCard(
                label: 'Watching',
                value: watchingItems.toString(),
                icon: Icons.play_circle,
                color: Colors.orange,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _StatCard(
                label: 'Favorites',
                value: favoriteItems.toString(),
                icon: Icons.favorite,
                color: Colors.red,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildTypeDistributionChart(List<MediaItem> items) {
    final typeCounts = <String, int>{};
    for (final item in items) {
      typeCounts[item.type] = (typeCounts[item.type] ?? 0) + 1;
    }

    final colors = [Colors.blue, Colors.green, Colors.orange, Colors.purple];
    final typeData = typeCounts.entries.toList();
    final total = typeData.fold(0, (sum, e) => sum + e.value);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Distribution by Type',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 16),
        SizedBox(
          height: 200,
          child: PieChart(
            PieChartData(
              sections: typeData.asMap().entries.map((entry) {
                final index = entry.key;
                final count = entry.value.value;
                final percentage = total > 0 ? (count / total) * 100 : 0;
                return PieChartSectionData(
                  value: count.toDouble(),
                  title: '${percentage.toStringAsFixed(1)}%',
                  color: colors[index % colors.length],
                  radius: 50,
                  titleStyle: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                );
              }).toList(),
              sectionsSpace: 2,
              centerSpaceRadius: 40,
            ),
          ),
        ),
        const SizedBox(height: 16),
        Wrap(
          spacing: 16,
          runSpacing: 8,
          children: typeData.asMap().entries.map((entry) {
            final index = entry.key;
            final type = entry.value.key;
            final count = entry.value.value;
            return Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 12,
                  height: 12,
                  decoration: BoxDecoration(
                    color: colors[index % colors.length],
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 4),
                Text('$type: $count'),
              ],
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildStatusDistributionChart(List<MediaItem> items) {
    final statusCounts = <String, int>{};
    for (final item in items) {
      statusCounts[item.status] = (statusCounts[item.status] ?? 0) + 1;
    }

    final colors = [Colors.green, Colors.orange, Colors.blue, Colors.grey];
    final statusData = statusCounts.entries.toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Distribution by Status',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 16),
        SizedBox(
          height: 200,
          child: BarChart(
            BarChartData(
              alignment: BarChartAlignment.spaceAround,
              maxY: statusData.isEmpty ? 0 : statusData.map((e) => e.value).reduce((a, b) => a > b ? a : b).toDouble() * 1.2,
              barGroups: statusData.asMap().entries.map((entry) {
                final index = entry.key;
                final count = entry.value.value;
                return BarChartGroupData(
                  x: index,
                  barRods: [
                    BarChartRodData(
                      toY: count.toDouble(),
                      color: colors[index % colors.length],
                      width: 20,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ],
                );
              }).toList(),
              titlesData: FlTitlesData(
                show: true,
                bottomTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    getTitlesWidget: (value, meta) {
                      if (value.toInt() >= 0 && value.toInt() < statusData.length) {
                        return Padding(
                          padding: const EdgeInsets.only(top: 8.0),
                          child: Text(
                            statusData[value.toInt()].key,
                            style: const TextStyle(fontSize: 10),
                          ),
                        );
                      }
                      return const Text('');
                    },
                  ),
                ),
                leftTitles: const AxisTitles(
                  sideTitles: SideTitles(showTitles: false),
                ),
                topTitles: const AxisTitles(
                  sideTitles: SideTitles(showTitles: false),
                ),
                rightTitles: const AxisTitles(
                  sideTitles: SideTitles(showTitles: false),
                ),
              ),
              borderData: FlBorderData(show: false),
              gridData: const FlGridData(show: false),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildGenreDistributionChart(List<MediaItem> items) {
    final genreCounts = <String, int>{};
    for (final item in items) {
      final genres = (item.extra?['genres'] as String?)?.split(',').map((g) => g.trim()).where((g) => g.isNotEmpty).toList() ?? [];
      for (final genre in genres) {
        genreCounts[genre] = (genreCounts[genre] ?? 0) + 1;
      }
    }

    final topGenres = genreCounts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final top10Genres = topGenres.take(10).toList();

    if (top10Genres.isEmpty) {
      return const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Top Genres',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          SizedBox(height: 16),
          Text('No genre data available'),
        ],
      );
    }

    final maxValue = top10Genres.first.value.toDouble();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Top Genres',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 16),
        SizedBox(
          height: top10Genres.length * 40.0,
          child: BarChart(
            BarChartData(
              alignment: BarChartAlignment.spaceAround,
              maxY: maxValue * 1.2,
              barGroups: top10Genres.asMap().entries.map((entry) {
                final index = entry.key;
                final count = entry.value.value;
                return BarChartGroupData(
                  x: index,
                  barRods: [
                    BarChartRodData(
                      toY: count.toDouble(),
                      color: Colors.blue,
                      width: 16,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ],
                );
              }).toList(),
              titlesData: FlTitlesData(
                show: true,
                bottomTitles: const AxisTitles(
                  sideTitles: SideTitles(showTitles: false),
                ),
                leftTitles: const AxisTitles(
                  sideTitles: SideTitles(showTitles: false),
                ),
                topTitles: const AxisTitles(
                  sideTitles: SideTitles(showTitles: false),
                ),
                rightTitles: const AxisTitles(
                  sideTitles: SideTitles(showTitles: false),
                ),
              ),
              borderData: FlBorderData(show: false),
              gridData: const FlGridData(show: false),
            ),
          ),
        ),
        const SizedBox(height: 8),
        ...top10Genres.asMap().entries.map((entry) {
          final count = entry.value.value;
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 2.0),
            child: Row(
              children: [
                SizedBox(
                  width: 30,
                  child: Text(
                    '${entry.key + 1}.',
                    style: const TextStyle(fontSize: 12),
                  ),
                ),
                Expanded(
                  child: Text(
                    entry.value.key,
                    style: const TextStyle(fontSize: 12),
                  ),
                ),
                Text(
                  count.toString(),
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                ),
              ],
            ),
          );
        }),
      ],
    );
  }

  Widget _buildMonthlyActivityChart(List<MediaItem> items) {
    final monthlyData = <String, int>{};
    
    for (final item in items) {
      if (item.addedDate != null) {
        final monthKey = '${item.addedDate!.year}-${item.addedDate!.month.toString().padLeft(2, '0')}';
        monthlyData[monthKey] = (monthlyData[monthKey] ?? 0) + 1;
      }
    }

    final sortedMonths = monthlyData.keys.toList()..sort();
    final last6Months = sortedMonths.take(6).toList();

    if (last6Months.isEmpty) {
      return const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Monthly Activity',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          SizedBox(height: 16),
          Text('No activity data available'),
        ],
      );
    }

    final maxValue = last6Months.map((m) => monthlyData[m] ?? 0).reduce((a, b) => a > b ? a : b).toDouble();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Monthly Activity',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 16),
        SizedBox(
          height: 200,
          child: LineChart(
            LineChartData(
              gridData: const FlGridData(show: true),
              titlesData: FlTitlesData(
                show: true,
                bottomTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    getTitlesWidget: (value, meta) {
                      if (value.toInt() >= 0 && value.toInt() < last6Months.length) {
                        final monthStr = last6Months[value.toInt()];
                        final parts = monthStr.split('-');
                        return Padding(
                          padding: const EdgeInsets.only(top: 8.0),
                          child: Text(
                            '${parts[1]}/${parts[0].substring(2)}',
                            style: const TextStyle(fontSize: 10),
                          ),
                        );
                      }
                      return const Text('');
                    },
                  ),
                ),
                leftTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    getTitlesWidget: (value, meta) {
                      if (value == value.toInt() && value > 0) {
                        return Text(
                          value.toInt().toString(),
                          style: const TextStyle(fontSize: 10),
                        );
                      }
                      return const Text('');
                    },
                    reservedSize: 30,
                  ),
                ),
                topTitles: const AxisTitles(
                  sideTitles: SideTitles(showTitles: false),
                ),
                rightTitles: const AxisTitles(
                  sideTitles: SideTitles(showTitles: false),
                ),
              ),
              borderData: FlBorderData(show: true),
              minX: 0,
              maxX: (last6Months.length - 1).toDouble(),
              minY: 0,
              maxY: maxValue * 1.2,
              lineBarsData: [
                LineChartBarData(
                  spots: last6Months.asMap().entries.map((entry) {
                    return FlSpot(
                      entry.key.toDouble(),
                      (monthlyData[entry.value] ?? 0).toDouble(),
                    );
                  }).toList(),
                  isCurved: true,
                  color: Colors.blue,
                  barWidth: 3,
                  dotData: const FlDotData(show: true),
                  belowBarData: BarAreaData(
                    show: true,
                    color: Colors.blue.withValues(alpha: 0.3),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildStreakInfo(List<MediaItem> items) {
    // Calculate streak based on watched dates
    final watchedDates = <DateTime>[];
    for (final item in items) {
      if (item.watchedYear != null) {
        watchedDates.add(DateTime(item.watchedYear!));
      }
      if (item.addedDate != null) {
        watchedDates.add(item.addedDate!);
      }
    }

    watchedDates.sort((a, b) => b.compareTo(a));

    int currentStreak = 0;
    if (watchedDates.isNotEmpty) {
      final today = DateTime.now();
      DateTime? currentDate = today;
      
      for (final date in watchedDates) {
        final dateOnly = DateTime(date.year, date.month, date.day);
        final currentOnly = currentDate != null ? DateTime(currentDate.year, currentDate.month, currentDate.day) : null;
        
        if (currentOnly != null && (dateOnly.isAtSameMomentAs(currentOnly) || 
            dateOnly.isAtSameMomentAs(currentOnly.subtract(const Duration(days: 1))))) {
          currentStreak++;
          currentDate = dateOnly;
        } else {
          break;
        }
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Activity Streak',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.orange.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.orange),
          ),
          child: Row(
            children: [
              const Icon(Icons.local_fire_department, color: Colors.orange, size: 32),
              const SizedBox(width: 16),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Current Streak',
                    style: TextStyle(fontSize: 14, color: Colors.grey),
                  ),
                  Text(
                    '$currentStreak days',
                    style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.orange),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _StatCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;

  const _StatCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(height: 8),
          Text(
            value,
            style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(fontSize: 12, color: Colors.grey[700]),
          ),
        ],
      ),
    );
  }
}
