import 'dart:async';

import 'package:countdown_core/countdown_core.dart';
import 'package:uuid/uuid.dart';

import 'protocol.dart';

typedef Sink = StreamSink<String>;

class _ConnectedPlayer {
  final String playerId;
  Sink sink;
  _ConnectedPlayer(this.playerId, this.sink);
}

class _Spectator {
  final String id;
  final Sink sink;
  _Spectator(this.id, this.sink);
}

class Room {
  final String code;
  final GameEngine _engine;
  final List<_ConnectedPlayer> _connections = [];
  final List<_Spectator> _spectators = [];
  final Map<String, int> _cardCountVotes = {};
  final Map<String, String> _pendingPlayers = {}; // playerId → name
  final Map<String, String> _engineIdToPlayerId = {};
  final Map<String, String> _playerIdToEngineId = {};
  String? _hostPlayerId;
  bool _started = false;
  Map<String, dynamic>? _lastPlayedBy;

  Room(this.code) : _engine = GameEngine();

  GameState get state => _engine.state;
  int get playerCount => _connections.length;
  bool get isEmpty => _connections.isEmpty;

  String? playerIdForEngineId(String engineId) => _engineIdToPlayerId[engineId];
  String? engineIdForPlayerId(String playerId) => _playerIdToEngineId[playerId];

  /// Adds a new player to the lobby. Returns the assigned player UUID.
  String addPlayer(String name, Sink sink) {
    if (_started) throw StateError('Game already in progress');

    final playerId = const Uuid().v4();
    _pendingPlayers[playerId] = name;
    _hostPlayerId ??= playerId;
    _connections.add(_ConnectedPlayer(playerId, sink));
    _broadcastLobbyState();
    return playerId;
  }

  /// Starts the game. Only the host may call this; requires ≥2 players.
  void startGame(String requestingPlayerId) {
    if (requestingPlayerId != _hostPlayerId) {
      throw StateError('Only the host can start the game');
    }
    if (_pendingPlayers.length < 2) {
      throw StateError('Need at least 2 players to start');
    }

    _started = true;
    final orderedNames = _connections
        .map((c) => _pendingPlayers[c.playerId]!)
        .toList();
    _engine.startGame(orderedNames);

    for (var i = 0; i < _connections.length; i++) {
      final engineId = _engine.state.players[i].id;
      final roomId = _connections[i].playerId;
      _engineIdToPlayerId[engineId] = roomId;
      _playerIdToEngineId[roomId] = engineId;
    }

    _broadcastState();
  }

  /// Records a card-count vote. Starts the round when all players have voted.
  /// The round uses the minimum vote (safe — won't exceed deck capacity).
  void voteCardCount(String playerId, int count) {
    _cardCountVotes[playerId] = count;

    if (_cardCountVotes.length == _connections.length) {
      final agreed = _cardCountVotes.values.reduce((a, b) => a < b ? a : b);
      _cardCountVotes.clear();
      _engine.startRound(agreed);
      _broadcastState();
    }
  }

  /// Plays a card on behalf of [playerId]. Broadcasts updated state.
  PlayResult playCard(String playerId, GameCard card) {
    final engineId = _playerIdToEngineId[playerId];
    if (engineId == null) throw StateError('Player not in engine: $playerId');

    final playerName = _pendingPlayers[playerId] ?? '';
    final result = _engine.playCard(engineId, card);

    _lastPlayedBy = {
      'player_id': playerId,
      'name': playerName,
      'card_value': card.value,
    };

    // If the round ended cleanly (not win/gameOver), reset to lobby so
    // clients know to vote for the next round.
    if (result == PlayResult.valid &&
        _engine.state.players.every((p) => p.hand.isEmpty)) {
      _engine.state.phase = GamePhase.lobby;
    }

    _broadcastState();
    return result;
  }

