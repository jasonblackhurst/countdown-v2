import 'package:flutter/material.dart';

import '../client/game_client.dart';
import '../theme.dart';
import 'tutorial_overlay.dart';

class HomeScreen extends StatefulWidget {
  final GameClient client;
  final VoidCallback? onSpectate;
  const HomeScreen({super.key, required this.client, this.onSpectate});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _codeController = TextEditingController();
  final _nameController = TextEditingController();
  bool _showTutorial = false;

  @override
  void dispose() {
    _codeController.dispose();
    _nameController.dispose();
    super.dispose();
  }

  void _showCreateDialog() {
    showDialog<void>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Create Room'),
        content: TextField(
          controller: _nameController,
          decoration: const InputDecoration(labelText: 'Your name'),
        ),
        actions: [
          TextButton(
            onPressed: () {
              widget.client.createRoom(_nameController.text.trim());
              Navigator.pop(context);
            },
            child: const Text('Create'),
          ),
        ],
      ),
    );
  }

  void _showJoinDialog() {
    showDialog<void>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Join Room'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _nameController,
              decoration: const InputDecoration(labelText: 'Your name'),
            ),
            TextField(
              controller: _codeController,
              decoration: const InputDecoration(labelText: 'Room code'),
              textCapitalization: TextCapitalization.characters,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              widget.client.joinRoom(
                _codeController.text.trim().toUpperCase(),
                _nameController.text.trim(),
              );
              Navigator.pop(context);
            },
            child: const Text('Join'),
          ),
        ],
      ),
    );
  }

  void _showSpectateDialog() {
    showDialog<void>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Table Display'),
        content: TextField(
          controller: _codeController,
          decoration: const InputDecoration(labelText: 'Room code'),
          textCapitalization: TextCapitalization.characters,
        ),
        actions: [
          TextButton(
            onPressed: () {
              widget.client.spectateRoom(
                _codeController.text.trim().toUpperCase(),
              );
              widget.onSpectate?.call();
              Navigator.pop(context);
            },
            child: const Text('Watch'),
          ),
        ],
      ),
    );
  }

  void _openTutorial() => setState(() => _showTutorial = true);
  void _closeTutorial() => setState(() => _showTutorial = false);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.help_outline),
            onPressed: _openTutorial,
            tooltip: 'How to Play',
          ),
        ],
      ),
      extendBodyBehindAppBar: true,
      body: Stack(
        children: [
          Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  'Countdown',
                  style:
                      Theme.of(context).appBarTheme.titleTextStyle?.copyWith(
                        fontSize: 48,
                        fontWeight: FontWeight.bold,
                      ) ??
                      const TextStyle(
                        fontSize: 48,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                ),
                const SizedBox(height: 8),
                Text(
                  '100 → 1  ·  play in silence',
                  style: TextStyle(
                    fontSize: 16,
                    color: kAccentColor.withValues(alpha: 0.7),
                  ),
                ),
                const SizedBox(height: 48),
                FilledButton(
                  onPressed: _showCreateDialog,
                  child: const Text('Create Room'),
                ),
                const SizedBox(height: 12),
                OutlinedButton(
                  onPressed: _showJoinDialog,
                  child: const Text('Join Room'),
                ),
                const SizedBox(height: 12),
                OutlinedButton(
                  onPressed: _showSpectateDialog,
                  child: const Text('Table Display'),
                ),
                const SizedBox(height: 24),
                TextButton(
                  onPressed: _openTutorial,
                  child: Text(
                    'How to Play',
                    style: TextStyle(
                      color: kAccentColor.withValues(alpha: 0.7),
                      fontSize: 14,
                    ),
                  ),
                ),
              ],
            ),
          ),
          if (_showTutorial) TutorialOverlay(onDismiss: _closeTutorial),
        ],
      ),
    );
  }
}
