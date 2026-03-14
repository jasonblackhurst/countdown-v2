import 'package:countdown_core/countdown_core.dart';
import 'package:flutter/material.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

import 'client/game_client.dart';
import 'screens/game_screen.dart';
import 'screens/home_screen.dart';
import 'screens/lobby_screen.dart';
import 'screens/pile_screen.dart';

class _WsMessageSink implements MessageSink {
  final WebSocketChannel _channel;
  _WsMessageSink(this._channel);

  @override
  void send(String msg) => _channel.sink.add(msg);

  @override
  void close() => _channel.sink.close();
}

class CountdownApp extends StatefulWidget {
  final Uri serverUri;
  final bool pileViewerMode;

  const CountdownApp({
    super.key,
    required this.serverUri,
    this.pileViewerMode = false,
  });

  @override
  State<CountdownApp> createState() => _CountdownAppState();
}

class _CountdownAppState extends State<CountdownApp> {
  late final GameClient _client;
  String? _lastShownError;

  @override
  void initState() {
    super.initState();
    _client = GameClient();
    _connectWs();
  }

  void _connectWs() {
    final channel = WebSocketChannel.connect(widget.serverUri);
    _client.connect(
      widget.serverUri,
      incomingStream: channel.stream.cast<String>(),
      sink: _WsMessageSink(channel),
    );
  }

  @override
  void dispose() {
    _client.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _client,
      builder: (context, __) {
        final state = _client.state;

        // Show error SnackBar when a new error arrives from the server
        if (state.lastError != null && state.lastError != _lastShownError) {
          _lastShownError = state.lastError;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text(state.lastError!)),
              );
            }
          });
        }

        if (widget.pileViewerMode && state.roomCode != null) {
          return PileScreen(client: _client);
        }

        if (state.roomCode == null) {
          return HomeScreen(client: _client);
        }

        final phase = state.phase;
        if (phase == GamePhase.round ||
            phase == GamePhase.won ||
            phase == GamePhase.gameOver) {
          return GameScreen(client: _client);
        }

        return LobbyScreen(client: _client);
      },
    );
  }
}
