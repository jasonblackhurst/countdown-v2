import 'dart:async';
import 'dart:convert';

import 'package:countdown_core/countdown_core.dart';
import 'package:flutter/foundation.dart';

// ── Local state model ─────────────────────────────────────────────────────

enum ConnectionStatus { disconnected, connecting, connected }

class ClientState {
  final ConnectionStatus connectionStatus;
  final String? roomCode;
  final String? playerId;
  final GamePhase? phase;
  final int? lives;
  final int? roundNumber;
  final List<int>? discardPile; // card values
  final List<PlayerSnapshot>? players;
  final String? lastError;
  final bool gameInitialized;
  final bool isFinalRound;
  final int? cardsRemaining;
  final String? lastPlayedByName;
  final int? lastPlayedCardValue;

  const ClientState({
    this.connectionStatus = ConnectionStatus.disconnected,
    this.roomCode,
    this.playerId,
    this.phase,
    this.lives,
    this.roundNumber,
    this.discardPile,
    this.players,
    this.lastError,
    this.gameInitialized = false,
    this.isFinalRound = false,
    this.cardsRemaining,
    this.lastPlayedByName,
    this.lastPlayedCardValue,
  });

  ClientState copyWith({
    ConnectionStatus? connectionStatus,
    String? roomCode,
    String? playerId,
    GamePhase? phase,
    int? lives,
    int? roundNumber,
    List<int>? discardPile,
    List<PlayerSnapshot>? players,
    String? lastError,
    bool? gameInitialized,
    bool? isFinalRound,
    int? cardsRemaining,
    String? Function()? lastPlayedByName,
    int? Function()? lastPlayedCardValue,
  }) => ClientState(
    connectionStatus: connectionStatus ?? this.connectionStatus,
    roomCode: roomCode ?? this.roomCode,
    playerId: playerId ?? this.playerId,
    phase: phase ?? this.phase,
    lives: lives ?? this.lives,
    roundNumber: roundNumber ?? this.roundNumber,
    discardPile: discardPile ?? this.discardPile,
    players: players ?? this.players,
    lastError: lastError,
    gameInitialized: gameInitialized ?? this.gameInitialized,
    isFinalRound: isFinalRound ?? this.isFinalRound,
    cardsRemaining: cardsRemaining ?? this.cardsRemaining,
    lastPlayedByName: lastPlayedByName != null
        ? lastPlayedByName()
        : this.lastPlayedByName,
    lastPlayedCardValue: lastPlayedCardValue != null
        ? lastPlayedCardValue()
        : this.lastPlayedCardValue,
  );

  /// Cards in my hand (hand_size is the count, but only the server knows the
  /// actual values — the server sends each player's hand to their own client
  /// via the full state_update).
  PlayerSnapshot? get myPlayer =>
      players?.where((p) => p.id == playerId).firstOrNull;
}

class PlayerSnapshot {
  final String id;
  final String name;
  final int handSize;
  final List<int> hand; // populated for the local player only

  const PlayerSnapshot({
    required this.id,
    required this.name,
    required this.handSize,
    this.hand = const [],
  });

  factory PlayerSnapshot.fromJson(Map<String, dynamic> json) => PlayerSnapshot(
    id: json['id'] as String,
    name: json['name'] as String,
    handSize: json['hand_size'] as int,
    hand: (json['hand'] as List?)?.cast<int>() ?? [],
  );
}

// ── Sink abstraction (injectable for testing) ─────────────────────────────

abstract class MessageSink {
  void send(String message);
  void close();
}

// ── GameClient ────────────────────────────────────────────────────────────

class GameClient extends ChangeNotifier {
  ClientState _state = const ClientState();
  ClientState get state => _state;

  /// The phase from the previous state update, used to detect transitions
  /// (e.g. round -> lobby for the round transition interstitial).
  GamePhase? _previousPhase;
  GamePhase? get previousPhase => _previousPhase;

  /// The lives count from the previous state update, used to detect life loss.
  int? _previousLives;
  int? get previousLives => _previousLives;

  StreamSubscription<String>? _sub;
  MessageSink? _sink;

