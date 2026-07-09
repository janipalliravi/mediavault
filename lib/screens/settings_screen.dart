import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:file_picker/file_picker.dart';
import 'package:provider/provider.dart';
import '../providers/media_provider.dart';
import '../providers/settings_provider.dart';
import '../services/database_service.dart';
import '../services/backup_service.dart';
import '../services/android_permissions.dart';
import '../theme/spacing.dart';
import '../constants/features.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  String _name = '';
  String? _photoPath;
  PackageInfo? _pkgInfo;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final info = await PackageInfo.fromPlatform();
    if (!mounted) return;
    final sp = Provider.of<SettingsProvider>(context, listen: false);
    final name = sp.name;
    final photo = sp.photoPath;
    setState(() {
      _name = name;
      _photoPath = photo;
      _pkgInfo = info;
    });
  }

  Future<void> _save() async {
    final sp = Provider.of<SettingsProvider>(context, listen: false);
    await sp.setName(_name);
    await sp.setPhotoPath(_photoPath);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Settings saved')));
  }

  Widget _section(BuildContext context, String title, List<Widget> children) {
    const gap = ThemeSpacing.gap12;
    return Padding(
      padding: EdgeInsets.only(bottom: gap),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: EdgeInsets.only(left: 4, bottom: gap / 2),
            child: Text(
              title,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
            ),
          ),
          Card(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(ThemeSpacing.radius12)),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (int idx = 0; idx < children.length; idx++) ...[
                    if (idx != 0) const Divider(height: 24),
                    children[idx],
                  ]
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
        actions: [
          IconButton(
            tooltip: 'Reset to defaults',
            icon: const Icon(Icons.restore),
            onPressed: () async {
              final ok = await showDialog<bool>(
                context: context,
                builder: (ctx) => AlertDialog(
                  title: const Text('Reset Settings'),
                  content: const Text('This will reset appearance and layout to defaults.'),
                  actions: [
                    TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
                    FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Reset')),
                  ],
                ),
              );
              if (ok == true && context.mounted) {
                await context.read<SettingsProvider>().resetToDefaults();
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Settings reset')));
                }
              }
            },
          )
        ],
      ),
      body: Consumer<SettingsProvider>(builder: (context, sp, _) {
        const gap = ThemeSpacing.gap12;
        final variants = const ['Light', 'Dark', 'AMOLED'];
        return ListView(
          padding: const EdgeInsets.all(ThemeSpacing.gap16),
          children: [
            // Profile
            Card(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(ThemeSpacing.radius12)),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Stack(
                      children: [
                        CircleAvatar(
                          radius: 30,
                          backgroundImage: _photoPath != null && _photoPath!.isNotEmpty
                              ? (_photoPath!.startsWith('http') ? NetworkImage(_photoPath!) : FileImage(File(_photoPath!))) as ImageProvider
                              : null,
                          child: (_photoPath == null || _photoPath!.isEmpty)
                              ? const Icon(Icons.person, size: 30)
                              : null,
                        ),
                        Positioned.fill(
                          child: Material(
                            color: Colors.transparent,
                            child: InkWell(
                              borderRadius: BorderRadius.circular(28),
                              onTap: () async {
                                final ok = await AndroidPermissions.ensureForImagePicker(fromCamera: false);
                                if (!ok) {
                                  if (!context.mounted) return;
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(content: Text('Permission required to access photos')),
                                  );
                                  return;
                                }
                                final picker = ImagePicker();
                                final picked = await picker.pickImage(source: ImageSource.gallery);
                                if (picked != null) {
                                  setState(() => _photoPath = picked.path);
                                  await _save();
                                }
                              },
                              onLongPress: () async {
                                setState(() => _photoPath = null);
                                await _save();
                              },
                            ),
                          ),
                        )
                      ],
                    ),
                    const SizedBox(width: ThemeSpacing.gap16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          TextField(
                            decoration: const InputDecoration(labelText: 'Your name', prefixIcon: Icon(Icons.badge_outlined)),
                            controller: TextEditingController(text: _name),
                            onChanged: (v) => _name = v,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            _pkgInfo == null ? '' : 'MediaVault • v${_pkgInfo!.version} (${_pkgInfo!.buildNumber})',
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            SizedBox(height: gap),
            // Appearance
            _section(context, 'Appearance', [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Theme Variant'),
                  const SizedBox(height: 8),
                  SegmentedButton<String>(
                    style: const ButtonStyle(visualDensity: VisualDensity.compact),
                    segments: variants
                        .map((e) {
                          final icon = e == 'Light'
                              ? const Icon(Icons.light_mode)
                              : e == 'Dark'
                                  ? const Icon(Icons.dark_mode)
                                  : const Icon(Icons.brightness_3);
                          return ButtonSegment<String>(
                            value: e,
                            label: FittedBox(
                              fit: BoxFit.scaleDown,
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  icon,
                                  const SizedBox(width: 6),
                                  const SizedBox.shrink(),
                                  Text(
                                    e,
                                    maxLines: 1,
                                    overflow: TextOverflow.fade,
                                    softWrap: false,
                                  ),
                                ],
                              ),
                            ),
                          );
                        })
                        .toList(),
                    selected: {sp.themeVariant},
                    onSelectionChanged: (s) => sp.setThemeVariant(s.first),
                  ),
                ],
              ),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.palette_outlined),
                title: const Text('Accent Color'),
                subtitle: const Text('Customize highlight color'),
                trailing: CircleAvatar(backgroundColor: sp.accentColor),
                onTap: () async {
                  final colors = [
                    const Color(0xFF1877F2),
                    const Color(0xFF42A5F5),
                    const Color(0xFF0F9D58),
                    const Color(0xFF34A853),
                    const Color(0xFFDB4437),
                    const Color(0xFFFF7043),
                    const Color(0xFFAA00FF),
                    const Color(0xFFFF6D00),
                    const Color(0xFFFFC107),
                    const Color(0xFF7C4DFF),
                  ];
                  // ignore: use_build_context_synchronously
                  showModalBottomSheet(
                    context: context,
                    showDragHandle: true,
                    builder: (ctx) {
                      return Padding(
                        padding: const EdgeInsets.all(16),
                        child: GridView.builder(
                          itemCount: colors.length,
                          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 5,
                            mainAxisSpacing: 12,
                            crossAxisSpacing: 12,
                          ),
                          itemBuilder: (c, i) => InkWell(
                            onTap: () async {
                              await sp.setAccentColor(colors[i]);
                              if (context.mounted) Navigator.pop(context);
                            },
                            child: CircleAvatar(backgroundColor: colors[i]),
                          ),
                        ),
                      );
                    },
                  );
                },
              ),
              Row(
                children: [
                  const Icon(Icons.text_increase),
                  const SizedBox(width: 12),
                  const Expanded(child: Text('Font Scale')),
                  SizedBox(
                    width: 180,
                    child: Slider(
                      value: sp.fontScale,
                      min: 0.8,
                      max: 1.4,
                      divisions: 6,
                      label: '${(sp.fontScale * 100).round()}%',
                      onChanged: (v) => sp.setFontScale(v),
                    ),
                  ),
                ],
              ),
            ]),
            // Behavior
            _section(context, 'Behavior', [
              Consumer<SettingsProvider>(builder: (context, sp, _) {
                return SwitchListTile(
                  value: sp.shuffleCardsEnabled,
                  title: const Text('Auto-shuffle data cards'),
                  subtitle: const Text('Periodically reshuffle card order on Home'),
                  onChanged: (v) async {
                    await sp.setShuffleCardsEnabled(v);
                    if (!mounted) return;
                    // ignore: use_build_context_synchronously
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text(v ? 'Auto-shuffle enabled' : 'Auto-shuffle disabled')),
                    );
                  },
                );
              }),
            ]),
            // Carousel
            _section(context, 'Carousel', [
              Row(
                children: [
                  const Icon(Icons.slideshow),
                  const SizedBox(width: 12),
                  const Expanded(child: Text('Carousel Interval', maxLines: 1, overflow: TextOverflow.ellipsis, softWrap: false)),
                  Builder(builder: (context) {
                    final isDark = Theme.of(context).brightness == Brightness.dark;
                    final textStyle = TextStyle(color: isDark ? Colors.white : Colors.black87);
                    final intervals = [0, 2, 3, 4, 5, 6, 7, 8, 9, 10];
                    String labelFor(int v) => v == 0 ? 'Off' : '$v s';
                    return DropdownButton<int>(
                      value: sp.carouselIntervalSec,
                      dropdownColor: isDark ? const Color(0xFF2A2A2A) : Colors.white,
                      items: intervals
                          .map((v) => DropdownMenuItem<int>(value: v, child: Text(labelFor(v), style: textStyle)))
                          .toList(),
                      selectedItemBuilder: (ctx) => intervals
                          .map((v) => Align(
                                alignment: Alignment.centerRight,
                                child: Text(labelFor(v), style: textStyle),
                              ))
                          .toList(),
                      onChanged: (v) async {
                        if (v == null) return;
                        await sp.setCarouselIntervalSec(v);
                        if (!mounted) return;
                        // ignore: use_build_context_synchronously
                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Carousel interval updated')));
                      },
                    );
                  }),
                ],
              ),
            ]),
            // Library & Backup
            _section(context, 'Library & Backup', [
              Consumer<SettingsProvider>(builder: (context, sp, _) {
                return SwitchListTile(
                  value: sp.autoBackupEnabled,
                  title: const Text('Automatic backup'),
                  subtitle: Text(sp.backupFolderPath == null || sp.backupFolderPath!.isEmpty
                      ? 'Backups saved via system dialog'
                      : 'Backups in: ${sp.backupFolderPath}'),
                  onChanged: (v) => sp.setAutoBackupEnabled(v),
                );
              }),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.folder_open),
                title: const Text('Set backup directory (device storage)'),
                subtitle: Consumer<SettingsProvider>(
                  builder: (_, sp, __) => Text(sp.backupFolderPath == null || sp.backupFolderPath!.isEmpty
                      ? 'Not set'
                      : sp.backupFolderPath!),
                ),
                onTap: () async {
                  try {
                    final selectedDirectory = await FilePicker.platform.getDirectoryPath(dialogTitle: 'Choose backup folder');
                    if (!context.mounted) return;
                    if (selectedDirectory != null && selectedDirectory.isNotEmpty) {
                      await context.read<SettingsProvider>().setBackupFolderPath(selectedDirectory);
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Backup directory set to: $selectedDirectory')));
                      }
                    } else {
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('No directory selected')));
                    }
                  } catch (_) {
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Failed to open folder picker')));
                    }
                  }
                },
              ),
              // Shorter backup note
              const ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Icon(Icons.info_outline),
                title: Text('Backups survive uninstall when saved to device storage.'),
              ),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.file_upload_outlined),
                title: const Text('Export Library'),
                subtitle: const Text('Save your data as JSON or CSV'),
                onTap: () async {
                  if (!mounted) return;
                  await showDialog(
                    // ignore: use_build_context_synchronously
                    context: context,
                    builder: (ctx) => AlertDialog(
                      title: const Text('Export Format'),
                      content: const Text('Choose export format:'),
                      actions: [
                        TextButton(
                          onPressed: () async {
                            Navigator.pop(ctx);
                            await _exportJSON();
                          },
                          child: const Text('JSON'),
                        ),
                        TextButton(
                          onPressed: () async {
                            Navigator.pop(ctx);
                            await _exportCSV();
                          },
                          child: const Text('CSV'),
                        ),
                        TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel'))
                      ],
                    ),
                  );
                },
              ),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.backup_outlined),
                title: const Text('Back up now'),
                subtitle: const Text('Create an encrypted snapshot immediately'),
                onTap: () async {
                  final ok = await BackupService().writeAutoBackup(force: true);
                  if (!context.mounted) return;
                  // ignore: use_build_context_synchronously
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(ok ? 'Backup created' : 'Backup failed')),
                  );
                },
              ),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.info_outline),
                title: const Text('Backup Location'),
                subtitle: Consumer<SettingsProvider>(
                  builder: (_, sp, __) => FutureBuilder<String>(
                    future: getApplicationDocumentsDirectory().then((dir) => dir.path),
                    builder: (context, snapshot) {
                      final path = snapshot.data ?? 'Loading...';
                      final backupPath = sp.backupFolderPath ?? path;
                      return Text(backupPath);
                    },
                  ),
                ),
                onTap: () async {
                  final dir = await getApplicationDocumentsDirectory();
                  final path = dir.path;
                  if (context.mounted) {
                    // ignore: use_build_context_synchronously
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Backup location: $path'),
                        duration: const Duration(seconds: 5),
                        action: SnackBarAction(
                          label: 'Copy',
                          onPressed: () {
                            Clipboard.setData(ClipboardData(text: path));
                          },
                        ),
                      ),
                    );
                  }
                },
              ),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.lock_outline_rounded),
                title: const Text('Create Encrypted Backup'),
                subtitle: const Text('Encrypted file stored locally'),
                onTap: () async {
                  try {
                    final rows = await DatabaseService().exportAll();
                    final jsonStr = jsonEncode(rows);
                    final dir = await getApplicationDocumentsDirectory();
                    final file = File('${dir.path}/mediavault_backup_${DateTime.now().millisecondsSinceEpoch}.mvb');
                    await file.writeAsString(jsonStr);
                    if (!mounted) return;
                    // ignore: use_build_context_synchronously
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Backup saved: ${file.path}'),
                        duration: const Duration(seconds: 5),
                        action: SnackBarAction(
                          label: 'Copy',
                          onPressed: () {
                            Clipboard.setData(ClipboardData(text: file.path));
                          },
                        ),
                      ),
                    );
                  } catch (e) {
                    if (!mounted) return;
                    // ignore: use_build_context_synchronously
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to create backup: $e')));
                  }
                },
              ),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.lock_open_rounded),
                title: const Text('Restore Backup'),
                subtitle: const Text('Pick a .mvb backup file to restore'),
                onTap: () async {
                  try {
                    final result = await FilePicker.platform.pickFiles(
                      type: FileType.custom,
                      allowedExtensions: ['mvb'],
                    );
                    if (result == null || result.files.isEmpty) return;
                    final path = result.files.single.path;
                    if (path == null) return;
                    final file = File(path);
                    final content = await file.readAsString();
                    // Try to decrypt first (for old encrypted backups)
                    String plain;
                    try {
                      plain = await DatabaseService().decryptFromBackup(content);
                    } catch (_) {
                      // If decryption fails, assume it's unencrypted JSON
                      plain = content;
                    }
                    final decoded = jsonDecode(plain);
                    final list = decoded is List ? decoded : [decoded];
                    
                    // Convert base64 images back to files
                    final dir = await getApplicationDocumentsDirectory();
                    final processedList = <Map<String, dynamic>>[];
                    
                    for (final item in list) {
                      final processedItem = Map<String, dynamic>.from(item);
                      
                      // Convert main image from base64
                      if (processedItem['imagePath_base64'] != null && processedItem['imagePath_base64'].toString().isNotEmpty) {
                        try {
                          final bytes = base64Decode(processedItem['imagePath_base64'].toString());
                          final imageFile = File('${dir.path}/mv_${DateTime.now().millisecondsSinceEpoch}.jpg');
                          await imageFile.writeAsBytes(bytes, flush: true);
                          processedItem['imagePath'] = imageFile.path;
                          processedItem.remove('imagePath_base64');
                        } catch (e) {
                          debugPrint('Failed to restore main image: $e');
                        }
                      }
                      
                      // Convert extra images from base64
                      if (processedItem['images_base64'] != null && processedItem['images_base64'] is List) {
                        final base64Images = processedItem['images_base64'] as List;
                        final restoredImages = <String>[];
                        for (final base64 in base64Images) {
                          if (base64 != null && base64.toString().isNotEmpty) {
                            try {
                              final bytes = base64Decode(base64.toString());
                              final imageFile = File('${dir.path}/mv_${DateTime.now().millisecondsSinceEpoch}.jpg');
                              await imageFile.writeAsBytes(bytes, flush: true);
                              restoredImages.add(imageFile.path);
                            } catch (e) {
                              debugPrint('Failed to restore extra image: $e');
                            }
                          }
                        }
                        processedItem['images'] = restoredImages;
                        processedItem.remove('images_base64');
                      }
                      
                      processedList.add(processedItem);
                    }
                    
                    // ignore: use_build_context_synchronously
                    final resultCounts = await context.read<MediaProvider>().importFromJsonDynamic(processedList);
                    if (!context.mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Restore complete: ${resultCounts['inserted']} added, ${resultCounts['updated']} updated, ${resultCounts['skipped']} skipped')),
                    );
                  } catch (e) {
                    if (!context.mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to restore backup: $e')));
                  }
                },
              ),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.system_update_alt_outlined),
                title: const Text('Import from Device'),
                subtitle: const Text('Select a JSON file to import'),
                onTap: () async {
                  try {
                    final result = await FilePicker.platform.pickFiles(
                      type: FileType.custom,
                      allowedExtensions: ['json'],
                    );
                    if (result == null || result.files.isEmpty) return;
                    final path = result.files.single.path;
                    if (path == null) return;
                    final file = File(path);
                    final content = await file.readAsString();
                    final decoded = jsonDecode(content);
                    final list = decoded is List ? decoded : [decoded];
                    // ignore: use_build_context_synchronously
                    final counts = await context.read<MediaProvider>().importFromJsonDynamic(list);
                    if (!context.mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Import complete: ${counts['inserted']} added, ${counts['updated']} updated, ${counts['skipped']} skipped')),
                    );
                  } catch (_) {
                    if (!context.mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Failed to import file')));
                  }
                },
              ),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.file_download_outlined),
                title: const Text('Import Library'),
                subtitle: const Text('Paste JSON to restore'),
                onTap: () async {
                  final controller = TextEditingController();
                  final confirmed = await showDialog<bool>(
                    context: context,
                    builder: (ctx) => AlertDialog(
                      title: const Text('Import JSON'),
                      content: TextField(controller: controller, maxLines: 8, decoration: const InputDecoration(hintText: 'Paste JSON here')),
                      actions: [
                        TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
                        TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Import')),
                      ],
                    ),
                  );
                  if (confirmed == true) {
                    try {
                      final text = controller.text.trim();
                      if (text.isEmpty) return;
                      final decoded = jsonDecode(text);
                      // ignore: use_build_context_synchronously
                      final result = await context.read<MediaProvider>().importFromJsonDynamic(decoded is List ? decoded : [decoded]);
                      if (!context.mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Import complete: ${result['inserted']} added, ${result['updated']} updated, ${result['skipped']} skipped')),
                      );
                    } catch (e) {
                      if (!context.mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Failed to import JSON')));
                    }
                  }
                },
              ),
            ]),
            // About & Privacy
            _section(context, 'About & Privacy', [
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.lock_outline),
                title: const Text('Protect Notes at Rest'),
                subtitle: const Text('Sensitive text is encrypted locally'),
                onTap: () {
                  showDialog(
                    context: context,
                    builder: (ctx) => AlertDialog(
                      title: const Text('Data Protection'),
                      content: const Text('MediaVault encrypts sensitive text fields (like notes) on your device using AES with a per-device key stored in secure storage.'),
                      actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('OK'))],
                    ),
                  );
                },
              ),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.new_releases_outlined),
                title: const Text('Features & What’s next'),
                subtitle: const Text('Vision, current features, and upcoming items'),
                onTap: () async {
                  final remote = Uri.parse('https://example.com/mediavault_features.json');
                  final list = await AppFeatures.fetchFromRemote(remote);
                  if (!context.mounted) return;
                  showModalBottomSheet(
                    context: context,
                    showDragHandle: true,
                    isScrollControlled: true,
                    builder: (ctx) {
                      final isDark = Theme.of(ctx).brightness == Brightness.dark;
                      return DraggableScrollableSheet(
                        expand: false,
                        initialChildSize: 0.7,
                        minChildSize: 0.4,
                        maxChildSize: 0.9,
                        builder: (context, scrollController) => Container(
                          color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
                          child: ListView(
                            controller: scrollController,
                            padding: const EdgeInsets.all(16),
                            children: [
                              const ListTile(
                                leading: Icon(Icons.lightbulb_outline, color: Color(0xFF42A5F5)),
                                title: Text('Why MediaVault?'),
                                subtitle: Text('A private, local-first catalog for movies, anime, K-drama, and series with fast adding, rich notes, and encrypted backups.'),
                              ),
                              const Divider(),
                              const ListTile(
                                leading: Icon(Icons.check_circle, color: Color(0xFF42A5F5)),
                                title: Text('Current features'),
                              ),
                              ...list.map((e) => ListTile(
                                    leading: const Icon(Icons.chevron_right),
                                    title: Text(e),
                                  )),
                              const Divider(),
                              const ListTile(
                                leading: Icon(Icons.rocket_launch_outlined, color: Color(0xFF42A5F5)),
                                title: Text('What’s next'),
                                subtitle: Text('Deeper insights, richer collections, cloud optional sync'),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  );
                },
              ),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.privacy_tip_outlined),
                title: const Text('Privacy Policy'),
                subtitle: const Text('How we handle your data'),
                onTap: () {
                  showDialog(
                    context: context,
                    builder: (ctx) => AlertDialog(
                      title: const Text('Privacy Policy'),
                      content: const Text(
                        'MediaVault stores data locally on your device and optionally syncs to your private cloud (Firebase) if configured. No data is shared with third parties.',
                      ),
                      actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Close'))],
                    ),
                  );
                },
              ),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.info_outline),
                title: const Text('About'),
                subtitle: Text(_pkgInfo == null ? '' : 'Version ${_pkgInfo!.version} (${_pkgInfo!.buildNumber})'),
              ),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.insights_outlined),
                title: const Text('Analytics & Insights'),
                subtitle: const Text('Breakdowns and stats'),
                onTap: () => Navigator.pushNamed(context, '/stats'),
              ),
            ]),
            SizedBox(height: gap),
            Center(
              child: FilledButton.icon(
                onPressed: _save,
                icon: const Icon(Icons.save),
                label: const Text('Save Settings'),
              ),
            ),
          ],
        );
      }),
    );
  }

  Future<void> _exportJSON() async {
    final rows = await DatabaseService().exportAll();
    final jsonStr = jsonEncode(rows);
    if (!mounted) return;
    await showDialog(
      // ignore: use_build_context_synchronously
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Export JSON'),
        content: SingleChildScrollView(child: Text(jsonStr, style: const TextStyle(fontFamily: 'monospace', fontSize: 10))),
        actions: [
          TextButton(
            onPressed: () async {
              await Clipboard.setData(ClipboardData(text: jsonStr));
              if (mounted) {
                // ignore: use_build_context_synchronously
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('JSON copied to clipboard')));
              }
            },
            child: const Text('Copy'),
          ),
          TextButton(
            onPressed: () async {
              try {
                final dir = await getTemporaryDirectory();
                final file = File('${dir.path}/mediavault_export_${DateTime.now().millisecondsSinceEpoch}.json');
                await file.writeAsString(jsonStr);
                await Share.shareXFiles([XFile(file.path)], text: 'MediaVault export');
              } catch (_) {}
            },
            child: const Text('Share/Download'),
          ),
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Close'))
        ],
      ),
    );
  }

  Future<void> _exportCSV() async {
    try {
      final rows = await DatabaseService().exportAll();
      if (rows.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('No data to export')));
        }
        return;
      }

      // CSV header
      final csvHeader = 'ID,Title,Type,Status,Release Year,Watched Year,Language,Rating,Recommend,Added Date,Notes,Image Path,Extra,Images\n';
      
      // CSV rows
      final csvRows = rows.map((row) {
        final id = row['id']?.toString() ?? '';
        final title = _escapeCSV(row['title']?.toString() ?? '');
        final type = _escapeCSV(row['type']?.toString() ?? '');
        final status = _escapeCSV(row['status']?.toString() ?? '');
        final releaseYear = row['releaseYear']?.toString() ?? '';
        final watchedYear = row['watchedYear']?.toString() ?? '';
        final language = _escapeCSV(row['language']?.toString() ?? '');
        final rating = row['rating']?.toString() ?? '';
        final recommend = row['recommend']?.toString() ?? '';
        final addedDate = row['addedDate']?.toString() ?? '';
        final notes = _escapeCSV(row['notes']?.toString() ?? '');
        final imagePath = _escapeCSV(row['imagePath']?.toString() ?? '');
        final extra = _escapeCSV(row['extra']?.toString() ?? '');
        final images = _escapeCSV(row['images']?.toString() ?? '');
        
        return '$id,$title,$type,$status,$releaseYear,$watchedYear,$language,$rating,$recommend,$addedDate,$notes,$imagePath,$extra,$images';
      }).join('\n');

      final csvContent = csvHeader + csvRows;
      
      final dir = await getTemporaryDirectory();
      final file = File('${dir.path}/mediavault_export_${DateTime.now().millisecondsSinceEpoch}.csv');
      await file.writeAsString(csvContent);
      
      if (mounted) {
        await Share.shareXFiles([XFile(file.path)], text: 'MediaVault CSV export');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Export failed: $e')));
      }
    }
  }

  String _escapeCSV(String value) {
    if (value.isEmpty) return '';
    // Escape quotes and wrap in quotes if contains comma, quote, or newline
    if (value.contains(',') || value.contains('"') || value.contains('\n') || value.contains('\r')) {
      return '"${value.replaceAll('"', '""')}"';
    }
    return value;
  }
}