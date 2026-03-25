import 'dart:async';
import 'dart:convert';

import 'package:countdown_core/countdown_core.dart';
import 'package:countdown_flutter/src/client/game_client.dart';
import 'package:countdown_flutter/src/screens/round_transition_screen.dart';
import 'package:countdown_flutter/src/theme.dart';
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

Widget _wrap(Widget child) => MaterialApp(theme: countdownTheme(), home: child);

void main() {
  // ── GameClient previousPhase tracking ───────────────────────────────────

  group('GameClient previousPhase', () {
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

    test('RT1. previousPhase is null initially', () {
      expect(client.previousPhase, isNull);
    });

    test('RT2. previousPhase tracks prior phase after state update', () async {
      // First state: round phase
      controller.add(jsonEncode(_stateUpdate(phase: 'round', roundNumber: 1)));
      await Future.microtask(() {});
      expect(client.state.phase, GamePhase.round);
      expect(client.previousPhase, isNull); // no prior state

      // Second state: lobby phase (round completed)
      controller.add(jsonEncode(_stateUpdate(phase: 'lobby', roundNumber: 1)));
      await Future.microtask(() {});
      expect(client.state.phase, GamePhase.lobby);
      expect(client.previousPhase, GamePhase.round);
    });

    test(
      'RT3. previousPhase does not report round->lobby for initial lobby (roundNumber 0)',
      () async {
        controller.add(
          jsonEncode(_stateUpdate(phase: 'lobby', roundNumber: 0)),
        );
        await Future.microtask(() {});
        expect(client.state.phase, GamePhase.lobby);
        expect(client.previousPhase, isNull);
      },
    );
  });

  // ── RoundTransitionScreen widget ────────────────────────────────────────

  group('RoundTransitionScreen', () {
    testWidgets('RT4. shows "Round N Complete" title', (tester) async {
      await tester.pumpWidget(
        _wrap(
          RoundTransitionScreen(
            roundNumber: 3,
            cardsPlayed: 30,
            lives: 4,
            onContinue: () {},
          ),
        ),
      );

      expect(find.text('Round 3 Complete'), findsOneWidget);
    });

    testWidgets('RT5. shows cards played progress text', (tester) async {
      await tester.pumpWidget(
        _wrap(
          RoundTransitionScreen(
            roundNumber: 2,
            cardsPlayed: 20,
            lives: 5,
            onContinue: () {},
          ),
        ),
      );

      expect(find.text('20 / 100 cards played'), findsOneWidget);
    });

    testWidgets('RT6. shows a progress bar (LinearProgressIndicator)', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(
          RoundTransitionScreen(
            roundNumber: 2,
            cardsPlayed: 50,
            lives: 5,
            onContinue: () {},
          ),
        ),
      );

      expect(find.byType(LinearProgressIndicator), findsOneWidget);
    });

    testWidgets('RT7. shows lives remaining with heart icons', (tester) async {
      await tester.pumpWidget(
        _wrap(
          RoundTransitionScreen(
            roundNumber: 2,
            cardsPlayed: 20,
            lives: 3,
            onContinue: () {},
          ),
        ),
      );

      expect(find.text('3 lives remaining'), findsOneWidget);
      expect(find.byIcon(Icons.favorite), findsOneWidget);
    });

    testWidgets('RT8. shows a Continue button', (tester) async {
      await tester.pumpWidget(
        _wrap(
          RoundTransitionScreen(
            roundNumber: 1,
            cardsPlayed: 10,
            lives: 5,
            onContinue: () {},
          ),
        ),
      );

      expect(find.text('Continue'), findsOneWidget);
    });

    testWidgets('RT9. tapping Continue calls onContinue callback', (
      tester,
    ) async {
      var continued = false;
      await tester.pumpWidget(
        _wrap(
          RoundTransitionScreen(
            roundNumber: 1,
            cardsPlayed: 10,
            lives: 5,
            onContinue: () => continued = true,
          ),
        ),
      );

      await tester.tap(find.text('Continue'));
      expect(continued, isTrue);
    });

    testWidgets('RT10. progress bar reflects correct fraction', (tester) async {
      await tester.pumpWidget(
        _wrap(
          RoundTransitionScreen(
            roundNumber: 5,
            cardsPlayed: 75,
            lives: 2,
            onContinue: () {},
          ),
        ),
      );

      final progressBar = tester.widget<LinearProgressIndicator>(
        find.byType(LinearProgressIndicator),
      );
      expect(progressBar.value, closeTo(0.75, 0.01));
    });
  });

  // ── Navigator integration: interstitial before lobby ────────────────────

  group('AppNavigator round transition interstitial', () {
    testWidgets(
      'RT11. shows RoundTransitionScreen when transitioning from round to lobby with roundNumber > 0',
      (tester) async {
        final client = GameClient();
        final (_, ctrl) = connectFake(client);

        // Put client in a room
        ctrl.add(
          jsonEncode({
            'type': 'room_joined',
            'room_code': 'ABCD',
            'player_id': 'p1',
          }),
        );
        await Future.microtask(() {});

        // Start in round phase
        ctrl.add(
          jsonEncode(
            _stateUpdate(
              phase: 'round',
              roundNumber: 1,
              discardPile: [100, 99, 98],
              lives: 4,
              players: [
                {
                  'id': 'p1',
                  'name': 'Alice',
                  'hand_size': 2,
                  'hand': [85, 61],
                },
                {'id': 'p2', 'name': 'Bob', 'hand_size': 2, 'hand': []},
              ],
            ),
          ),
        );
        await Future.microtask(() {});

        // Import and build the full app navigator
        await tester.pumpWidget(
          MaterialApp(
            theme: countdownTheme(),
            home: _TestNavigator(client: client),
          ),
        );
        await tester.pump();

        // Now transition to lobby (round complete)
        ctrl.add(
          jsonEncode(
            _stateUpdate(
              phase: 'lobby',
              roundNumber: 1,
              discardPile: [100, 99, 98, 97, 96],
              lives: 4,
            ),
          ),
        );
        await Future.microtask(() {});
        await tester.pump();

        // Should show the round transition screen
        expect(find.byType(RoundTransitionScreen), findsOneWidget);
        expect(find.text('Round 1 Complete'), findsOneWidget);

        await ctrl.close();
        client.dispose();
      },
    );

    testWidgets(
      'RT12. does NOT show RoundTransitionScreen for initial lobby (roundNumber 0)',
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
        await Future.microtask(() {});

        ctrl.add(jsonEncode(_stateUpdate(phase: 'lobby', roundNumber: 0)));
        await Future.microtask(() {});

        await tester.pumpWidget(
          MaterialApp(
            theme: countdownTheme(),
            home: _TestNavigator(client: client),
          ),
        );
        await tester.pump();

        expect(find.byType(RoundTransitionScreen), findsNothing);

        await ctrl.close();
        client.dispose();
      },
    );

    testWidgets(
      'RT13. tapping Continue on interstitial shows lobby/vote screen',
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
        await Future.microtask(() {});

        // Start in round phase
        ctrl.add(
          jsonEncode(
            _stateUpdate(
              phase: 'round',
              roundNumber: 1,
              discardPile: [100, 99, 98],
              lives: 4,
              players: [
                {
                  'id': 'p1',
                  'name': 'Alice',
                  'hand_size': 2,
                  'hand': [85, 61],
                },
                {'id': 'p2', 'name': 'Bob', 'hand_size': 2, 'hand': []},
              ],
            ),
          ),
        );
        await Future.microtask(() {});

        await tester.pumpWidget(
          MaterialApp(
            theme: countdownTheme(),
            home: _TestNavigator(client: client),
          ),
        );
        await tester.pump();

        // Transition to lobby
        ctrl.add(
          jsonEncode(
            _stateUpdate(
              phase: 'lobby',
              roundNumber: 1,
              discardPile: [100, 99, 98, 97, 96],
              lives: 4,
            ),
          ),
        );
        await Future.microtask(() {});
        await tester.pump();

        // Tap Continue
        await tester.tap(find.text('Continue'));
        await tester.pump();

        // Interstitial should be gone, lobby should be visible
        expect(find.byType(RoundTransitionScreen), findsNothing);
        expect(find.text('Confirm Vote'), findsOneWidget);

        await ctrl.close();
        client.dispose();
      },
    );
  });
}

