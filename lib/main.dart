import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'providers/media_provider.dart';
import 'providers/settings_provider.dart';
import 'screens/home_screen.dart';
import 'screens/add_edit_screen.dart';
import 'screens/details_screen.dart';
import 'theme/app_theme.dart';
import 'screens/settings_screen.dart';
import 'screens/splash_screen.dart';
import 'screens/duplicates_screen.dart';
import 'screens/related_items_screen.dart';
import 'screens/stats_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Avoid runtime font fetching in debug which can slow first frame

  final mediaProvider = MediaProvider();
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: mediaProvider),
        ChangeNotifierProvider(create: (_) => SettingsProvider()),
      ],
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});
  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  @override
  void initState() {
    super.initState();
    // Load settings after widget tree is built to avoid plugin channel issues
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<SettingsProvider>().load();
    });
  }

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsProvider>();
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: AppTheme.build(
        dark: settings.isDarkMode,
        seed: settings.accentColor,
        amoled: settings.useAmoled,
        fontScale: settings.fontScale,
      ),
      builder: (context, child) {
        final mq = MediaQuery.of(context);
        return MediaQuery(
          data: mq.copyWith(textScaler: TextScaler.linear(settings.fontScale)),
          child: child ?? const SizedBox.shrink(),
        );
      },
      initialRoute: '/splash',
      routes: {
        '/splash': (context) => const SplashScreen(),
        '/': (context) => const HomeScreen(),
        '/add': (context) => const AddEditScreen(),
        '/details': (context) => DetailsScreen(
          item: ModalRoute.of(context)!.settings.arguments as dynamic,
        ),
        '/settings': (context) => const SettingsScreen(),
        '/duplicates': (context) => const DuplicatesScreen(),
        '/related': (context) => const RelatedItemsScreen(),
        '/stats': (context) => const StatsScreen(),
      },
    );
  }
}