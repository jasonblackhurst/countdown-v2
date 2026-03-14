import 'package:countdown_flutter/src/screens/home_screen.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/golden_test_helpers.dart';

void main() {
  group('HomeScreen golden', () {
    testGoldenAcrossViewports(
      description: 'HomeScreen initial state',
      goldenPrefix: 'home_screen',
      screenBuilder: (client) => HomeScreen(client: client),
      setup: (client, controller) async {
        // HomeScreen needs no server state — just connected
      },
    );
  });
}
