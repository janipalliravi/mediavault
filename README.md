# MediaVault

A modern Flutter application for managing your personal media library including movies, anime, series, and manga. Keep track of what you've watched, what you're currently watching, and what's on your watchlist.

## Features

### 📱 Core Features
- **Multi-Media Support**: Track Movies, Anime, Series, K-Drama, and Manga
- **Smart Organization**: Categorize by type, status, language, and release year
- **Rating System**: Rate your media with 1-5 stars
- **Progress Tracking**: Track seasons, episodes, and chapters
- **Search & Filter**: Find your media quickly with advanced search and filtering
- **Favorites**: Mark your favorite titles for quick access

### 🎨 User Experience
- **Modern UI**: Clean, intuitive interface with dark/light theme support
- **Grid & List Views**: Choose your preferred viewing style
- **Auto-Shuffle**: Automatically shuffle your media cards for discovery
- **Smooth Scrolling**: Optimized performance for smooth navigation
- **Responsive Design**: Works seamlessly across different screen sizes

### 💾 Data Management
- **Automatic Backup**: Encrypted backups to your chosen folder
- **Import/Export**: JSON-based data import and export
- **Cloud Sync Ready**: Prepared for future cloud synchronization
- **Data Safety**: Automatic backups prevent data loss

### 📊 Analytics & Insights
- **Statistics Dashboard**: View your media consumption patterns
- **Progress Tracking**: Monitor your watching/reading progress
- **Recommendations**: Track what you recommend to others
- **Yearly Overview**: See your media activity by year

### 🔧 Advanced Features
- **Image Management**: Add custom images for your media
- **Notes & Cast**: Add personal notes and cast information
- **Duplicate Detection**: Find and manage duplicate entries
- **Share Functionality**: Share media details as images
- **Multi-Select**: Bulk operations for managing multiple items

## Screenshots

*[Screenshots will be added here]*

## Getting Started

### Prerequisites
- Flutter SDK (3.0 or higher)
- Android Studio / VS Code
- Android SDK (for Android builds)
- Git

### Installation

1. **Clone the repository**
   ```bash
   git clone https://github.com/yourusername/mediavault.git
   cd mediavault
   ```

2. **Install dependencies**
   ```bash
   flutter pub get
   ```

3. **Run the app**
   ```bash
   flutter run
   ```

### Android 14–16 support

MediaVault targets **API 36** and is configured for **Android 14, 15, and 16** (API 34–36):

- Granular media permissions + partial gallery access (Android 14+)
- Edge-to-edge UI (Android 15+)
- 16 KB native page size (Android 16 devices)

`minSdk` remains **23** so older phones can still install; use an API 34+ emulator or device for full behavior testing.

### Android 16 install blocked?

This is usually **Play Protect** or **Advanced Protection**, not the app itself. See **[SIDELOAD_INSTALL.md](SIDELOAD_INSTALL.md)** for step-by-step fixes and `adb install`.

### Android emulator

You already have AVDs in Android Studio. List and start them from the terminal:

```bash
flutter emulators
flutter emulators --launch Pixel_8
```

Available on this machine:

| ID | Name | Notes |
|----|------|--------|
| `Pixel_8` | Pixel 8 | Good default for MediaVault |
| `Pixel_9` | Pixel 9 | Newer Pixel profile |
| `Medium_Phone_API_36.0` | Medium Phone API 36 | Android 16 (API 36) |

After the emulator boots, confirm it appears:

```bash
flutter devices
flutter run -d emulator-5554
```

**Create another AVD:** Android Studio → **Device Manager** → **Create device**, or:

```bash
flutter emulators --create
```

### Building for Release

**Android APK:**
```bash
flutter build apk --release
```

The APK will be generated at: `build/app/outputs/flutter-apk/app-release.apk`

## Project Structure

```
lib/
├── constants/          # App constants and configurations
├── models/            # Data models
├── providers/         # State management (Provider pattern)
├── screens/           # UI screens
├── services/          # Business logic and external services
├── theme/             # App theming and styling
├── utils/             # Utility functions
└── widgets/           # Reusable UI components
```

## Key Technologies

- **Framework**: Flutter 3.x
- **State Management**: Provider
- **Database**: SQLite (via sqflite)
- **Storage**: SharedPreferences, Secure Storage
- **Image Handling**: image_picker, crop_your_image
- **File Operations**: file_picker, file_saver
- **UI Components**: Material Design 3

## Configuration

### Android Configuration
- **Package ID**: `com.mediavault.personal` (personal sideload; see [SIDELOAD_INSTALL.md](SIDELOAD_INSTALL.md) if Android 16 blocks install)
- **Min SDK**: 21 (Android 5.0)
- **Target SDK**: 34 (Android 14)
- **Auto Backup**: Enabled with custom rules
- **R8 Shrinking**: Enabled for optimized APK size

### Backup Configuration
- **Auto Backup**: Encrypted backups to user-selected folder
- **Backup Format**: `.mvb` (MediaVault Backup)
- **Frequency**: On every data change
- **Manual Backup**: Available in Settings

## Usage Guide

### Adding Media
1. Tap the "+" button on the home screen
2. Fill in the media details (title, type, status, etc.)
3. Add an image (optional)
4. Save the entry

### Managing Your Library
- **Search**: Use the search bar to find specific titles
- **Filter**: Use filters to narrow down by type, status, or language
- **Sort**: Tap column headers to sort your library
- **Multi-Select**: Long press to enter selection mode for bulk operations

### Backup & Restore
- **Automatic**: Backups happen automatically when you make changes
- **Manual**: Go to Settings → "Back up now" for immediate backup
- **Import**: Use "Import Library" in Settings to restore from JSON

## Contributing

1. Fork the repository
2. Create a feature branch (`git checkout -b feature/amazing-feature`)
3. Commit your changes (`git commit -m 'Add some amazing feature'`)
4. Push to the branch (`git push origin feature/amazing-feature`)
5. Open a Pull Request

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## Acknowledgments

- Flutter team for the amazing framework
- Material Design team for the design system
- All contributors and users of MediaVault

## Support

If you encounter any issues or have questions:
1. Check the [Issues](https://github.com/yourusername/mediavault/issues) page
2. Create a new issue with detailed information
3. Include device information and steps to reproduce

---

**MediaVault** - Your personal media library, organized and secure.
