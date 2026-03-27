import 'package:countdown_core/countdown_core.dart';
import 'package:flutter/material.dart';

import '../client/game_client.dart';
import '../theme.dart';

class LobbyScreen extends StatefulWidget {
  final GameClient client;
  const LobbyScreen({super.key, required this.client});

  @override
  State<LobbyScreen> createState() => _LobbyScreenState();
}

class _LobbyScreenState extends State<LobbyScreen> {
  int? _selectedCount;

  @override
  Widget build(BuildContext context) {
    final state = widget.client.state;
    final players = state.players ?? [];
    final gameStarted = (state.roundNumber ?? 0) > 0;
    final isRound = state.phase == GamePhase.round;
    // Show vote UI during an active round, between rounds (lobby after round 1+),
    // or post-startGame waiting for first vote (game_initialized: true, round 0)
    final showVote = isRound || gameStarted || state.gameInitialized;

    return Scaffold(
      appBar: AppBar(
        title: Text('Room  ${state.roomCode ?? ''}'),
        centerTitle: true,
      ),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              state.roomCode ?? '',
              textAlign: TextAlign.center,
              style:
                  Theme.of(context).appBarTheme.titleTextStyle?.copyWith(
                    fontSize: 56,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 12,
                    color: kAccentColor,
                  ) ??
                  TextStyle(
                    fontSize: 56,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 12,
                    color: kAccentColor,
                  ),
            ),
            const SizedBox(height: 32),
            Text(
              'Players',
              style: TextStyle(
                fontSize: 18,
                color: Colors.white.withValues(alpha: 0.7),
              ),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: ListView.separated(
                itemCount: players.length,
                separatorBuilder: (_, _) => const Divider(),
                itemBuilder: (_, i) => ListTile(
                  leading: const Icon(Icons.person),
                  title: Text(players[i].name),
                  trailing: players[i].id == state.playerId
                      ? const Chip(label: Text('You'))
                      : null,
                ),
              ),
            ),
            const SizedBox(height: 16),
            if (showVote &&
                state.cardsRemaining != null &&
                state.cardsRemaining! < players.length * 2) ...[
              Text(
                'Final round — cards may be dealt unevenly',
                textAlign: TextAlign.center,
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(color: Colors.amber),
              ),
              const SizedBox(height: 8),
            ],
            if (!showVote) ...[
              FilledButton(
                onPressed: players.length >= 2
                    ? () => widget.client.startGame()
                    : null,
                child: const Text('Start Game'),
              ),
            ] else ...[
              const Text('Vote: cards per player this round'),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  for (var n = 1; n <= 5; n++)
                    Padding(
                      padding: const EdgeInsets.all(4),
                      child: ChoiceChip(
                        label: Text('$n'),
                        selected: _selectedCount == n,
                        onSelected: (_) {
                          widget.client.voteCardCount(n);
                          setState(() => _selectedCount = n);
                        },
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 8),
              AnimatedOpacity(
                opacity: _selectedCount != null ? 1.0 : 0.0,
                duration: const Duration(milliseconds: 200),
                child: const Text(
                  'Waiting for other players...',
                  style: TextStyle(fontSize: 16, color: Colors.white70),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