  /// Resets the room for a new game, keeping all connected players.
  void resetForPlayAgain() {
    _cardCountVotes.clear();
    _engineIdToPlayerId.clear();
    _playerIdToEngineId.clear();
    _lastPlayedBy = null;

    // Re-initialize the engine with the same players
    final orderedNames = _connections
        .map((c) => _pendingPlayers[c.playerId]!)
        .toList();
    _engine.startGame(orderedNames);

    // Rebuild the engine-to-room ID mappings
    for (var i = 0; i < _connections.length; i++) {
      final engineId = _engine.state.players[i].id;
      final roomId = _connections[i].playerId;
      _engineIdToPlayerId[engineId] = roomId;
      _playerIdToEngineId[roomId] = engineId;
    }

    _broadcastState();
  }

  void send(String playerId, Map<String, dynamic> msg) {
    final conn = _connections.firstWhere(
      (c) => c.playerId == playerId,
      orElse: () => throw StateError('Player $playerId not connected'),
    );
    conn.sink.add(encode(msg));
  }

  /// Replaces the WebSocket connection for an existing player (reconnection).
  /// Throws [StateError] if [playerId] is not found in this room.
  void rejoinPlayer(String playerId, Sink sink) {
    final conn = _connections.where((c) => c.playerId == playerId).firstOrNull;
    if (conn == null) {
      throw StateError('Player $playerId not found in room $code');
    }
    conn.sink = sink;

    // If the game has started, broadcast per-player state; otherwise lobby.
    if (_started) {
      _broadcastState();
    } else {
      _broadcastLobbyState();
    }
  }

  /// Adds a spectator connection. Returns a spectator ID for later removal.
  String addSpectator(Sink sink) {
    final id = const Uuid().v4();
    _spectators.add(_Spectator(id, sink));
    // Send current state immediately
    if (_started) {
      _broadcastStateToSpectators();
    } else {
      _broadcastLobbyStateToSpectators();
    }
    return id;
  }

  void removeSpectator(String spectatorId) {
    _spectators.removeWhere((s) => s.id == spectatorId);
  }

  void removePlayer(String playerId) {
    _connections.removeWhere((c) => c.playerId == playerId);
  }

  /// Sends a pre-game lobby snapshot — used before the engine is initialized.
  void _broadcastLobbyState() {
    final msg = _lobbyStateMsg();

    for (final conn in _connections) {
      conn.sink.add(msg);
    }
    for (final spec in _spectators) {
      spec.sink.add(msg);
    }
  }

  String _lobbyStateMsg() {
    final players = _connections
        .map(
          (c) => {
            'id': c.playerId,
            'name': _pendingPlayers[c.playerId] ?? '',
            'hand_size': 0,
            'hand': <int>[],
          },
        )
        .toList();

    return encode({
      'type': 'state_update',
      'state': {
        'phase': 'lobby',
        'lives': 5,
        'round_number': 0,
        'discard_pile': <int>[],
        'game_initialized': false,
        'is_final_round': false,
        'cards_remaining': 100,
        'last_played_by': null,
        'players': players,
      },
    });
  }

  void _broadcastState() {
    for (final conn in _connections) {
      final engineId = _playerIdToEngineId[conn.playerId];
      final msg = encode(
        stateUpdateMsg(
          _engine.state,
          localEnginePlayerId: engineId,
          engineToRoomIds: _engineIdToPlayerId,
          lastPlayedBy: _lastPlayedBy,
        ),
      );
      conn.sink.add(msg);
    }
    _broadcastStateToSpectators();
  }

  void _broadcastStateToSpectators() {
    if (_spectators.isEmpty) return;
    // Spectators see no hands (localEnginePlayerId is null)
    final msg = encode(
      stateUpdateMsg(
        _engine.state,
        engineToRoomIds: _engineIdToPlayerId,
        lastPlayedBy: _lastPlayedBy,
      ),
    );
    for (final spec in _spectators) {
      spec.sink.add(msg);
    }
  }

  void _broadcastLobbyStateToSpectators() {
    if (_spectators.isEmpty) return;
    final msg = _lobbyStateMsg();
    for (final spec in _spectators) {
      spec.sink.add(msg);
    }
  }
}
