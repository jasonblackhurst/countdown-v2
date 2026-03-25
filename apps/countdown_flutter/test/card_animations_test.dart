import 'dart:async';
import 'dart:convert';

import 'package:countdown_flutter/src/client/game_client.dart';
import 'package:countdown_flutter/src/screens/game_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

// ── Test doubles ──────────────────────────────────────────────────────────

class _FakeSink implements MessageSink {
  final List<Map<String, dynamic>> sent = [];
  bool closed = false;

  @override
  void send(String msg) => sent.add(jsonDecode(msg) as Map<String, dynamic>);

  @override
  void close() => closed = true;
}

(_FakeSink, StreamController<String>) connectFake(GameClient client) {
  final sink = _FakeSink();
  final controller = StreamController<String>();
  client.connect(
    Uri.parse('ws://localhost:8080/ws'),
    incomingStream: controller.stream,
    sink: sink,
  );
  return (sink, controller);
}

Map<String, dynamic> _stateUpdate({
  String phase = 'lobby',
  int lives = 5,
  int roundNumber = 0,
  List<int> discardPile = const [],
  List<Map<String, dynamic>>? players,
  bool gameInitialized = false,
  bool isFinalRound = false,
  int cardsRemaining = 100,
}) => {
  'type': 'state_update',
  'state': {
    'phase': phase,
    'lives': lives,
    'round_number': roundNumber,
    'discard_pile': discardPile,
    'game_initialized': gameInitialized,
    'is_final_round': isFinalRound,
    'cards_remaining': cardsRemaining,
    'players':
        players ??
        [
          {'id': 'p1', 'name': 'Alice', 'hand_size': 0, 'hand': []},
          {'id': 'p2', 'name': 'Bob', 'hand_size': 0, 'hand': []},
        ],
  },
};

Widget _wrap(Widget child, GameClient client) => MaterialApp(
  home: ListenableBuilder(listenable: client, builder: (_, _) => child),
);

