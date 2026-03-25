import 'package:countdown_flutter/src/screens/home_screen.dart';
import 'package:countdown_flutter/src/screens/tutorial_overlay.dart';
import 'package:countdown_flutter/src/client/game_client.dart';
import 'package:countdown_flutter/src/theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _wrap(Widget child) => MaterialApp(theme: countdownTheme(), home: child);

void main() {
  group('TutorialOverlay widget', () {
    testWidgets('T1. renders 4 pages with correct titles', (tester) async {
      await tester.pumpWidget(
        _wrap(Scaffold(body: TutorialOverlay(onDismiss: () {}))),
      );

      // Page 1 visible by default
      expect(find.text('Cards Count Down'), findsOneWidget);

      // Swipe to page 2
      await tester.drag(find.byType(PageView), const Offset(-400, 0));
      await tester.pumpAndSettle();
      expect(find.text('Play in Silence'), findsOneWidget);

      // Swipe to page 3
      await tester.drag(find.byType(PageView), const Offset(-400, 0));
      await tester.pumpAndSettle();
      expect(find.text('Wrong Card? Lose a Life'), findsOneWidget);

      // Swipe to page 4
      await tester.drag(find.byType(PageView), const Offset(-400, 0));
      await tester.pumpAndSettle();
      expect(find.text('Play All 100 to Win!'), findsOneWidget);
    });

    testWidgets('T2. shows page indicator dots', (tester) async {
      await tester.pumpWidget(
        _wrap(Scaffold(body: TutorialOverlay(onDismiss: () {}))),
      );

      // Should have 4 dot indicators
      expect(find.byType(AnimatedContainer), findsNWidgets(4));
    });

    testWidgets('T3. Skip button calls onDismiss', (tester) async {
      var dismissed = false;
      await tester.pumpWidget(
        _wrap(
          Scaffold(body: TutorialOverlay(onDismiss: () => dismissed = true)),
        ),
      );

      await tester.tap(find.text('Skip'));
      expect(dismissed, isTrue);
    });

    testWidgets('T4. Next button advances to next page', (tester) async {
      await tester.pumpWidget(
        _wrap(Scaffold(body: TutorialOverlay(onDismiss: () {}))),
      );

      expect(find.text('Cards Count Down'), findsOneWidget);
      await tester.tap(find.text('Next'));
      await tester.pumpAndSettle();
      expect(find.text('Play in Silence'), findsOneWidget);
    });

    testWidgets('T5. Last page shows "Got it" instead of "Next"', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(Scaffold(body: TutorialOverlay(onDismiss: () {}))),
      );

      // Navigate to last page
      for (var i = 0; i < 3; i++) {
        await tester.tap(find.text('Next'));
        await tester.pumpAndSettle();
      }

      expect(find.text('Next'), findsNothing);
      expect(find.text('Got it'), findsOneWidget);
    });

    testWidgets('T6. "Got it" on last page calls onDismiss', (tester) async {
      var dismissed = false;
      await tester.pumpWidget(
        _wrap(
          Scaffold(body: TutorialOverlay(onDismiss: () => dismissed = true)),
        ),
      );

      // Navigate to last page
      for (var i = 0; i < 3; i++) {
        await tester.tap(find.text('Next'));
        await tester.pumpAndSettle();
      }

      await tester.tap(find.text('Got it'));
      expect(dismissed, isTrue);
    });

    testWidgets('T7. each page has a description', (tester) async {
      await tester.pumpWidget(
        _wrap(Scaffold(body: TutorialOverlay(onDismiss: () {}))),
      );

      expect(
        find.text('Play cards from 100 down to 1 across multiple rounds.'),
        findsOneWidget,
      );
    });
  });

  group('HomeScreen tutorial access', () {
    testWidgets('T8. HomeScreen has a help (?) icon button', (tester) async {
      final client = GameClient();
      await tester.pumpWidget(
        MaterialApp(
          theme: countdownTheme(),
          home: ListenableBuilder(
            listenable: client,
            builder: (_, _) => HomeScreen(client: client),
          ),
        ),
      );

      expect(find.byIcon(Icons.help_outline), findsOneWidget);
      client.dispose();
    });

    testWidgets('T9. tapping ? icon shows the tutorial overlay', (
      tester,
    ) async {
      final client = GameClient();
      await tester.pumpWidget(
        MaterialApp(
          theme: countdownTheme(),
          home: ListenableBuilder(
            listenable: client,
            builder: (_, _) => HomeScreen(client: client),
          ),
        ),
      );

      await tester.tap(find.byIcon(Icons.help_outline));
      await tester.pumpAndSettle();

      expect(find.byType(TutorialOverlay), findsOneWidget);
      client.dispose();
    });

    testWidgets('T10. HomeScreen has a "How to Play" button', (tester) async {
      final client = GameClient();
      await tester.pumpWidget(
        MaterialApp(
          theme: countdownTheme(),
          home: ListenableBuilder(
            listenable: client,
            builder: (_, _) => HomeScreen(client: client),
          ),
        ),
      );

      expect(find.text('How to Play'), findsOneWidget);
      client.dispose();
    });

    testWidgets('T11. tapping "How to Play" shows tutorial overlay', (
      tester,
    ) async {
      final client = GameClient();
      await tester.pumpWidget(
        MaterialApp(
          theme: countdownTheme(),
          home: ListenableBuilder(
            listenable: client,
            builder: (_, _) => HomeScreen(client: client),
          ),
        ),
      );

      await tester.tap(find.text('How to Play'));
      await tester.pumpAndSettle();

      expect(find.byType(TutorialOverlay), findsOneWidget);
      client.dispose();
    });

    testWidgets('T12. dismissing tutorial overlay removes it', (tester) async {
      final client = GameClient();
      await tester.pumpWidget(
        MaterialApp(
          theme: countdownTheme(),
          home: ListenableBuilder(
            listenable: client,
            builder: (_, _) => HomeScreen(client: client),
          ),
        ),
      );

      // Open tutorial
      await tester.tap(find.byIcon(Icons.help_outline));
      await tester.pumpAndSettle();
      expect(find.byType(TutorialOverlay), findsOneWidget);

      // Dismiss via Skip
      await tester.tap(find.text('Skip'));
      await tester.pumpAndSettle();
      expect(find.byType(TutorialOverlay), findsNothing);
      client.dispose();
    });
  });
}
