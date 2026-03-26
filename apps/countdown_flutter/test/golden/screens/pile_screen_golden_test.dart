import 'package:countdown_flutter/src/screens/pile_screen.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/golden_test_helpers.dart';

void main() {
  group('PileScreen golden', () {
    testGoldenAcrossViewports(
      description: 'PileScreen with played cards',
      goldenPrefix: 'pile_screen',
      screenBuilder: (client) => PileScreen(client: client),
      setup: (client, controller) async {
        await sendRoomEvent(
          controller,
          type: 'room_joined',
          roomCode: 'ABCD',
          playerId: 'p1',
        );
        await sendStateUpdate(
          controller,
          phase: 'round',
          lives: 4,
          roundNumber: 1,
          discardPile: [100, 99, 97, 95, 93, 90, 88, 85, 82, 80],
          lastPlayedBy: {'id': 'p2', 'name': 'Bob', 'card_value': 80},
          players: [
            {
              'id': 'p1',
              'name': 'Alice',
              'hand_size': 1,
              'hand': [75],
            },
            {'id': 'p2', 'name': 'Bob', 'hand_size': 1, 'hand': []},
          ],
        );
      },
    );
  });
}
