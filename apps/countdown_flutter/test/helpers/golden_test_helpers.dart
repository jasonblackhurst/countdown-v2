import 'dart:async';
import 'dart:convert';

import 'package:countdown_flutter/src/client/game_client.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';

// ── Test doubles (shared with widget_test.dart pattern) ──────────────────────

class FakeSink implements MessageSink {
  final List<Map<String, dynamic>> sent = [];
  bool closed = false;

  @override
  void send(String msg) => sent.add(jsonDecode(msg) as Map<String, dynamic>);

  @override
  void close() => closed = true;
}

/// Connects [client] to fake in-memory streams for testing.
(FakeSink, StreamController<String>) connectFake(GameClient client) {
  final sink = FakeSink();
  final controller = StreamController<String>();
  client.connect(
    Uri.parse('ws://localhost:8080/ws'),
    incomingStream: controller.stream,
    sink: sink,
  );
  return (sink, controller);
}

/// Sends a state_update message to the client via [controller].
Future<void> sendStateUpdate(
  StreamController<String> controller, {
  String phase = 'lobby',
  int lives = 5,
  int roundNumber = 0,
  List<int> discardPile = const [],
  List<Map<String, dynamic>>? players,
  bool gameInitialized = false,
  Map<String, dynamic>? lastPlayedBy,
}) async {
  controller.add(
    jsonEncode({
      'type': 'state_update',
      'state': {
        'phase': phase,
        'lives': lives,
        'round_number': roundNumber,
        'discard_pile': discardPile,
        'game_initialized': gameInitialized,
        'last_played_by': lastPlayedBy,
        'players':
            players ??
            [
              {'id': 'p1', 'name': 'Alice', 'hand_size': 0, 'hand': []},
              {'id': 'p2', 'name': 'Bob', 'hand_size': 0, 'hand': []},
            ],
      },
    }),
  );
  await Future.microtask(() {});
}

/// Sends a room_created or room_joined message.
Future<void> sendRoomEvent(
  StreamController<String> controller, {
  String type = 'room_created',
  String roomCode = 'TEST',
  String playerId = 'p1',
}) async {
  controller.add(
    jsonEncode({'type': type, 'room_code': roomCode, 'player_id': playerId}),
  );
  await Future.microtask(() {});
}

// ── Viewport helpers ─────────────────────────────────────────────────────────

/// Standard viewports for golden tests.
enum TestViewport {
  iphoneSE(375, 667, 'iphone_se'),
  iphone14Pro(390, 844, 'iphone_14_pro'),
  desktop(1920, 1080, 'desktop');

  const TestViewport(this.width, this.height, this.suffix);
  final double width;
  final double height;
  final String suffix;
}

/// Sets the test viewport and registers a tearDown to reset it.
void setupViewport(WidgetTester tester, TestViewport viewport) {
  tester.view.physicalSize = Size(viewport.width, viewport.height);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(() {
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });
}

/// Suppresses RenderFlex overflow errors and GoogleFonts async errors.
void suppressOverflowErrors() {
  final originalOnError = FlutterError.onError;
  FlutterError.onError = (details) {
    final msg = details.toString();
    if (msg.contains('overflowed') ||
        msg.contains('google_fonts') ||
        msg.contains('GoogleFonts') ||
        msg.contains('PlayfairDisplay')) {
      return;
    }
    originalOnError?.call(details);
  };
  addTearDown(() => FlutterError.onError = originalOnError);
}

// ── Pump helpers ─────────────────────────────────────────────────────────────

/// Wraps a screen in MaterialApp + ListenableBuilder for golden tests.
Future<void> pumpScreen(
  WidgetTester tester, {
  required Widget screen,
  required GameClient client,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      theme: ThemeData.dark(useMaterial3: true),
      home: ListenableBuilder(listenable: client, builder: (_, _) => screen),
      debugShowCheckedModeBanner: false,
    ),
  );
  await tester.pumpAndSettle();
}

/// Golden test helper: pumps a screen at a given viewport and matches golden.
Future<void> testGoldenAtSize(
  WidgetTester tester, {
  required Widget screen,
  required GameClient client,
  required TestViewport viewport,
  required String goldenName,
}) async {
  suppressOverflowErrors();
  setupViewport(tester, viewport);
  await pumpScreen(tester, screen: screen, client: client);
  await expectLater(
    find.byType(MaterialApp),
    matchesGoldenFile('goldens/${goldenName}_${viewport.suffix}.png'),
  );
}

/// Runs a golden test across all standard viewports.
void testGoldenAcrossViewports({
  required String description,
  required String goldenPrefix,
  required Widget Function(GameClient client) screenBuilder,
  required Future<void> Function(
    GameClient client,
    StreamController<String> controller,
  )
  setup,
}) {
  for (final viewport in TestViewport.values) {
    testWidgets('$description - ${viewport.name}', (tester) async {
      GoogleFonts.config.allowRuntimeFetching = false;
      final client = GameClient();
      final (_, controller) = connectFake(client);

      await setup(client, controller);

      await testGoldenAtSize(
        tester,
        screen: screenBuilder(client),
        client: client,
        viewport: viewport,
        goldenName: goldenPrefix,
      );

      await controller.close();
      client.dispose();
    });
  }
}
