import 'package:countdown_core/countdown_core.dart';
import 'package:flutter/material.dart';

import '../client/game_client.dart';

class GameScreen extends StatelessWidget {
  final GameClient client;
  const GameScreen({super.key, required this.client});

  @override
  Widget build(BuildContext context) {
    final state = client.state;
    final myPlayer = state.myPlayer;
    final hand = myPlayer?.hand ?? [];
    final discard = state.discardPile ?? [];
    final lastPlayed = discard.isNotEmpty ? discard.last : null;

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              // ── Status bar ──────────────────────────────────────────────
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
                    style: const TextStyle(fontSize: 14, color: Colors.grey),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              // ── Last played card ────────────────────────────────────────
              _LastPlayedCard(value: lastPlayed),
              const SizedBox(height: 24),
              const Divider(),
              const SizedBox(height: 8),
              const Text(
                'Your hand',
                style: TextStyle(fontSize: 16, color: Colors.grey),
              ),
              const SizedBox(height: 8),
              // ── Hand ────────────────────────────────────────────────────
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
                              ? () => client.playCard(hand[i])
                              : null,
                        ),
                      ),
              ),

              // ── Final round callout ─────────────────────────────────────
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
              // ── End-of-round / game-over banners ────────────────────────
              if (state.phase == GamePhase.won)
                _Banner(
                  text: 'You won! All 100 cards played.',
                  color: Colors.green.shade700,
                ),
              if (state.phase == GamePhase.gameOver)
                _Banner(
                  text: 'Game over — no lives left.',
                  color: Colors.red.shade700,
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

class _Banner extends StatelessWidget {
  final String text;
  final Color color;
  const _Banner({required this.text, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      margin: const EdgeInsets.only(top: 8),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: const TextStyle(color: Colors.white, fontSize: 16),
      ),
    );
  }
}
