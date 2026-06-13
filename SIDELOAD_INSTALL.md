# Install MediaVault on Android 14–16 (personal use)

Android 16 does **not** block personal apps by default. Install failures usually come from **Play Protect**, **Advanced Protection**, or **installing during a phone call**.

## Before you install

1. Build a **release-signed** APK (not debug):
   ```powershell
   .\scripts\build_release_apk.ps1
   ```
   Output: `build/app/outputs/flutter-apk/app-release.apk`

2. **End any phone call** — Android 16 can block “Install unknown apps” changes while on a call.

3. If **Advanced Protection** is ON (Settings → Security & privacy → Advanced Protection):
   - Turn it **OFF** temporarily to sideload, **or**
   - Use `adb install` from a PC (see below).

## On your phone

### Step 1 — Allow installs from your file app

Settings → **Apps** → **Special app access** → **Install unknown apps**  
→ Enable for **Files**, **Chrome**, or whichever app opens the APK.

### Step 2 — Play Protect (important)

Settings → **Security & privacy** → **Google Play Protect** → gear icon:

- Turn **off** “Scan apps from outside Play Store” (install only), **or**
- When prompted during install, tap **Install anyway** / **More details** → **Install anyway**.

Play Protect often blocks `com.example.*` packages. This project uses **`com.mediavault.personal`** to reduce false blocks.

### Step 3 — Install the APK

Open `app-release.apk` from Files → **Install**.

### Step 4 — After install (Android 15/16)

Settings → **Apps** → **MediaVault** → **⋮** → **Allow restricted settings**  
(needed for backup folder / some file access on sideloaded apps.)

## Install from PC (most reliable on Android 16)

```powershell
# USB debugging enabled on phone
adb devices
adb install -r build\app\outputs\flutter-apk\app-release.apk
```

Or use the helper script:

```powershell
.\scripts\install_personal_android.ps1
```

## Package ID change

| Old | New |
|-----|-----|
| `com.example.mediavault` | `com.mediavault.personal` |

Uninstall any old `com.example.mediavault` build before installing the new APK. Data is not migrated automatically.

## Still blocked?

| Symptom | Fix |
|---------|-----|
| “Blocked for security” | Play Protect → Install anyway; or disable scan for outside Play Store |
| “Can’t install during call” | End the call, retry |
| Advanced Protection on | Disable it, or use `adb install` |
| Wrong APK | Use `app-release.apk` from release build with your keystore |
| Old package installed | Uninstall old app first if signatures differ |

This app is for **personal use only** — not distributed on Play Store. Signing with your own release keystore is the correct way to install updates on your devices.
