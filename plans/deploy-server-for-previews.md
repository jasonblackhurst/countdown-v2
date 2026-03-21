# Plan: Deploy Game Server for Playable PR Previews

## Context

The PR preview and main GitHub Pages deployments only build the Flutter web app as a static site. The app hardcodes `ws://localhost:8080/ws`, so it can't connect to any server when hosted on GitHub Pages. Neither deployment is actually playable. We need to:

1. Deploy the Dart WebSocket server somewhere publicly accessible
2. Make the Flutter app's server URL configurable at build time
3. Update both deploy workflows to point builds at the deployed server

---

## Recommended Approach: Fly.io + `--dart-define`

### Why Fly.io

- Free tier supports an always-on machine (shared-cpu-1x, 256MB) — no cold starts
- Automatic TLS on `*.fly.dev` — browsers require `wss://` from HTTPS pages (GitHub Pages)
- Native Docker support — Dockerfile already exists
- CLI deploys integrate into GitHub Actions via `superfly/flyctl-actions`

### Alternative: Render

- Also free, also has Docker + auto-TLS on `*.onrender.com`
- **Downside**: free tier spins down after 15 min idle, causing 30-60s cold starts on first WebSocket connect — poor UX for the first player joining

---

## Changes

### 1. Fix the Dockerfile for monorepo path dependencies

**File:** `apps/countdown_server/Dockerfile`

Current Dockerfile only copies the server directory, but `countdown_core` is a path dependency at `../../packages/countdown_core`. Build must be run from repo root.

```dockerfile
FROM dart:stable AS build
WORKDIR /app
COPY packages/countdown_core packages/countdown_core
COPY apps/countdown_server apps/countdown_server
WORKDIR /app/apps/countdown_server
RUN dart pub get
RUN dart compile exe bin/server.dart -o /app/bin/server

FROM scratch
COPY --from=build /runtime/ /
COPY --from=build /app/bin/server /app/bin/
EXPOSE 8080
CMD ["/app/bin/server"]
```

### 2. Make WebSocket URL configurable in Flutter

**File:** `apps/countdown_flutter/lib/main.dart`

Replace hardcoded URI with compile-time constant:

```dart
const wsUrl = String.fromEnvironment(
  'WS_URL',
  defaultValue: 'ws://localhost:8080/ws',
);
// ... Uri.parse(wsUrl) passed to CountdownApp
```

- `flutter build web --dart-define=WS_URL=wss://countdown-server.fly.dev/ws` bakes in the production URL
- `flutter run` with no define uses `ws://localhost:8080/ws` (local dev unchanged)

### 3. Add `fly.toml` at repo root

```toml
app = "countdown-server"
primary_region = "ord"

[build]
  dockerfile = "apps/countdown_server/Dockerfile"

[http_service]
  internal_port = 8080
  force_https = true
  auto_stop_machines = false
  auto_start_machines = true
  min_machines_running = 1

[[vm]]
  size = "shared-cpu-1x"
  memory = "256mb"
```

### 4. New workflow: `deploy-server.yml`

Deploys server to Fly.io when server or core code changes on main:

```yaml
on:
  push:
    branches: [main]
    paths:
      - 'apps/countdown_server/**'
      - 'packages/countdown_core/**'
  workflow_dispatch:
```

Requires `FLY_API_TOKEN` repository secret.

### 5. Update `pr-preview.yml` build command

Add `--dart-define=WS_URL=wss://countdown-server.fly.dev/ws` to the `flutter build web` step.

### 6. Update `deploy-pages.yml` build command

Same `--dart-define` addition.

---

## Files to modify

| # | File | Change |
|---|------|--------|
| 1 | `apps/countdown_server/Dockerfile` | Restructure for monorepo path deps |
| 2 | `apps/countdown_flutter/lib/main.dart` | `String.fromEnvironment` for WS_URL |
| 3 | `fly.toml` (new) | Fly.io app config |
| 4 | `.github/workflows/deploy-server.yml` (new) | Server deploy on main push |
| 5 | `.github/workflows/pr-preview.yml` | Add `--dart-define` to build |
| 6 | `.github/workflows/deploy-pages.yml` | Add `--dart-define` to build |

## Files NOT changed

- Server code (`server.dart`, `room.dart`, etc.) — no changes needed
- `app_navigator.dart` — already reads `serverUri` from widget prop
- Widget/golden tests — use fake state, don't touch WebSocket

---

## Manual setup (one-time, before merging)

1. Install `flyctl` locally
2. `fly launch` from repo root (creates app, picks region)
3. `fly deploy` to verify it works
4. `curl https://countdown-server.fly.dev/health` → `ok`
5. Add `FLY_API_TOKEN` secret to GitHub repo settings

---

## Verification

1. **Local dev** — `flutter run -d chrome` still connects to `ws://localhost:8080/ws` (no `--dart-define`)
2. **Docker build** — `docker build -f apps/countdown_server/Dockerfile .` from repo root succeeds
3. **Fly health** — `curl https://countdown-server.fly.dev/health` returns `ok`
4. **Fly WebSocket** — `websocat wss://countdown-server.fly.dev/ws` connects
5. **PR preview** — open PR, wait for deploy, open preview URL, create room → room code appears
6. **Main deploy** — after merge, GitHub Pages site connects to server
7. **All existing tests** — `dart test`, `flutter test` pass unchanged
