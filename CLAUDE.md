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

# Run the Flutter app (macOS)
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

## Development Practices

Follow the global CLAUDE.md TDD rules. All new features need:
1. Failing tests written first
2. Implementation to make them pass
3. No skipping tests because "similar code is untested elsewhere"
