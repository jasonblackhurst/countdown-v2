import 'package:shared_preferences/shared_preferences.dart';

/// Persists room/player session info so the app can rejoin after a restart.
class SessionStore {
  static const _keyRoomCode = 'countdown_room_code';
  static const _keyPlayerId = 'countdown_player_id';

  /// Saves the current session (room code + player ID).
  static Future<void> save(String roomCode, String playerId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyRoomCode, roomCode);
    await prefs.setString(_keyPlayerId, playerId);
  }

  /// Loads a previously saved session. Returns null if none exists.
  static Future<({String roomCode, String playerId})?> load() async {
    final prefs = await SharedPreferences.getInstance();
    final roomCode = prefs.getString(_keyRoomCode);
    final playerId = prefs.getString(_keyPlayerId);
    if (roomCode != null && playerId != null) {
      return (roomCode: roomCode, playerId: playerId);
    }
    return null;
  }

  /// Clears the stored session.
  static Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keyRoomCode);
    await prefs.remove(_keyPlayerId);
  }
}
