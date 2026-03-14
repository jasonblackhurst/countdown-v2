import 'dart:math';

import 'models/card.dart';
import 'models/deck.dart';
import 'models/game_state.dart';
import 'models/hand.dart';
import 'models/player.dart';

enum PlayResult { valid, invalid, gameOver, win }

class GameEngine {
  late GameState state;

  void startGame(List<String> playerNames, {Random? random}) {
    final players = playerNames
        .asMap()
        .entries
        .map((e) => Player(id: 'player_${e.key}', name: e.value))
        .toList();

    state = GameState(
      lives: 5,
      deck: Deck(random: random),
      players: players,
      phase: GamePhase.lobby,
    );
  }

  void startRound(int cardsPerPlayer) {
    final needed = cardsPerPlayer * state.players.length;
    if (needed > state.deck.cardsRemaining) {
      throw StateError(
        'Cannot start round: need $needed cards but only '
        '${state.deck.cardsRemaining} remain',
      );
    }

    final hands = state.deck.deal(cardsPerPlayer, state.players.length);
    for (var i = 0; i < state.players.length; i++) {
      state.players[i].hand = Hand(hands[i]);
    }

    state.roundNumber++;
    state.phase = GamePhase.round;
  }

  GameCard? currentHighestCard() {
    GameCard? highest;
    for (final player in state.players) {
      final card = player.hand.highest;
      if (card != null && (highest == null || card.value > highest.value)) {
        highest = card;
      }
    }
    return highest;
  }

  int cardsRemaining() => state.deck.cardsRemaining;

  PlayResult playCard(String playerId, GameCard card) {
    final player = state.players.firstWhere(
      (p) => p.id == playerId,
      orElse: () => throw ArgumentError('Unknown player: $playerId'),
    );

    if (!player.hand.cards.contains(card)) {
      throw ArgumentError('Player $playerId does not hold $card');
    }

    final highest = currentHighestCard();
    if (highest == null || card.value != highest.value) {
      // Wrong card played
      player.hand.remove(card);
      state.discardPile.add(card);
      state.lives--;

      if (state.lives <= 0) {
        state.phase = GamePhase.gameOver;
        return PlayResult.gameOver;
      }
      return PlayResult.invalid;
    }

    // Correct card
    player.hand.remove(card);
    state.discardPile.add(card);

    if (state.discardPile.length == 100) {
      state.phase = GamePhase.won;
      return PlayResult.win;
    }

    return PlayResult.valid;
  }
}
