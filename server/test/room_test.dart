import 'dart:math';

import 'package:mingle_protocol/mingle_protocol.dart';
import 'package:mingle_server/mingle_server.dart';
import 'package:test/test.dart';

class FakeClient {
  FakeClient(Room room) {
    session = room.connect(inbox.add);
  }
  late final Session session;
  final inbox = <ServerMessage>[];

  void send(ClientMessage m) => session.handle(m.encode());
  T last<T extends ServerMessage>() => inbox.whereType<T>().last;
}

void main() {
  late Room room;
  setUp(() => room = Room(random: Random(1)));

  test('join sends welcome with everyone and notifies others', () {
    final a = FakeClient(room)..send(const JoinMessage('alice'));
    final b = FakeClient(room)..send(const JoinMessage('bob'));

    final welcomeB = b.last<WelcomeMessage>();
    expect(welcomeB.players.map((p) => p.name), ['alice', 'bob']);
    expect(welcomeB.selfId, b.session.player!.id);

    expect(a.last<PlayerJoinedMessage>().player.name, 'bob');
    expect(b.inbox.whereType<PlayerJoinedMessage>(), isEmpty);
    expect(room.playerCount, 2);
  });

  test('move is clamped and broadcast to others only', () {
    final a = FakeClient(room)..send(const JoinMessage('alice'));
    final b = FakeClient(room)..send(const JoinMessage('bob'));
    a.inbox.clear();

    a.send(const MoveMessage(-50, 99999));

    final moved = b.last<PlayerMovedMessage>();
    expect((moved.x, moved.y), (0.0, Limits.worldHeight));
    expect(a.inbox, isEmpty);
    expect(a.session.player!.x, 0);

    // A late joiner sees the updated position.
    final c = FakeClient(room)..send(const JoinMessage('carol'));
    final aSeenByC = c.last<WelcomeMessage>().players.firstWhere(
      (p) => p.name == 'alice',
    );
    expect((aSeenByC.x, aSeenByC.y), (0.0, Limits.worldHeight));
  });

  test('chat is trimmed, truncated and echoed to everyone', () {
    final a = FakeClient(room)..send(const JoinMessage('alice'));
    final b = FakeClient(room)..send(const JoinMessage('bob'));

    a.send(ChatMessage('  ${'x' * 500}  '));
    expect(a.last<PlayerChatMessage>().text.length, Limits.maxChatLength);
    expect(b.last<PlayerChatMessage>().id, a.session.player!.id);

    final before = b.inbox.length;
    a.send(const ChatMessage('   '));
    expect(b.inbox.length, before, reason: 'blank chat is dropped');
  });

  test('names are sanitized', () {
    final a = FakeClient(room)..send(const JoinMessage('   '));
    expect(a.session.player!.name, startsWith('guest-'));

    final b = FakeClient(room)..send(JoinMessage('a  b${'z' * 50}'));
    expect(b.session.player!.name, startsWith('a b'));
    expect(b.session.player!.name.length, Limits.maxNameLength);
  });

  test('rejects actions before join, double join, and garbage', () {
    final a = FakeClient(room);
    a.send(const MoveMessage(1, 1));
    expect(a.last<ErrorMessage>().reason, 'join first');

    a.session.handle('garbage');
    expect(a.inbox.last, isA<ErrorMessage>());

    a.session.handle('x' * (Room.maxFrameLength + 1));
    expect(a.last<ErrorMessage>().reason, 'frame too large');

    a.send(const JoinMessage('alice'));
    a.send(const JoinMessage('again'));
    expect(a.last<ErrorMessage>().reason, 'already joined');
    expect(room.playerCount, 1);
  });

  test('close removes the player once and notifies others', () {
    final a = FakeClient(room)..send(const JoinMessage('alice'));
    final b = FakeClient(room)..send(const JoinMessage('bob'));

    a.session.close();
    a.session.close();

    expect(b.inbox.whereType<PlayerLeftMessage>().length, 1);
    expect(room.playerCount, 1);

    // Closing a session that never joined is harmless.
    FakeClient(room).session.close();
    expect(room.playerCount, 1);
  });
}
