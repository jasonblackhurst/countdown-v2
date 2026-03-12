import 'card.dart';

class Deck {
  final List<GameCard> _cards;
  int _position = 0;

  Deck() : _cards = List.generate(100, (i) => GameCard(100 - i));

  int get cardsRemaining => _cards.length - _position;

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
