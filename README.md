# Countdown

A cooperative card game based on [The Mind](https://boardgamegeek.com/boardgame/244992/the-mind), played in **descending order from 100 to 1**. Players silently synchronize to play cards in the correct order — no talking, no signals, just vibes.

## Status

All three phases complete and playable end-to-end.

| Phase | Package | Status | Tests |
|---|---|---|---|
| 1 | `countdown_core` — game engine | ✅ Done | 13 |
| 1 | `countdown_console` — bot simulation | ✅ Done | 2 |
| 2 | `countdown_server` — WebSocket backend | ✅ Done | 17 |
| 3 | `countdown_flutter` — cross-platform client | ✅ Done | 17 |

**49 tests total, all passing.**

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

### 2. Play in the browser (recommended for multi-player on one machine)

```bash
cd apps/countdown_flutter
flutter build web
python3 -m http.server 8081 --directory build/web
# open http://localhost:8081 in multiple windows
```

Open three browser windows at `http://localhost:8081`:
- **Window 1**: tap **Create Room**, note the 4-letter code
- **Windows 2 & 3**: tap **Join Room**, enter the code and a name
- **Window 1 (host)**: tap **Start Game** once all players appear
- All players vote on cards per player → round begins → tap cards to play

### 3. Run the Flutter app natively (macOS)

```bash
cd apps/countdown_flutter
flutter run -d macos
```

### 4. Pile viewer mode

A device can join as a read-only full-screen pile viewer (no hand, no play button). Set `pileViewerMode: true` in `CountdownApp` — useful for a shared display showing the last played card.

### 5. Bot simulation (no server needed)

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
cd packages/countdown_core    && dart test
cd packages/countdown_console && dart test
cd apps/countdown_server      && dart test
cd apps/countdown_flutter     && flutter test
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

- `RoomManager` — creates rooms with unique 4-char codes; removes empty rooms on disconnect
- `Room` — holds connected WebSocket sinks, maps UUIDs ↔ engine player IDs, runs card-count voting, broadcasts personalized `state_update` snapshots (each player sees their own hand values, others get `[]`). Broadcasts a pre-game lobby snapshot on every `addPlayer` so the player list updates live. Resets phase to `lobby` after all hands are empty so players can vote for the next round.
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
| `LobbyScreen` | Shows live player list as people join; host starts game; all players vote on card count per round (and between rounds) |
| `GameScreen` | Hand grid (tap to play), lives indicator, last played card, round info, win/lose banners |
| `PileScreen` | Read-only full-screen last-played card display for a dedicated pile-viewer device |

### LobbyScreen state logic

| `phase` | `roundNumber` | What shows |
|---|---|---|
| `lobby` | 0 | Player list + **Start Game** button |
| `lobby` | > 0 | Player list + vote chips (between rounds) |
| `round` | any | Player list + vote chips (mid-round, shouldn't normally occur) |

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

Each player only receives their own hand values in the `hand` array; other players' `hand` arrays are always empty. The pre-game lobby snapshot uses the same `state_update` shape with `phase: "lobby"` and `hand_size: 0`.
