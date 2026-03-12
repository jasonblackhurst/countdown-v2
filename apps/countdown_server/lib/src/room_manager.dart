import 'dart:math';

import 'room.dart';

class RoomManager {
  final Map<String, Room> _rooms = {};
  final Random _rng = Random();

  /// Creates a new room and returns it.
  Room createRoom() {
    String code;
    do {
      code = _generateCode();
    } while (_rooms.containsKey(code));

    final room = Room(code);
    _rooms[code] = room;
    return room;
  }

  Room? getRoom(String code) => _rooms[code.toUpperCase()];

  void removeRoom(String code) => _rooms.remove(code);

  String _generateCode() {
    const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ';
    return List.generate(4, (_) => chars[_rng.nextInt(chars.length)]).join();
  }
}
