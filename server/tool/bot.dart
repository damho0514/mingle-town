// Dev helper: joins the server as one or more bots that wander, chat and emote.
//
//   dart run tool/bot.dart [ws://localhost:8080] [count]
import 'dart:async';
import 'dart:math';

import 'package:mingle_protocol/mingle_protocol.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

const _lines = ['안녕하세요!', '여기 분수 예쁘다', '같이 산책해요', '반가워요 👋', '연못 가볼래요?'];

Future<void> main(List<String> args) async {
  final uri = Uri.parse(args.isNotEmpty ? args[0] : 'ws://localhost:8080');
  final count = args.length > 1 ? int.parse(args[1]) : 1;
  await Future.wait([
    for (var i = 1; i <= count; i++) _runBot(uri, 'bot$i', i),
  ]);
}

Future<void> _runBot(Uri uri, String name, int seed) async {
  final rng = Random(seed);
  final channel = WebSocketChannel.connect(uri);
  await channel.ready;
  print('$name connected to $uri');

  var x = Limits.worldWidth / 2, y = Limits.worldHeight / 2;
  channel.stream.listen((data) {
    final m = ServerMessage.decode(data as String);
    if (m is WelcomeMessage) {
      final me = m.players.firstWhere((p) => p.id == m.selfId);
      x = me.x;
      y = me.y;
    }
  }, onDone: () => print('$name disconnected'));
  channel.sink.add(JoinMessage(name).encode());

  var tick = 0;
  Timer.periodic(const Duration(seconds: 3), (_) {
    tick++;
    // Stroll around the plaza.
    x = (x + rng.nextDouble() * 240 - 120).clamp(560, 1040);
    y = (y + rng.nextDouble() * 240 - 120).clamp(560, 1040);
    channel.sink.add(MoveMessage(x, y).encode());
    if (tick % 3 == 0) {
      channel.sink.add(
        ChatMessage(_lines[rng.nextInt(_lines.length)]).encode(),
      );
    } else if (tick % 3 == 1) {
      channel.sink.add(
        EmoteMessage(Emote.values[rng.nextInt(Emote.values.length)]).encode(),
      );
    }
  });
}
