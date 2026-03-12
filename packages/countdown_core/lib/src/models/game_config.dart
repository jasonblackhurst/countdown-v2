class GameConfig {
  final int playerCount;

  const GameConfig({required this.playerCount})
      : assert(playerCount >= 2 && playerCount <= 5,
            'Player count must be 2–5');
}
