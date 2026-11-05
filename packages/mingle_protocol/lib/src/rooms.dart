/// The fixed set of rooms (channels) players can join.
abstract final class Rooms {
  static const ids = ['plaza-1', 'plaza-2', 'plaza-3'];
  static const defaultId = 'plaza-1';
  static const capacity = 30;

  /// Human-friendly label, e.g. `plaza-2` -> `광장 2`.
  static String label(String id) {
    final n = id.split('-').last;
    return '광장 $n';
  }
}

/// Occupancy of one room, served by `GET /rooms`.
class RoomInfo {
  const RoomInfo({
    required this.id,
    required this.count,
    required this.capacity,
  });

  final String id;
  final int count;
  final int capacity;

  bool get isFull => count >= capacity;

  Map<String, Object?> toJson() => {
    'id': id,
    'count': count,
    'capacity': capacity,
  };

  static RoomInfo fromJson(Map<String, Object?> json) => RoomInfo(
    id: json['id'] as String,
    count: json['count'] as int,
    capacity: json['capacity'] as int,
  );
}
