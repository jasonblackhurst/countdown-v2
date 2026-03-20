import 'dart:math';

import 'package:countdown_console/countdown_console.dart';
import 'package:countdown_core/countdown_core.dart';

/// Simulates a full game with the given bots.
///
/// [botType] is either 'optimal' or 'fallible'.
void simulate(String botType, {int playerCount = 2}) {
  final engine = GameEngine();
  final names = List.generate(playerCount, (i) => 'Player${i + 1}');
  engine.startGame(names);

  final bots = engine.state.players.map((p) {
    return botType == 'optimal' ? OptimalBot(p.id) as Bot : FallibleBot(p.id);
  }).toList();

  print('=== Countdown (Descending) — $botType bots, $playerCount players ===');

  final rng = Random();
  var roundNumber = 0;

  while (engine.state.phase != GamePhase.gameOver &&
      engine.state.phase != GamePhase.won) {
    final remaining = engine.cardsRemaining();
    if (remaining == 0) {
      // No cards left to deal — game should have ended
      break;
    }

    // Bots agree on a random card count between 1 and min(5, remaining/players)
    final maxPerPlayer = (remaining / playerCount).floor().clamp(1, 5);
    final cardsPerPlayer = rng.nextInt(maxPerPlayer) + 1;

    roundNumber++;
    engine.startRound(cardsPerPlayer);
    print(
      '\n--- Round $roundNumber | $cardsPerPlayer card(s)/player | '
      '${engine.cardsRemaining()} remaining | Lives: ${engine.state.lives} ---',
    );

    // Bots take turns playing one card at a time until all hands are empty
    var anyPlayed = true;
    while (anyPlayed) {
      anyPlayed = false;

      for (final bot in bots) {
        if (engine.state.phase == GamePhase.gameOver ||
            engine.state.phase == GamePhase.won)
          break;

        final card = bot.chooseCard(engine);
        if (card == null) continue;

        final result = engine.playCard(bot.playerId, card);
        anyPlayed = true;

        final marker = switch (result) {
          PlayResult.valid => '✓',
          PlayResult.invalid => '✗ (-1 life)',
          PlayResult.gameOver => '✗ GAME OVER',
          PlayResult.win => '★ WIN',
        };
        print(
          '  ${bot.runtimeType}[${bot.playerId}] plays ${card.value} → $marker',
        );

        if (result == PlayResult.gameOver || result == PlayResult.win) break;
      }
    }
  }

  print('\n=== Result: ${engine.state.phase.name.toUpperCase()} ===');
  print('Rounds played: $roundNumber');
  print('Cards discarded: ${engine.state.discardPile.length}');
  print('Lives remaining: ${engine.state.lives}');
}

void main(List<String> args) {
  final botType = args.isNotEmpty ? args[0] : 'optimal';
  final playerCount = args.length > 1 ? int.parse(args[1]) : 2;
  simulate(botType, playerCount: playerCount);
}
