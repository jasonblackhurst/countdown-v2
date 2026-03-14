import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:countdown_server/src/server.dart';
import 'package:test/test.dart';

// A simple WebSocket client wrapper for testing.
//
// Uses a broadcast StreamController so that multiple listeners can attach
// and so that messages received before [nextMsgOfType] is called are NOT
// silently dropped.  We record all messages in [_log] and drain them first
// before waiting for new ones.
class _WsClient {
  final WebSocket _ws;
  final StreamController<Map<String, dynamic>> _ctrl =
      StreamController.broadcast();
  final List<Map<String, dynamic>> _log = [];

  _WsClient._(this._ws) {
    _ws.listen((data) {
      final msg = jsonDecode(data as String) as Map<String, dynamic>;
      _log.add(msg);
      _ctrl.add(msg);
    });
  }

  static Future<_WsClient> connect(int port) async {
    final ws = await WebSocket.connect('ws://localhost:$port/ws');
    return _WsClient._(ws);
  }

  void send(Map<String, dynamic> msg) => _ws.add(jsonEncode(msg));

  /// Returns a [Future] that completes with the next message matching
  /// [predicate].  Already-received messages in [_log] are checked first
  /// (FIFO) so we don't miss messages that arrived before this call.
  Future<Map<String, dynamic>> nextMsg(
    bool Function(Map<String, dynamic>) predicate, {
    Duration timeout = const Duration(seconds: 5),
  }) {
    // Check buffered messages first (FIFO – remove the first match).
    for (var i = 0; i < _log.length; i++) {
      if (predicate(_log[i])) {
        return Future.value(_log.removeAt(i));
      }
    }
    // Not yet arrived – wait on the live broadcast stream.
    return _ctrl.stream
        .firstWhere(predicate)
        .timeout(timeout)
        .then((m) {
      _log.remove(m); // keep _log consistent
      return m;
    });
  }

  /// Convenience wrapper: next message whose [type] field matches [type].
  Future<Map<String, dynamic>> nextMsgOfType(
    String type, {
    Duration timeout = const Duration(seconds: 5),
  }) =>
      nextMsg((m) => m['type'] == type, timeout: timeout);

  Future<void> close() => _ws.close();
}

