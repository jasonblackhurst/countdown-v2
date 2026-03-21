import 'package:countdown_flutter/src/screens/lobby_screen.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/golden_test_helpers.dart';

void main() {
  group('LobbyScreen golden', () {
    testGoldenAcrossViewports(
      description: 'LobbyScreen pre-game with 2 players',
      goldenPrefix: 'lobby_screen_pregame',
      screenBuilder: (client) => LobbyScreen(client: client),
      setup: (client, controller) async {
        await sendRoomEvent(controller, roomCode: 'ABCD', playerId: 'p1');
        await sendStateUpdate(
          controller,
          phase: 'lobby',
          roundNumber: 0,
          gameInitialized: false,
          players: [
            {'id': 'p1', 'name': 'Alice', 'hand_size': 0, 'hand': []},
            {'id': 'p2', 'name': 'Bob', 'hand_size': 0, 'hand': []},
          ],
        );
      },
    );

    testGoldenAcrossViewports(
      description: 'LobbyScreen between rounds (vote UI)',
      goldenPrefix: 'lobby_screen_between_rounds',
      screenBuilder: (client) => LobbyScreen(client: client),
      setup: (client, controller) async {
        await sendRoomEvent(controller, roomCode: 'ABCD', playerId: 'p1');
        await sendStateUpdate(
          controller,
          phase: 'lobby',
          roundNumber: 2,
          gameInitialized: true,
          players: [
            {'id': 'p1', 'name': 'Alice', 'hand_size': 0, 'hand': []},
            {'id': 'p2', 'name': 'Bob', 'hand_size': 0, 'hand': []},
          ],
        );
      },
    );
  });
}
