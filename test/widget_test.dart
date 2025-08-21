// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:mediavault/main.dart' as app;
import 'package:mediavault/env.dart';
import 'package:provider/provider.dart';
import 'package:mediavault/providers/media_provider.dart';
import 'package:mediavault/providers/settings_provider.dart';

void main() {
  testWidgets('Counter increments smoke test', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    AppEnv.testMode = true;
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider(create: (_) => MediaProvider()),
          ChangeNotifierProvider(create: (_) => SettingsProvider()),
        ],
        child: const app.MyApp(),
      ),
    );
    // Let any short post-frame timers complete
    await tester.pump(const Duration(milliseconds: 300));

    // Smoke: App builds and shows a scaffold/home content
    expect(find.byType(Scaffold), findsWidgets);
  });
}
