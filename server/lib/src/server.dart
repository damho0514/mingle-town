import 'dart:io';

import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart' as shelf_io;
import 'package:shelf_web_socket/shelf_web_socket.dart';

import 'room.dart';

/// HTTP handler: `GET /healthz` for health checks, WebSocket upgrade elsewhere.
Handler createHandler(Room room) {
  final ws = webSocketHandler((webSocket, _) {
    final session = room.connect((m) => webSocket.sink.add(m.encode()));
    webSocket.stream.listen(
      (data) {
        if (data is String) session.handle(data);
      },
      onDone: session.close,
      onError: (Object _) => session.close(),
      cancelOnError: true,
    );
  }, pingInterval: const Duration(seconds: 20));

  return (Request request) {
    if (request.url.path == 'healthz') {
      return Response.ok('ok (${room.playerCount} players)');
    }
    return ws(request);
  };
}

Future<HttpServer> startServer({
  Room? room,
  Object address = '0.0.0.0',
  int port = 8080,
}) => shelf_io.serve(createHandler(room ?? Room()), address, port);
