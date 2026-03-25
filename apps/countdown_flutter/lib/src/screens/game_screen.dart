import 'package:confetti/confetti.dart';
import 'package:countdown_core/countdown_core.dart';
import 'package:flutter/material.dart';

import '../client/game_client.dart';

class GameScreen extends StatefulWidget {
  final GameClient client;
  const GameScreen({super.key, required this.client});

  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen> {
  late final ConfettiController _confettiController;

  @override
  void initState() {
    super.initState();
    _confettiController = ConfettiController(
      duration: const Duration(seconds: 5),
    );
    // Start confetti if already in won phase
    if (widget.client.state.phase == GamePhase.won) {
      _confettiController.play();
    }
    widget.client.addListener(_onStateChange);
  }

  void _onStateChange() {
    if (widget.client.state.phase == GamePhase.won) {
      _confettiController.play();
    }
  }

  @override
  void dispose() {
    widget.client.removeListener(_onStateChange);
    _confettiController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = widget.client.state;
    final myPlayer = state.myPlayer;
    final hand = myPlayer?.hand ?? [];
    final discard = state.discardPile ?? [];
    final lastPlayed = discard.isNotEmpty ? discard.last : null;

    return Scaffold(
      body: SafeArea(
        child: Stack(
          children: [
            // ── Normal game content ──────────────────────────────────────
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  // ── Status bar ─────────────────────────────────────────
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Round ${state.roundNumber ?? 0}',
                        style: const TextStyle(fontSize: 18),
                      ),
                      _LivesIndicator(lives: state.lives ?? 5),
                      Text(
                        '${discard.length}/100 played',
                        style: const TextStyle(
                          fontSize: 14,
                          color: Colors.grey,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  // ── Last played card ───────────────────────────────────
                  _LastPlayedCard(value: lastPlayed),
                  const SizedBox(height: 24),
                  const Divider(),
                  const SizedBox(height: 8),
                  const Text(
                    'Your hand',
                    style: TextStyle(fontSize: 16, color: Colors.grey),
                  ),
                  const SizedBox(height: 8),
                  // ── Hand ───────────────────────────────────────────────
                  Expanded(
                    child: hand.isEmpty
                        ? const Center(child: Text('No cards'))
                        : GridView.builder(
                            gridDelegate:
                                const SliverGridDelegateWithMaxCrossAxisExtent(
                                  maxCrossAxisExtent: 120,
                                  mainAxisSpacing: 8,
                                  crossAxisSpacing: 8,
                                  childAspectRatio: 0.75,
                                ),
                            itemCount: hand.length,
                            itemBuilder: (_, i) => _CardTile(
                              value: hand[i],
                              onTap: state.phase == GamePhase.round
                                  ? () => widget.client.playCard(hand[i])
                                  : null,
                            ),
                          ),
                  ),

                  // ── Final round callout ────────────────────────────────
                  if (state.isFinalRound)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Text(
                        'Final round! Some players have extra cards.',
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Colors.orange.shade700,
                        ),
                      ),
                    ),
                ],
              ),
            ),

            // ── Win overlay ──────────────────────────────────────────────
            if (state.phase == GamePhase.won)
              _WinOverlay(
                cardsPlayed: discard.length,
                confettiController: _confettiController,
                onPlayAgain: () => widget.client.playAgain(),
                onLeaveRoom: () => widget.client.disconnect(),
              ),

            // ── Loss overlay ─────────────────────────────────────────────
            if (state.phase == GamePhase.gameOver)
              _LossOverlay(
                cardsPlayed: discard.length,
                onPlayAgain: () => widget.client.playAgain(),
                onLeaveRoom: () => widget.client.disconnect(),
              ),
          ],
        ),
      ),
    );
  }
}

// ── Win Overlay ──────────────────────────────────────────────────────────────

class _WinOverlay extends StatelessWidget {
  final int cardsPlayed;
  final ConfettiController confettiController;
  final VoidCallback onPlayAgain;
  final VoidCallback onLeaveRoom;

