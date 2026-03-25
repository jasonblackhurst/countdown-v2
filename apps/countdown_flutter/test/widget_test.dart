import 'dart:async';
import 'dart:convert';

import 'package:confetti/confetti.dart';
import 'package:countdown_core/countdown_core.dart';
import 'package:countdown_flutter/src/client/game_client.dart';
import 'package:countdown_flutter/src/screens/game_screen.dart';
import 'package:countdown_flutter/src/screens/home_screen.dart';
import 'package:countdown_flutter/src/screens/lobby_screen.dart';
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

  Map<String, dynamic>? lastSent() => sent.isEmpty ? null : sent.last;
}

/// Connects [client] to fake in-memory streams for testing.
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

// ── GameClient unit tests ─────────────────────────────────────────────────

void main() {
  group('GameClient', () {
    late GameClient client;
    late _FakeSink sink;
    late StreamController<String> controller;

    setUp(() {
      client = GameClient();
      (sink, controller) = connectFake(client);
    });

    tearDown(() {
      controller.close();
      client.dispose();
    });

    test('1. connect sets status to connected', () {
      expect(client.state.connectionStatus, ConnectionStatus.connected);
    });

    test('2. room_created message stores roomCode and playerId', () async {
      controller.add(
        jsonEncode({
          'type': 'room_created',
          'room_code': 'ABCD',
          'player_id': 'pid-1',
        }),
      );
      await Future.microtask(() {});
      expect(client.state.roomCode, 'ABCD');
      expect(client.state.playerId, 'pid-1');
    });

    test('3. room_joined message stores roomCode and playerId', () async {
      controller.add(
        jsonEncode({
          'type': 'room_joined',
          'room_code': 'WXYZ',
          'player_id': 'pid-2',
        }),
      );
      await Future.microtask(() {});
      expect(client.state.roomCode, 'WXYZ');
      expect(client.state.playerId, 'pid-2');
    });

    test(
      '4. state_update message applies phase, lives, round, players',
      () async {
        controller.add(
          jsonEncode(
            _stateUpdate(
              phase: 'round',
              lives: 4,
              roundNumber: 2,
              discardPile: [100, 99],
            ),
          ),
        );
        await Future.microtask(() {});
        expect(client.state.phase, GamePhase.round);
        expect(client.state.lives, 4);
        expect(client.state.roundNumber, 2);
        expect(client.state.discardPile, [100, 99]);
        expect(client.state.players, hasLength(2));
      },
    );

    test('5. error message stores lastError', () async {
      controller.add(
        jsonEncode({'type': 'error', 'message': 'Room not found'}),
      );
      await Future.microtask(() {});
      expect(client.state.lastError, 'Room not found');
    });

    test('6. createRoom() sends correct JSON', () {
      client.createRoom();
      expect(sink.lastSent(), {'type': 'create_room'});
    });

    test('7. joinRoom() sends correct JSON', () {
      client.joinRoom('ABCD', 'Alice');
      expect(sink.lastSent(), {
        'type': 'join_room',
        'room_code': 'ABCD',
        'name': 'Alice',
      });
    });

    test('8. startGame() sends correct JSON', () {
      client.startGame();
      expect(sink.lastSent(), {'type': 'start_game'});
    });

    test('9. voteCardCount() sends correct JSON', () {
      client.voteCardCount(3);
      expect(sink.lastSent(), {'type': 'vote_card_count', 'count': 3});
    });

    test('10. playCard() sends correct JSON', () {
      client.playCard(42);
      expect(sink.lastSent(), {'type': 'play_card', 'value': 42});
    });

    test('11. stream close sets status to disconnected', () async {
      await controller.close();
      await Future.microtask(() {});
      expect(client.state.connectionStatus, ConnectionStatus.disconnected);
    });

    test(
      '12. myPlayer returns the snapshot whose id matches playerId',
      () async {
        controller.add(
          jsonEncode({
            'type': 'room_joined',
            'room_code': 'ABCD',
            'player_id': 'p2',
          }),
        );
        await Future.microtask(() {});
        controller.add(jsonEncode(_stateUpdate()));
        await Future.microtask(() {});
        expect(client.state.myPlayer?.name, 'Bob');
      },
    );
  });

  // ── Widget tests ──────────────────────────────────────────────────────────

  Widget wrap(Widget child, GameClient client) => MaterialApp(
    home: ListenableBuilder(listenable: client, builder: (_, _) => child),
  );

  group('HomeScreen', () {
    testWidgets('13. shows Create Room and Join Room buttons', (tester) async {
      final client = GameClient();
      await tester.pumpWidget(wrap(HomeScreen(client: client), client));
      expect(find.text('Create Room'), findsOneWidget);
      expect(find.text('Join Room'), findsOneWidget);
      client.dispose();
    });

    testWidgets('14. tapping Create Room calls client.createRoom()', (
      tester,
    ) async {
      final client = GameClient();
      final (sink, ctrl) = connectFake(client);

      await tester.pumpWidget(wrap(HomeScreen(client: client), client));
      await tester.tap(find.text('Create Room'));
      await tester.pump();

      expect(sink.sent.any((m) => m['type'] == 'create_room'), isTrue);
      await ctrl.close();
      client.dispose();
    });
  });

  group('LobbyScreen', () {
    testWidgets('15. shows room code and player list', (tester) async {
      final client = GameClient();
      final (_, ctrl) = connectFake(client);

      ctrl.add(
        jsonEncode({
          'type': 'room_created',
          'room_code': 'TEST',
          'player_id': 'p1',
        }),
      );
      ctrl.add(
        jsonEncode(
          _stateUpdate(
            players: [
              {'id': 'p1', 'name': 'Alice', 'hand_size': 0, 'hand': []},
            ],
          ),
        ),
      );
      await Future.microtask(() {});

      await tester.pumpWidget(wrap(LobbyScreen(client: client), client));
      await tester.pump();

      expect(find.text('TEST'), findsOneWidget);
      expect(find.text('Alice'), findsOneWidget);
      await ctrl.close();
      client.dispose();
    });
  });

  group('LobbyScreen game_initialized', () {
    testWidgets(
      'A. pre-game (game_initialized: false, 2 players) shows Start Game, not vote UI',
      (tester) async {
        final client = GameClient();
        final (_, ctrl) = connectFake(client);

        ctrl.add(
          jsonEncode({
            'type': 'room_created',
            'room_code': 'ABCD',
            'player_id': 'p1',
          }),
        );
        ctrl.add(
          jsonEncode(
            _stateUpdate(
              phase: 'lobby',
              roundNumber: 0,
              gameInitialized: false,
              players: [
                {'id': 'p1', 'name': 'Alice', 'hand_size': 0, 'hand': []},
                {'id': 'p2', 'name': 'Bob', 'hand_size': 0, 'hand': []},
              ],
            ),
          ),
        );
        await Future.microtask(() {});

        await tester.pumpWidget(wrap(LobbyScreen(client: client), client));
        await tester.pump();

        expect(find.text('Start Game'), findsOneWidget);
        expect(find.text('Confirm Vote'), findsNothing);
        await ctrl.close();
        client.dispose();
      },
    );

    testWidgets(
      'B. post-startGame (game_initialized: true, phase lobby) shows vote UI, not Start Game',
      (tester) async {
        final client = GameClient();
        final (_, ctrl) = connectFake(client);

        ctrl.add(
          jsonEncode({
            'type': 'room_created',
            'room_code': 'ABCD',
            'player_id': 'p1',
          }),
        );
        ctrl.add(
          jsonEncode(
            _stateUpdate(
              phase: 'lobby',
              roundNumber: 0,
              gameInitialized: true,
              players: [
                {'id': 'p1', 'name': 'Alice', 'hand_size': 0, 'hand': []},
                {'id': 'p2', 'name': 'Bob', 'hand_size': 0, 'hand': []},
              ],
            ),
          ),
        );
        await Future.microtask(() {});

        await tester.pumpWidget(wrap(LobbyScreen(client: client), client));
        await tester.pump();

        expect(find.text('Start Game'), findsNothing);
        expect(find.text('Confirm Vote'), findsOneWidget);
        await ctrl.close();
        client.dispose();
      },
    );
  });

  group('LobbyScreen between-rounds', () {
    testWidgets(
      '17. shows vote chips (not Start Game) when roundNumber > 0 and phase is lobby',
      (tester) async {
        final client = GameClient();
        final (_, ctrl) = connectFake(client);

        ctrl.add(
          jsonEncode({
            'type': 'room_created',
            'room_code': 'ABCD',
            'player_id': 'p1',
          }),
        );
        // phase=lobby but roundNumber=1 → between rounds
        ctrl.add(
          jsonEncode(
            _stateUpdate(
              phase: 'lobby',
              roundNumber: 1,
              players: [
                {'id': 'p1', 'name': 'Alice', 'hand_size': 0, 'hand': []},
                {'id': 'p2', 'name': 'Bob', 'hand_size': 0, 'hand': []},
              ],
            ),
          ),
        );
        await Future.microtask(() {});

        await tester.pumpWidget(wrap(LobbyScreen(client: client), client));
        await tester.pump();

        expect(find.text('Start Game'), findsNothing);
        expect(find.text('Confirm Vote'), findsOneWidget);
        await ctrl.close();
        client.dispose();
      },
    );
  });

  group('GameScreen', () {
    testWidgets('16. shows lives, round number, and hand cards', (
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
            lives: 3,
            roundNumber: 2,
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

      await tester.pumpWidget(wrap(GameScreen(client: client), client));
      await tester.pump();

      expect(find.text('3'), findsOneWidget); // lives
      expect(find.text('Round 2'), findsOneWidget);
      expect(find.text('75'), findsOneWidget);
      expect(find.text('42'), findsOneWidget);
      await ctrl.close();
      client.dispose();
    });

    testWidgets('20. shows final-round callout when isFinalRound is true', (
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
            roundNumber: 3,
            isFinalRound: true,
            cardsRemaining: 0,
            players: [
              {
                'id': 'p1',
                'name': 'Alice',
                'hand_size': 3,
                'hand': [10, 5, 2],
              },
              {'id': 'p2', 'name': 'Bob', 'hand_size': 2, 'hand': []},
            ],
          ),
        ),
      );
      await Future.microtask(() {});

      await tester.pumpWidget(wrap(GameScreen(client: client), client));
      await tester.pump();

      expect(
        find.text('Final round! Some players have extra cards.'),
        findsOneWidget,
      );
      await ctrl.close();
      client.dispose();
    });

    testWidgets(
      '21. does NOT show final-round callout when isFinalRound is false',
      (tester) async {
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
              roundNumber: 2,
              isFinalRound: false,
              cardsRemaining: 50,
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

        await tester.pumpWidget(wrap(GameScreen(client: client), client));
        await tester.pump();

        expect(
          find.text('Final round! Some players have extra cards.'),
          findsNothing,
        );
        await ctrl.close();
        client.dispose();
      },
    );
  });

  group('LobbyScreen final-round callout', () {
    testWidgets(
      '22. shows final-round callout when cardsRemaining is low and voting',
      (tester) async {
        final client = GameClient();
        final (_, ctrl) = connectFake(client);

        ctrl.add(
          jsonEncode({
            'type': 'room_created',
            'room_code': 'ABCD',
            'player_id': 'p1',
          }),
        );
        ctrl.add(
          jsonEncode(
            _stateUpdate(
              phase: 'lobby',
              roundNumber: 1,
              gameInitialized: true,
              cardsRemaining: 3, // < 2 * 2 players = 4
              players: [
                {'id': 'p1', 'name': 'Alice', 'hand_size': 0, 'hand': []},
                {'id': 'p2', 'name': 'Bob', 'hand_size': 0, 'hand': []},
              ],
            ),
          ),
        );
        await Future.microtask(() {});

        await tester.pumpWidget(wrap(LobbyScreen(client: client), client));
        await tester.pump();

        expect(find.textContaining('Final round'), findsOneWidget);
        await ctrl.close();
        client.dispose();
      },
    );

    testWidgets(
      '23. does NOT show final-round callout when cardsRemaining is high',
      (tester) async {
        final client = GameClient();
        final (_, ctrl) = connectFake(client);

        ctrl.add(
          jsonEncode({
            'type': 'room_created',
            'room_code': 'ABCD',
            'player_id': 'p1',
          }),
        );
        ctrl.add(
          jsonEncode(
            _stateUpdate(
              phase: 'lobby',
              roundNumber: 1,
              gameInitialized: true,
              cardsRemaining: 50,
              players: [
                {'id': 'p1', 'name': 'Alice', 'hand_size': 0, 'hand': []},
                {'id': 'p2', 'name': 'Bob', 'hand_size': 0, 'hand': []},
              ],
            ),
          ),
        );
        await Future.microtask(() {});

        await tester.pumpWidget(wrap(LobbyScreen(client: client), client));
        await tester.pump();

        expect(find.textContaining('Final round'), findsNothing);
        await ctrl.close();
        client.dispose();
      },
    );
  });

  // ── Play Again / Leave Room ──────────────────────────────────────────────

  group('GameClient play again', () {
    late GameClient client;
    late _FakeSink sink;
    late StreamController<String> controller;

    setUp(() {
      client = GameClient();
      (sink, controller) = connectFake(client);
    });

    tearDown(() {
      controller.close();
      client.dispose();
    });

    test('24. playAgain() sends correct JSON', () {
      client.playAgain();
      expect(sink.lastSent(), {'type': 'play_again'});
    });

    test('25. disconnect() resets state so navigator shows HomeScreen', () {
      // Simulate being in a room
      controller.add(
        jsonEncode({
          'type': 'room_created',
          'room_code': 'ABCD',
          'player_id': 'p1',
        }),
      );

      client.disconnect();
      expect(client.state.roomCode, isNull);
      expect(client.state.connectionStatus, ConnectionStatus.disconnected);
    });
  });

  group('GameScreen play again buttons', () {
    testWidgets('26. shows Play Again button when phase is won', (
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
            phase: 'won',
            lives: 5,
            roundNumber: 10,
            discardPile: List.generate(100, (i) => 100 - i),
            players: [
              {'id': 'p1', 'name': 'Alice', 'hand_size': 0, 'hand': []},
              {'id': 'p2', 'name': 'Bob', 'hand_size': 0, 'hand': []},
            ],
          ),
        ),
      );
      await Future.microtask(() {});

      await tester.pumpWidget(wrap(GameScreen(client: client), client));
      await tester.pump();

      expect(find.text('Play Again'), findsOneWidget);
      expect(find.text('Leave Room'), findsOneWidget);
      await ctrl.close();
      client.dispose();
    });

    testWidgets('27. shows Play Again button when phase is gameOver', (
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
            phase: 'gameOver',
            lives: 0,
            roundNumber: 3,
            players: [
              {'id': 'p1', 'name': 'Alice', 'hand_size': 0, 'hand': []},
              {'id': 'p2', 'name': 'Bob', 'hand_size': 0, 'hand': []},
            ],
          ),
        ),
      );
      await Future.microtask(() {});

      await tester.pumpWidget(wrap(GameScreen(client: client), client));
      await tester.pump();

      expect(find.text('Play Again'), findsOneWidget);
      expect(find.text('Leave Room'), findsOneWidget);
      await ctrl.close();
      client.dispose();
    });

    testWidgets('28. does NOT show Play Again button during active round', (
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

      await tester.pumpWidget(wrap(GameScreen(client: client), client));
      await tester.pump();

      expect(find.text('Play Again'), findsNothing);
      expect(find.text('Leave Room'), findsNothing);
      await ctrl.close();
      client.dispose();
    });

    testWidgets('29. tapping Play Again sends play_again message', (
      tester,
    ) async {
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
            phase: 'won',
            lives: 5,
            roundNumber: 10,
            discardPile: List.generate(100, (i) => 100 - i),
            players: [
              {'id': 'p1', 'name': 'Alice', 'hand_size': 0, 'hand': []},
              {'id': 'p2', 'name': 'Bob', 'hand_size': 0, 'hand': []},
            ],
          ),
        ),
      );
      await Future.microtask(() {});

      await tester.pumpWidget(wrap(GameScreen(client: client), client));
      await tester.pump();

      await tester.tap(find.text('Play Again'));
      await tester.pump();

      expect(sink.sent.any((m) => m['type'] == 'play_again'), isTrue);
      await ctrl.close();
      client.dispose();
    });

    testWidgets('30. tapping Leave Room calls disconnect', (tester) async {
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
            phase: 'gameOver',
            lives: 0,
            roundNumber: 3,
            players: [
              {'id': 'p1', 'name': 'Alice', 'hand_size': 0, 'hand': []},
              {'id': 'p2', 'name': 'Bob', 'hand_size': 0, 'hand': []},
            ],
          ),
        ),
      );
      await Future.microtask(() {});

      await tester.pumpWidget(wrap(GameScreen(client: client), client));
      await tester.pump();

      await tester.tap(find.text('Leave Room'));
      await tester.pump();

      // After disconnect, roomCode should be null
      expect(client.state.roomCode, isNull);
      // Close controller before dispose to avoid hanging futures
      unawaited(ctrl.close());
      client.dispose();
    });
  });

  // ── Win/Loss Celebration Screens ────────────────────────────────────────────

  group('Win celebration screen', () {
    testWidgets(
      '31. win screen shows full-screen overlay with "You Won!" title',
      (tester) async {
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
              phase: 'won',
              lives: 5,
              roundNumber: 10,
              discardPile: List.generate(100, (i) => 100 - i),
              players: [
                {'id': 'p1', 'name': 'Alice', 'hand_size': 0, 'hand': []},
                {'id': 'p2', 'name': 'Bob', 'hand_size': 0, 'hand': []},
              ],
            ),
          ),
        );
        await Future.microtask(() {});

        await tester.pumpWidget(wrap(GameScreen(client: client), client));
        await tester.pump();

        expect(find.text('You Won!'), findsOneWidget);
        expect(find.text('100/100 cards played'), findsOneWidget);
        await ctrl.close();
        client.dispose();
      },
    );

    testWidgets('32. win screen has confetti widget', (tester) async {
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
            phase: 'won',
            lives: 5,
            roundNumber: 10,
            discardPile: List.generate(100, (i) => 100 - i),
            players: [
              {'id': 'p1', 'name': 'Alice', 'hand_size': 0, 'hand': []},
              {'id': 'p2', 'name': 'Bob', 'hand_size': 0, 'hand': []},
            ],
          ),
        ),
      );
      await Future.microtask(() {});

      await tester.pumpWidget(wrap(GameScreen(client: client), client));
      await tester.pump();

      // ConfettiWidget from confetti package should be present
      expect(find.byType(ConfettiWidget), findsWidgets);
      await ctrl.close();
      client.dispose();
    });

    testWidgets('33. win screen does NOT show old small banner', (
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
            phase: 'won',
            lives: 5,
            roundNumber: 10,
            discardPile: List.generate(100, (i) => 100 - i),
            players: [
              {'id': 'p1', 'name': 'Alice', 'hand_size': 0, 'hand': []},
              {'id': 'p2', 'name': 'Bob', 'hand_size': 0, 'hand': []},
            ],
          ),
        ),
      );
      await Future.microtask(() {});

      await tester.pumpWidget(wrap(GameScreen(client: client), client));
      await tester.pump();

      // Old banner text should be gone
      expect(find.text('You won! All 100 cards played.'), findsNothing);
      await ctrl.close();
      client.dispose();
    });
  });

  group('Loss celebration screen', () {
    testWidgets(
      '34. loss screen shows full-screen overlay with "Game Over" title',
      (tester) async {
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
              phase: 'gameOver',
              lives: 0,
              roundNumber: 3,
              discardPile: List.generate(42, (i) => 100 - i),
              players: [
                {'id': 'p1', 'name': 'Alice', 'hand_size': 0, 'hand': []},
                {'id': 'p2', 'name': 'Bob', 'hand_size': 0, 'hand': []},
              ],
            ),
          ),
        );
        await Future.microtask(() {});

        await tester.pumpWidget(wrap(GameScreen(client: client), client));
        await tester.pump();

        expect(find.text('Game Over'), findsOneWidget);
        expect(find.text('No lives left'), findsOneWidget);
        await ctrl.close();
        client.dispose();
      },
    );

    testWidgets(
      '35. loss screen shows card progress (e.g., "42/100 cards played")',
      (tester) async {
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
              phase: 'gameOver',
              lives: 0,
              roundNumber: 3,
              discardPile: List.generate(42, (i) => 100 - i),
              players: [
                {'id': 'p1', 'name': 'Alice', 'hand_size': 0, 'hand': []},
                {'id': 'p2', 'name': 'Bob', 'hand_size': 0, 'hand': []},
              ],
            ),
          ),
        );
        await Future.microtask(() {});

        await tester.pumpWidget(wrap(GameScreen(client: client), client));
        await tester.pump();

        expect(find.text('42/100 cards played'), findsOneWidget);
        await ctrl.close();
        client.dispose();
      },
    );

    testWidgets('36. loss screen does NOT show old small banner', (
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
            phase: 'gameOver',
            lives: 0,
            roundNumber: 3,
            discardPile: List.generate(42, (i) => 100 - i),
            players: [
              {'id': 'p1', 'name': 'Alice', 'hand_size': 0, 'hand': []},
              {'id': 'p2', 'name': 'Bob', 'hand_size': 0, 'hand': []},
            ],
          ),
        ),
      );
      await Future.microtask(() {});

      await tester.pumpWidget(wrap(GameScreen(client: client), client));
      await tester.pump();

      // Old banner text should be gone
      expect(find.text('Game over — no lives left.'), findsNothing);
      await ctrl.close();
      client.dispose();
    });

    testWidgets('37. loss screen still has Play Again and Leave Room buttons', (
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
            phase: 'gameOver',
            lives: 0,
            roundNumber: 3,
            discardPile: List.generate(42, (i) => 100 - i),
            players: [
              {'id': 'p1', 'name': 'Alice', 'hand_size': 0, 'hand': []},
              {'id': 'p2', 'name': 'Bob', 'hand_size': 0, 'hand': []},
            ],
          ),
        ),
      );
      await Future.microtask(() {});

      await tester.pumpWidget(wrap(GameScreen(client: client), client));
      await tester.pump();

      expect(find.text('Play Again'), findsOneWidget);
      expect(find.text('Leave Room'), findsOneWidget);
      await ctrl.close();
      client.dispose();
    });
  });

  group('Win/Loss screen does not appear during normal play', () {
    testWidgets('38. no celebration overlay during active round', (
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

      await tester.pumpWidget(wrap(GameScreen(client: client), client));
      await tester.pump();

      expect(find.text('You Won!'), findsNothing);
      expect(find.text('Game Over'), findsNothing);
      await ctrl.close();
      client.dispose();
    });
  });
}
