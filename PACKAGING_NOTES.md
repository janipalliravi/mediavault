# MediaVault Packaging Configuration (Save for future updates)

## Android 14–16 compatibility (API 34–36)

| Version | API | Notes |
|---------|-----|--------|
| Android 14 | 34 | Partial photo access (`READ_MEDIA_VISUAL_USER_SELECTED`); runtime gallery permission |
| Android 15 | 35 | Edge-to-edge enforced (`values-v35/styles.xml`, `SystemUiMode.edgeToEdge`) |
| Android 16 | 36 | `targetSdk 36`, 16 KB page alignment (`android.experimental.enable16kPages=true`) |

- **minSdk 23** — app still installs on older Android; primary testing target is API 34–36.
- **Runtime permissions** — `lib/services/android_permissions.dart` requests photos/camera before picker on Android 13+.
- **Removed** unused `POST_NOTIFICATIONS` (app does not show notifications).

## Android 16 (API 36)

- **compileSdk / targetSdk**: `36` in `android/app/build.gradle.kts`
- **Permissions**: declared in `android/app/src/main/AndroidManifest.xml` (before `<application>`)
  - Media: `READ_MEDIA_IMAGES`, `READ_MEDIA_VIDEO`, `READ_MEDIA_VISUAL_USER_SELECTED`
  - Legacy: `READ_EXTERNAL_STORAGE` (maxSdk 32), `WRITE_EXTERNAL_STORAGE` (maxSdk 29)
  - Camera, biometrics, notifications, internet
- **Edge-to-edge**: `MainActivity` uses `WindowCompat.setDecorFitsSystemWindows`
- **Predictive back**: `android:enableOnBackInvokedCallback="true"`
- **Network**: HTTPS-only in release (`network_security_config.xml`)

## Package ID (personal sideload)

- Value: `com.mediavault.personal` (replaces `com.example.mediavault` — Play Protect flags example.* packages)
- Files:
  - `android/app/build.gradle.kts` → `applicationId`, `namespace`
  - `android/app/src/main/kotlin/com/mediavault/personal/MainActivity.kt`
- Uninstall old `com.example.mediavault` before installing this build.

## Android 16 install blocked?

See **SIDELOAD_INSTALL.md** — usually Play Protect, Advanced Protection, or installing during a call. Use release APK + `scripts/install_personal_android.ps1` if needed.

## Backup (personal data preservation)

- `android/app/src/main/res/xml/backup_rules.xml`
- `android/app/src/main/res/xml/data_extraction_rules.xml`
- Domains: `database`, `sharedpref`, `file`

## Versioning

- `pubspec.yaml` → e.g. `version: 1.0.2+3` (`+3` is Android `versionCode`)

## Release signing (required for trusted sideload / updates)

1. One-time setup:
   ```powershell
   .\scripts\create_release_keystore.ps1
   ```
   Creates `android/app/mediavault-release.jks` and `android/key.properties` (both gitignored).

2. Customize passwords in `android/key.properties` if desired (keep the same keystore file for updates).

3. Build signed **single universal APK**:
   ```powershell
   .\scripts\build_release_apk.ps1
   ```
   Or manually:
   ```powershell
   flutter build apk --release
   ```

## APK output

- **Single universal APK** (all ABIs): `build/app/outputs/flutter-apk/app-release.apk`
- ABI splits are disabled; no `app-arm64-v8a-release.apk` variants.

## Install (personal / sideload)

Full guide: **SIDELOAD_INSTALL.md**

1. Build release APK (`scripts/build_release_apk.ps1`).
2. Uninstall old `com.example.mediavault` if present.
3. On phone: allow unknown apps for Files/Chrome; Play Protect → **Install anyway** or disable outside-Play scan.
4. On Android 16: turn off **Advanced Protection** while sideloading, or use `adb install -r`.
5. After install: **Allow restricted settings** for MediaVault (backup / folder picker).

## Notes

- `android/key.properties` and `*.jks` are never committed.
- Debug-signed release builds cannot update a release-signed install (and vice versa).
- Always bump `versionCode` (`pubspec` `+N`) before distributing a new APK.
