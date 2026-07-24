# Taiwanese Motorcycle License App (Patente Moto Taiwan)

A cross-platform Flutter application designed to help users prepare for the Taiwanese Motorcycle License written examination. It includes practice modules, category-based training, realistic exam simulations, and offline performance metrics.

---

## Features

- **Training Mode**: Practice questions by specific category or general question pools with instant feedback and explanations.
- **Exam Simulation**: Timed mock exams matching official Taiwanese motorcycle test structures and passing criteria.
- **Results & Review**: Detailed exam breakdown showing wrong answers, correct explanations, and overall performance.
- **Metrics & History**: Local tracking of pass rates, quiz statistics, and weak categories via `SharedPreferences`.

---

## Prerequisites

Before setting up and running the project, ensure you have the following installed on your environment:

1. **Flutter SDK**: `^3.12.2` or later ([Installation Guide](https://docs.flutter.dev/get-started/install))
2. **Dart SDK**: Included with Flutter SDK
3. **IDE / Editor**: [VS Code](https://code.visualstudio.com/) with Flutter/Dart extensions or [Android Studio](https://developer.android.com/studio)
4. **Platform Toolchain** (depending on target platform):
   - **Android**: Android Studio & Android SDK / Emulator
   - **iOS/macOS**: Xcode & CocoaPods (macOS host only)
   - **Web**: Chrome or any modern browser

Verify your setup by running:
```bash
flutter doctor
```

---

## Getting Started & Setup

1. **Clone the Repository**:
   ```bash
   git clone https://github.com/simomass/taiwan-license-app.git
   cd app_patente_taiwanese
   ```

2. **Install Dependencies**:
   ```bash
   flutter pub get
   ```

3. **Verify Connected Devices**:
   ```bash
   flutter devices
   ```

---

## Running the Application

### Debug Mode

Run the application on a connected device, emulator, or browser:

- **Run on default active device**:
  ```bash
  flutter run
  ```

- **Run on Chrome (Web)**:
  ```bash
  flutter run -d chrome
  ```

- **Run on a specific target device**:
  ```bash
  flutter run -d <device-id>
  ```

---

## Building for Production

To generate production builds:

- **Android APK**:
  ```bash
  flutter build apk --release
  ```
- **Android App Bundle (AAB)**:
  ```bash
  flutter build appbundle --release
  ```
- **Web App**:
  ```bash
  flutter build web --release
  ```
- **iOS App** (macOS required):
  ```bash
  flutter build ipa --release
  ```

## CI/CD & Releases

This project uses GitHub Actions for automated continuous integration and delivery. 

### CI Builds (Commits to `main`)
Every push or pull request to the `main` branch triggers the **Validate and Build** workflow.
- It validates that the Python-generated `questions.json` is correctly updated.
- It formats, analyzes, and tests the Flutter code.
- It builds binaries for Android, Web, Windows, Linux, and macOS.
- Build files are available for download under the **Artifacts** section of the Actions run. These are CI snapshots, not permanent releases.

### Creating a Release
To publish a formal release, push a version tag starting with `v` (e.g., `v1.0.0`). Ensure the Git tag matches the `version:` in `pubspec.yaml`:
```bash
git tag -a v1.0.0 -m "Release v1.0.0"
git push origin v1.0.0
```
This triggers the same builds as CI, but adds a final **Publish Release** job that creates a GitHub Release and attaches the following downloadable binaries:
- `patente-moto-taiwan-android.apk`
- `patente-moto-taiwan-web.zip`
- `patente-moto-taiwan-windows.zip`
- `patente-moto-taiwan-linux.tar.gz`
- `patente-moto-taiwan-macos.zip`

> **Note on Platform Limitations**:
> - **Android**: The provided APK is built in release mode but is intended for direct side-loading (internal/downloadable distribution). It is not signed with a production Google Play Store keystore.
> - **macOS/Windows**: The desktop builds may be unsigned or not notarized, requiring users to bypass security prompts (e.g., macOS Gatekeeper) to run them.
> - **Linux**: The Linux archive requires compatible GTK/desktop libraries on the host system.

---

## Project Structure

```
lib/
├── main.dart                       # App entry point
├── models/
│   └── question.dart               # Question data structures & JSON models
├── managers/
│   ├── data_manager.dart           # Question loading & category management
│   └── metrics_manager.dart        # Persistence layer for stats & performance tracking
└── screens/
    ├── home_screen.dart            # Main dashboard
    ├── category_selection_screen.dart # Topic selection UI
    ├── training_screen.dart        # Interactive practice mode
    ├── simulation_screen.dart      # Mock exam interface
    ├── simulation_result_screen.dart # Results & review page
    └── metrics_screen.dart         # User statistics & history UI
```