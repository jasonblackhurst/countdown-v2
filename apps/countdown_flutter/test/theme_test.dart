import 'dart:async';
import 'dart:convert';

import 'package:countdown_flutter/src/client/game_client.dart';
import 'package:countdown_flutter/src/screens/game_screen.dart';
import 'package:countdown_flutter/src/screens/home_screen.dart';
import 'package:countdown_flutter/src/theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';

// ── Test doubles ──────────────────────────────────────────────────────────

class _FakeSink implements MessageSink {
  final List<Map<String, dynamic>> sent = [];
  bool closed = false;

  @override
  void send(String msg) => sent.add(jsonDecode(msg) as Map<String, dynamic>);

  @override
  void close() => closed = true;
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

Widget _wrapWithTheme(Widget child, GameClient client) => MaterialApp(
  theme: countdownTheme(),
  home: ListenableBuilder(listenable: client, builder: (_, _) => child),
);

/// Suppresses GoogleFonts async loading errors in test zone.
void _suppressGoogleFontsErrors() {
  final originalOnError = FlutterError.onError;
  FlutterError.onError = (details) {
    if (details.toString().contains('google_fonts') ||
        details.toString().contains('GoogleFonts') ||
        details.toString().contains('PlayfairDisplay')) {
      return; // suppress
    }
    originalOnError?.call(details);
  };
  addTearDown(() => FlutterError.onError = originalOnError);
}

void main() {
  // Prevent real HTTP fetches; font family strings are set synchronously.
  GoogleFonts.config.allowRuntimeFetching = false;

  group('countdownTheme()', () {
    // Using testWidgets so the binding catches async GoogleFonts errors.
    testWidgets('T1. uses dark brightness', (tester) async {
      _suppressGoogleFontsErrors();
      final theme = countdownTheme();
      expect(theme.colorScheme.brightness, Brightness.dark);
    });

    testWidgets('T2. scaffold background is deep navy', (tester) async {
      _suppressGoogleFontsErrors();
      final theme = countdownTheme();
      expect(theme.scaffoldBackgroundColor, kBackgroundColor);
    });

    testWidgets('T3. primary color is warm amber/gold', (tester) async {
      _suppressGoogleFontsErrors();
      final theme = countdownTheme();
      expect(theme.colorScheme.primary, kAccentColor);
    });

    testWidgets('T4. Material 3 is enabled', (tester) async {
      _suppressGoogleFontsErrors();
      final theme = countdownTheme();
      expect(theme.useMaterial3, isTrue);
    });

    testWidgets('T5. card theme uses cream/off-white color', (tester) async {
      _suppressGoogleFontsErrors();
      final theme = countdownTheme();
      expect(theme.cardTheme.color, kCardColor);
    });

    testWidgets('T6. card theme has rounded corners', (tester) async {
      _suppressGoogleFontsErrors();
      final theme = countdownTheme();
      final shape = theme.cardTheme.shape as RoundedRectangleBorder;
      expect(shape.borderRadius, BorderRadius.circular(12));
    });

    testWidgets('T7. app bar uses Playfair Display font', (tester) async {
      _suppressGoogleFontsErrors();
      final theme = countdownTheme();
      expect(
        theme.appBarTheme.titleTextStyle?.fontFamily,
        contains('PlayfairDisplay'),
      );
    });

    testWidgets('T8. dialog title uses Playfair Display font', (tester) async {
      _suppressGoogleFontsErrors();
      final theme = countdownTheme();
      expect(
        theme.dialogTheme.titleTextStyle?.fontFamily,
        contains('PlayfairDisplay'),
      );
    });
  });

  group('HomeScreen with dark theme', () {
    testWidgets('T9. scaffold uses dark background color', (tester) async {
      _suppressGoogleFontsErrors();
      final client = GameClient();
      await tester.pumpWidget(
        _wrapWithTheme(HomeScreen(client: client), client),
      );

      final context = tester.element(find.byType(Scaffold));
      final themeData = Theme.of(context);
      expect(themeData.scaffoldBackgroundColor, kBackgroundColor);
      client.dispose();
    });

    testWidgets('T10. title uses font family from appBarTheme', (tester) async {
      _suppressGoogleFontsErrors();
      final client = GameClient();
      await tester.pumpWidget(
        _wrapWithTheme(HomeScreen(client: client), client),
      );

      final titleWidget = tester.widget<Text>(find.text('Countdown'));
      // Title style inherits fontFamily from appBarTheme.titleTextStyle
      expect(titleWidget.style?.fontFamily, contains('PlayfairDisplay'));
      client.dispose();
    });
  });

  group('GameScreen card styling with dark theme', () {
    testWidgets('T11. Card widgets use cream color from theme', (tester) async {
      _suppressGoogleFontsErrors();
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

      await tester.pumpWidget(
        _wrapWithTheme(GameScreen(client: client), client),
      );
      await tester.pump();

      final context = tester.element(find.byType(Card).first);
      final cardTheme = Theme.of(context).cardTheme;
      expect(cardTheme.color, kCardColor);

      await ctrl.close();
      client.dispose();
    });

    testWidgets('T12. card number text uses dark color for contrast', (
      tester,
    ) async {
      _suppressGoogleFontsErrors();
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
        _wrapWithTheme(GameScreen(client: client), client),
      );
      await tester.pump();

      final cardText = tester.widget<Text>(find.text('75'));
      expect(cardText.style?.color, kCardTextColor);

      await ctrl.close();
      client.dispose();
    });
  });
}
