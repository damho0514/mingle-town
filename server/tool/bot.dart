// Dev helper: joins the server as one or more bots that wander, chat, emote
// and play tag (chasing when "it", fleeing otherwise).
//
//   dart run tool/bot.dart [ws://localhost:8080] [count] [room]
import 'dart:async';
import 'dart:math';

import 'package:mingle_protocol/mingle_protocol.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

const _lines = ['안녕하세요!', '여기 분수 예쁘다', '같이 산책해요', '반가워요 👋', '술래잡기 할 사람?'];

Future<void> main(List<String> args) async {
  final uri = Uri.parse(args.isNotEmpty ? args[0] : 'ws://localhost:8080');
  final count = args.length > 1 ? int.parse(args[1]) : 1;
  final room = args.length > 2 ? args[2] : Rooms.defaultId;
  await Future.wait([for (var i = 1; i <= count; i++) Bot(uri, room, i).run()]);
}

class Bot {
  Bot(this.uri, this.room, this.n) : rng = Random(n);

  final Uri uri;
  final String room;
  final int n;
  final Random rng;
  final map = WorldMap.instance;

  String? selfId;
  String? itId;
  var pos = WorldMap.center;
  WorldPoint? wanderTarget;
  final others = <String, WorldPoint>{};

  Future<void> run() async {
    final channel = WebSocketChannel.connect(uri);
    await channel.ready;
    print('bot$n connected to $uri ($room)');
    void send(ClientMessage m) => channel.sink.add(m.encode());

    channel.stream.listen((data) {
      switch (ServerMessage.decode(data as String)) {
        case WelcomeMessage(:final selfId, :final players, :final tag):
          this.selfId = selfId;
          itId = tag?.itId;
          for (final p in players) {
            if (p.id == selfId) {
              pos = (x: p.x, y: p.y);
            } else {
              others[p.id] = (x: p.x, y: p.y);
            }
          }
        case PlayerJoinedMessage(:final player):
          others[player.id] = (x: player.x, y: player.y);
        case PlayerLeftMessage(:final id):
          others.remove(id);
        case PlayerMovedMessage(:final id, :final x, :final y):
          others[id] = (x: x, y: y);
        case TagMessage(:final phase, itId: final it):
          itId = phase == TagPhase.ended ? null : it;
          if (phase == TagPhase.tagged && it == selfId) {
            send(const EmoteMessage(Emote.sad));
          }
        case _:
          break;
      }
    }, onDone: () => print('bot$n disconnected'));

    send(
      JoinMessage(
        'bot$n',
        room: room,
        color: Palette.colors[rng.nextInt(Palette.colors.length)],
        hat: Hat.values[rng.nextInt(Hat.values.length)],
      ),
    );

    // Stream movement at the same rate as real clients.
    const dt = 0.1;
    var ticks = 0;
    Timer.periodic(MoveRateLimit.sendInterval, (_) {
      ticks++;
      final dir = _direction();
      if (dir != null) {
        final step = Limits.walkSpeed * dt * (itId == null ? 0.6 : 0.9);
        pos = map.resolve((x: pos.x + dir.x * step, y: pos.y + dir.y * step));
        send(MoveMessage(pos.x, pos.y));
      }
      if (ticks % 80 == 0) {
        send(ChatMessage(_lines[rng.nextInt(_lines.length)]));
      } else if (ticks % 80 == 40) {
        send(EmoteMessage(Emote.values[rng.nextInt(Emote.values.length)]));
      }
    });
  }

  /// Unit vector to walk along this tick, or null to stand still.
  WorldPoint? _direction() {
    final it = itId;
    if (it != null && others.isNotEmpty) {
      if (it == selfId) {
        final prey = others.values.reduce((a, b) => _d(a) < _d(b) ? a : b);
        return _unit(prey.x - pos.x, prey.y - pos.y);
      }
      final chaser = others[it];
      if (chaser != null && _d(chaser) < 300) {
        // Flee, with a little sideways wobble so bots don't run in lines.
        final away = _unit(pos.x - chaser.x, pos.y - chaser.y);
        return _unit(
          away.x + rng.nextDouble() * 0.6 - 0.3,
          away.y + rng.nextDouble() * 0.6 - 0.3,
        );
      }
    }
    final target = wanderTarget;
    if (target == null || _d(target) < 12) {
      wanderTarget = map.resolve((
        x: WorldMap.center.x + rng.nextDouble() * 600 - 300,
        y: WorldMap.center.y + rng.nextDouble() * 600 - 300,
      ));
      return rng.nextBool() ? null : _direction();
    }
    return _unit(target.x - pos.x, target.y - pos.y);
  }

  double _d(WorldPoint p) => sqrt(pow(p.x - pos.x, 2) + pow(p.y - pos.y, 2));

  static WorldPoint _unit(double x, double y) {
    final l = sqrt(x * x + y * y);
    return l == 0 ? (x: 0, y: 0) : (x: x / l, y: y / l);
  }
}
