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

class FakeSoundService implements SoundService {
  bool _isMuted = false;
  int cardSoundCount = 0;
  int lifeLossSoundCount = 0;
  int winSoundCount = 0;
  int lossSoundCount = 0;

  @override
  bool get isMuted => _isMuted;

  @override
  bool toggleMute() {
    _isMuted = !_isMuted;
    return _isMuted;
  }

  @override
  void playCardSound() => cardSoundCount++;

  @override
  void playLifeLossSound() => lifeLossSoundCount++;

  @override
  void playWinSound() => winSoundCount++;

  @override
  void playLossSound() => lossSoundCount++;
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
  // ── SoundService unit tests ──────────────────────────────────────────────

  group('SoundService', () {
    test('SD1. starts unmuted', () {
      final service = FakeSoundService();
      expect(service.isMuted, isFalse);
    });

    test('SD2. toggleMute switches state and returns new value', () {
      final service = FakeSoundService();
      expect(service.toggleMute(), isTrue);
      expect(service.isMuted, isTrue);
      expect(service.toggleMute(), isFalse);
      expect(service.isMuted, isFalse);
    });

    test('SD3. SystemSoundService respects mute for playCardSound', () {
      final service = SystemSoundService();
      expect(service.isMuted, isFalse);
      service.toggleMute();
      // Should not throw when muted — the method returns early
      service.playCardSound();
      expect(service.isMuted, isTrue);
    });
  });

  // ── GameScreen sound integration tests ────────────────────────────────────

  group('GameScreen sound triggers', () {
    testWidgets('SD4. playCardSound is called when local player taps a card', (
      tester,
    ) async {
      final client = GameClient();
      final soundService = FakeSoundService();
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

      await tester.pumpWidget(
        _wrap(GameScreen(client: client, soundService: soundService), client),
      );
      await tester.pump();

      expect(soundService.cardSoundCount, 0);

      // Tap card 75
      await tester.tap(find.text('75'));
      await tester.pump();

      expect(soundService.cardSoundCount, 1);

      await ctrl.close();
      client.dispose();
    });

    testWidgets('SD5. playLifeLossSound is called when lives decrease', (
      tester,
    ) async {
      final client = GameClient();
      final soundService = FakeSoundService();
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

      await tester.pumpWidget(
        _wrap(GameScreen(client: client, soundService: soundService), client),
      );
      await tester.pump();

      expect(soundService.lifeLossSoundCount, 0);

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

      expect(soundService.lifeLossSoundCount, 1);

      await ctrl.close();
      client.dispose();
    });

    testWidgets('SD6. playWinSound is called when phase transitions to won', (
      tester,
    ) async {
      final client = GameClient();
      final soundService = FakeSoundService();
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
                'hand_size': 1,
                'hand': [1],
              },
              {'id': 'p2', 'name': 'Bob', 'hand_size': 0, 'hand': []},
            ],
          ),
        ),
      );
      await Future.microtask(() {});

      await tester.pumpWidget(
        _wrap(GameScreen(client: client, soundService: soundService), client),
      );
      await tester.pump();

      expect(soundService.winSoundCount, 0);

      // Win!
      ctrl.add(
        jsonEncode(
          _stateUpdate(
            phase: 'won',
            lives: 5,
            roundNumber: 1,
            discardPile: List.generate(100, (i) => 100 - i),
            players: [
              {'id': 'p1', 'name': 'Alice', 'hand_size': 0, 'hand': []},
              {'id': 'p2', 'name': 'Bob', 'hand_size': 0, 'hand': []},
            ],
          ),
        ),
      );
      await Future.microtask(() {});
      await tester.pump();

      expect(soundService.winSoundCount, 1);

      await ctrl.close();
      client.dispose();
    });

    testWidgets(
      'SD7. playLossSound is called when phase transitions to gameOver',
      (tester) async {
        final client = GameClient();
        final soundService = FakeSoundService();
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
              lives: 1,
              roundNumber: 1,
              players: [
                {
                  'id': 'p1',
                  'name': 'Alice',
                  'hand_size': 1,
                  'hand': [50],
                },
                {'id': 'p2', 'name': 'Bob', 'hand_size': 1, 'hand': []},
              ],
            ),
          ),
        );
        await Future.microtask(() {});

        await tester.pumpWidget(
          _wrap(GameScreen(client: client, soundService: soundService), client),
        );
        await tester.pump();

        expect(soundService.lossSoundCount, 0);

        // Game over
        ctrl.add(
          jsonEncode(
            _stateUpdate(
              phase: 'gameOver',
              lives: 0,
              roundNumber: 1,
              discardPile: [100],
              players: [
                {'id': 'p1', 'name': 'Alice', 'hand_size': 0, 'hand': []},
                {'id': 'p2', 'name': 'Bob', 'hand_size': 0, 'hand': []},
              ],
            ),
          ),
        );
        await Future.microtask(() {});
        await tester.pump();

        expect(soundService.lossSoundCount, 1);

        await ctrl.close();
        client.dispose();
      },
    );

    testWidgets('SD8. no sounds play when muted', (tester) async {
      final client = GameClient();
      final soundService = FakeSoundService();
      soundService.toggleMute(); // mute it
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

      await tester.pumpWidget(
        _wrap(GameScreen(client: client, soundService: soundService), client),
      );
      await tester.pump();

      // Tap card — should NOT play sound because muted
      await tester.tap(find.text('75'));
      await tester.pump();

      expect(soundService.cardSoundCount, 0);

      await ctrl.close();
      client.dispose();
    });

    testWidgets('SD9. mute toggle button appears and toggles state', (
      tester,
    ) async {
      final client = GameClient();
      final soundService = FakeSoundService();
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
                'hand_size': 1,
                'hand': [75],
              },
              {'id': 'p2', 'name': 'Bob', 'hand_size': 1, 'hand': []},
            ],
          ),
        ),
      );
      await Future.microtask(() {});

      await tester.pumpWidget(
        _wrap(GameScreen(client: client, soundService: soundService), client),
      );
      await tester.pump();

      // Find mute button by key
      final muteButton = find.byKey(const Key('mute-toggle'));
      expect(muteButton, findsOneWidget);

      // Initially unmuted — should show volume_up icon
      expect(find.byIcon(Icons.volume_up), findsOneWidget);

      // Tap to mute
      await tester.tap(muteButton);
      await tester.pump();

      expect(soundService.isMuted, isTrue);
      expect(find.byIcon(Icons.volume_off), findsOneWidget);

      // Tap again to unmute
      await tester.tap(muteButton);
      await tester.pump();

      expect(soundService.isMuted, isFalse);
      expect(find.byIcon(Icons.volume_up), findsOneWidget);

      await ctrl.close();
      client.dispose();
    });
  });
}
