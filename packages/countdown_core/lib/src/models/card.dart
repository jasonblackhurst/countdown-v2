class GameCard implements Comparable<GameCard> {
  final int value;

  const GameCard(this.value)
      : assert(value >= 1 && value <= 100, 'Card value must be 1–100');

  @override
  int compareTo(GameCard other) => value.compareTo(other.value);

  @override
  bool operator ==(Object other) => other is GameCard && other.value == value;

  @override
  int get hashCode => value.hashCode;

  @override
  String toString() => 'Card($value)';
}
