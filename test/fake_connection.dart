import 'dart:async';

import 'package:mingle_protocol/mingle_protocol.dart';
import 'package:mingle_town/net/game_connection.dart';

class FakeConnection implements GameConnection {
  final sent = <ClientMessage>[];
  final _messages = StreamController<ServerMessage>.broadcast();
  final _done = Completer<void>();
  bool closed = false;

  void receive(ServerMessage m) => _messages.add(m);
  void drop() => _done.complete();

  @override
  Stream<ServerMessage> get messages => _messages.stream;
  @override
  Future<void> get done => _done.future;
  @override
  void send(ClientMessage message) => sent.add(message);
  @override
  Future<void> close() async {
    closed = true;
    if (!_done.isCompleted) _done.complete();
  }
}