  /// Connect to the server. [channelFactory] is injectable for tests.
  void connect(
    Uri serverUri, {
    required Stream<String> incomingStream,
    required MessageSink sink,
  }) {
    _sink = sink;
    _update(_state.copyWith(connectionStatus: ConnectionStatus.connected));

    _sub = incomingStream.listen(
      _onMessage,
      onDone: _onDisconnect,
      onError: (_) => _onDisconnect(),
    );
  }

  void disconnect() {
    _sub?.cancel();
    _sink?.close();
    _sink = null;
    _update(const ClientState());
  }

  // ── Outgoing ────────────────────────────────────────────────────────────

  void createRoom() => _send({'type': 'create_room'});

  void joinRoom(String roomCode, String playerName) =>
      _send({'type': 'join_room', 'room_code': roomCode, 'name': playerName});

  void startGame() => _send({'type': 'start_game'});

  void voteCardCount(int count) =>
      _send({'type': 'vote_card_count', 'count': count});

  void playCard(int value) => _send({'type': 'play_card', 'value': value});

  void playAgain() => _send({'type': 'play_again'});

  void rejoinRoom(String roomCode, String playerId) => _send({
    'type': 'rejoin_room',
    'room_code': roomCode,
    'player_id': playerId,
  });

  void _send(Map<String, dynamic> msg) {
    _sink?.send(jsonEncode(msg));
  }

  // ── Incoming ────────────────────────────────────────────────────────────

  void _onMessage(String raw) {
    final msg = jsonDecode(raw) as Map<String, dynamic>;
    switch (msg['type'] as String) {
      case 'room_created':
        _update(
          _state.copyWith(
            roomCode: msg['room_code'] as String,
            playerId: msg['player_id'] as String,
          ),
        );
      case 'room_joined':
        _update(
          _state.copyWith(
            roomCode: msg['room_code'] as String,
            playerId: msg['player_id'] as String,
          ),
        );
      case 'room_rejoined':
        _update(
          _state.copyWith(
            roomCode: msg['room_code'] as String,
            playerId: msg['player_id'] as String,
          ),
        );
      case 'state_update':
        _applyStateUpdate(msg['state'] as Map<String, dynamic>);
      case 'error':
        _update(_state.copyWith(lastError: msg['message'] as String));
    }
  }

  void _applyStateUpdate(Map<String, dynamic> s) {
    final phase = _parsePhase(s['phase'] as String);
    final players = (s['players'] as List)
        .cast<Map<String, dynamic>>()
        .map(PlayerSnapshot.fromJson)
        .toList();
    final discard = (s['discard_pile'] as List).cast<int>();

    final lastPlayedByRaw = s['last_played_by'] as Map<String, dynamic>?;
    final lastPlayedByName = lastPlayedByRaw != null
        ? lastPlayedByRaw['name'] as String?
        : null;
    final lastPlayedCardValue = lastPlayedByRaw != null
        ? lastPlayedByRaw['card_value'] as int?
        : null;

    _update(
      _state.copyWith(
        phase: phase,
        lives: s['lives'] as int,
        roundNumber: s['round_number'] as int,
        discardPile: discard,
        players: players,
        gameInitialized: s['game_initialized'] as bool? ?? false,
        isFinalRound: s['is_final_round'] as bool? ?? false,
        cardsRemaining: s['cards_remaining'] as int?,
        lastPlayedByName: () => lastPlayedByName,
        lastPlayedCardValue: () => lastPlayedCardValue,
      ),
    );
  }

  GamePhase _parsePhase(String raw) => switch (raw) {
    'lobby' => GamePhase.lobby,
    'round' => GamePhase.round,
    'gameOver' => GamePhase.gameOver,
    'won' => GamePhase.won,
    _ => GamePhase.lobby,
  };

  void _onDisconnect() {
    _sub = null;
    _sink = null;
    _update(_state.copyWith(connectionStatus: ConnectionStatus.disconnected));
  }

  void _update(ClientState next) {
    _previousPhase = _state.phase;
    _previousLives = _state.lives;
    _state = next;
    notifyListeners();
  }

  @override
  void dispose() {
    disconnect();
    super.dispose();
  }
}
