# carbonfeet

A new Flutter project.

## Getting Started

This project is a starting point for a Flutter application.

A few resources to get you started if this is your first Flutter project:

- [Lab: Write your first Flutter app](https://docs.flutter.dev/get-started/codelab)
- [Cookbook: Useful Flutter samples](https://docs.flutter.dev/cookbook)

For help getting started with Flutter development, view the
[online documentation](https://docs.flutter.dev/), which offers tutorials,
samples, guidance on mobile development, and a full API reference.

## Remote State Configuration

The app defaults to local persistence (`LocalAppRepository`).

Enable remote-backed state with `--dart-define` values:

```bash
flutter run \
  --dart-define=CARBONFEET_USE_REMOTE_STATE=true \
  --dart-define=CARBONFEET_REMOTE_BASE_URL=https://api.example.com/v1/ \
  --dart-define=CARBONFEET_REMOTE_STATE_PATH=state \
  --dart-define=CARBONFEET_REMOTE_STATE_TOKEN=your-token
```

Notes:
- If remote mode is enabled but `CARBONFEET_REMOTE_BASE_URL` is empty/invalid, the app falls back to local repository mode.
- Remote client expects `GET` and `PUT` on the configured state path with JSON payloads compatible with `PersistedAppState`.
