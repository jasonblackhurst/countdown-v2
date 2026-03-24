import 'dart:async';
import 'dart:convert';

import 'package:countdown_flutter/src/client/game_client.dart';
import 'package:countdown_flutter/src/screens/game_screen.dart';
import 'package:countdown_flutter/src/services/sound_service.dart';
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

class _FakeSoundService implements SoundService {
  bool _isMuted = false;

  @override
  bool get isMuted => _isMuted;

  @override
  bool toggleMute() {
    _isMuted = !_isMuted;
    return _isMuted;
  }

  @override
  void playCardSound() {}

  @override
  void playLifeLossSound() {}

  @override
  void playWinSound() {}

  @override
  void playLossSound() {}
}

(_FakeSink, StreamController<String>) _connectFake(GameClient client) {
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
  Map<String, dynamic>? lastPlayedBy,
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
    'last_played_by': lastPlayedBy,
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

/// Pumps a GameScreen at the given surface size.
Future<void> _pumpGameScreen(
  WidgetTester tester,
  GameClient client, {
  Size surfaceSize = const Size(400, 800),
}) async {
  await tester.binding.setSurfaceSize(surfaceSize);
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(
    _wrap(
      GameScreen(client: client, soundService: _FakeSoundService()),
      client,
    ),
  );
  await tester.pump();
}

void main() {
  // ── Compact status bar ──────────────────────────────────────────────────

  group('Compact status bar', () {
    testWidgets(
      'VO1. status bar shows compact format with round, lives, and progress',
      (tester) async {
        final client = GameClient();
        final (_, ctrl) = _connectFake(client);

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
              roundNumber: 3,
              discardPile: List.generate(42, (i) => 100 - i),
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

        await _pumpGameScreen(tester, client);

        // Should find compact status bar key
        expect(find.byKey(const Key('compact-status-bar')), findsOneWidget);

        // Should show round number in compact format
        expect(find.textContaining('R3'), findsOneWidget);

        // Should show progress in compact format
        expect(find.textContaining('42/100'), findsOneWidget);

        await ctrl.close();
        client.dispose();
      },
    );
  });

  // ── Larger last-played card ─────────────────────────────────────────────

  group('Larger last-played card', () {
    testWidgets('VO2. last-played card container is larger than old 80x120', (
      tester,
    ) async {
      final client = GameClient();
      final (_, ctrl) = _connectFake(client);

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
            discardPile: [100, 99],
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

      await _pumpGameScreen(tester, client);

      // Find the last played card container by key
      final cardFinder = find.byKey(const Key('last-played-card'));
      expect(cardFinder, findsOneWidget);

      final cardBox = tester.renderObject(cardFinder) as RenderBox;
      // Should be larger than old 80x120
      expect(cardBox.size.width, greaterThanOrEqualTo(100));
      expect(cardBox.size.height, greaterThanOrEqualTo(140));

      await ctrl.close();
      client.dispose();
    });
  });

  // ── Responsive layout ──────────────────────────────────────────────────

  group('Responsive layout with LayoutBuilder', () {
    testWidgets('VO3. narrow screen (<600px) uses vertical layout', (
      tester,
    ) async {
      final client = GameClient();
      final (_, ctrl) = _connectFake(client);

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

      // Narrow screen (phone portrait)
      await _pumpGameScreen(tester, client, surfaceSize: const Size(400, 800));

      // Should use column layout (vertical), identified by key
      expect(find.byKey(const Key('narrow-layout')), findsOneWidget);
      expect(find.byKey(const Key('wide-layout')), findsNothing);

      await ctrl.close();
      client.dispose();
    });

    testWidgets('VO4. wide screen (>=600px) uses side-by-side layout', (
      tester,
    ) async {
      final client = GameClient();
      final (_, ctrl) = _connectFake(client);

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

      // Wide screen (tablet/landscape)
      await _pumpGameScreen(tester, client, surfaceSize: const Size(800, 600));

      // Should use row layout (side-by-side), identified by key
      expect(find.byKey(const Key('wide-layout')), findsOneWidget);
      expect(find.byKey(const Key('narrow-layout')), findsNothing);

      await ctrl.close();
      client.dispose();
    });
  });

  // ── Hand card sizing ───────────────────────────────────────────────────

  group('Hand card layout', () {
    testWidgets('VO5. cards in hand have minimum touch target size (48px)', (
      tester,
    ) async {
      final client = GameClient();
      final (_, ctrl) = _connectFake(client);

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
                'hand_size': 3,
                'hand': [90, 75, 42],
              },
              {'id': 'p2', 'name': 'Bob', 'hand_size': 2, 'hand': []},
            ],
          ),
        ),
      );
      await Future.microtask(() {});

      await _pumpGameScreen(tester, client);

      // Find card 90 and check its rendered size
      final cardFinder = find.text('90');
      expect(cardFinder, findsOneWidget);

      // The Card widget ancestor should have at least 48px in each dimension
      final cardWidget = find.ancestor(
        of: cardFinder,
        matching: find.byType(Card),
      );
      expect(cardWidget, findsOneWidget);
      final cardBox = tester.renderObject(cardWidget.first) as RenderBox;
      expect(cardBox.size.width, greaterThanOrEqualTo(48));
      expect(cardBox.size.height, greaterThanOrEqualTo(48));

      await ctrl.close();
      client.dispose();
    });
  });

  // ── Reduced visual clutter ─────────────────────────────────────────────

  group('Reduced visual clutter', () {
    testWidgets('VO6. no "Your hand" label shown during gameplay', (
      tester,
    ) async {
      final client = GameClient();
      final (_, ctrl) = _connectFake(client);

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

      await _pumpGameScreen(tester, client);

      // "Your hand" label should be removed for a cleaner look
      expect(find.text('Your hand'), findsNothing);

      await ctrl.close();
      client.dispose();
    });

    testWidgets('VO7. no explicit Divider widget between discard and hand', (
      tester,
    ) async {
      final client = GameClient();
      final (_, ctrl) = _connectFake(client);

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

      await _pumpGameScreen(tester, client);

      // The explicit Divider widget should be removed
      expect(find.byType(Divider), findsNothing);

      await ctrl.close();
      client.dispose();
    });
  });

  // ── Existing functionality preserved ───────────────────────────────────

  group('Existing functionality preserved', () {
    testWidgets('VO8. win overlay still shows correctly', (tester) async {
      final client = GameClient();
      final (_, ctrl) = _connectFake(client);

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

      await _pumpGameScreen(tester, client);

      expect(find.text('You Won!'), findsOneWidget);
      expect(find.text('100/100 cards played'), findsOneWidget);

      await ctrl.close();
      client.dispose();
    });

    testWidgets('VO9. loss overlay still shows correctly', (tester) async {
      final client = GameClient();
      final (_, ctrl) = _connectFake(client);

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

      await _pumpGameScreen(tester, client);

      expect(find.text('Game Over'), findsOneWidget);
      expect(find.text('42/100 cards played'), findsOneWidget);

      await ctrl.close();
      client.dispose();
    });

    testWidgets('VO10. player bar still shows during gameplay', (tester) async {
      final client = GameClient();
      final (_, ctrl) = _connectFake(client);

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

      await _pumpGameScreen(tester, client);

      expect(find.byKey(const Key('player-bar')), findsOneWidget);
      expect(find.text('Alice'), findsOneWidget);
      expect(find.text('Bob'), findsOneWidget);

      await ctrl.close();
      client.dispose();
    });

    testWidgets('VO11. tapping a card still sends play_card message', (
      tester,
    ) async {
      final client = GameClient();
      final (sink, ctrl) = _connectFake(client);

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

      await _pumpGameScreen(tester, client);

      await tester.tap(find.text('75'));
      await tester.pump();

      expect(
        sink.sent.any((m) => m['type'] == 'play_card' && m['value'] == 75),
        isTrue,
      );

      await ctrl.close();
      client.dispose();
    });
  });
}
