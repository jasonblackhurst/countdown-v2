import 'dart:async';

import 'package:countdown_core/countdown_core.dart';
import 'package:uuid/uuid.dart';

import 'protocol.dart';

typedef Sink = StreamSink<String>;

class _ConnectedPlayer {
  final String playerId;
  final Sink sink;
  _ConnectedPlayer(this.playerId, this.sink);
}

class Room {
  final String code;
  final GameEngine _engine;
  final List<_ConnectedPlayer> _connections = [];
  final Map<String, int> _cardCountVotes = {};
  final Map<String, String> _pendingPlayers = {}; // playerId → name
  final Map<String, String> _engineIdToPlayerId = {};
  final Map<String, String> _playerIdToEngineId = {};
  String? _hostPlayerId;
  bool _started = false;

  Room(this.code) : _engine = GameEngine();

  GameState get state => _engine.state;
  int get playerCount => _connections.length;
  bool get isEmpty => _connections.isEmpty;

  String? playerIdForEngineId(String engineId) =>
      _engineIdToPlayerId[engineId];
  String? engineIdForPlayerId(String playerId) =>
      _playerIdToEngineId[playerId];

  /// Adds a new player to the lobby. Returns the assigned player UUID.
  String addPlayer(String name, Sink sink) {
    if (_started) throw StateError('Game already in progress');

    final playerId = const Uuid().v4();
    _pendingPlayers[playerId] = name;
    _hostPlayerId ??= playerId;
    _connections.add(_ConnectedPlayer(playerId, sink));
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
    final orderedNames =
        _connections.map((c) => _pendingPlayers[c.playerId]!).toList();
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

    final result = _engine.playCard(engineId, card);

    // If the round ended cleanly (not win/gameOver), reset to lobby so
    // clients know to vote for the next round.
    if (result == PlayResult.valid &&
        _engine.state.players.every((p) => p.hand.isEmpty)) {
      _engine.state.phase = GamePhase.lobby;
    }

    _broadcastState();
    return result;
  }

  void send(String playerId, Map<String, dynamic> msg) {
    final conn = _connections.firstWhere(
      (c) => c.playerId == playerId,
      orElse: () => throw StateError('Player $playerId not connected'),
    );
    conn.sink.add(encode(msg));
  }

  void removePlayer(String playerId) {
    _connections.removeWhere((c) => c.playerId == playerId);
  }

  void _broadcastState() {
    for (final conn in _connections) {
      final engineId = _playerIdToEngineId[conn.playerId];
      final msg = encode(stateUpdateMsg(
        _engine.state,
        localEnginePlayerId: engineId,
      ));
      conn.sink.add(msg);
    }
  }
}
