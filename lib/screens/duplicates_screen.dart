import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/media_provider.dart';
import '../models/media_item.dart';
import '../theme/spacing.dart';

/// DuplicatesScreen shows potential duplicate groups and allows merge/delete actions.
class DuplicatesScreen extends StatelessWidget {
  const DuplicatesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final mp = context.watch<MediaProvider>();
    const double gap = ThemeSpacing.gap12;
    final groups = mp.findDuplicateGroups();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Duplicate Items'),
      ),
      body: groups.isEmpty
          ? const Center(child: Text('No duplicates found'))
          : ListView.separated(
              padding: const EdgeInsets.all(gap),
              itemCount: groups.length,
              separatorBuilder: (_, __) => const SizedBox(height: gap),
              itemBuilder: (context, index) {
                final List<MediaItem> group = groups[index];
                final newest = group.first;
                return Card(
                  child: Padding(
                    padding: const EdgeInsets.all(gap),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${newest.title} (${newest.releaseYear ?? 'N/A'}) — ${newest.type}',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const SizedBox(height: gap),
                        ...group.map((it) => Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    '#${it.id ?? '-'} | ${it.status}${it.language != null ? ' | ${it.language}' : ''}',
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                if (it.id != newest.id)
                                  TextButton(
                                    onPressed: () async {
                                      try {
                                        if (it.id != null) await mp.deleteItem(it.id!);
                                        if (!context.mounted) return;
                                        ScaffoldMessenger.of(context)
                                            .showSnackBar(const SnackBar(content: Text('Duplicate deleted')));
                                      } catch (_) {}
                                    },
                                    child: const Text('Delete'),
                                  ),
                              ],
                            )),
                        const SizedBox(height: gap),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            FilledButton.tonalIcon(
                              onPressed: () async {
                                try {
                                  await mp.mergeDuplicateGroup(group);
                                  if (context.mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Merged group into newest')));
                                  }
                                } catch (_) {}
                              },
                              icon: const Icon(Icons.merge_type),
                              label: const Text('Merge group'),
                            ),
                            const SizedBox(width: gap),
                            FilledButton.icon(
                              onPressed: () async {
                                try {
                                  await mp.deleteDuplicatesKeepFirst(group);
                                  if (context.mounted) {
                                    ScaffoldMessenger.of(context)
                                        .showSnackBar(const SnackBar(content: Text('Kept newest, deleted others')));
                                  }
                                } catch (_) {}
                              },
                              icon: const Icon(Icons.cleaning_services),
                              label: const Text('Keep newest, delete rest'),
                            ),
                          ],
                        )
                      ],
                    ),
                  ),
                );
              },
            ),
      bottomNavigationBar: groups.isEmpty
          ? null
          : SafeArea(
              child: Padding(
                padding: EdgeInsets.fromLTRB(16, gap / 2, 16, 16),
                child: FilledButton.icon(
                  onPressed: () async {
                    try {
                      await mp.mergeAllDuplicateGroups();
                      if (context.mounted) {
                        ScaffoldMessenger.of(context)
                            .showSnackBar(const SnackBar(content: Text('Merged all duplicate groups')));
                      }
                    } catch (_) {}
                  },
                  icon: const Icon(Icons.all_inclusive),
                  label: const Text('Merge all duplicates'),
                ),
              ),
            ),
    );
  }
}


