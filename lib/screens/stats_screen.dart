import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../theme/spacing.dart';
import '../providers/media_provider.dart';
import '../constants/app_constants.dart';

/// StatsScreen shows analytics with filters and a simple sparkline.
class StatsScreen extends StatefulWidget {
  const StatsScreen({super.key});

  @override
  State<StatsScreen> createState() => _StatsScreenState();
}

class _StatsScreenState extends State<StatsScreen> {
  String _type = 'All';
  String _status = 'All';
  String _language = 'All';
  String _rating = 'All';
  bool _favoritesOnly = false;

  @override
  Widget build(BuildContext context) {
    const double gap = ThemeSpacing.gap12;
    final allItems = context.watch<MediaProvider>().items;

    final items = allItems.where((it) {
      final okType = _type == 'All' || it.type == _type;
      final okStatus = _status == 'All' || it.status == _status;
      final okLanguage = _language == 'All' || (it.language ?? '').trim() == _language;
      final okRating = _rating == 'All' || 
          (_rating == 'Rated' && (it.rating ?? 0) > 0) ||
          (_rating == 'Unrated' && (it.rating ?? 0) == 0);
      final okFavorite = !_favoritesOnly || it.favorite;
      return okType && okStatus && okLanguage && okRating && okFavorite;
    }).toList(growable: false);

    Map<String, int> countBy(String Function(dynamic) keyOf) {
      final map = <String, int>{};
      for (final it in items) {
        final k = keyOf(it);
        if (k.isEmpty) continue;
        map[k] = (map[k] ?? 0) + 1;
      }
      final entries = map.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
      return {for (final e in entries) e.key: e.value};
    }

    final total = items.length;
    final byType = countBy((it) => it.type ?? '');
    final byStatus = countBy((it) => it.status ?? '');
    final byLanguage = countBy((it) => (it.language ?? '').trim());
    final rated = items.where((it) => (it.rating ?? 0) > 0).toList();
    final avgRating = rated.isEmpty ? 0.0 : (rated.map((e) => e.rating!).reduce((a, b) => a + b) / rated.length);
    final favorites = items.where((it) => it.favorite).length;

    // Year breakdown
    final byReleaseYear = countBy((it) => (it.releaseYear?.toString() ?? 'Unknown'));
    final byWatchedYear = countBy((it) => (it.watchedYear?.toString() ?? 'Not watched'));

    // Monthly breakdown (by added date)
    final byMonth = <String, int>{};
    for (final it in items) {
      if (it.addedDate != null) {
        final monthKey = '${it.addedDate!.year}-${it.addedDate!.month.toString().padLeft(2, '0')}';
        byMonth[monthKey] = (byMonth[monthKey] ?? 0) + 1;
      }
    }
    final sortedMonths = byMonth.entries.toList()..sort((a, b) => a.key.compareTo(b.key));

    // Rating distribution
    final ratingDistribution = <String, int>{};
    for (final it in items) {
      final rating = (it.rating ?? 0).toInt();
      final ratingKey = rating > 0 ? '$rating stars' : 'Unrated';
      ratingDistribution[ratingKey] = (ratingDistribution[ratingKey] ?? 0) + 1;
    }

    // Prepare sparkline data: ratings over time by addedDate
    final sorted = [...items]..sort((a, b) => (a.addedDate ?? DateTime(2000)).compareTo(b.addedDate ?? DateTime(2000)));
    final sparkValues = sorted.map((e) => (e.rating ?? 0).toDouble()).toList(growable: false);

    Widget section(String title, Map<String, int> data, {int? take}) {
      final entries = data.entries.toList();
      if (take != null && entries.length > take) entries.removeRange(take, entries.length);
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(gap),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: gap),
              ...entries.map((e) => Row(
                    children: [
                      Expanded(child: Text(e.key.isEmpty ? 'Unknown' : e.key)),
                      Text('${e.value}')
                    ],
                  )),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Analytics & Insights')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Wrap(
            spacing: gap,
            runSpacing: gap / 2,
            children: [
              DropdownButton<String>(
                value: _type,
                items: ['All', ...AppConstants.categories]
                    .map((t) => DropdownMenuItem<String>(value: t, child: Text(t)))
                    .toList(),
                onChanged: (v) => setState(() => _type = v ?? 'All'),
              ),
              DropdownButton<String>(
                value: _status,
                items: const ['All', 'Watching', 'Done', 'Watch list']
                    .map((s) => DropdownMenuItem<String>(value: s, child: Text(s)))
                    .toList(),
                onChanged: (v) => setState(() => _status = v ?? 'All'),
              ),
              DropdownButton<String>(
                value: _language,
                items: ['All', ...allItems.map((e) => (e.language ?? '').trim()).where((e) => e.isNotEmpty).toSet().toList()..sort()]
                    .map((l) => DropdownMenuItem<String>(value: l, child: Text(l)))
                    .toList(),
                onChanged: (v) => setState(() => _language = v ?? 'All'),
              ),
              DropdownButton<String>(
                value: _rating,
                items: const ['All', 'Rated', 'Unrated']
                    .map((r) => DropdownMenuItem<String>(value: r, child: Text(r)))
                    .toList(),
                onChanged: (v) => setState(() => _rating = v ?? 'All'),
              ),
              FilterChip(
                label: const Text('Favorites only'),
                selected: _favoritesOnly,
                onSelected: (v) => setState(() => _favoritesOnly = v),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(gap),
              child: Row(
                children: [
                  Expanded(child: Text('Total items', style: Theme.of(context).textTheme.titleMedium)),
                  Text('$total')
                ],
              ),
            ),
          ),
          Row(
            children: [
              Expanded(
                child: Card(
                  child: Padding(
                    padding: const EdgeInsets.all(gap),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Favorites'),
                        const SizedBox(height: gap / 2),
                        Text('$favorites'),
                      ],
                    ),
                  ),
                ),
              ),
              Expanded(
                child: Card(
                  child: Padding(
                    padding: const EdgeInsets.all(gap),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Avg. rating'),
                        const SizedBox(height: gap / 2),
                        Text(rated.isEmpty ? '—' : avgRating.toStringAsFixed(2)),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(gap),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(child: Text('Ratings over time', style: Theme.of(context).textTheme.titleMedium)),
                      Text('${sparkValues.where((v) => v > 0).length} rated')
                    ],
                  ),
                  const SizedBox(height: gap),
                  SizedBox(height: 60, child: _Sparkline(values: sparkValues)),
                ],
              ),
            ),
          ),
          section('By Type', byType),
          section('By Status', byStatus),
          section('By Release Year', byReleaseYear),
          section('By Watched Year', byWatchedYear),
          section('Rating Distribution', ratingDistribution),
          section('Top Languages', byLanguage, take: 10),
          if (sortedMonths.isNotEmpty)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(gap),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Items Added by Month', style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(height: gap),
                    SizedBox(
                      height: 100,
                      child: ListView.builder(
                        scrollDirection: Axis.horizontal,
                        itemCount: sortedMonths.length,
                        itemBuilder: (context, index) {
                          final entry = sortedMonths[index];
                          return Container(
                            width: 60,
                            margin: const EdgeInsets.only(right: 8),
                            child: Column(
                              children: [
                                Text(entry.key, style: const TextStyle(fontSize: 10)),
                                const SizedBox(height: 4),
                                Container(
                                  height: 50,
                                  width: 20,
                                  alignment: Alignment.bottomCenter,
                                  decoration: BoxDecoration(
                                    color: Theme.of(context).colorScheme.primary,
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Container(
                                    height: (entry.value / sortedMonths.map((e) => e.value).reduce((a, b) => a > b ? a : b)) * 50,
                                    color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.7),
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text('${entry.value}', style: const TextStyle(fontSize: 10)),
                              ],
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _Sparkline extends StatelessWidget {
  final List<double> values;
  const _Sparkline({required this.values});

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _SparklinePainter(values: values, color: Theme.of(context).colorScheme.primary),
      child: const SizedBox.expand(),
    );
  }
}

class _SparklinePainter extends CustomPainter {
  final List<double> values;
  final Color color;
  _SparklinePainter({required this.values, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    if (values.isEmpty) return;
    final nonZero = values.where((v) => v > 0).toList();
    final data = nonZero.isEmpty ? [0.0] : nonZero;
    final minV = 0.0;
    final maxV = data.reduce((a, b) => a > b ? a : b);
    final double pad = 2.0;
    final double w = size.width - pad * 2;
    final double h = size.height - pad * 2;
    if (data.length == 1) {
      final y = h - (data.first - minV) / ((maxV - minV).clamp(1e-6, 9999)) * h;
      final p = Paint()
        ..color = color
        ..strokeWidth = 2
        ..style = PaintingStyle.stroke;
      canvas.drawLine(Offset(pad, y + pad), Offset(size.width - pad, y + pad), p);
      return;
    }
    final dx = w / (data.length - 1);
    final path = Path();
    for (int i = 0; i < data.length; i++) {
      final x = pad + dx * i;
      final y = pad + (h - (data[i] - minV) / ((maxV - minV).clamp(1e-6, 9999)) * h);
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }
    final paintLine = Paint()
      ..color = color
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;
    canvas.drawPath(path, paintLine);
  }

  @override
  bool shouldRepaint(covariant _SparklinePainter oldDelegate) {
    return oldDelegate.values != values || oldDelegate.color != color;
  }
}


