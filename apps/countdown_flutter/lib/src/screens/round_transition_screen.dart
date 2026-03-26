import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../client/game_client.dart';
import '../theme.dart';

/// Interstitial screen shown between rounds, displaying round completion
/// stats and allowing the player to vote for the next round's card count.
class RoundTransitionScreen extends StatefulWidget {
  final int roundNumber;
  final int cardsPlayed;
  final int lives;
  final GameClient client;

  const RoundTransitionScreen({
    super.key,
    required this.roundNumber,
    required this.cardsPlayed,
    required this.lives,
    required this.client,
  });

  @override
  State<RoundTransitionScreen> createState() => _RoundTransitionScreenState();
}

class _RoundTransitionScreenState extends State<RoundTransitionScreen> {
  int? _selectedCount;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Round complete title
              Text(
                'Round ${widget.roundNumber} Complete',
                style: GoogleFonts.playfairDisplay(
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                  color: kAccentColor,
                ),
              ),
              const SizedBox(height: 40),

              // Cards played progress
              Text(
                '${widget.cardsPlayed} / 100 cards played',
                style: const TextStyle(fontSize: 18, color: Colors.white),
              ),
              const SizedBox(height: 12),
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: LinearProgressIndicator(
                  value: widget.cardsPlayed / 100,
                  minHeight: 12,
                  backgroundColor: Colors.white.withValues(alpha: 0.15),
                  valueColor: const AlwaysStoppedAnimation<Color>(kAccentColor),
                ),
              ),
              const SizedBox(height: 32),

              // Lives remaining
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.favorite, color: Colors.red.shade400, size: 24),
                  const SizedBox(width: 8),
                  Text(
                    '${widget.lives} lives remaining',
                    style: const TextStyle(fontSize: 18, color: Colors.white),
                  ),
                ],
              ),
              const SizedBox(height: 48),

              // Vote UI — chips always visible, tap to vote/re-vote
              const Text(
                'Cards per player next round',
                style: TextStyle(fontSize: 16, color: Colors.white),
              ),
              const SizedBox(height: 12),
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
              if (_selectedCount != null) ...[
                const SizedBox(height: 16),
                const Text(
                  'Waiting for other players...',
                  style: TextStyle(fontSize: 16, color: Colors.white70),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
