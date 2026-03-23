import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../theme.dart';

/// Interstitial screen shown between rounds, displaying round completion
/// stats before the player proceeds to the vote UI.
class RoundTransitionScreen extends StatelessWidget {
  final int roundNumber;
  final int cardsPlayed;
  final int lives;
  final VoidCallback onContinue;

  const RoundTransitionScreen({
    super.key,
    required this.roundNumber,
    required this.cardsPlayed,
    required this.lives,
    required this.onContinue,
  });

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
                'Round $roundNumber Complete',
                style: GoogleFonts.playfairDisplay(
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                  color: kAccentColor,
                ),
              ),
              const SizedBox(height: 40),

              // Cards played progress
              Text(
                '$cardsPlayed / 100 cards played',
                style: const TextStyle(fontSize: 18, color: Colors.white),
              ),
              const SizedBox(height: 12),
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: LinearProgressIndicator(
                  value: cardsPlayed / 100,
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
                    '$lives lives remaining',
                    style: const TextStyle(fontSize: 18, color: Colors.white),
                  ),
                ],
              ),
              const SizedBox(height: 48),

              // Continue button
              FilledButton(
                onPressed: onContinue,
                child: const Text('Continue'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
