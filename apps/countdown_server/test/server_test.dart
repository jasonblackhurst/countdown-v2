import 'dart:async';
import 'dart:convert';

import 'package:countdown_core/countdown_core.dart';
import 'package:countdown_server/src/protocol.dart';
import 'package:countdown_server/src/room_manager.dart';
import 'package:test/test.dart';

// ── Stub sink for testing without real WebSockets ─────────────────────────

class _RecordingSink implements StreamSink<String> {
  final List<Map<String, dynamic>> received = [];
  bool closed = false;

  @override
  void add(String event) =>
      received.add(jsonDecode(event) as Map<String, dynamic>);

  @override
  void addError(Object error, [StackTrace? stackTrace]) {}

  @override
  Future addStream(Stream<String> stream) async {}

  @override
  Future get done => Future.value();

  @override
  Future close() async => closed = true;

  Map<String, dynamic>? lastMsg() => received.isEmpty ? null : received.last;

  Iterable<Map<String, dynamic>> msgsOfType(String type) =>
      received.where((m) => m['type'] == type);
}

void main() {
  // ── RoomManager ───────────────────────────────────────────────────────────

  group('RoomManager', () {
    test('1. createRoom generates a room with a 4-character code', () {
      final manager = RoomManager();
      final room = manager.createRoom();
      expect(room.code, hasLength(4));
      expect(room.code, matches(RegExp(r'^[A-Z]+$')));
    });

    test('2. createRoom codes are unique across multiple rooms', () {
      final manager = RoomManager();
      final codes = {for (var i = 0; i < 20; i++) manager.createRoom().code};
      expect(codes.length, 20);
    });

    test('3. getRoom retrieves an existing room by code', () {
      final manager = RoomManager();
      final room = manager.createRoom();
      expect(manager.getRoom(room.code), same(room));
    });

    test('4. getRoom returns null for unknown code', () {
      final manager = RoomManager();
      expect(manager.getRoom('ZZZZ'), isNull);
    });
  });

  // ── Room – lobby & setup ──────────────────────────────────────────────────

  group('Room setup', () {
    test(
      '5a. addPlayer broadcasts lobby state_update to all existing players',
      () {
        final manager = RoomManager();
        final room = manager.createRoom();
        final sink1 = _RecordingSink();
        room.addPlayer('Alice', sink1);

        final sink2 = _RecordingSink();
        room.addPlayer('Bob', sink2);

        // Alice should have received a lobby update when Bob joined
        final aliceUpdates = sink1.msgsOfType('state_update').toList();
        expect(aliceUpdates, isNotEmpty);
        final players = aliceUpdates.last['state']['players'] as List;
        expect(
          players.map((p) => (p as Map)['name']),
          containsAll(['Alice', 'Bob']),
        );
      },
    );

    test('5. addPlayer returns a player ID and accepts a sink', () {
      final manager = RoomManager();
      final room = manager.createRoom();
      final sink = _RecordingSink();
      final id = room.addPlayer('Alice', sink);
      expect(id, isNotEmpty);
    });

    test('6. startGame requires at least 2 players', () {
      final manager = RoomManager();
      final room = manager.createRoom();
      final sink = _RecordingSink();
      final id = room.addPlayer('Alice', sink);
      expect(() => room.startGame(id), throwsStateError);
    });

    test('7. startGame broadcasts state_update to all connected sinks', () {
      final manager = RoomManager();
      final room = manager.createRoom();
      final sinks = [_RecordingSink(), _RecordingSink()];
      final ids = [
        room.addPlayer('Alice', sinks[0]),
        room.addPlayer('Bob', sinks[1]),
      ];
      room.startGame(ids.first);

      for (final sink in sinks) {
        expect(sink.msgsOfType('state_update').length, greaterThanOrEqualTo(1));
      }
    });

    test('8. only the host can start the game', () {
      final manager = RoomManager();
      final room = manager.createRoom();
      final sinks = [_RecordingSink(), _RecordingSink()];
      room.addPlayer('Alice', sinks[0]);
      final bobId = room.addPlayer('Bob', sinks[1]);
      expect(() => room.startGame(bobId), throwsStateError);
    });
  });

  // ── Room – round voting ───────────────────────────────────────────────────

  group('Room voting', () {
    test('9. round starts when all players have voted', () {
      final manager = RoomManager();
      final room = manager.createRoom();
      final sinks = [_RecordingSink(), _RecordingSink()];
      final ids = [
        room.addPlayer('Alice', sinks[0]),
        room.addPlayer('Bob', sinks[1]),
      ];
      room.startGame(ids.first);

      room.voteCardCount(ids[0], 2);
      expect(room.state.phase, GamePhase.lobby); // not yet started

      room.voteCardCount(ids[1], 2);
      expect(room.state.phase, GamePhase.round); // round started
    });

    test('10. round uses the minimum of all votes', () {
      final manager = RoomManager();
      final room = manager.createRoom();
      final sinks = [_RecordingSink(), _RecordingSink()];
      final ids = [
        room.addPlayer('Alice', sinks[0]),
        room.addPlayer('Bob', sinks[1]),
      ];
      room.startGame(ids.first);

      room.voteCardCount(ids[0], 5);
      room.voteCardCount(ids[1], 2);

      // Each player gets 2 cards (the min)
      for (final p in room.state.players) {
        expect(p.hand.cards.length, 2);
      }
    });

    test('11. voteCardCount broadcasts state_update after round starts', () {
      final manager = RoomManager();
      final room = manager.createRoom();
      final sinks = [_RecordingSink(), _RecordingSink()];
      final ids = [
        room.addPlayer('Alice', sinks[0]),
        room.addPlayer('Bob', sinks[1]),
      ];
      room.startGame(ids.first);

      room.voteCardCount(ids[0], 1);
      room.voteCardCount(ids[1], 1); // triggers broadcast

      for (final sink in sinks) {
        // 1 from startGame + 1 from round start
        expect(sink.msgsOfType('state_update').length, greaterThanOrEqualTo(2));
      }
    });
  });

  // ── Room – gameplay ───────────────────────────────────────────────────────

  group('Room gameplay', () {
    test('12. playing the correct card returns valid and broadcasts state', () {
      final manager = RoomManager();
      final room = manager.createRoom();
      final sinks = [_RecordingSink(), _RecordingSink()];
      final ids = [
        room.addPlayer('Alice', sinks[0]),
        room.addPlayer('Bob', sinks[1]),
      ];
      room.startGame(ids.first);
      room.voteCardCount(ids[0], 1);
      room.voteCardCount(ids[1], 1);

      // Find who holds the globally highest card and play it
      final highest = room.state.players
          .expand((p) => p.hand.cards)
          .reduce((a, b) => a.value > b.value ? a : b);
      final holderId = room.state.players
          .firstWhere((p) => p.hand.cards.contains(highest))
          .id;

      // Map engine player ID back to room player ID
      final roomPlayerId = ids.firstWhere(
        (id) =>
            room.playerIdForEngineId(holderId) == id ||
            room.engineIdForPlayerId(id) == holderId,
      );

      final result = room.playCard(roomPlayerId, highest);
      expect(result, PlayResult.valid);

      for (final sink in sinks) {
        expect(sink.msgsOfType('state_update').length, greaterThanOrEqualTo(3));
      }
    });

    test('13. playing wrong card decrements lives and broadcasts state', () {
      final manager = RoomManager();
      final room = manager.createRoom();
      final sinks = [_RecordingSink(), _RecordingSink()];
      final ids = [
        room.addPlayer('Alice', sinks[0]),
        room.addPlayer('Bob', sinks[1]),
      ];
      room.startGame(ids.first);
      room.voteCardCount(ids[0], 2);
      room.voteCardCount(ids[1], 2);

      // Find a player with a card that is NOT the global highest
      final globalHighest = room.state.players
          .expand((p) => p.hand.cards)
          .reduce((a, b) => a.value > b.value ? a : b);

      final wrongHolder = room.state.players.firstWhere(
        (p) => p.hand.cards.any((c) => c != globalHighest),
      );
      final wrongCard = wrongHolder.hand.cards.firstWhere(
        (c) => c != globalHighest,
      );

      final roomPlayerId = ids.firstWhere(
        (id) => room.engineIdForPlayerId(id) == wrongHolder.id,
      );

      room.playCard(roomPlayerId, wrongCard);
      expect(room.state.lives, 4);
    });

    test(
      '14. state_update includes hand values for the receiving player only',
      () {
        final manager = RoomManager();
        final room = manager.createRoom();
        final sinks = [_RecordingSink(), _RecordingSink()];
        final ids = [
          room.addPlayer('Alice', sinks[0]),
          room.addPlayer('Bob', sinks[1]),
        ];
        room.startGame(ids.first);
        room.voteCardCount(ids[0], 2);
        room.voteCardCount(ids[1], 2);

        // Alice's state_update should contain her own hand values
        final aliceUpdate = sinks[0].msgsOfType('state_update').last;
        final alicePlayers = aliceUpdate['state']['players'] as List;
        final aliceEntry =
            alicePlayers.firstWhere((p) => ids[0] == (p as Map)['id']) as Map;
        expect((aliceEntry['hand'] as List).isNotEmpty, isTrue);

        // Alice's view of Bob should have an empty hand list
        final bobEntry =
            alicePlayers.firstWhere((p) => ids[1] == (p as Map)['id']) as Map;
        expect(bobEntry['hand'], isEmpty);
      },
    );

    test(
      '15. after all hands are played, phase resets to lobby for re-voting',
      () {
        final manager = RoomManager();
        final room = manager.createRoom();
        final sinks = [_RecordingSink(), _RecordingSink()];
        final ids = [
          room.addPlayer('Alice', sinks[0]),
          room.addPlayer('Bob', sinks[1]),
        ];
        room.startGame(ids.first);
        room.voteCardCount(ids[0], 1);
        room.voteCardCount(ids[1], 1);

        // Play both cards in the correct order (highest first)
        final allCards = room.state.players.expand((p) => p.hand.cards).toList()
          ..sort((a, b) => b.value.compareTo(a.value));

        for (final card in allCards) {
          final engineHolder = room.state.players.firstWhere(
            (p) => p.hand.cards.contains(card),
          );
          final roomId = room.playerIdForEngineId(engineHolder.id)!;
          room.playCard(roomId, card);
        }

        expect(room.state.phase, GamePhase.lobby);
      },
    );

    test('17. addPlayer lobby state_update has game_initialized: false', () {
      final manager = RoomManager();
      final room = manager.createRoom();
      final sink1 = _RecordingSink();
      room.addPlayer('Alice', sink1);
      final sink2 = _RecordingSink();
      room.addPlayer('Bob', sink2);

      // The last state_update each sink received should have game_initialized: false
      final aliceLastUpdate = sink1.msgsOfType('state_update').last;
      expect(aliceLastUpdate['state']['game_initialized'], isFalse);

      final bobLastUpdate = sink2.msgsOfType('state_update').last;
      expect(bobLastUpdate['state']['game_initialized'], isFalse);
    });

    test('18. startGame state_update has game_initialized: true', () {
      final manager = RoomManager();
      final room = manager.createRoom();
      final sinks = [_RecordingSink(), _RecordingSink()];
      final ids = [
        room.addPlayer('Alice', sinks[0]),
        room.addPlayer('Bob', sinks[1]),
      ];
      room.startGame(ids.first);

      // The last state_update after startGame should have game_initialized: true
      final aliceLastUpdate = sinks[0].msgsOfType('state_update').last;
      expect(aliceLastUpdate['state']['game_initialized'], isTrue);

      final bobLastUpdate = sinks[1].msgsOfType('state_update').last;
      expect(bobLastUpdate['state']['game_initialized'], isTrue);
    });

    test('16. removePlayer on last player returns isEmpty true', () {
      final manager = RoomManager();
      final room = manager.createRoom();
      final sinks = [_RecordingSink(), _RecordingSink()];
      final ids = [
        room.addPlayer('Alice', sinks[0]),
        room.addPlayer('Bob', sinks[1]),
      ];
      room.removePlayer(ids[0]);
      room.removePlayer(ids[1]);
      expect(room.isEmpty, isTrue);
    });

    test('19. state_update player IDs are room UUIDs, not engine IDs', () {
      final manager = RoomManager();
      final room = manager.createRoom();
      final sinks = [_RecordingSink(), _RecordingSink()];
      final ids = [
        room.addPlayer('Alice', sinks[0]),
        room.addPlayer('Bob', sinks[1]),
      ];
      room.startGame(ids.first);
      room.voteCardCount(ids[0], 1);
      room.voteCardCount(ids[1], 1);

      final lastUpdate = sinks[0].msgsOfType('state_update').last;
      final players = lastUpdate['state']['players'] as List;

      // The players list must contain Alice's room UUID
      expect(
        players.any((p) => (p as Map)['id'] == ids[0]),
        isTrue,
        reason: 'Expected room UUID ${ids[0]} in players list',
      );

      // The players list must NOT contain the engine ID (e.g. "player_0")
      final engineId = room.engineIdForPlayerId(ids[0]);
      expect(
        players.any((p) => (p as Map)['id'] == engineId),
        isFalse,
        reason: 'Engine ID $engineId should not appear in players list',
      );
    });

    test(
      '20. myPlayer can be identified from state_update using the room player ID',
      () {
        final manager = RoomManager();
        final room = manager.createRoom();
        final sinks = [_RecordingSink(), _RecordingSink()];
        final ids = [
          room.addPlayer('Alice', sinks[0]),
          room.addPlayer('Bob', sinks[1]),
        ];
        room.startGame(ids.first);
        room.voteCardCount(ids[0], 1);
        room.voteCardCount(ids[1], 1);

        final lastUpdate = sinks[0].msgsOfType('state_update').last;
        final players = lastUpdate['state']['players'] as List;

        // Alice's entry (identified by room UUID) should have a non-empty hand
        final aliceEntry =
            players.firstWhere((p) => (p as Map)['id'] == ids[0]) as Map;
        expect((aliceEntry['hand'] as List).isNotEmpty, isTrue);
      },
    );
  });

  // ── Room – play again ────────────────────────────────────────────────────

  group('Room play again', () {
    test(
      '21. resetForPlayAgain resets phase to lobby with fresh engine state',
      () {
        final manager = RoomManager();
        final room = manager.createRoom();
        final sinks = [_RecordingSink(), _RecordingSink()];
        final ids = [
          room.addPlayer('Alice', sinks[0]),
          room.addPlayer('Bob', sinks[1]),
        ];
        room.startGame(ids.first);
        room.voteCardCount(ids[0], 1);
        room.voteCardCount(ids[1], 1);

        // Play incorrectly to lose a life
        final globalHighest = room.state.players
            .expand((p) => p.hand.cards)
            .reduce((a, b) => a.value > b.value ? a : b);
        final wrongHolder = room.state.players.firstWhere(
          (p) => p.hand.cards.any((c) => c != globalHighest),
        );
        final wrongCard = wrongHolder.hand.cards.firstWhere(
          (c) => c != globalHighest,
        );
        final roomPlayerId = ids.firstWhere(
          (id) => room.engineIdForPlayerId(id) == wrongHolder.id,
        );
        room.playCard(roomPlayerId, wrongCard);
        expect(room.state.lives, 4); // sanity check

        // Now reset
        room.resetForPlayAgain();

        // Phase should be lobby
        expect(room.state.phase, GamePhase.lobby);
        // Lives should be back to 5
        expect(room.state.lives, 5);
        // Discard pile should be empty
        expect(room.state.discardPile, isEmpty);
        // Round number should be 0
        expect(room.state.roundNumber, 0);
      },
    );

    test(
      '22. resetForPlayAgain broadcasts lobby state_update to all players',
      () {
        final manager = RoomManager();
        final room = manager.createRoom();
        final sinks = [_RecordingSink(), _RecordingSink()];
        final ids = [
          room.addPlayer('Alice', sinks[0]),
          room.addPlayer('Bob', sinks[1]),
        ];
        room.startGame(ids.first);

        final countBefore = sinks[0].msgsOfType('state_update').length;
        room.resetForPlayAgain();
        final countAfter = sinks[0].msgsOfType('state_update').length;

        expect(countAfter, greaterThan(countBefore));

        // The broadcast state should show lobby phase
        final lastUpdate = sinks[0].msgsOfType('state_update').last;
        expect(lastUpdate['state']['phase'], 'lobby');
        expect(lastUpdate['state']['lives'], 5);
        expect(lastUpdate['state']['round_number'], 0);
        expect(lastUpdate['state']['game_initialized'], isTrue);
      },
    );

    test('23. resetForPlayAgain keeps all connected players', () {
      final manager = RoomManager();
      final room = manager.createRoom();
      final sinks = [_RecordingSink(), _RecordingSink()];
      final ids = [
        room.addPlayer('Alice', sinks[0]),
        room.addPlayer('Bob', sinks[1]),
      ];
      room.startGame(ids.first);
      room.resetForPlayAgain();

      // Both players should still be connected
      expect(room.playerCount, 2);

      // Should be able to start a new game and vote
      room.voteCardCount(ids[0], 1);
      room.voteCardCount(ids[1], 1);
      expect(room.state.phase, GamePhase.round);
    });

    test('24. play_again message is parsed by ClientMessage.parse', () {
      final msg = ClientMessage.parse('{"type": "play_again"}');
      expect(msg, isA<PlayAgainMsg>());
    });
  });

  // ── Player activity indicators ──────────────────────────────────────────

  group('Player activity indicators', () {
    test('25. state_update includes last_played_by after a card is played', () {
      final manager = RoomManager();
      final room = manager.createRoom();
      final sinks = [_RecordingSink(), _RecordingSink()];
      final ids = [
        room.addPlayer('Alice', sinks[0]),
        room.addPlayer('Bob', sinks[1]),
      ];
      room.startGame(ids.first);
      room.voteCardCount(ids[0], 1);
      room.voteCardCount(ids[1], 1);

      // Find who holds the globally highest card and play it
      final highest = room.state.players
          .expand((p) => p.hand.cards)
          .reduce((a, b) => a.value > b.value ? a : b);
      final holderId = room.state.players
          .firstWhere((p) => p.hand.cards.contains(highest))
          .id;
      final roomPlayerId = ids.firstWhere(
        (id) => room.engineIdForPlayerId(id) == holderId,
      );

      room.playCard(roomPlayerId, highest);

      // Both sinks should receive a state_update with last_played_by
      for (final sink in sinks) {
        final lastUpdate = sink.msgsOfType('state_update').last;
        final state = lastUpdate['state'] as Map<String, dynamic>;
        expect(state.containsKey('last_played_by'), isTrue);
        final lastPlayedBy = state['last_played_by'] as Map<String, dynamic>;
        expect(lastPlayedBy['player_id'], roomPlayerId);
        expect(lastPlayedBy['card_value'], highest.value);
      }
    });

    test('26. last_played_by includes the player name', () {
      final manager = RoomManager();
      final room = manager.createRoom();
      final sinks = [_RecordingSink(), _RecordingSink()];
      final ids = [
        room.addPlayer('Alice', sinks[0]),
        room.addPlayer('Bob', sinks[1]),
      ];
      room.startGame(ids.first);
      room.voteCardCount(ids[0], 1);
      room.voteCardCount(ids[1], 1);

      final highest = room.state.players
          .expand((p) => p.hand.cards)
          .reduce((a, b) => a.value > b.value ? a : b);
      final holderId = room.state.players
          .firstWhere((p) => p.hand.cards.contains(highest))
          .id;
      final roomPlayerId = ids.firstWhere(
        (id) => room.engineIdForPlayerId(id) == holderId,
      );
      final holderName = room.state.players
          .firstWhere((p) => p.id == holderId)
          .name;

      room.playCard(roomPlayerId, highest);

      final lastUpdate = sinks[0].msgsOfType('state_update').last;
      final lastPlayedBy =
          lastUpdate['state']['last_played_by'] as Map<String, dynamic>;
      expect(lastPlayedBy['name'], holderName);
    });

    test(
      '27. last_played_by is null in lobby state_update (before any card played)',
      () {
        final manager = RoomManager();
        final room = manager.createRoom();
        final sinks = [_RecordingSink(), _RecordingSink()];
        final ids = [
          room.addPlayer('Alice', sinks[0]),
          room.addPlayer('Bob', sinks[1]),
        ];
        room.startGame(ids.first);

        final lastUpdate = sinks[0].msgsOfType('state_update').last;
        final state = lastUpdate['state'] as Map<String, dynamic>;
        expect(state['last_played_by'], isNull);
      },
    );

    test('28. last_played_by is null in pre-game lobby broadcasts', () {
      final manager = RoomManager();
      final room = manager.createRoom();
      final sink = _RecordingSink();
      room.addPlayer('Alice', sink);

      final lastUpdate = sink.msgsOfType('state_update').last;
      final state = lastUpdate['state'] as Map<String, dynamic>;
      expect(state['last_played_by'], isNull);
    });

    test('29. resetForPlayAgain clears last_played_by', () {
      final manager = RoomManager();
      final room = manager.createRoom();
      final sinks = [_RecordingSink(), _RecordingSink()];
      final ids = [
        room.addPlayer('Alice', sinks[0]),
        room.addPlayer('Bob', sinks[1]),
      ];
      room.startGame(ids.first);
      room.voteCardCount(ids[0], 1);
      room.voteCardCount(ids[1], 1);

      // Play a card
      final highest = room.state.players
          .expand((p) => p.hand.cards)
          .reduce((a, b) => a.value > b.value ? a : b);
      final holderId = room.state.players
          .firstWhere((p) => p.hand.cards.contains(highest))
          .id;
      final roomPlayerId = ids.firstWhere(
        (id) => room.engineIdForPlayerId(id) == holderId,
      );
      room.playCard(roomPlayerId, highest);

      // Reset
      room.resetForPlayAgain();

      final lastUpdate = sinks[0].msgsOfType('state_update').last;
      final state = lastUpdate['state'] as Map<String, dynamic>;
      expect(state['last_played_by'], isNull);
    });
  });
}