void main() {
  // ── GameClient previousLives tracking ──────────────────────────────────

  group('GameClient previousLives', () {
    late GameClient client;
    late StreamController<String> controller;

    setUp(() {
      client = GameClient();
      (_, controller) = connectFake(client);
    });

    tearDown(() {
      controller.close();
      client.dispose();
    });

    test('CA1. previousLives is null initially', () {
      expect(client.previousLives, isNull);
    });

    test('CA2. previousLives tracks prior lives after state update', () async {
      controller.add(
        jsonEncode(_stateUpdate(phase: 'round', lives: 5, roundNumber: 1)),
      );
      await Future.microtask(() {});
      expect(client.state.lives, 5);
      expect(client.previousLives, isNull);

      // Life lost
      controller.add(
        jsonEncode(_stateUpdate(phase: 'round', lives: 4, roundNumber: 1)),
      );
      await Future.microtask(() {});
      expect(client.state.lives, 4);
      expect(client.previousLives, 5);
    });

    test('CA3. previousLives stays same when no life change', () async {
      controller.add(
        jsonEncode(
          _stateUpdate(
            phase: 'round',
            lives: 5,
            roundNumber: 1,
            discardPile: [100],
          ),
        ),
      );
      await Future.microtask(() {});

      controller.add(
        jsonEncode(
          _stateUpdate(
            phase: 'round',
            lives: 5,
            roundNumber: 1,
            discardPile: [100, 99],
          ),
        ),
      );
      await Future.microtask(() {});
      expect(client.state.lives, 5);
      expect(client.previousLives, 5);
    });
  });

  // ── Life-loss red flash overlay ────────────────────────────────────────

  group('GameScreen life-loss flash', () {
    testWidgets('CA4. red flash overlay appears when lives decrease', (
      tester,
    ) async {
      final client = GameClient();
      final (_, ctrl) = connectFake(client);

      ctrl.add(
        jsonEncode({
          'type': 'room_joined',
          'room_code': 'ABCD',
          'player_id': 'p1',
        }),
      );
      ctrl.add(
        jsonEncode(
          _stateUpdate(
            phase: 'round',
            lives: 5,
            roundNumber: 1,
            players: [
              {
                'id': 'p1',
                'name': 'Alice',
                'hand_size': 2,
                'hand': [75, 42],
              },
              {'id': 'p2', 'name': 'Bob', 'hand_size': 2, 'hand': []},
            ],
          ),
        ),
      );
      await Future.microtask(() {});

      await tester.pumpWidget(_wrap(GameScreen(client: client), client));
      await tester.pump();

      // No flash initially
      expect(find.byKey(const Key('life-loss-flash')), findsNothing);

      // Life lost
      ctrl.add(
        jsonEncode(
          _stateUpdate(
            phase: 'round',
            lives: 4,
            roundNumber: 1,
            discardPile: [100],
            players: [
              {
                'id': 'p1',
                'name': 'Alice',
                'hand_size': 1,
                'hand': [42],
              },
              {'id': 'p2', 'name': 'Bob', 'hand_size': 2, 'hand': []},
            ],
          ),
        ),
      );
      await Future.microtask(() {});
      await tester.pump();

      // Flash should be visible
      expect(find.byKey(const Key('life-loss-flash')), findsOneWidget);

      // After animation completes, flash should be gone
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.byKey(const Key('life-loss-flash')), findsNothing);

      await ctrl.close();
      client.dispose();
    });

    testWidgets('CA5. no flash when lives stay the same', (tester) async {
      final client = GameClient();
      final (_, ctrl) = connectFake(client);

      ctrl.add(
        jsonEncode({
          'type': 'room_joined',
          'room_code': 'ABCD',
          'player_id': 'p1',
        }),
      );
      ctrl.add(
        jsonEncode(
          _stateUpdate(
            phase: 'round',
            lives: 5,
            roundNumber: 1,
            players: [
              {
                'id': 'p1',
                'name': 'Alice',
                'hand_size': 2,
                'hand': [75, 42],
              },
              {'id': 'p2', 'name': 'Bob', 'hand_size': 2, 'hand': []},
            ],
          ),
        ),
      );
      await Future.microtask(() {});

      await tester.pumpWidget(_wrap(GameScreen(client: client), client));
      await tester.pump();

      // Send update with same lives
      ctrl.add(
        jsonEncode(
          _stateUpdate(
            phase: 'round',
            lives: 5,
            roundNumber: 1,
            discardPile: [100],
            players: [
              {
                'id': 'p1',
                'name': 'Alice',
                'hand_size': 1,
                'hand': [42],
              },
              {'id': 'p2', 'name': 'Bob', 'hand_size': 2, 'hand': []},
            ],
          ),
        ),
      );
      await Future.microtask(() {});
      await tester.pump();

      expect(find.byKey(const Key('life-loss-flash')), findsNothing);

      await ctrl.close();
      client.dispose();
    });
  });

  // ── Discard pile animation ─────────────────────────────────────────────

  group('GameScreen discard pile animation', () {
    testWidgets('CA6. last played card uses AnimatedScale widget', (
      tester,
    ) async {
      final client = GameClient();
      final (_, ctrl) = connectFake(client);

      ctrl.add(
        jsonEncode({
          'type': 'room_joined',
          'room_code': 'ABCD',
          'player_id': 'p1',
        }),
      );
      ctrl.add(
        jsonEncode(
          _stateUpdate(
            phase: 'round',
            lives: 5,
            roundNumber: 1,
            discardPile: [100],
            players: [
              {
                'id': 'p1',
                'name': 'Alice',
                'hand_size': 2,
                'hand': [75, 42],
              },
              {'id': 'p2', 'name': 'Bob', 'hand_size': 2, 'hand': []},
            ],
          ),
        ),
      );
      await Future.microtask(() {});

      await tester.pumpWidget(_wrap(GameScreen(client: client), client));
      await tester.pump();

      // The last played card area should use AnimatedSwitcher for transitions
      expect(find.byKey(const Key('last-played-animated')), findsOneWidget);

      await ctrl.close();
      client.dispose();
    });
  });

  // ── Card tap animation ─────────────────────────────────────────────────

  group('GameScreen card tap animation', () {
    testWidgets(
      'CA7. tapping a card triggers scale-down animation before sending',
      (tester) async {
        final client = GameClient();
        final (sink, ctrl) = connectFake(client);

        ctrl.add(
          jsonEncode({
            'type': 'room_joined',
            'room_code': 'ABCD',
            'player_id': 'p1',
          }),
        );
        ctrl.add(
          jsonEncode(
            _stateUpdate(
              phase: 'round',
              lives: 5,
              roundNumber: 1,
              players: [
                {
                  'id': 'p1',
                  'name': 'Alice',
                  'hand_size': 2,
                  'hand': [75, 42],
                },
                {'id': 'p2', 'name': 'Bob', 'hand_size': 2, 'hand': []},
              ],
            ),
          ),
        );
        await Future.microtask(() {});

        await tester.pumpWidget(_wrap(GameScreen(client: client), client));
        await tester.pump();

        // Tap card 75
        await tester.tap(find.text('75'));
        await tester.pump();

        // The play_card message should be sent
        expect(
          sink.sent.any((m) => m['type'] == 'play_card' && m['value'] == 75),
          isTrue,
        );

        // An AnimatedScale should be present wrapping the cards
        expect(find.byType(AnimatedScale), findsWidgets);

        await ctrl.close();
        client.dispose();
      },
    );
  });

  // ── Lives indicator pulse on life loss ─────────────────────────────────

  group('GameScreen lives indicator animation', () {
    testWidgets('CA8. lives indicator uses AnimatedScale for pulse effect', (
      tester,
    ) async {
      final client = GameClient();
      final (_, ctrl) = connectFake(client);

      ctrl.add(
        jsonEncode({
          'type': 'room_joined',
          'room_code': 'ABCD',
          'player_id': 'p1',
        }),
      );
      ctrl.add(
        jsonEncode(
          _stateUpdate(
            phase: 'round',
            lives: 5,
            roundNumber: 1,
            players: [
              {
                'id': 'p1',
                'name': 'Alice',
                'hand_size': 2,
                'hand': [75, 42],
              },
              {'id': 'p2', 'name': 'Bob', 'hand_size': 2, 'hand': []},
            ],
          ),
        ),
      );
      await Future.microtask(() {});

      await tester.pumpWidget(_wrap(GameScreen(client: client), client));
      await tester.pump();

      // The lives indicator should have an animated key for pulse detection
      expect(find.byKey(const Key('lives-indicator')), findsOneWidget);

      await ctrl.close();
      client.dispose();
    });
  });
}
