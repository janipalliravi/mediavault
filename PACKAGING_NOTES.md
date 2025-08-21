# MediaVault Packaging Configuration (Save for future updates)

- Package ID (Android applicationId / namespace)
  - Value: `com.example.mediavault`
  - Files:
    - android/app/build.gradle.kts → `applicationId = "com.example.mediavault"`
    - android/app/build.gradle.kts → `namespace = "com.example.mediavault"`
    - android/app/src/main/kotlin/.../MainActivity.kt → `package com.example.mediavault`
  - Purpose: Changing this installs a new app instead of updating the existing one.

- Flutter embedding (v2)
  - android/app/src/main/AndroidManifest.xml → `android:name="${applicationName}"` on the `<application>` tag

- Backup configuration (Android 12+ compatible)
  - Files:
    - android/app/src/main/res/xml/backup_rules.xml (full backup)
    - android/app/src/main/res/xml/data_extraction_rules.xml (cloud backup + device transfer)
  - Domains used: `database`, `sharedpref`, `file`

- Versioning (bump each release)
  - pubspec.yaml → e.g., `version: 1.0.2+3` (`+3` is the Android versionCode)

- Signing (keep consistent across releases)
  - Current: release build uses debug signing (for convenience)
  - Production: add a release keystore and set `signingConfig` for `release` in android/app/build.gradle.kts
  - Use the SAME key to allow in‑place updates

- Build steps
  - flutter clean
  - flutter pub get
  - flutter build apk --release

- APK output path
  - build/app/outputs/flutter-apk/app-release.apk

- Notes
  - Changing applicationId/namespace or signing key causes side‑by‑side installs (not updates)
  - Always increase versionCode (pubspec `+N`) for Play Store or side‑load updates
