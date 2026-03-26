import 'package:confetti/confetti.dart';
import 'package:countdown_core/countdown_core.dart';
import 'package:flutter/material.dart';

import '../client/game_client.dart';
import '../services/sound_service.dart';
import '../theme.dart';

class GameScreen extends StatefulWidget {
  final GameClient client;
  final SoundService? soundService;
  const GameScreen({super.key, required this.client, this.soundService});

  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen> with TickerProviderStateMixin {
  late final ConfettiController _confettiController;
  late final AnimationController _lifeLossController;
  late final AnimationController _livesPulseController;
  bool _showLifeLossFlash = false;
  late final SoundService _soundService;

  @override
  void initState() {
    super.initState();
    _confettiController = ConfettiController(
      duration: const Duration(seconds: 5),
    );
    _lifeLossController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _lifeLossController.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        setState(() => _showLifeLossFlash = false);
      }
    });
    _livesPulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
      lowerBound: 0.8,
      upperBound: 1.2,
      value: 1.0,
    );
    _soundService = widget.soundService ?? SystemSoundService();
    // Start confetti if already in won phase
    if (widget.client.state.phase == GamePhase.won) {
      _confettiController.play();
    }
    widget.client.addListener(_onStateChange);
  }

  void _onStateChange() {
    final phase = widget.client.state.phase;
    final prevPhase = widget.client.previousPhase;

    if (phase == GamePhase.won) {
      _confettiController.play();
      if (prevPhase != GamePhase.won) {
        _soundService.playWinSound();
      }
    }
    if (phase == GamePhase.gameOver && prevPhase != GamePhase.gameOver) {
      _soundService.playLossSound();
    }
    // Detect life loss
    final prevLives = widget.client.previousLives;
    final curLives = widget.client.state.lives;
    if (prevLives != null && curLives != null && curLives < prevLives) {
      _triggerLifeLossFlash();
      _soundService.playLifeLossSound();
    }
  }

  void _triggerLifeLossFlash() {
    setState(() => _showLifeLossFlash = true);
    _lifeLossController.forward(from: 0.0);
    // Pulse the lives indicator
    _livesPulseController.forward(from: 0.8).then((_) {
      if (mounted) _livesPulseController.reverse();
    });
  }

  @override
  void dispose() {
    widget.client.removeListener(_onStateChange);
    _confettiController.dispose();
    _lifeLossController.dispose();
    _livesPulseController.dispose();
    super.dispose();
  }

  Widget _buildHandGrid(List<int> hand, ClientState state) {
    if (hand.isEmpty) {
      return const Center(child: Text('No cards'));
    }
    return GridView.builder(
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 120,
        mainAxisSpacing: 8,
        crossAxisSpacing: 8,
        childAspectRatio: 0.75,
      ),
      itemCount: hand.length,
      itemBuilder: (_, i) => _AnimatedCardTile(
        value: hand[i],
        onTap: state.phase == GamePhase.round
            ? () {
                if (!_soundService.isMuted) {
                  _soundService.playCardSound();
                }
                widget.client.playCard(hand[i]);
              }
            : null,
      ),
    );
  }

  Widget _buildDiscardArea(ClientState state, int? lastPlayed) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // ── Recent play indicator ───────────────────────────
        if (state.lastPlayedByName != null && state.lastPlayedCardValue != null)
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 300),
            child: Text(
              '${state.lastPlayedByName} played ${state.lastPlayedCardValue}',
              key: ValueKey<String>(
                '${state.lastPlayedByName}-${state.lastPlayedCardValue}',
              ),
              style: TextStyle(
                fontSize: 14,
                color: kAccentColor.withValues(alpha: 0.9),
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        const SizedBox(height: 8),
        // ── Last played card ───────────────────────────────────
        AnimatedSwitcher(
          key: const Key('last-played-animated'),
          duration: const Duration(milliseconds: 300),
          transitionBuilder: (child, animation) =>
              ScaleTransition(scale: animation, child: child),
          child: _LastPlayedCard(
            key: ValueKey<int?>(lastPlayed),
            value: lastPlayed,
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = widget.client.state;
    final myPlayer = state.myPlayer;
    final hand = myPlayer?.hand ?? [];
    final discard = state.discardPile ?? [];
    final lastPlayed = state.lastPlayedCardValue;

    return Scaffold(
      body: SafeArea(
        child: Stack(
          children: [
            // ── Normal game content ──────────────────────────────────────
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: Column(
                children: [
                  // ── Compact status bar ──────────────────────────────────
                  Row(
                    key: const Key('compact-status-bar'),
                    children: [
                      Text(
                        'R${state.roundNumber ?? 0}',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(width: 8),
                      ScaleTransition(
                        key: const Key('lives-indicator'),
                        scale: _livesPulseController,
                        child: _LivesIndicator(lives: state.lives ?? 5),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '${discard.length}/100',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.white.withValues(alpha: 0.6),
                        ),
                      ),
                      const Spacer(),
                      SizedBox(
                        width: 36,
                        height: 36,
                        child: IconButton(
                          key: const Key('mute-toggle'),
                          padding: EdgeInsets.zero,
                          icon: Icon(
                            _soundService.isMuted
                                ? Icons.volume_off
                                : Icons.volume_up,
                            size: 18,
                            color: Colors.white.withValues(alpha: 0.5),
                          ),
                          onPressed: () {
                            setState(() {
                              _soundService.toggleMute();
                            });
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  // ── Player bar ──────────────────────────────────────
                  _PlayerBar(
                    key: const Key('player-bar'),
                    players: state.players ?? [],
                    localPlayerId: state.playerId,
                    lastPlayedByName: state.lastPlayedByName,
                  ),
                  const SizedBox(height: 4),
                  // ── Responsive layout ──────────────────────────────────
                  Expanded(
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        final isWide = constraints.maxWidth >= 600;
                        if (isWide) {
                          return Row(
                            key: const Key('wide-layout'),
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              // Left: discard area
                              Expanded(
                                child: Center(
                                  child: _buildDiscardArea(state, lastPlayed),
                                ),
                              ),
                              const SizedBox(width: 16),
                              // Right: hand
                              Expanded(
                                child: Column(
                                  children: [
                                    Expanded(
                                      child: _buildHandGrid(hand, state),
                                    ),
                                    if (state.isFinalRound)
                                      Padding(
                                        padding: const EdgeInsets.only(
                                          bottom: 4,
                                        ),
                                        child: Text(
                                          'Final round! Some players have extra cards.',
                                          textAlign: TextAlign.center,
                                          style: Theme.of(context)
                                              .textTheme
                                              .bodySmall
                                              ?.copyWith(color: Colors.amber),
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                            ],
                          );
                        }
                        // Narrow (phone) layout
                        return Column(
                          key: const Key('narrow-layout'),
                          children: [
                            _buildDiscardArea(state, lastPlayed),
                            const SizedBox(height: 12),
                            Expanded(child: _buildHandGrid(hand, state)),
                            if (state.isFinalRound)
                              Padding(
                                padding: const EdgeInsets.only(bottom: 4),
                                child: Text(
                                  'Final round! Some players have extra cards.',
                                  textAlign: TextAlign.center,
                                  style: Theme.of(context).textTheme.bodySmall
                                      ?.copyWith(color: Colors.amber),
                                ),
                              ),
                          ],
                        );
                      },
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

            // ── Life-loss red flash ────────────────────────────────────
            if (_showLifeLossFlash)
              Positioned.fill(
                key: const Key('life-loss-flash'),
                child: FadeTransition(
                  opacity: Tween<double>(
                    begin: 0.35,
                    end: 0.0,
                  ).animate(_lifeLossController),
                  child: IgnorePointer(child: Container(color: Colors.red)),
                ),
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
  const _LastPlayedCard({super.key, this.value});

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const Key('last-played-card'),
      height: 160,
      width: 110,
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
            color: kAccentColor.withValues(alpha: value != null ? 0.15 : 0.0),
            blurRadius: 20,
            spreadRadius: 2,
          ),
        ],
      ),
      alignment: Alignment.center,
      child: value == null
          ? Text(
              'Discard Pile',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: kCardTextColor.withValues(alpha: 0.4),
              ),
            )
          : Text(
              '$value',
              style: const TextStyle(
                fontSize: 52,
                fontWeight: FontWeight.w900,
                color: kCardTextColor,
              ),
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
                color: onTap != null
                    ? kCardTextColor
                    : kCardTextColor.withValues(alpha: 0.5),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Compact player bar showing each player's name and card count.
class _PlayerBar extends StatelessWidget {
  final List<PlayerSnapshot> players;
  final String? localPlayerId;
  final String? lastPlayedByName;

  const _PlayerBar({
    super.key,
    required this.players,
    this.localPlayerId,
    this.lastPlayedByName,
  });

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 4,
      alignment: WrapAlignment.center,
      children: players.map((p) {
        final isLocal = p.id == localPlayerId;
        final justPlayed = p.name == lastPlayedByName;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: justPlayed
                ? kAccentColor.withValues(alpha: 0.25)
                : kSurfaceColor,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isLocal
                  ? kAccentColor
                  : Colors.white.withValues(alpha: 0.15),
              width: isLocal ? 1.5 : 1.0,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                p.name,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: isLocal ? FontWeight.bold : FontWeight.normal,
                  color: isLocal ? kAccentColor : Colors.white70,
                ),
              ),
              if (isLocal)
                Text(
                  ' (you)',
                  style: TextStyle(
                    fontSize: 11,
                    color: kAccentColor.withValues(alpha: 0.7),
                  ),
                ),
              const SizedBox(width: 4),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '${p.handSize}',
                  style: const TextStyle(fontSize: 11, color: Colors.white54),
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }
}

/// Card tile wrapped with a scale animation for tap feedback.
class _AnimatedCardTile extends StatefulWidget {
  final int value;
  final VoidCallback? onTap;
  const _AnimatedCardTile({required this.value, this.onTap});

  @override
  State<_AnimatedCardTile> createState() => _AnimatedCardTileState();
}

class _AnimatedCardTileState extends State<_AnimatedCardTile>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
      lowerBound: 0.0,
      upperBound: 1.0,
      value: 1.0,
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _handleTap() {
    if (widget.onTap == null) return;
    // Animate scale down, then fire the callback
    _controller.animateTo(0.85, curve: Curves.easeIn).then((_) {
      if (mounted) {
        _controller.animateTo(1.0, curve: Curves.easeOut);
      }
    });
    widget.onTap!();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedScale(
      scale: 1.0,
      duration: const Duration(milliseconds: 200),
      child: ScaleTransition(
        scale: _controller,
        child: _CardTile(
          value: widget.value,
          onTap: widget.onTap != null ? _handleTap : null,
        ),
      ),
    );
  }
}
