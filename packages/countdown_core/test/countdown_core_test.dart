import 'dart:math';

import 'package:countdown_core/countdown_core.dart';
import 'package:test/test.dart';

void main() {
  // ── Deck ──────────────────────────────────────────────────────────────────

  group('Deck', () {
    test('1. initializes with exactly 100 unique cards valued 1–100', () {
      final deck = Deck();
      expect(deck.cardsRemaining, 100);

      // Deal all cards to one player to inspect values
      final hands = deck.deal(100, 1);
      final values = hands.first.map((c) => c.value).toSet();
      expect(values, Set<int>.from(List.generate(100, (i) => i + 1)));
    });

    test('1b. deck is shuffled (non-deterministic order)', () {
      // Two decks with different Random seeds should produce different orders
      final deck1 = Deck(random: Random(1));
      final deck2 = Deck(random: Random(2));
      final values1 = deck1.deal(100, 1).first.map((c) => c.value).toList();
      final values2 = deck2.deal(100, 1).first.map((c) => c.value).toList();
      expect(values1, isNot(equals(values2)));
    });

    test('1c. seeded deck produces deterministic order', () {
      final deck1 = Deck(random: Random(42));
      final deck2 = Deck(random: Random(42));
      final values1 = deck1.deal(100, 1).first.map((c) => c.value).toList();
      final values2 = deck2.deal(100, 1).first.map((c) => c.value).toList();
      expect(values1, equals(values2));
    });

    test('2. deal(n, playerCount) gives each player n unique non-overlapping cards', () {
      final deck = Deck(random: Random(42));
      final hands = deck.deal(3, 2); // 6 cards total
      expect(hands[0].length, 3);
      expect(hands[1].length, 3);
      // No overlap between players
      final set0 = hands[0].map((c) => c.value).toSet();
      final set1 = hands[1].map((c) => c.value).toSet();
      expect(set0.intersection(set1), isEmpty);
    });

    test('3. cardsRemaining reflects correct count after dealing', () {
      final deck = Deck();
      deck.deal(5, 2); // deal 10 cards
      expect(deck.cardsRemaining, 90);
    });

    test('4. cannot deal more cards than remain — throws StateError', () {
      final deck = Deck();
      deck.deal(50, 2); // deal 100 cards — deck now empty
      expect(() => deck.deal(1, 1), throwsStateError);
    });
  });

  // ── GameEngine ────────────────────────────────────────────────────────────

  group('GameEngine', () {
    late GameEngine engine;

    setUp(() {
      engine = GameEngine();
      engine.startGame(['Alice', 'Bob'], random: Random(42));
    });

    test('5. startGame initializes 5 lives and empty discard', () {
      expect(engine.state.lives, 5);
      expect(engine.state.discardPile, isEmpty);
      expect(engine.state.phase, GamePhase.lobby);
    });

    test('6. startRound deals n cards to each player from remaining deck', () {
      engine.startRound(3);
      for (final player in engine.state.players) {
        expect(player.hand.cards.length, 3);
      }
      expect(engine.cardsRemaining(), 94); // 100 - 3*2
    });

    test('7. currentHighestCard returns max card across all hands', () {
      engine.startRound(3);
      final allValues = engine.state.players
          .expand((p) => p.hand.cards)
          .map((c) => c.value);
      expect(engine.currentHighestCard()?.value, allValues.reduce((a, b) => a > b ? a : b));
    });

    test('8. playing the correct card (highest) returns PlayResult.valid', () {
      engine.startRound(1);
      final highest = engine.currentHighestCard()!;
      final holder = engine.state.players.firstWhere(
        (p) => p.hand.cards.contains(highest),
      );
      final result = engine.playCard(holder.id, highest);
      expect(result, PlayResult.valid);
    });

    test('9. playing correct card decrements hand and adds to discard', () {
      engine.startRound(1);
      final highest = engine.currentHighestCard()!;
      final holder = engine.state.players.firstWhere(
        (p) => p.hand.cards.contains(highest),
      );
      engine.playCard(holder.id, highest);
      expect(holder.hand.isEmpty, isTrue);
      expect(engine.state.discardPile.length, 1);
      expect(engine.state.discardPile.first, highest);
    });

    test('10. playing incorrect card returns PlayResult.invalid and decrements lives', () {
      engine.startRound(2);
      final highest = engine.currentHighestCard()!;
      // Find any player holding a card that is not the highest
      final wrongHolder = engine.state.players.firstWhere(
        (p) => p.hand.cards.any((c) => c != highest),
      );
      final wrongCard = wrongHolder.hand.cards.firstWhere((c) => c != highest);

      final result = engine.playCard(wrongHolder.id, wrongCard);
      expect(result, PlayResult.invalid);
      expect(engine.state.lives, 4);
    });

    test('11. playing incorrect card with 1 life remaining returns PlayResult.gameOver', () {
      engine.state.lives = 1;
      engine.startRound(2);
      final bob = engine.state.players[1];
      final highest = engine.currentHighestCard()!;
      final wrongCard = bob.hand.cards.firstWhere((c) => c != highest);

      final result = engine.playCard(bob.id, wrongCard);
      expect(result, PlayResult.gameOver);
      expect(engine.state.lives, 0);
      expect(engine.state.phase, GamePhase.gameOver);
    });

    test('12 & 13. playing the 100th card returns PlayResult.win', () {
      // Pre-fill discard with 99 cards (values 100 down to 2)
      for (var i = 100; i > 1; i--) {
        engine.state.discardPile.add(GameCard(i));
      }
      // Give Alice card 1 (the only card in play)
      final alice = engine.state.players[0];
      alice.hand = Hand([const GameCard(1)]);
      engine.state.players[1].hand = Hand([]);

      final result = engine.playCard(alice.id, const GameCard(1));
      expect(result, PlayResult.win);
      expect(engine.state.discardPile.length, 100);
      expect(engine.state.phase, GamePhase.won);
    });

    test('14. two sequential rounds deal from correct deck position (no overlap, no gap)', () {
      engine.startRound(2);
      final round1Cards = engine.state.players
          .expand((p) => p.hand.cards)
          .map((c) => c.value)
          .toSet();
      expect(round1Cards.length, 4); // 2 cards × 2 players

      engine.startRound(2);
      final round2Cards = engine.state.players
          .expand((p) => p.hand.cards)
          .map((c) => c.value)
          .toSet();
      expect(round2Cards.length, 4);

      expect(round1Cards.intersection(round2Cards), isEmpty);
      expect(engine.cardsRemaining(), 92); // 100 - 4 - 4
    });
  });
}
