import 'dart:math';

import 'card.dart';

class Deck {
  final List<GameCard> _cards;
  int _position = 0;

  Deck({Random? random})
    : _cards = List.generate(100, (i) => GameCard(100 - i)) {
    _cards.shuffle(random);
  }

  int get cardsRemaining => _cards.length - _position;

  /// Deals an uneven number of cards to each player.
  /// [countsPerPlayer] specifies how many cards each player gets.
  List<List<GameCard>> dealUneven(List<int> countsPerPlayer) {
    final needed = countsPerPlayer.fold<int>(0, (sum, c) => sum + c);
    if (needed > cardsRemaining) {
      throw StateError(
        'Cannot deal $needed cards — only $cardsRemaining remain',
      );
    }
    return List.generate(countsPerPlayer.length, (playerIndex) {
      return List.generate(
        countsPerPlayer[playerIndex],
        (_) => _cards[_position++],
      );
    });
  }

  List<List<GameCard>> deal(int cardsPerPlayer, int playerCount) {
    final needed = cardsPerPlayer * playerCount;
    if (needed > cardsRemaining) {
      throw StateError(
        'Cannot deal $needed cards — only $cardsRemaining remain',
      );
    }
    return List.generate(playerCount, (playerIndex) {
      return List.generate(cardsPerPlayer, (_) => _cards[_position++]);
    });
  }
}
