import 'card.dart';
import 'hand.dart';

class Player {
  final String id;
  final String name;
  Hand hand;

  Player({required this.id, required this.name, List<GameCard>? cards})
      : hand = Hand(cards ?? []);
}
