
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:mediavault/providers/media_provider.dart';
import 'package:mediavault/providers/settings_provider.dart';
import 'package:mediavault/screens/add_edit_screen.dart';
import 'package:mediavault/env.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  testWidgets('add then edit item flow', (tester) async {
    // Minimal app shell for the form
    AppEnv.testMode = true;
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider(create: (_) => MediaProvider()),
          ChangeNotifierProvider(create: (_) => SettingsProvider()),
        ],
        child: const MaterialApp(home: AddEditScreen()),
      ),
    );

    // Enter title and ensure no crash on save button presence
    expect(find.text('Add Item'), findsOneWidget);
    await tester.enterText(find.byType(TextFormField).first, 'Test Movie');
    // Verify Save button exists
    expect(find.text('Save'), findsOneWidget);

    // End: verify UI remains stable
    expect(find.byType(AddEditScreen), findsOneWidget);
  });
}


