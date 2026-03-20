import 'dart:math';

import 'package:countdown_core/countdown_core.dart';

abstract class Bot {
  final String playerId;
  Bot(this.playerId);

  /// Returns the card this bot wants to play next, or null if it passes.
  GameCard? chooseCard(GameEngine engine);
}

/// Plays only when it holds the globally highest card — always correct.
class OptimalBot extends Bot {
  OptimalBot(super.playerId);

  @override
  GameCard? chooseCard(GameEngine engine) {
    final player = engine.state.players.firstWhere((p) => p.id == playerId);
    final myHighest = player.hand.highest;
    if (myHighest == null) return null;
    final globalHighest = engine.currentHighestCard();
    return myHighest == globalHighest ? myHighest : null;
  }
}

/// Normally waits until it holds the globally highest card, but with
/// [errorRate] probability plays its own highest card prematurely.
class FallibleBot extends Bot {
  final double errorRate;
  final Random _rng;

  FallibleBot(super.playerId, {this.errorRate = 0.4, Random? rng})
    : _rng = rng ?? Random();

  @override
  GameCard? chooseCard(GameEngine engine) {
    final player = engine.state.players.firstWhere((p) => p.id == playerId);
    final myHighest = player.hand.highest;
    if (myHighest == null) return null;

    final globalHighest = engine.currentHighestCard();
    if (myHighest == globalHighest) {
      // It's legitimately our turn — always play correctly
      return myHighest;
    }

    // It's someone else's turn — play anyway with errorRate probability
    return _rng.nextDouble() < errorRate ? myHighest : null;
  }
}
