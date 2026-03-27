import 'package:flutter/material.dart';

import '../theme.dart';

/// A single tutorial page's data.
class _TutorialPage {
  final IconData icon;
  final String title;
  final String description;

  const _TutorialPage({
    required this.icon,
    required this.title,
    required this.description,
  });
}

const _pages = [
  _TutorialPage(
    icon: Icons.arrow_downward_rounded,
    title: 'Cards Count Down',
    description: 'Play cards from 100 down to 1 across multiple rounds.',
  ),
  _TutorialPage(
    icon: Icons.volume_off_rounded,
    title: 'Play in Silence',
    description:
        'No talking, no signals. Synchronize with your teammates through intuition alone.',
  ),
  _TutorialPage(
    icon: Icons.favorite_rounded,
    title: 'Wrong Card? Lose a Life',
    description:
        'If you play a card that isn\'t the highest held by any player, you lose a life. You only have 5.',
  ),
  _TutorialPage(
    icon: Icons.emoji_events_rounded,
    title: 'Play All 100 to Win!',
    description:
        'Work together to play all 100 cards in descending order. Every card counts.',
  ),
];

/// A full-screen modal overlay with swipeable tutorial pages.
class TutorialOverlay extends StatefulWidget {
  /// Called when the user dismisses the tutorial (Skip or Got it).
  final VoidCallback onDismiss;

  const TutorialOverlay({super.key, required this.onDismiss});

  @override
  State<TutorialOverlay> createState() => _TutorialOverlayState();
}

class _TutorialOverlayState extends State<TutorialOverlay> {
  final _controller = PageController();
  int _currentPage = 0;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  bool get _isLastPage => _currentPage == _pages.length - 1;

  void _nextPage() {
    if (_isLastPage) {
      widget.onDismiss();
    } else {
      _controller.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: kBackgroundColor.withValues(alpha: 0.95),
      child: SafeArea(
        child: Column(
          children: [
            // Top bar with Skip
            Align(
              alignment: Alignment.topRight,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: TextButton(
                  onPressed: widget.onDismiss,
                  child: Text(
                    'Skip',
                    style: TextStyle(
                      color: kAccentColor.withValues(alpha: 0.7),
                      fontSize: 16,
                    ),
                  ),
                ),
              ),
            ),
            // Pages
            Expanded(
              child: PageView.builder(
                controller: _controller,
                itemCount: _pages.length,
                onPageChanged: (i) => setState(() => _currentPage = i),
                itemBuilder: (context, index) {
                  final page = _pages[index];
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 40),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(page.icon, size: 80, color: kAccentColor),
                        const SizedBox(height: 32),
                        Text(
                          page.title,
                          style: const TextStyle(
                            fontFamily: 'PlayfairDisplay',
                            fontSize: 28,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          page.description,
                          style: TextStyle(
                            fontSize: 16,
                            color: kCardColor.withValues(alpha: 0.8),
                            height: 1.5,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
            // Page indicator dots
            Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(
                  _pages.length,
                  (i) => AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    width: _currentPage == i ? 24 : 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: _currentPage == i
                          ? kAccentColor
                          : kAccentColor.withValues(alpha: 0.3),
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                ),
              ),
            ),
            // Next / Got it button
            Padding(
              padding: const EdgeInsets.only(bottom: 32, left: 40, right: 40),
              child: SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: _nextPage,
                  child: Text(_isLastPage ? 'Got it' : 'Next'),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