/// A minimal navigator widget that mirrors the logic from _CountdownAppState
/// but is testable without the WebSocket connection setup.
class _TestNavigator extends StatefulWidget {
  final GameClient client;
  const _TestNavigator({required this.client});

  @override
  State<_TestNavigator> createState() => _TestNavigatorState();
}

class _TestNavigatorState extends State<_TestNavigator> {
  bool _showRoundTransition = false;
  int _transitionRoundNumber = 0;
  int _transitionCardsPlayed = 0;
  int _transitionLives = 5;

  @override
  void initState() {
    super.initState();
    widget.client.addListener(_onClientUpdate);
  }

  @override
  void dispose() {
    widget.client.removeListener(_onClientUpdate);
    super.dispose();
  }

  void _onClientUpdate() {
    final state = widget.client.state;
    final prev = widget.client.previousPhase;

    // Detect round -> lobby transition with roundNumber > 0
    if (prev == GamePhase.round &&
        state.phase == GamePhase.lobby &&
        (state.roundNumber ?? 0) > 0 &&
        !_showRoundTransition) {
      setState(() {
        _showRoundTransition = true;
        _transitionRoundNumber = state.roundNumber ?? 0;
        _transitionCardsPlayed = state.discardPile?.length ?? 0;
        _transitionLives = state.lives ?? 5;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.client,
      builder: (context, _) {
        final state = widget.client.state;

        if (_showRoundTransition) {
          return RoundTransitionScreen(
            roundNumber: _transitionRoundNumber,
            cardsPlayed: _transitionCardsPlayed,
            lives: _transitionLives,
            onContinue: () => setState(() => _showRoundTransition = false),
          );
        }

        final phase = state.phase;
        if (phase == GamePhase.round ||
            phase == GamePhase.won ||
            phase == GamePhase.gameOver) {
          return const Scaffold(body: Text('GameScreen'));
        }

        // Show lobby with vote UI
        return Scaffold(
          body: Column(
            children: [
              const Text('LobbyScreen'),
              if ((state.roundNumber ?? 0) > 0 || state.gameInitialized)
                FilledButton(
                  onPressed: () {},
                  child: const Text('Confirm Vote'),
                ),
            ],
          ),
        );
      },
    );
  }
}
