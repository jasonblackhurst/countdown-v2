import 'package:flutter/material.dart';

import '../client/game_client.dart';

class HomeScreen extends StatefulWidget {
  final GameClient client;
  const HomeScreen({super.key, required this.client});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _codeController = TextEditingController();
  final _nameController = TextEditingController();

  @override
  void dispose() {
    _codeController.dispose();
    _nameController.dispose();
    super.dispose();
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text(
              'Countdown',
              style: TextStyle(fontSize: 48, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text(
              '100 → 1  ·  play in silence',
              style: TextStyle(fontSize: 16, color: Colors.grey),
            ),
            const SizedBox(height: 48),
            FilledButton(
              onPressed: widget.client.createRoom,
              child: const Text('Create Room'),
            ),
            const SizedBox(height: 12),
            OutlinedButton(
              onPressed: _showJoinDialog,
              child: const Text('Join Room'),
            ),
          ],
        ),
      ),
    );
  }
}
