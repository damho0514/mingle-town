import 'dart:async';
import 'dart:math';

import 'package:mingle_protocol/mingle_protocol.dart';

import 'room.dart';
import 'session.dart';

typedef Clock = DateTime Function();
typedef TimerFactory = Timer Function(Duration delay, void Function() callback);

/// Owns every [Room] and hands out [Session]s for new connections.
class Lobby {
  Lobby({Random? random, Clock? clock, TimerFactory? timer})
    : random = random ?? Random(),
      clock = clock ?? DateTime.now,
      timer = timer ?? Timer.new {
    for (final id in Rooms.ids) {
      rooms[id] = Room(id, this);
    }
  }

  final Random random;
  final Clock clock;
  final TimerFactory timer;
  final Map<String, Room> rooms = {};
  int _nextId = 1;

  String nextPlayerId() => 'p${_nextId++}';

  Session connect(SendFn send) => Session(this, send);

  List<RoomInfo> get roomInfo => [
    for (final r in rooms.values)
      RoomInfo(id: r.id, count: r.playerCount, capacity: Rooms.capacity),
  ];

  int get playerCount => rooms.values.fold(0, (sum, r) => sum + r.playerCount);
}
