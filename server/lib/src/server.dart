import 'dart:convert';
import 'dart:io';

import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart' as shelf_io;
import 'package:shelf_web_socket/shelf_web_socket.dart';

import 'lobby.dart';

/// HTTP handler:
/// - `GET /healthz`: liveness check
/// - `GET /rooms`: room occupancy (CORS-enabled for the web client)
/// - anything else: WebSocket upgrade
Handler createHandler(Lobby lobby) {
  final ws = webSocketHandler((webSocket, _) {
    final session = lobby.connect((m) => webSocket.sink.add(m.encode()));
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
    switch (request.url.path) {
      case 'healthz':
        return Response.ok('ok (${lobby.playerCount} players)');
      case 'rooms':
        return Response.ok(
          jsonEncode({
            'rooms': [for (final r in lobby.roomInfo) r.toJson()],
          }),
          headers: {
            'content-type': 'application/json',
            'access-control-allow-origin': '*',
          },
        );
      default:
        return ws(request);
    }
  };
}

Future<HttpServer> startServer({
  Lobby? lobby,
  Object address = '0.0.0.0',
  int port = 8080,
}) => shelf_io.serve(createHandler(lobby ?? Lobby()), address, port);
