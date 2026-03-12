import 'package:countdown_core/countdown_core.dart';
import 'package:test/test.dart';

void main() {
  // ── Deck ──────────────────────────────────────────────────────────────────

  group('Deck', () {
    test('1. initializes with exactly 100 cards, values 100 down to 1', () {
      final deck = Deck();
      expect(deck.cardsRemaining, 100);

      // Deal all cards to one player to inspect order
      final hands = deck.deal(100, 1);
      final values = hands.first.map((c) => c.value).toList();
      expect(values, List.generate(100, (i) => 100 - i));
    });

    test('2. deal(n, playerCount) takes the next n*playerCount cards from the front', () {
      final deck = Deck();
      final hands = deck.deal(3, 2); // 6 cards total
      // Player 0 gets positions 0,1,2 (values 100,99,98)
      expect(hands[0].map((c) => c.value).toList(), [100, 99, 98]);
      // Player 1 gets positions 3,4,5 (values 97,96,95)
      expect(hands[1].map((c) => c.value).toList(), [97, 96, 95]);
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
      engine.startGame(['Alice', 'Bob']);
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
      // After dealing 6 cards (100,99,98 | 97,96,95), highest is 100
      expect(engine.currentHighestCard()?.value, 100);
    });

    test('8. playing the correct card (highest) returns PlayResult.valid', () {
      engine.startRound(1);
      // Alice gets card 100, Bob gets card 99
      final alice = engine.state.players[0];
      final highest = engine.currentHighestCard()!;
      final result = engine.playCard(alice.id, highest);
      expect(result, PlayResult.valid);
    });

    test('9. playing correct card decrements hand and adds to discard', () {
      engine.startRound(1);
      final alice = engine.state.players[0];
      final highest = engine.currentHighestCard()!;
      engine.playCard(alice.id, highest);
      expect(alice.hand.isEmpty, isTrue);
      expect(engine.state.discardPile.length, 1);
      expect(engine.state.discardPile.first, highest);
    });

    test('10. playing incorrect card returns PlayResult.invalid and decrements lives', () {
      engine.startRound(2);
      // Bob holds cards at positions 3,4 → values 97,96; neither is the highest (100)
      final bob = engine.state.players[1];
      final highest = engine.currentHighestCard()!;
      final wrongCard = bob.hand.cards.firstWhere((c) => c != highest);

      final result = engine.playCard(bob.id, wrongCard);
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
      engine.startRound(2); // deals positions 0–3 (values 100,99,98,97)
      final round1Cards = engine.state.players
          .expand((p) => p.hand.cards)
          .map((c) => c.value)
          .toSet();

      engine.startRound(2); // deals positions 4–7 (values 96,95,94,93)
      final round2Cards = engine.state.players
          .expand((p) => p.hand.cards)
          .map((c) => c.value)
          .toSet();

      expect(round1Cards.intersection(round2Cards), isEmpty);
      expect(engine.cardsRemaining(), 92); // 100 - 4 - 4
    });
  });
}
