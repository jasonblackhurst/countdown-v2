# Countdown

A cooperative card game based on [The Mind](https://boardgamegeek.com/boardgame/244992/the-mind), played in **descending order from 100 to 1**. Players silently synchronize to play cards in the correct order — no talking, no signals, just vibes.

## Status

All three phases complete.

| Phase | Package | Status | Tests |
|---|---|---|---|
| 1 | `countdown_core` — game engine | ✅ Done | 13 |
| 1 | `countdown_console` — bot simulation | ✅ Done | 2 |
| 2 | `countdown_server` — WebSocket backend | ✅ Done | 13 |
| 3 | `countdown_flutter` — cross-platform client | ✅ Done | 16 |

**44 tests total, all passing.**

## Project Structure

```
countdown/
  packages/
    countdown_core/      # Pure Dart — game engine reused by server and Flutter
    countdown_console/   # CLI runner with OptimalBot and FallibleBot simulation
  apps/
    countdown_server/    # Dart + shelf WebSocket backend
    countdown_flutter/   # Flutter client (iOS, Android, macOS, Windows, Linux, Web)
```

## Quick Start

### 1. Start the server

```bash
cd apps/countdown_server
dart run bin/server.dart
# Countdown server listening on ws://localhost:8080/ws
```

### 2. Run the Flutter app

```bash
cd apps/countdown_flutter
flutter run -d macos      # or -d chrome, -d ios, etc.
```

Two players open the app on separate devices (or windows), one taps **Create Room**, shares the 4-letter code, the other taps **Join Room**. The host taps **Start Game**, everyone votes on card count, and you play.

### 3. Pile viewer mode

A third device can join as a read-only pile viewer — large-format display of the last played card, suited for a shared screen. Set `pileViewerMode: true` in `CountdownApp`.

### 4. Bot simulation (no server needed)

```bash
cd packages/countdown_console
dart run bin/countdown_console.dart optimal    # always wins — plays all 100
dart run bin/countdown_console.dart fallible   # loses lives — tests game-over path
```

## Game Rules

- Single deck: cards **100 down to 1**, never reshuffled
- Each round: all players vote on how many cards they each get; the round uses the **minimum** vote
- **Win:** all 100 cards discarded in descending order
- **Lose:** all 5 lives exhausted
- A life is lost when a player plays a card that is not the current highest card held by any player
- No throwing stars, no life recovery

## Running Tests

```bash
# Game engine
cd packages/countdown_core && dart test

# Bot simulation
cd packages/countdown_console && dart test

# WebSocket server
cd apps/countdown_server && dart test

# Flutter client
cd apps/countdown_flutter && flutter test
```

## Architecture

### `countdown_core` (packages/countdown_core)

Pure Dart — no Flutter dependency. Exports:

- `GameCard`, `Deck`, `Hand`, `Player`, `GameState`, `GameConfig` — models
- `GameEngine` — `startGame`, `startRound`, `playCard`, `currentHighestCard`
- `PlayResult` — `valid | invalid | gameOver | win`

Imported as a path dependency by both the server and the Flutter app.

### `countdown_server` (apps/countdown_server)

Dart + `shelf` + `shelf_web_socket`. Responsibilities:

- `RoomManager` — creates rooms with unique 4-char codes
- `Room` — holds connected WebSocket sinks, maps UUIDs ↔ engine player IDs, runs card-count voting, broadcasts `state_update` snapshots after every state change
- `Protocol` — sealed `ClientMessage` types; JSON serialisers for server→client messages
- Server is **authoritative** — validates every `play_card` server-side, never trusts clients

### `countdown_flutter` (apps/countdown_flutter)

Flutter targeting iOS, Android, macOS, Windows, Linux, Web.

- `GameClient` (`ChangeNotifier`) — `MessageSink` abstraction keeps WebSocket code out of tests; parses incoming JSON and exposes `ClientState` via `notifyListeners`
- `CountdownApp` — state-driven screen switcher: Home → Lobby → Game, driven by `ClientState.phase`
- No game logic in the client — server is the single source of truth

### Screens

| Screen | Description |
|---|---|
| `HomeScreen` | Create or join a room |
| `LobbyScreen` | Wait for players; host starts game; all players vote on card count per round |
| `GameScreen` | Hand grid (tap to play), lives indicator, last played card, round info, win/lose banners |
| `PileScreen` | Read-only full-screen last-played card display for a dedicated pile-viewer device |

## WebSocket Protocol

**Client → Server**

```json
{"type": "create_room"}
{"type": "join_room", "room_code": "ABCD", "name": "Alice"}
{"type": "start_game"}
{"type": "vote_card_count", "count": 3}
{"type": "play_card", "value": 72}
```

**Server → Client**

```json
{"type": "room_created", "room_code": "ABCD", "player_id": "uuid"}
{"type": "room_joined",  "room_code": "ABCD", "player_id": "uuid"}
{"type": "state_update", "state": {
    "phase": "round",
    "lives": 4,
    "round_number": 2,
    "discard_pile": [100, 99, 97],
    "players": [
      {"id": "uuid", "name": "Alice", "hand_size": 2, "hand": [85, 61]},
      {"id": "uuid", "name": "Bob",   "hand_size": 3, "hand": []}
    ]
}}
{"type": "error", "message": "Room ZZZZ not found"}
```

Each player only receives their own hand values in the `hand` array; other players' `hand` arrays are empty.
