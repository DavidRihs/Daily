# Daily — Standup meeting organizer

A Flutter web app for running daily standups: multiple meetings, per-person timers, and markdown notes shared across all browsers via a central Dart server.

---

## Production deployment

**Prerequisites:** Docker only — no Flutter or Dart SDK needed on the host.

```bash
docker compose up -d --build --force-recreate
```

The app is available at **http://localhost:8080**.

The Docker build handles everything: Flutter web compilation and Dart server compilation run inside the container. To update after a code change, run the same command again.

To change the pinned Flutter version, edit the `FLUTTER_VERSION` build arg at the top of the `Dockerfile`.

---

## Local development

**Prerequisites:** Flutter SDK, Dart SDK

```bash
# Install dependencies
flutter pub get
cd server && dart pub get && cd ..

# Start the API server (port 8080)
dart run server/bin/server.dart

# In a second terminal, start the Flutter dev server
flutter run -d chrome
```

The Flutter dev server runs on a random port and automatically targets the API on `localhost:8080`.

---

## Server environment variables

| Variable | Default | Description |
|---|---|---|
| `PORT` | `8080` | Port the server listens on |
| `STATIC_PATH` | `../build/web` | Path to the Flutter web build output |
| `DATA_PATH` | `meetings.json` | Path to the JSON data file |

---

## Data

Meeting data is stored in a single JSON file. In Docker it lives in the named volume `daily-data` and persists across container restarts and rebuilds.

Manual backup:
```bash
docker run --rm \
  -v daily_daily-data:/data \
  -v $(pwd):/backup \
  alpine tar czf /backup/meetings-$(date +%F).tar.gz /data
```
