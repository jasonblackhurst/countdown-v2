import 'package:flutter/material.dart';

import '../client/game_client.dart';
import '../theme.dart';

/// Full-screen discard pile display. Read-only — no hand, no play button.
class PileScreen extends StatelessWidget {
  final GameClient client;
  const PileScreen({super.key, required this.client});

  @override
  Widget build(BuildContext context) {
    final state = client.state;
    final discard = state.discardPile ?? [];
    final lastPlayed = state.lastPlayedCardValue;

    return Scaffold(
      backgroundColor: kBackgroundColor,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              lastPlayed == null ? 'Discard Pile' : '$lastPlayed',
              style: TextStyle(
                fontSize: lastPlayed == null ? 48 : 160,
                fontWeight: FontWeight.bold,
                color: lastPlayed == null
                    ? Colors.white.withValues(alpha: 0.4)
                    : Colors.white,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              '${discard.length} / 100 played',
              style: const TextStyle(fontSize: 24, color: Colors.grey),
            ),
            const SizedBox(height: 8),
            Text(
              '♥ ${state.lives ?? 5}',
              style: const TextStyle(fontSize: 24, color: Colors.red),
            ),
          ],
        ),
      ),
    );
  }
}
