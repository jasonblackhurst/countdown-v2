import 'package:countdown_flutter/src/screens/game_screen.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/golden_test_helpers.dart';

void main() {
  group('GameScreen golden', () {
    testGoldenAcrossViewports(
      description: 'GameScreen mid-round with hand cards',
      goldenPrefix: 'game_screen_midround',
      screenBuilder: (client) => GameScreen(client: client),
      setup: (client, controller) async {
        await sendRoomEvent(controller,
            type: 'room_joined', roomCode: 'ABCD', playerId: 'p1');
        await sendStateUpdate(controller,
            phase: 'round',
            lives: 3,
            roundNumber: 2,
            discardPile: [100, 99, 97],
            players: [
              {
                'id': 'p1',
                'name': 'Alice',
                'hand_size': 3,
                'hand': [85, 61, 42]
              },
              {'id': 'p2', 'name': 'Bob', 'hand_size': 2, 'hand': []},
            ]);
      },
    );
  });
}
