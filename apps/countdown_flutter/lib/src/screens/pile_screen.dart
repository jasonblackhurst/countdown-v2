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
    final roundNumber = state.roundNumber ?? 0;
    final lives = state.lives ?? 5;

    return Scaffold(
      backgroundColor: kBackgroundColor,
      body: Stack(
        children: [
          Column(
            children: [
              // Status bar
              SafeArea(
                bottom: false,
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      if (roundNumber > 0)
                        Text(
                          'Round $roundNumber',
                          style: TextStyle(
                            fontSize: 16,
                            color: Colors.white.withValues(alpha: 0.7),
                          ),
                        )
                      else
                        const SizedBox.shrink(),
                      Text(
                        '${discard.length}/100',
                        style: TextStyle(
                          fontSize: 16,
                          color: Colors.white.withValues(alpha: 0.7),
                        ),
                      ),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.favorite,
                            size: 18,
                            color: Colors.red.shade400,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            '$lives',
                            style: TextStyle(
                              fontSize: 16,
                              color: Colors.white.withValues(alpha: 0.7),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              // Card display — centered in remaining space
              Expanded(
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (lastPlayed != null)
                        Container(
                          width: 140,
                          height: 200,
                          decoration: BoxDecoration(
                            color: kCardColor,
                            borderRadius: BorderRadius.circular(14),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.5),
                                blurRadius: 12,
                                offset: const Offset(0, 4),
                              ),
                              BoxShadow(
                                color: kAccentColor.withValues(alpha: 0.15),
                                blurRadius: 20,
                                spreadRadius: 2,
                              ),
                            ],
                          ),
                          alignment: Alignment.center,
                          child: Text(
                            '$lastPlayed',
                            style: const TextStyle(
                              fontSize: 64,
                              fontWeight: FontWeight.w900,
                              color: kCardTextColor,
                            ),
                          ),
                        )
                      else
                        Container(
                          width: 140,
                          height: 200,
                          decoration: BoxDecoration(
                            color: kCardColor.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: Colors.white.withValues(alpha: 0.15),
                            ),
                          ),
                          alignment: Alignment.center,
                          child: Text(
                            'Discard\nPile',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w500,
                              color: Colors.white.withValues(alpha: 0.3),
                            ),
                          ),
                        ),
                      if (playedBy != null) ...[
                        const SizedBox(height: 16),
                        Text(
                          playedBy,
                          style: TextStyle(
                            fontSize: 20,
                            color: Colors.white.withValues(alpha: 0.7),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ],
          ),
          // Win overlay — matches player screen
          if (isWon)
            Positioned.fill(
              child: Container(
                color: Colors.black.withValues(alpha: 0.85),
                child: Stack(
                  children: [
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
                    Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.emoji_events,
                            size: 80,
                            color: Colors.amber,
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'You Won!',
                            style: TextStyle(
                              fontSize: 48,
                              fontWeight: FontWeight.bold,
                              color: Colors.green.shade300,
                            ),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            '${discard.length}/100 cards played',
                            style: const TextStyle(
                              fontSize: 22,
                              color: Colors.white70,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}
