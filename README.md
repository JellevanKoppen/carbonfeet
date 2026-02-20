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
  --dart-define=CARBONFEET_REMOTE_STATE_TOKEN=your-token \
  --dart-define=CARBONFEET_REMOTE_API_VERSION=2026-02 \
  --dart-define=CARBONFEET_REMOTE_USE_ENVELOPE=true
```

Notes:
- If remote mode is enabled but `CARBONFEET_REMOTE_BASE_URL` is empty/invalid, the app falls back to local repository mode.
- `CARBONFEET_REMOTE_API_VERSION` is optional; when set, the app sends `x-carbonfeet-api-version` on remote requests.
- `CARBONFEET_REMOTE_USE_ENVELOPE=true` makes `PUT` payloads use `{ "state": ... }` instead of sending raw state JSON.
- `GET` accepts both payload shapes:
  - raw `PersistedAppState` JSON
  - envelope JSON with `{ "state": ..., "session": ... }`
- Remote session tokens are restored and persisted locally through `SharedPreferencesRemoteSessionStore` and can rotate via:
  - response body `session.accessToken`/`session.expiresAt`
  - response headers `x-carbonfeet-access-token` (or `x-carbonfeet-session-token`) + `x-carbonfeet-session-expires-at`
