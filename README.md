# Zuburb Ride (Customer App)

Customer-facing Flutter app for booking on-demand and scheduled rides.

## Features

- Phone authentication with Firebase Auth (OTP flow)
- Map-based pickup/drop selection using Google Maps
- Place autocomplete and route distance support
- Rider discovery and booking flow
- Driver tracking and ride status handling
- Scheduled rides support (including scheduled ride lists)
- Ride completion and rating flow

## Tech Stack

- Flutter (Dart)
- `flutter_bloc` for state management
- Firebase (`firebase_core`, `firebase_auth`, `cloud_firestore`, `firebase_messaging`)
- Google Maps (`google_maps_flutter`)
- Geolocation (`geolocator`)
- HTTP integrations (`http`)
- Geohash utilities (`dart_geohash`)

## Project Structure

- `lib/bloc/` — Cubits/BLoC states and business logic
- `lib/presentation/screens/` — App screens/UI
- `lib/repository/` — Data access and API clients
- `lib/utils/` — Utility helpers (distance, geohash, etc.)
- `android/`, `ios/`, `web/`, `macos/`, `linux/`, `windows/` — platform targets

## Prerequisites

- Flutter SDK (matching project Dart SDK constraint)
- Android Studio / Xcode setup
- Firebase project configured
- Google Maps key configured for Android/iOS

## Setup

1. Install dependencies:

```bash
flutter pub get
```

2. Firebase setup:

- Ensure `android/app/google-services.json` is valid for your Firebase project.
- Ensure iOS Firebase config file is added if building for iOS.

3. Google Maps / API keys:

- Android: key is read via Gradle property `MAPS_API_KEY` (fallback currently exists in app Gradle config).
- Recommended run command:

```bash
flutter run --dart-define=MAPS_API_KEY=YOUR_KEY
```

## Run

```bash
flutter run
```

## Verify

```bash
flutter analyze
flutter test
```

## Firestore Collections (high level)

- `customers` — customer profile, ride linkage fields
- `riders` — rider availability and assignment state
- `rider_locations` — live rider location data
- `rides` — ride lifecycle documents (live and scheduled)

## Notes

- This is the customer app only; rider-side activation/background dispatch logic is handled in the rider app.
- Keep customer/rider Firestore schema changes coordinated between both apps.
