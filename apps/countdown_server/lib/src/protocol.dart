import 'dart:convert';

import 'package:countdown_core/countdown_core.dart';

// ── Incoming message types ────────────────────────────────────────────────

sealed class ClientMessage {
  const ClientMessage();

  static ClientMessage parse(String raw) {
    final map = jsonDecode(raw) as Map<String, dynamic>;
    return switch (map['type'] as String) {
      'create_room' => const CreateRoomMsg(),
      'join_room' => JoinRoomMsg(
          roomCode: map['room_code'] as String,
          playerName: map['name'] as String,
        ),
      'start_game' => const StartGameMsg(),
      'vote_card_count' => VoteCardCountMsg(map['count'] as int),
      'play_card' => PlayCardMsg(GameCard(map['value'] as int)),
      _ => throw FormatException('Unknown message type: ${map['type']}'),
    };
  }
}

class CreateRoomMsg extends ClientMessage {
  const CreateRoomMsg();
}

class JoinRoomMsg extends ClientMessage {
  final String roomCode;
  final String playerName;
  const JoinRoomMsg({required this.roomCode, required this.playerName});
}

class StartGameMsg extends ClientMessage {
  const StartGameMsg();
}

class VoteCardCountMsg extends ClientMessage {
  final int count;
  const VoteCardCountMsg(this.count);
}

class PlayCardMsg extends ClientMessage {
  final GameCard card;
  const PlayCardMsg(this.card);
}

// ── Outgoing message builders ─────────────────────────────────────────────

Map<String, dynamic> roomCreatedMsg(String roomCode, String playerId) => {
      'type': 'room_created',
      'room_code': roomCode,
      'player_id': playerId,
    };

Map<String, dynamic> roomJoinedMsg(String roomCode, String playerId) => {
      'type': 'room_joined',
      'room_code': roomCode,
      'player_id': playerId,
    };

Map<String, dynamic> errorMsg(String message) => {
      'type': 'error',
      'message': message,
    };

Map<String, dynamic> stateUpdateMsg(
  GameState state, {
  String? localEnginePlayerId,
}) =>
    {
      'type': 'state_update',
      'state': _serializeState(state, localEnginePlayerId: localEnginePlayerId),
    };

Map<String, dynamic> _serializeState(
  GameState state, {
  String? localEnginePlayerId,
}) =>
    {
      'phase': state.phase.name,
      'lives': state.lives,
      'round_number': state.roundNumber,
      'discard_pile': state.discardPile.map((c) => c.value).toList(),
      'players': state.players
          .map((p) => {
                'id': p.id,
                'name': p.name,
                'hand_size': p.hand.cards.length,
                // Only include actual card values for the local player
                'hand': p.id == localEnginePlayerId
                    ? p.hand.cards.map((c) => c.value).toList()
                    : <int>[],
              })
          .toList(),
    };

String encode(Map<String, dynamic> msg) => jsonEncode(msg);
