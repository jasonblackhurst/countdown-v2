import 'package:confetti/confetti.dart';
import 'package:countdown_core/countdown_core.dart';
import 'package:flutter/material.dart';

import '../client/game_client.dart';
import '../theme.dart';

/// Full-screen discard pile display. Read-only — no hand, no play button.
class PileScreen extends StatefulWidget {
  final GameClient client;
  const PileScreen({super.key, required this.client});

  @override
  State<PileScreen> createState() => _PileScreenState();
}

class _PileScreenState extends State<PileScreen> {
  late final ConfettiController _confettiController;

  @override
  void initState() {
    super.initState();
    _confettiController = ConfettiController(
      duration: const Duration(seconds: 10),
    );
    widget.client.addListener(_onClientUpdate);
    if (widget.client.state.phase == GamePhase.won) {
      _confettiController.play();
    }
  }

  void _onClientUpdate() {
    if (widget.client.state.phase == GamePhase.won) {
      _confettiController.play();
    }
  }

  @override
  void dispose() {
    widget.client.removeListener(_onClientUpdate);
    _confettiController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = widget.client.state;
    final discard = state.discardPile ?? [];
    final lastPlayed = state.lastPlayedCardValue;
    final playedBy = state.lastPlayedByName;
    final isWon = state.phase == GamePhase.won;

    return Scaffold(
      backgroundColor: kBackgroundColor,
      body: Stack(
        children: [
          Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Card display
                if (lastPlayed != null)
                  Container(
                    width: 280,
                    height: 400,
                    decoration: BoxDecoration(
                      color: kCardColor,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.4),
                          blurRadius: 20,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: Center(
                      child: Text(
                        '$lastPlayed',
                        style: const TextStyle(
                          fontSize: 120,
                          fontWeight: FontWeight.bold,
                          color: kCardTextColor,
                        ),
                      ),
                    ),
                  )
                else
                  Text(
                    'Discard Pile',
                    style: TextStyle(
                      fontSize: 48,
                      fontWeight: FontWeight.bold,
                      color: Colors.white.withValues(alpha: 0.4),
                    ),
                  ),
                const SizedBox(height: 24),
                // Who played it
                if (playedBy != null)
                  Text(
                    playedBy,
                    style: TextStyle(
                      fontSize: 28,
                      color: Colors.white.withValues(alpha: 0.7),
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
          // Confetti on win
          if (isWon)
            Align(
              alignment: Alignment.topCenter,
              child: ConfettiWidget(
                confettiController: _confettiController,
                blastDirectionality: BlastDirectionality.explosive,
                shouldLoop: true,
                colors: const [
                  Colors.green,
                  Colors.amber,
                  Colors.yellow,
                  Colors.lightGreen,
                  Colors.white,
                ],
                numberOfParticles: 20,
                maxBlastForce: 30,
                minBlastForce: 10,
                emissionFrequency: 0.05,
                gravity: 0.1,
              ),
            ),
        ],
      ),
    );
  }
}
