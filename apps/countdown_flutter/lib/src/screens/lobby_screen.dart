import 'package:countdown_core/countdown_core.dart';
import 'package:flutter/material.dart';

import '../client/game_client.dart';

class LobbyScreen extends StatefulWidget {
  final GameClient client;
  const LobbyScreen({super.key, required this.client});

  @override
  State<LobbyScreen> createState() => _LobbyScreenState();
}

class _LobbyScreenState extends State<LobbyScreen> {
  int _selectedCount = 1;

  @override
  Widget build(BuildContext context) {
    final state = widget.client.state;
    final players = state.players ?? [];
    final gameStarted = (state.roundNumber ?? 0) > 0;
    final isRound = state.phase == GamePhase.round;
    // Show vote UI during an active round OR between rounds (lobby after round 1+)
    final showVote = isRound || gameStarted;

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
              style: const TextStyle(
                fontSize: 56,
                fontWeight: FontWeight.bold,
                letterSpacing: 12,
              ),
            ),
            const SizedBox(height: 32),
            const Text('Players', style: TextStyle(fontSize: 18)),
            const SizedBox(height: 8),
            Expanded(
              child: ListView.separated(
                itemCount: players.length,
                separatorBuilder: (_, __) => const Divider(),
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
                        onSelected: (_) => setState(() => _selectedCount = n),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 8),
              FilledButton(
                onPressed: () => widget.client.voteCardCount(_selectedCount),
                child: const Text('Confirm Vote'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
