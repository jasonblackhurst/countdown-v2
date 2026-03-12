import 'dart:io';

import 'package:countdown_core/countdown_core.dart';
import 'package:countdown_server/src/protocol.dart';
import 'package:countdown_server/src/room.dart';
import 'package:countdown_server/src/room_manager.dart';
import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart';
import 'package:shelf_router/shelf_router.dart';
import 'package:shelf_web_socket/shelf_web_socket.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

final _rooms = RoomManager();

Handler _buildHandler() {
  final router = Router()
    ..get('/ws', webSocketHandler(_onConnection))
    ..get('/health', (_) => Response.ok('ok\n'));

  return Pipeline().addMiddleware(logRequests()).addHandler(router.call);
}

void _onConnection(WebSocketChannel ws) {
  final channel = ws.cast<String>();
  String? roomCode;
  String? playerId;

  channel.stream.listen(
    (raw) {
      try {
        final msg = ClientMessage.parse(raw);
        _handle(msg, channel.sink, roomCode, playerId, (rc, pid) {
          roomCode = rc;
          playerId = pid;
        });
      } catch (e) {
        channel.sink.add(encode(errorMsg(e.toString())));
      }
    },
    onDone: () {
      final rc = roomCode;
      final pid = playerId;
      if (rc != null && pid != null) {
        _rooms.getRoom(rc)?.removePlayer(pid);
      }
    },
  );
}

void _handle(
  ClientMessage msg,
  Sink sink,
  String? roomCode,
  String? playerId,
  void Function(String rc, String pid) setContext,
) {
  switch (msg) {
    case CreateRoomMsg():
      final room = _rooms.createRoom();
      final pid = room.addPlayer('Host', sink);
      setContext(room.code, pid);
      sink.add(encode(roomCreatedMsg(room.code, pid)));

    case JoinRoomMsg(:final roomCode, :final playerName):
      final room = _rooms.getRoom(roomCode);
      if (room == null) {
        sink.add(encode(errorMsg('Room $roomCode not found')));
        return;
      }
      final pid = room.addPlayer(playerName, sink);
      setContext(room.code, pid);
      sink.add(encode(roomJoinedMsg(room.code, pid)));

    case StartGameMsg():
      final rc = roomCode;
      final pid = playerId;
      if (rc == null || pid == null) {
        sink.add(encode(errorMsg('Not in a room')));
        return;
      }
      _rooms.getRoom(rc)?.startGame(pid);

    case VoteCardCountMsg(:final count):
      final rc = roomCode;
      final pid = playerId;
      if (rc == null || pid == null) {
        sink.add(encode(errorMsg('Not in a room')));
        return;
      }
      _rooms.getRoom(rc)?.voteCardCount(pid, count);

    case PlayCardMsg(:final card):
      final rc = roomCode;
      final pid = playerId;
      if (rc == null || pid == null) {
        sink.add(encode(errorMsg('Not in a room')));
        return;
      }
      final room = _rooms.getRoom(rc);
      if (room == null) return;
      final result = room.playCard(pid, card);
      if (result == PlayResult.win) {
        print('Room $rc: game WON!');
        _rooms.removeRoom(rc);
      } else if (result == PlayResult.gameOver) {
        print('Room $rc: game OVER');
        _rooms.removeRoom(rc);
      }
  }
}

void main(List<String> args) async {
  final ip = InternetAddress.anyIPv4;
  final port = int.parse(Platform.environment['PORT'] ?? '8080');
  final server = await serve(_buildHandler(), ip, port);
  print('Countdown server listening on ws://localhost:${server.port}/ws');
}
