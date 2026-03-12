import 'card.dart';
import 'deck.dart';
import 'player.dart';

enum GamePhase { lobby, round, gameOver, won }

class GameState {
  int lives;
  final Deck deck;
  final List<Player> players;
  final List<GameCard> discardPile;
  GamePhase phase;
  int roundNumber;

  GameState({
    required this.lives,
    required this.deck,
    required this.players,
    List<GameCard>? discardPile,
    this.phase = GamePhase.lobby,
    this.roundNumber = 0,
  }) : discardPile = discardPile ?? [];
}
