# Countdown — Project Instructions for Claude

## What This Is

A cooperative card game based on The Mind, played in **descending order from 100 to 1**.
Players silently synchronize to play cards in the correct order across multiple rounds.

## Project Structure

```
countdown/
  packages/
    countdown_core/      # Pure Dart game engine — shared by server and Flutter
    countdown_console/   # CLI runner with bot simulation
  apps/
    countdown_server/    # WebSocket backend (Dart + shelf)
    countdown_flutter/   # Cross-platform Flutter client
```

## Build & Test

```bash
# Run all tests in a package
dart test                          # in packages/countdown_core or countdown_console
dart test                          # in apps/countdown_server
flutter test                       # in apps/countdown_flutter

# Run the console bot simulation
dart run bin/countdown_console.dart optimal   # always wins
dart run bin/countdown_console.dart fallible  # loses lives

# Start the server
dart run bin/server.dart           # in apps/countdown_server (default port 8080)

# Build and serve Flutter web (for browser testing)
cd apps/countdown_flutter && flutter build web
python3 -m http.server 8081 --directory build/web

# Run the Flutter app (macOS native)
flutter run -d macos               # in apps/countdown_flutter
```

## Game Rules

- Single deck: cards 100 down to 1 (no reshuffling ever)
- Each round: players vote on how many cards each player gets; the round uses the minimum vote
- Win: all 100 cards played in descending order (100 discarded total)
- Lose: all 5 lives exhausted
- A life is lost when a player plays a card that is **not** the current highest card held by any player
- No throwing stars, no life recovery

## Architecture Decisions

- **`countdown_core` is the single source of truth** for all game logic. The server imports it as a path dependency; the Flutter client does too (for types/enums only — logic stays server-side).
- **Server is authoritative**: the Flutter client sends intent messages and renders `state_update` snapshots. It never makes game decisions locally.
- **`MessageSink` abstraction** in `GameClient` keeps WebSocket code out of Flutter tests — tests inject a `_FakeSink` and a plain `StreamController<String>`.
- **`PlayResult.invalid`** still consumes the wrongly played card (discarded, life lost). The card does not return to the player's hand.
- **`OptimalBot`** plays only when it holds the globally highest card — skipping its turn otherwise. This ensures it never plays out of turn.
- **`FallibleBot`** plays its own highest card with `errorRate` probability even when it's not the global highest — this is what causes life loss.
- **Card-count voting**: round uses the minimum of all player votes (safe against deck exhaustion).
- **Pre-game lobby broadcasts**: `addPlayer` calls `_broadcastLobbyState()` immediately after adding the player, so all connected clients see the updated player list in real time. Before the engine is initialized, this uses a hand-built JSON snapshot from `_pendingPlayers` rather than the engine state.
- **Between-rounds state**: after all hands are empty and `playCard` returns `valid`, `Room` resets `phase` to `lobby`. The Flutter `LobbyScreen` detects between-rounds via `roundNumber > 0 && phase == lobby` and shows vote chips instead of the Start Game button.
- **Per-player hand serialization**: `stateUpdateMsg` takes an optional `localEnginePlayerId`; `_broadcastState` iterates connections individually and passes each player's engine ID so they receive their own card values. Other players' `hand` arrays are always empty.
- **macOS sandbox**: both `DebugProfile.entitlements` and `Release.entitlements` need `com.apple.security.network.client` for the app to open WebSocket connections. The scaffold only includes `network.server` by default.

## Known Gotchas

- **Port 8080 in use**: the old server process may still be running. `lsof -ti:8080 | xargs kill -9` before restarting.
- **Web build required for browser testing**: `flutter run -d chrome` works for development but the built web app at port 8081 is needed for multi-window play (each window is an independent client).
- **`_started` flag prevents rejoining**: once `startGame` is called, `addPlayer` throws. There is no rejoin-by-player-ID flow yet.

## WebSocket Protocol

All messages are JSON. Client → Server:

| type | fields |
|---|---|
| `create_room` | — |
| `join_room` | `room_code`, `name` |
| `start_game` | — |
| `vote_card_count` | `count` |
| `play_card` | `value` |

Server → Client:

| type | fields |
|---|---|
| `room_created` | `room_code`, `player_id` |
| `room_joined` | `room_code`, `player_id` |
| `state_update` | `state` (full snapshot) |
| `error` | `message` |

`state_update` shape:
```json
{
  "phase": "lobby|round|gameOver|won",
  "lives": 5,
  "round_number": 0,
  "discard_pile": [100, 99],
  "players": [
    {"id": "uuid", "name": "Alice", "hand_size": 2, "hand": [85, 61]},
    {"id": "uuid", "name": "Bob",   "hand_size": 2, "hand": []}
  ]
}
```

Each player receives their own `hand` values; all others get `[]`.

## Development Practices

Follow the global CLAUDE.md TDD rules. All new features need:
1. Failing tests written first
2. Implementation to make them pass
3. No skipping tests because "similar code is untested elsewhere"
