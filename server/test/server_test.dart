import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:mingle_protocol/mingle_protocol.dart';
import 'package:mingle_server/mingle_server.dart';
import 'package:test/test.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

class WsClient {
  WsClient._(this.channel) {
    channel.stream.listen(
      (data) => _messages.add(ServerMessage.decode(data as String)),
    );
  }

  static Future<WsClient> connect(int port) async {
    final channel = WebSocketChannel.connect(Uri.parse('ws://127.0.0.1:$port'));
    await channel.ready;
    return WsClient._(channel);
  }

  final WebSocketChannel channel;
  final _messages = StreamController<ServerMessage>.broadcast();
  late final _queue = StreamIterator(_messages.stream);

  void send(ClientMessage m) => channel.sink.add(m.encode());

  Future<T> next<T extends ServerMessage>() async {
    while (await _queue.moveNext().timeout(const Duration(seconds: 5))) {
      if (_queue.current is T) return _queue.current as T;
    }
    throw StateError('stream closed');
  }
}

void main() {
  late HttpServer server;
  setUp(() async => server = await startServer(address: '127.0.0.1', port: 0));
  tearDown(() => server.close(force: true));

  test('health check responds', () async {
    final client = HttpClient();
    final res = await (await client.getUrl(
      Uri.parse('http://127.0.0.1:${server.port}/healthz'),
    )).close();
    expect(res.statusCode, 200);
    client.close();
  });

  test('rooms endpoint lists occupancy with CORS', () async {
    final client = HttpClient();
    final res = await (await client.getUrl(
      Uri.parse('http://127.0.0.1:${server.port}/rooms'),
    )).close();
    expect(res.statusCode, 200);
    expect(res.headers.value('access-control-allow-origin'), '*');
    final body = jsonDecode(
      await res.transform(utf8.decoder).join(),
    ) as Map<String, Object?>;
    final rooms = (body['rooms'] as List).map(
      (r) => RoomInfo.fromJson(r as Map<String, Object?>),
    );
    expect(rooms.map((r) => r.id), Rooms.ids);
    client.close();
  });

  test('two clients see each other join, move, chat and leave', () async {
    final a = await WsClient.connect(server.port);
    a.send(const JoinMessage('alice'));
    final aId = (await a.next<WelcomeMessage>()).selfId;

    final b = await WsClient.connect(server.port);
    b.send(const JoinMessage('bob'));
    final welcomeB = await b.next<WelcomeMessage>();
    expect(welcomeB.players.map((p) => p.id), contains(aId));
    expect((await a.next<PlayerJoinedMessage>()).player.name, 'bob');

    a.send(const MoveMessage(300, 400));
    final moved = await b.next<PlayerMovedMessage>();
    expect((moved.id, moved.x, moved.y), (aId, 300.0, 400.0));

    b.send(const ChatMessage('hello'));
    expect((await a.next<PlayerChatMessage>()).text, 'hello');

    await a.channel.sink.close();
    expect((await b.next<PlayerLeftMessage>()).id, aId);
    await b.channel.sink.close();
  });
}
