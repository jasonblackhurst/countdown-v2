import 'dart:async';

import 'package:countdown_core/countdown_core.dart';
import 'package:flutter/material.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

import 'client/game_client.dart';
import 'client/session_store.dart';
import 'screens/game_screen.dart';
import 'screens/home_screen.dart';
import 'screens/lobby_screen.dart';
import 'screens/pile_screen.dart';
import 'screens/round_transition_screen.dart';

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
  bool _showRoundTransition = false;
  int _transitionRoundNumber = 0;
  int _transitionCardsPlayed = 0;
  int _transitionLives = 5;
  bool _isReconnecting = false;
  int _reconnectAttempts = 0;
  static const _maxReconnectAttempts = 3;

  @override
  void initState() {
    super.initState();
    _client = GameClient();
    _client.addListener(_onClientUpdate);
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

  void _onClientUpdate() {
    final state = _client.state;
    final prev = _client.previousPhase;

    // Save session whenever we have room/player info
    if (state.roomCode != null && state.playerId != null) {
      SessionStore.save(state.roomCode!, state.playerId!);
      // Reset reconnect attempts on successful connection with room info
      _reconnectAttempts = 0;
      if (_isReconnecting) {
        setState(() => _isReconnecting = false);
      }
    }

    // Handle unexpected disconnect — attempt reconnection
    if (state.connectionStatus == ConnectionStatus.disconnected &&
        !_isReconnecting) {
      _attemptReconnect();
    }

    // Handle rejoin error — clear session and stop reconnecting
    if (state.lastError != null && _isReconnecting) {
      _clearSessionAndStopReconnecting();
    }

    // Detect round -> lobby transition with roundNumber > 0
    if (prev == GamePhase.round &&
        state.phase == GamePhase.lobby &&
        (state.roundNumber ?? 0) > 0 &&
        !_showRoundTransition) {
      setState(() {
        _showRoundTransition = true;
        _transitionRoundNumber = state.roundNumber ?? 0;
        _transitionCardsPlayed = state.discardPile?.length ?? 0;
        _transitionLives = state.lives ?? 5;
      });
    }
  }

  Future<void> _attemptReconnect() async {
    final session = await SessionStore.load();
    if (session == null) return;

    if (_reconnectAttempts >= _maxReconnectAttempts) {
      await _clearSessionAndStopReconnecting();
      return;
    }

    setState(() => _isReconnecting = true);
    _reconnectAttempts++;

    // Small delay before reconnecting
    await Future<void>.delayed(const Duration(seconds: 1));
    if (!mounted) return;

    try {
      _connectWs();
      // Send rejoin after connection is established
      _client.rejoinRoom(session.roomCode, session.playerId);
    } catch (_) {
      if (_reconnectAttempts >= _maxReconnectAttempts) {
        await _clearSessionAndStopReconnecting();
      }
    }
  }

  Future<void> _clearSessionAndStopReconnecting() async {
    await SessionStore.clear();
    if (mounted) {
      setState(() => _isReconnecting = false);
    }
  }

  @override
  void dispose() {
    _client.removeListener(_onClientUpdate);
    _client.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _client,
      builder: (context, _) {
        final state = _client.state;

        // Show error SnackBar when a new error arrives from the server
        if (state.lastError != null && state.lastError != _lastShownError) {
          _lastShownError = state.lastError;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) {
              ScaffoldMessenger.of(
                context,
              ).showSnackBar(SnackBar(content: Text(state.lastError!)));
            }
          });
        }

        // Show reconnecting indicator
        if (_isReconnecting) {
          return const Scaffold(
            body: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text('Reconnecting...', style: TextStyle(fontSize: 18)),
                ],
              ),
            ),
          );
        }

        if (widget.pileViewerMode && state.roomCode != null) {
          return PileScreen(client: _client);
        }

        if (state.roomCode == null) {
          return HomeScreen(client: _client);
        }

        if (_showRoundTransition) {
          return RoundTransitionScreen(
            roundNumber: _transitionRoundNumber,
            cardsPlayed: _transitionCardsPlayed,
            lives: _transitionLives,
            onContinue: () => setState(() => _showRoundTransition = false),
          );
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
