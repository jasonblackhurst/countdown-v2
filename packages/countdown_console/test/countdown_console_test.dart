import 'dart:math';

import 'package:countdown_console/countdown_console.dart';
import 'package:countdown_core/countdown_core.dart';
import 'package:test/test.dart';

/// Runs a full simulated game with the provided bots and returns the final
/// game state.
GameState runGame(GameEngine engine, List<Bot> bots) {
  final rng = Random(42);
  final playerCount = bots.length;

  while (engine.state.phase != GamePhase.gameOver &&
      engine.state.phase != GamePhase.won) {
    final remaining = engine.cardsRemaining();
    if (remaining == 0) break;

    final maxPerPlayer = (remaining / playerCount).floor().clamp(1, 5);
    final cardsPerPlayer = rng.nextInt(maxPerPlayer) + 1;
    engine.startRound(cardsPerPlayer);

    var anyPlayed = true;
    while (anyPlayed) {
      anyPlayed = false;
      for (final bot in bots) {
        if (engine.state.phase == GamePhase.gameOver ||
            engine.state.phase == GamePhase.won)
          break;

        final card = bot.chooseCard(engine);
        if (card == null) continue;

        engine.playCard(bot.playerId, card);
        anyPlayed = true;
      }
    }
  }

  return engine.state;
}

void main() {
  group('Bot simulation (integration)', () {
    test('15. OptimalBot game with 2 players always results in win', () {
      final engine = GameEngine();
      engine.startGame(['Alice', 'Bob']);
      final bots = engine.state.players
          .map((p) => OptimalBot(p.id) as Bot)
          .toList();

      final state = runGame(engine, bots);

      expect(state.phase, GamePhase.won);
      expect(state.discardPile.length, 100);
    });

    test('16. FallibleBot game eventually loses all lives', () {
      // Use a high error rate and fixed seed so the test is deterministic
      final engine = GameEngine();
      engine.startGame(['Alice', 'Bob']);
      final rng = Random(1); // fixed seed → predictable failures
      final bots = engine.state.players
          .map((p) => FallibleBot(p.id, errorRate: 0.6, rng: rng) as Bot)
          .toList();

      final state = runGame(engine, bots);

      expect(state.phase, GamePhase.gameOver);
      expect(state.lives, 0);
    });
  });
}
