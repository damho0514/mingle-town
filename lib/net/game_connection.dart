import 'dart:async';

import 'package:mingle_protocol/mingle_protocol.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

/// Bidirectional link to the game server.
abstract interface class GameConnection {
  Stream<ServerMessage> get messages;

  /// Completes when the connection ends, for whatever reason.
  Future<void> get done;

  void send(ClientMessage message);
  Future<void> close();
}

class WebSocketGameConnection implements GameConnection {
  WebSocketGameConnection._(this._channel) {
    _channel.stream.listen(
      (data) {
        if (data is! String) return;
        try {
          _messages.add(ServerMessage.decode(data));
        } on ProtocolException {
          // Ignore frames we don't understand (e.g. from a newer server).
        }
      },
      onDone: _finish,
      onError: (Object _) => _finish(),
      cancelOnError: true,
    );
  }

  /// Opens a connection, throwing if the server can't be reached.
  static Future<WebSocketGameConnection> connect(
    Uri uri, {
    Duration timeout = const Duration(seconds: 5),
  }) async {
    final channel = WebSocketChannel.connect(uri);
    try {
      await channel.ready.timeout(timeout);
    } catch (_) {
      unawaited(channel.sink.close());
      rethrow;
    }
    return WebSocketGameConnection._(channel);
  }

  final WebSocketChannel _channel;
  final _messages = StreamController<ServerMessage>.broadcast();
  final _done = Completer<void>();

  @override
  Stream<ServerMessage> get messages => _messages.stream;

  @override
  Future<void> get done => _done.future;

  @override
  void send(ClientMessage message) {
    if (!_done.isCompleted) _channel.sink.add(message.encode());
  }

  @override
  Future<void> close() async {
    await _channel.sink.close();
    _finish();
  }

  void _finish() {
    if (_done.isCompleted) return;
    _done.complete();
    _messages.close();
  }
}
