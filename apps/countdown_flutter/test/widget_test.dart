import 'dart:async';
import 'dart:convert';

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
}) =>
    {
      'type': 'state_update',
      'state': {
        'phase': phase,
        'lives': lives,
        'round_number': roundNumber,
        'discard_pile': discardPile,
        'players': players ??
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
      controller.add(jsonEncode({
        'type': 'room_created',
        'room_code': 'ABCD',
        'player_id': 'pid-1',
      }));
      await Future.microtask(() {});
      expect(client.state.roomCode, 'ABCD');
      expect(client.state.playerId, 'pid-1');
    });

    test('3. room_joined message stores roomCode and playerId', () async {
      controller.add(jsonEncode({
        'type': 'room_joined',
        'room_code': 'WXYZ',
        'player_id': 'pid-2',
      }));
      await Future.microtask(() {});
      expect(client.state.roomCode, 'WXYZ');
      expect(client.state.playerId, 'pid-2');
    });

    test('4. state_update message applies phase, lives, round, players', () async {
      controller.add(jsonEncode(_stateUpdate(
        phase: 'round',
        lives: 4,
        roundNumber: 2,
        discardPile: [100, 99],
      )));
      await Future.microtask(() {});
      expect(client.state.phase, GamePhase.round);
      expect(client.state.lives, 4);
      expect(client.state.roundNumber, 2);
      expect(client.state.discardPile, [100, 99]);
      expect(client.state.players, hasLength(2));
    });

    test('5. error message stores lastError', () async {
      controller.add(jsonEncode({
        'type': 'error',
        'message': 'Room not found',
      }));
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

    test('12. myPlayer returns the snapshot whose id matches playerId', () async {
      controller.add(jsonEncode({
        'type': 'room_joined',
        'room_code': 'ABCD',
        'player_id': 'p2',
      }));
      await Future.microtask(() {});
      controller.add(jsonEncode(_stateUpdate()));
      await Future.microtask(() {});
      expect(client.state.myPlayer?.name, 'Bob');
    });
  });

  // ── Widget tests ──────────────────────────────────────────────────────────

  Widget _wrap(Widget child, GameClient client) => MaterialApp(
        home: ListenableBuilder(
          listenable: client,
          builder: (_, __) => child,
        ),
      );

  group('HomeScreen', () {
    testWidgets('13. shows Create Room and Join Room buttons', (tester) async {
      final client = GameClient();
      await tester.pumpWidget(_wrap(HomeScreen(client: client), client));
      expect(find.text('Create Room'), findsOneWidget);
      expect(find.text('Join Room'), findsOneWidget);
      client.dispose();
    });

    testWidgets('14. tapping Create Room calls client.createRoom()', (tester) async {
      final client = GameClient();
      final (sink, ctrl) = connectFake(client);

      await tester.pumpWidget(_wrap(HomeScreen(client: client), client));
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

      ctrl.add(jsonEncode(
          {'type': 'room_created', 'room_code': 'TEST', 'player_id': 'p1'}));
      ctrl.add(jsonEncode(_stateUpdate(players: [
        {'id': 'p1', 'name': 'Alice', 'hand_size': 0, 'hand': []},
      ])));
      await Future.microtask(() {});

      await tester.pumpWidget(_wrap(LobbyScreen(client: client), client));
      await tester.pump();

      expect(find.text('TEST'), findsOneWidget);
      expect(find.text('Alice'), findsOneWidget);
      await ctrl.close();
      client.dispose();
    });
  });

  group('GameScreen', () {
    testWidgets('16. shows lives, round number, and hand cards', (tester) async {
      final client = GameClient();
      final (_, ctrl) = connectFake(client);

      ctrl.add(jsonEncode(
          {'type': 'room_joined', 'room_code': 'ABCD', 'player_id': 'p1'}));
      ctrl.add(jsonEncode(_stateUpdate(
        phase: 'round',
        lives: 3,
        roundNumber: 2,
        players: [
          {
            'id': 'p1',
            'name': 'Alice',
            'hand_size': 2,
            'hand': [75, 42]
          },
          {'id': 'p2', 'name': 'Bob', 'hand_size': 2, 'hand': []},
        ],
      )));
      await Future.microtask(() {});

      await tester.pumpWidget(_wrap(GameScreen(client: client), client));
      await tester.pump();

      expect(find.text('3'), findsOneWidget); // lives
      expect(find.text('Round 2'), findsOneWidget);
      expect(find.text('75'), findsOneWidget);
      expect(find.text('42'), findsOneWidget);
      await ctrl.close();
      client.dispose();
    });
  });
}
