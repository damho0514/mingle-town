import 'package:mingle_protocol/mingle_protocol.dart';
import 'package:test/test.dart';

void main() {
  const alice =
      PlayerState(id: 'p1', name: 'alice', color: 0xFFFF7043, x: 10, y: 20.5);

  group('ClientMessage', () {
    test('round-trips every type', () {
      final join =
          ClientMessage.decode(const JoinMessage('bob').encode()) as JoinMessage;
      expect(join.name, 'bob');

      final move =
          ClientMessage.decode(const MoveMessage(1, 2.5).encode()) as MoveMessage;
      expect((move.x, move.y), (1.0, 2.5));

      final chat =
          ClientMessage.decode(const ChatMessage('hi').encode()) as ChatMessage;
      expect(chat.text, 'hi');
    });

    test('accepts integer coordinates', () {
      final move = ClientMessage.decode('{"t":"move","x":3,"y":4}');
      expect(move, isA<MoveMessage>());
    });

    test('rejects malformed input', () {
      for (final raw in [
        'not json',
        '[1,2]',
        '{"t":"nope"}',
        '{"t":"join"}',
        '{"t":"join","name":5}',
        '{"t":"move","x":"1","y":2}',
      ]) {
        expect(() => ClientMessage.decode(raw), throwsA(isA<ProtocolException>()),
            reason: raw);
      }
    });
  });

  group('ServerMessage', () {
    test('round-trips every type', () {
      final welcome = ServerMessage.decode(
              const WelcomeMessage(selfId: 'p1', players: [alice]).encode())
          as WelcomeMessage;
      expect(welcome.selfId, 'p1');
      expect(welcome.players, [alice]);

      final joined = ServerMessage.decode(const PlayerJoinedMessage(alice).encode())
          as PlayerJoinedMessage;
      expect(joined.player, alice);

      expect(
          (ServerMessage.decode(const PlayerLeftMessage('p1').encode())
                  as PlayerLeftMessage)
              .id,
          'p1');

      final moved = ServerMessage.decode(
          const PlayerMovedMessage('p1', 5, 6).encode()) as PlayerMovedMessage;
      expect((moved.id, moved.x, moved.y), ('p1', 5.0, 6.0));

      final chat = ServerMessage.decode(
          const PlayerChatMessage('p1', 'yo').encode()) as PlayerChatMessage;
      expect((chat.id, chat.text), ('p1', 'yo'));

      expect(
          (ServerMessage.decode(const ErrorMessage('bad').encode())
                  as ErrorMessage)
              .reason,
          'bad');
    });

    test('rejects malformed players', () {
      expect(
          () => ServerMessage.decode('{"t":"joined","player":{"id":1}}'),
          throwsA(isA<ProtocolException>()));
    });
  });
}
