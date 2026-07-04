# TrailMate Mobile (Flutter)

**Status: blocked — Flutter SDK is not installed on this machine.**

Phase 0 requires `flutter run` to boot a default app on an emulator. Once the
Flutter SDK (stable channel) and an Android emulator are installed:

```bash
cd mobile
flutter create . --project-name trailmate --org com.saintgits.trailmate --platforms android,ios
flutter pub get
flutter run
```

The folder layout below is pre-created to match the repo structure contract
in `CLAUDE.md` Section 3 (clean architecture):

```
mobile/lib/
├── data/           # dio client, hive adapters, repositories
├── domain/         # models, use-cases
└── presentation/   # screens, widgets, riverpod providers
```

Install Flutter on Windows: https://docs.flutter.dev/get-started/install/windows
(requires Android Studio + SDK for emulator support).