void main() {
  group('E2E: two-player game', () {
    late HttpServer server;
    late int port;

    setUpAll(() async {
      server = await startServer(0); // port 0 → OS picks a free port
      port = server.port;
    });

    tearDownAll(() async {
      await server.close(force: true);
    });

    test('two players join, vote 1 card each, highest card is played first',
        () async {
      // ── Connect Alice ──────────────────────────────────────────────────────
      final alice = await _WsClient.connect(port);
      alice.send({'type': 'create_room'});

      final roomCreated = await alice.nextMsgOfType('room_created');
      final roomCode = roomCreated['room_code'] as String;
      expect(roomCode, hasLength(4));

      // ── Connect Bob ────────────────────────────────────────────────────────
      final bob = await _WsClient.connect(port);
      bob.send({'type': 'join_room', 'room_code': roomCode, 'name': 'Bob'});

      final roomJoined = await bob.nextMsgOfType('room_joined');
      expect(roomJoined['room_code'], roomCode);

      // ── Start game (Alice is host) ─────────────────────────────────────────
      // Set up futures BEFORE sending start_game so we don't race.
      // After startGame the engine is in phase=lobby (waiting for votes).
      // We specifically look for the post-startGame lobby state which has
      // round_number == 0 and players populated from the engine.
      // Using phase-specific predicates avoids confusion with earlier
      // pre-game lobby broadcasts.
      alice.send({'type': 'start_game'});

      // After startGame both clients receive state_update phase=lobby.
      // Drain to the last buffered lobby update (round_number == 0).
      final aliceLobbyState = await alice.nextMsg(
        (m) => m['type'] == 'state_update' && m['state']['phase'] == 'lobby',
      );
      expect(aliceLobbyState['state']['phase'], 'lobby');

      final bobLobbyState = await bob.nextMsg(
        (m) => m['type'] == 'state_update' && m['state']['phase'] == 'lobby',
      );
      expect(bobLobbyState['state']['phase'], 'lobby');

      // ── Vote for 1 card each ───────────────────────────────────────────────
      alice.send({'type': 'vote_card_count', 'count': 1});
      bob.send({'type': 'vote_card_count', 'count': 1});

      // Both receive a state_update with phase 'round' and hands dealt.
      final aliceRoundState = await alice.nextMsg(
        (m) => m['type'] == 'state_update' && m['state']['phase'] == 'round',
      );
      expect(aliceRoundState['state']['phase'], 'round');

      final bobRoundState = await bob.nextMsg(
        (m) => m['type'] == 'state_update' && m['state']['phase'] == 'round',
      );
      expect(bobRoundState['state']['phase'], 'round');

      // ── Find who holds the highest card ───────────────────────────────────
      // Each player can only see their own hand values; others get [].
      final alicePlayers =
          aliceRoundState['state']['players'] as List<dynamic>;
      final bobPlayers = bobRoundState['state']['players'] as List<dynamic>;

      // Alice's view: the entry whose hand list is non-empty is Alice herself.
      final aliceEntry = alicePlayers.firstWhere(
        (p) => ((p as Map)['hand'] as List).isNotEmpty,
      ) as Map<String, dynamic>;
      final aliceCard = (aliceEntry['hand'] as List<dynamic>).first as int;

      // Bob's view: the entry whose hand list is non-empty is Bob himself.
      final bobEntry = bobPlayers.firstWhere(
        (p) => ((p as Map)['hand'] as List).isNotEmpty,
      ) as Map<String, dynamic>;
      final bobCard = (bobEntry['hand'] as List<dynamic>).first as int;

      // ── The player with the highest card plays it ─────────────────────────
      final highCard = aliceCard > bobCard ? aliceCard : bobCard;
      final highPlayer = aliceCard > bobCard ? alice : bob;

      highPlayer.send({'type': 'play_card', 'value': highCard});

      // Both receive a state_update with the played card in the discard pile.
      final aliceFinalState = await alice.nextMsg(
        (m) =>
            m['type'] == 'state_update' &&
            ((m['state']['discard_pile'] as List).contains(highCard)),
      );
      final discardPile =
          aliceFinalState['state']['discard_pile'] as List<dynamic>;
      expect(discardPile, contains(highCard));

      // ── Cleanup ───────────────────────────────────────────────────────────
      await alice.close();
      await bob.close();
    });

    test(
        'four players ramp up card counts and win a perfect game',
        () async {
      // ── Connect Alice (host) ───────────────────────────────────────────────
      final alice = await _WsClient.connect(port);
      alice.send({'type': 'create_room'});

      final roomCreated = await alice.nextMsgOfType('room_created');
      final roomCode = roomCreated['room_code'] as String;

      // ── Connect Bob, Carol, Dave ───────────────────────────────────────────
      final bob = await _WsClient.connect(port);
      bob.send({'type': 'join_room', 'room_code': roomCode, 'name': 'Bob'});
      await bob.nextMsgOfType('room_joined');

      final carol = await _WsClient.connect(port);
      carol.send({'type': 'join_room', 'room_code': roomCode, 'name': 'Carol'});
      await carol.nextMsgOfType('room_joined');

      final dave = await _WsClient.connect(port);
      dave.send({'type': 'join_room', 'room_code': roomCode, 'name': 'Dave'});
      await dave.nextMsgOfType('room_joined');

      // ── Start game ────────────────────────────────────────────────────────
      alice.send({'type': 'start_game'});

      // Drain to the post-startGame lobby state on all clients.
      for (final client in [alice, bob, carol, dave]) {
        await client.nextMsg(
          (m) =>
              m['type'] == 'state_update' && m['state']['phase'] == 'lobby',
        );
      }

      // ── Game loop: 7 rounds, ramping card counts ──────────────────────────
      // Round schedule: [1, 2, 3, 4, 5, 6, 4] cards per player.
      // Total: 4+8+12+16+20+24+16 = 100 cards.
      final clients = [alice, bob, carol, dave];
      final cardCounts = [1, 2, 3, 4, 5, 6, 4];

      for (var roundIndex = 0; roundIndex < cardCounts.length; roundIndex++) {
        final roundNum = roundIndex + 1;
        final count = cardCounts[roundIndex];
        final isLastRound = roundIndex == cardCounts.length - 1;

        // All 4 players vote.
        for (final client in clients) {
          client.send({'type': 'vote_card_count', 'count': count});
        }

        // Await round-start state for this specific round from all clients.
        // Filter by round_number to avoid consuming stale mid-round broadcasts.
        bool isThisRoundStart(Map<String, dynamic> m) {
          if (m['type'] != 'state_update') return false;
          if (m['state']['phase'] != 'round') return false;
          if (m['state']['round_number'] != roundNum) return false;
          final players = m['state']['players'] as List<dynamic>;
          return players.any((p) => ((p as Map)['hand'] as List).isNotEmpty);
        }

        final aliceRound = await alice.nextMsg(isThisRoundStart);
        final bobRound = await bob.nextMsg(isThisRoundStart);
        final carolRound = await carol.nextMsg(isThisRoundStart);
        final daveRound = await dave.nextMsg(isThisRoundStart);

        // Extract each player's full hand.
        final aliceHand = _myHand(aliceRound);
        final bobHand = _myHand(bobRound);
        final carolHand = _myHand(carolRound);
        final daveHand = _myHand(daveRound);

        // Build globally sorted play order: descending by card value.
        final allCards = <(int, _WsClient)>[
          ...aliceHand.map((c) => (c, alice)),
          ...bobHand.map((c) => (c, bob)),
          ...carolHand.map((c) => (c, carol)),
          ...daveHand.map((c) => (c, dave)),
        ]..sort((a, b) => b.$1.compareTo(a.$1));

        // Play each card in descending order.
        for (var i = 0; i < allCards.length; i++) {
          final (cardValue, player) = allCards[i];
          player.send({'type': 'play_card', 'value': cardValue});

          if (isLastRound && i == allCards.length - 1) {
            // Final card of the entire game → expect won state.
            final wonState = await alice.nextMsg(
              (m) =>
                  m['type'] == 'state_update' &&
                  m['state']['phase'] == 'won',
            );
            expect(wonState['state']['phase'], 'won');
            expect(
              (wonState['state']['discard_pile'] as List).length,
              100,
            );
            expect(wonState['state']['lives'], 5);
          } else if (i == allCards.length - 1) {
            // Last card of a non-final round → server resets phase to lobby.
            await alice.nextMsg(
              (m) =>
                  m['type'] == 'state_update' &&
                  m['state']['phase'] == 'lobby',
            );
            // Drain lobby state on remaining clients to keep queues clean.
            for (final client in [bob, carol, dave]) {
              await client.nextMsg(
                (m) =>
                    m['type'] == 'state_update' &&
                    m['state']['phase'] == 'lobby',
              );
            }
          } else {
            // Intermediate card → wait for it to appear in the discard pile.
            await alice.nextMsg(
              (m) =>
                  m['type'] == 'state_update' &&
                  (m['state']['discard_pile'] as List).contains(cardValue),
            );
          }
        }
      }

      // ── Cleanup ───────────────────────────────────────────────────────────
      await alice.close();
      await bob.close();
      await carol.close();
      await dave.close();
    }, timeout: const Timeout(Duration(seconds: 60)));

    test('two players play a perfect game and win with all 100 cards discarded',
        () async {
      // ── Connect Alice ──────────────────────────────────────────────────────
      final alice = await _WsClient.connect(port);
      alice.send({'type': 'create_room'});

      final roomCreated = await alice.nextMsgOfType('room_created');
      final roomCode = roomCreated['room_code'] as String;

      // ── Connect Bob ────────────────────────────────────────────────────────
      final bob = await _WsClient.connect(port);
      bob.send({'type': 'join_room', 'room_code': roomCode, 'name': 'Bob'});
      await bob.nextMsgOfType('room_joined');

      // ── Start game (Alice is host) ─────────────────────────────────────────
      alice.send({'type': 'start_game'});

      // Drain to the post-startGame lobby state (phase == lobby) on both clients.
      await alice.nextMsg(
        (m) => m['type'] == 'state_update' && m['state']['phase'] == 'lobby',
      );
      await bob.nextMsg(
        (m) => m['type'] == 'state_update' && m['state']['phase'] == 'lobby',
      );

      // ── Game loop: 50 rounds (2 players × 1 card = 100 cards total) ───────
      for (var round = 1; round <= 50; round++) {
        // Vote 1 card each.
        alice.send({'type': 'vote_card_count', 'count': 1});
        bob.send({'type': 'vote_card_count', 'count': 1});

        // Wait for the round-start state for this specific round number.
        // Filtering by round_number avoids consuming stale phase='round' updates
        // from mid-round broadcasts of the previous round (e.g., the state
        // emitted after the first of two cards is played, where the second
        // player's hand is still visible in their own log).
        bool isThisRoundStart(Map<String, dynamic> m) {
          if (m['type'] != 'state_update') return false;
          if (m['state']['phase'] != 'round') return false;
          if (m['state']['round_number'] != round) return false;
          final players = m['state']['players'] as List<dynamic>;
          return players.any((p) => ((p as Map)['hand'] as List).isNotEmpty);
        }

        final aliceRound = await alice.nextMsg(isThisRoundStart);
        final bobRound = await bob.nextMsg(isThisRoundStart);

        // Extract each player's card (only the local player's hand is non-empty).
        final aliceCard = _myHandCard(aliceRound);
        final bobCard = _myHandCard(bobRound);

        // Determine optimal play order: highest card first.
        final firstPlayer = aliceCard > bobCard ? alice : bob;
        final firstCard = aliceCard > bobCard ? aliceCard : bobCard;
        final secondPlayer = aliceCard > bobCard ? bob : alice;
        final secondCard = aliceCard > bobCard ? bobCard : aliceCard;

        firstPlayer.send({'type': 'play_card', 'value': firstCard});

        // Wait for intermediate state: first card appears in discard pile.
        await alice.nextMsg(
          (m) =>
              m['type'] == 'state_update' &&
              (m['state']['discard_pile'] as List).contains(firstCard),
        );

        secondPlayer.send({'type': 'play_card', 'value': secondCard});

        if (round == 50) {
          // Last round: await the won state.
          final wonState = await alice.nextMsg(
            (m) =>
                m['type'] == 'state_update' && m['state']['phase'] == 'won',
          );
          expect(wonState['state']['phase'], 'won');
          expect(
            (wonState['state']['discard_pile'] as List).length,
            100,
          );
          expect(wonState['state']['lives'], 5);
        } else {
          // Between rounds: await lobby reset on both clients before next vote.
          // Draining Bob's queue prevents stale mid-round states from being
          // consumed as the round-start state in the next iteration.
          await alice.nextMsg(
            (m) =>
                m['type'] == 'state_update' && m['state']['phase'] == 'lobby',
          );
          await bob.nextMsg(
            (m) =>
                m['type'] == 'state_update' && m['state']['phase'] == 'lobby',
          );
        }
      }

      // ── Cleanup ───────────────────────────────────────────────────────────
      await alice.close();
      await bob.close();
    }, timeout: const Timeout(Duration(seconds: 30)));
  });
}

/// Extracts the local player's first card value from a round state_update.
/// Each client only sees its own hand values; the others have empty lists.
int _myHandCard(Map<String, dynamic> stateUpdate) {
  final players = stateUpdate['state']['players'] as List<dynamic>;
  final myEntry = players.firstWhere(
    (p) => ((p as Map)['hand'] as List).isNotEmpty,
  ) as Map<String, dynamic>;
  return (myEntry['hand'] as List<dynamic>).first as int;
}

/// Extracts the local player's full hand from a round state_update.
List<int> _myHand(Map<String, dynamic> stateUpdate) {
  final players = stateUpdate['state']['players'] as List<dynamic>;
  final myEntry = players.firstWhere(
    (p) => ((p as Map)['hand'] as List).isNotEmpty,
    orElse: () => <String, dynamic>{'hand': <int>[]},
  ) as Map<String, dynamic>;
  return (myEntry['hand'] as List<dynamic>).cast<int>();
}
