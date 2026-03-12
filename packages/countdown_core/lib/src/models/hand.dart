import 'card.dart';

class Hand {
  final List<GameCard> _cards;

  Hand(List<GameCard> cards) : _cards = List.of(cards);

  List<GameCard> get cards => List.unmodifiable(_cards);

  GameCard? get highest =>
      _cards.isEmpty ? null : _cards.reduce((a, b) => a.value > b.value ? a : b);

  bool remove(GameCard card) => _cards.remove(card);

  bool get isEmpty => _cards.isEmpty;
}
