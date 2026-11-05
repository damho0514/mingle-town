/// Snapshot of a player as seen by every client.
class PlayerState {
  const PlayerState({
    required this.id,
    required this.name,
    required this.color,
    required this.x,
    required this.y,
  });

  final String id;
  final String name;

  /// ARGB color value.
  final int color;
  final double x;
  final double y;

  PlayerState copyWith({double? x, double? y}) => PlayerState(
    id: id,
    name: name,
    color: color,
    x: x ?? this.x,
    y: y ?? this.y,
  );

  Map<String, Object?> toJson() => {
    'id': id,
    'name': name,
    'color': color,
    'x': x,
    'y': y,
  };

  static PlayerState fromJson(Map<String, Object?> json) => PlayerState(
    id: json['id'] as String,
    name: json['name'] as String,
    color: json['color'] as int,
    x: (json['x'] as num).toDouble(),
    y: (json['y'] as num).toDouble(),
  );

  @override
  bool operator ==(Object other) =>
      other is PlayerState &&
      other.id == id &&
      other.name == name &&
      other.color == color &&
      other.x == x &&
      other.y == y;

  @override
  int get hashCode => Object.hash(id, name, color, x, y);
}
