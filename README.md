# ProFaceMind

A Flutter-based mobile application for face detection, location tracking, and personal information management. Built with **Google ML Kit** for face detection and **Google Maps** for location services.

## Features

- **Face Detection**: Real-time face detection using Google ML Kit
- **Photo Capture**: Camera integration with permission handling
- **Location Services**: GPS-based location tracking and Google Maps integration
- **Database Management**: SQLite for local data persistence
- **Personal Information**: Register and manage user profiles with photo
- **History Tracking**: Keep records of past entries
- **Text-to-Speech**: Audio feedback support
- **Multi-language Support**: English and Thai localization
- **Secure Storage**: SharedPreferences for app preferences
- **Map Integration**: Google Places and Google Maps APIs

## Project Structure

```
lib/
  ├── main.dart              # App entry point & routing
  ├── camera.dart            # Camera & face detection
  ├── database_helper.dart   # SQLite operations
  ├── register.dart          # User registration flow
  ├── personinfo.dart        # Personal information page
  ├── ownerinfo.dart         # Owner details screen
  ├── profile.dart           # User profile management
  ├── history.dart           # View history records
  ├── fillinfo.dart          # Form filling screen
  ├── setmap.dart            # Map location picker
  ├── setphonenum.dart       # Phone number input
  ├── selectposition.dart    # Position selection
  ├── navigation.dart        # Navigation handler
  ├── secondpage.dart        # Secondary navigation
  └── allregister.dart       # Registration overview

assets/
  └── MobileFaceNet.tflite   # Face detection model

android/
  └── build.gradle, gradle.properties, etc.

```

## Requirements

- Flutter SDK: ^3.6.1 or higher
- Dart SDK: Latest stable
- Android 5.0+ or iOS 11.0+
- Camera permissions (required)
- Location permissions (required)
- Storage permissions (required)

## Dependencies

Key packages used:

| Package | Version | Purpose |
| --- | --- | --- |
| `google_mlkit_face_detection` | ^0.12.0 | Face detection engine |
| `google_maps_flutter` | ^2.5.0 | Map display |
| `geolocator` | ^13.0.2 | GPS location access |
| `geocoding` | ^2.1.0 | Location to address conversion |
| `sqflite` | ^2.2.8+4 | Local SQLite database |
| `image_picker` | ^1.0.4 | Camera & gallery access |
| `permission_handler` | ^11.0.1 | Runtime permissions |
| `google_places_flutter` | ^2.0.5 | Places search |
| `flutter_tts` | ^3.8.4 | Text-to-speech |
| `shared_preferences` | ^2.0.15 | App preferences storage |
| `google_place` | ^0.4.7 | Google Places API |

## Setup Instructions

### 1. Install Flutter
Follow the [Flutter installation guide](https://flutter.dev/docs/get-started/install).

### 2. Clone the Repository
```bash
git clone <repository-url>
cd ProFaceMind-master
```

### 3. Install Dependencies
```bash
flutter pub get
```

### 4. Configure Google Services

Create a `.env` file in the project root with your API keys:
```
GOOGLE_MAPS_API_KEY=your_key_here
GOOGLE_PLACES_API_KEY=your_key_here
```

**Note**: This app expects `flutter_dotenv` for environment configuration.

### 5. Android Configuration

Update `android/app/build.gradle`:
```gradle
compileSdkVersion 34  // Or higher
minSdkVersion 21
targetSdkVersion 34
```

Ensure `android/gradle.properties` has:
```
org.gradle.jvmargs=-Xmx4096m
```

### 6. iOS Configuration (if applicable)

Update `ios/Podfile` to set a minimum deployment target of 11.0 or higher.

### 7. Run the App

**For Android**:
```bash
flutter run -v
```

**For Android (release build)**:
```bash
flutter build apk
```

## How to Use

1. **First Launch**: App detects first-time user and shows the Personal Info registration screen.
2. **Capture Photo**: Use the camera to take a photo; face detection runs automatically.
3. **Register**: Fill in personal information and location details.
4. **View Profile**: Check saved information in the Profile section.
5. **History**: View past records and captured photos.
6. **Settings**: Adjust app preferences via SharedPreferences.

## Permissions Required

The app requests:
- `CAMERA`: For face detection via live feed or photo
- `ACCESS_FINE_LOCATION`: For precise GPS coordinates
- `READ_EXTERNAL_STORAGE`: To access gallery images
- `WRITE_EXTERNAL_STORAGE`: To save captured images (Android 9 and below)

## Database Schema

**Users Table**:
- `id` (INTEGER PRIMARY KEY)
- `name` (TEXT)
- `phone` (TEXT)
- `photo_path` (TEXT)
- `location` (TEXT)
- `latitude` (REAL)
- `longitude` (REAL)
- `timestamp` (DATETIME)

**History Table**:
- `id` (INTEGER PRIMARY KEY)
- `user_id` (INTEGER FOREIGN KEY)
- `action` (TEXT)
- `timestamp` (DATETIME)

## Troubleshooting

| Issue | Solution |
| --- | --- |
| Camera not working | Grant camera permission; check `android/app/src/main/AndroidManifest.xml` |
| Face detection fails | Ensure good lighting; MobileFaceNet model path is correct |
| Location returns null | Enable GPS; grant location permission; check device settings |
| Maps not displaying | Verify Google Maps API key in build.gradle; check AndroidManifest.xml |
| Database errors | Clear app cache (`flutter clean`); reinstall |
| Localization not working | Ensure `.arb` files are in `lib/l10n/` (if using intl) |

## Build & Distribution

**Generate APK**:
```bash
flutter build apk --release
```

**Generate App Bundle (Google Play)**:
```bash
flutter build appbundle --release
```

## Project Status

**Year 4 Capstone Project**  
Status: Development/Complete  
Last Updated: January 2026

## Contributors

Add your team members here.

## License

Specify your license here (e.g., MIT, Apache 2.0).

## Support & Documentation

- [Flutter Docs](https://docs.flutter.dev/)
- [Google ML Kit Docs](https://developers.google.com/ml-kit)
- [Google Maps Flutter Plugin](https://pub.dev/packages/google_maps_flutter)
- [SQLite Docs](https://www.sqlite.org/docs.html)

---

For more information or issues, please create a GitHub issue or contact the development team.