  const _WinOverlay({
    required this.cardsPlayed,
    required this.confettiController,
    required this.onPlayAgain,
    required this.onLeaveRoom,
  });

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: Container(
        color: Colors.black.withValues(alpha: 0.85),
        child: Stack(
          children: [
            // Confetti from top center
            Align(
              alignment: Alignment.topCenter,
              child: ConfettiWidget(
                confettiController: confettiController,
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
            // Content
            Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.emoji_events, size: 80, color: Colors.amber),
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
                    '$cardsPlayed/100 cards played',
                    style: const TextStyle(fontSize: 22, color: Colors.white70),
                  ),
                  const SizedBox(height: 40),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green.shade700,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 32,
                        vertical: 14,
                      ),
                    ),
                    onPressed: onPlayAgain,
                    child: const Text('Play Again'),
                  ),
                  const SizedBox(height: 16),
                  OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.white70,
                      side: const BorderSide(color: Colors.white30),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 32,
                        vertical: 14,
                      ),
                    ),
                    onPressed: onLeaveRoom,
                    child: const Text('Leave Room'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Loss Overlay ─────────────────────────────────────────────────────────────

class _LossOverlay extends StatelessWidget {
  final int cardsPlayed;
  final VoidCallback onPlayAgain;
  final VoidCallback onLeaveRoom;

  const _LossOverlay({
    required this.cardsPlayed,
    required this.onPlayAgain,
    required this.onLeaveRoom,
  });

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: Container(
        color: Colors.black.withValues(alpha: 0.9),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.favorite_border, size: 80, color: Colors.red.shade400),
              const SizedBox(height: 16),
              Text(
                'Game Over',
                style: TextStyle(
                  fontSize: 48,
                  fontWeight: FontWeight.bold,
                  color: Colors.red.shade300,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'No lives left',
                style: TextStyle(fontSize: 20, color: Colors.white54),
              ),
              const SizedBox(height: 12),
              Text(
                '$cardsPlayed/100 cards played',
                style: const TextStyle(fontSize: 22, color: Colors.white70),
              ),
              const SizedBox(height: 40),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red.shade800,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 32,
                    vertical: 14,
                  ),
                ),
                onPressed: onPlayAgain,
                child: const Text('Play Again'),
              ),
              const SizedBox(height: 16),
              OutlinedButton(
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.white70,
                  side: const BorderSide(color: Colors.white30),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 32,
                    vertical: 14,
                  ),
                ),
                onPressed: onLeaveRoom,
                child: const Text('Leave Room'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Sub-widgets ─────────────────────────────────────────────────────────────

class _LivesIndicator extends StatelessWidget {
  final int lives;
  const _LivesIndicator({required this.lives});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          '$lives',
          style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
        ),
        const SizedBox(width: 4),
        const Icon(Icons.favorite, color: Colors.red, size: 20),
      ],
    );
  }
}

class _LastPlayedCard extends StatelessWidget {
  final int? value;
  const _LastPlayedCard({this.value});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 120,
      width: 80,
      decoration: BoxDecoration(
        color: Colors.grey.shade200,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade400),
      ),
      alignment: Alignment.center,
      child: value == null
          ? const Text('—', style: TextStyle(fontSize: 32, color: Colors.grey))
          : Text(
              '$value',
              style: const TextStyle(fontSize: 40, fontWeight: FontWeight.bold),
            ),
    );
  }
}

class _CardTile extends StatelessWidget {
  final int value;
  final VoidCallback? onTap;
  const _CardTile({required this.value, this.onTap});

  @override
  Widget build(BuildContext context) {
    // Semantics(button: true) produces role="button" in Flutter's web accessibility
    // tree, which lets Playwright and screen readers interact with card tiles via
    // standard click/activation — GestureDetector alone only produces role="group".
    return Semantics(
      button: onTap != null,
      label: '$value',
      onTap: onTap,
      child: GestureDetector(
        onTap: onTap,
        child: Card(
          elevation: onTap != null ? 4 : 1,
          child: Center(
            child: Text(
              '$value',
              style: TextStyle(
                fontSize: 32,
                fontWeight: FontWeight.bold,
                color: onTap != null ? Colors.black87 : Colors.grey,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
