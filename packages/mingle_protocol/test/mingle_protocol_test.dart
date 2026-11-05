import 'package:mingle_protocol/mingle_protocol.dart';
import 'package:test/test.dart';

T roundTripClient<T extends ClientMessage>(T m) =>
    ClientMessage.decode(m.encode()) as T;
T roundTripServer<T extends ServerMessage>(T m) =>
    ServerMessage.decode(m.encode()) as T;

void main() {
  const alice = PlayerState(
    id: 'p1',
    name: 'alice',
    color: 0xFFFF7043,
    hat: Hat.crown,
    x: 10,
    y: 20.5,
  );

  group('ClientMessage', () {
    test('round-trips every type', () {
      final join = roundTripClient(
        const JoinMessage(
          'bob',
          room: 'plaza-2',
          color: 0xFF42A5F5,
          hat: Hat.bow,
        ),
      );
      expect(
        (join.name, join.room, join.color, join.hat),
        ('bob', 'plaza-2', 0xFF42A5F5, Hat.bow),
      );

      final move = roundTripClient(const MoveMessage(1, 2.5));
      expect((move.x, move.y), (1.0, 2.5));
      expect(roundTripClient(const ChatMessage('hi')).text, 'hi');
      expect(
        roundTripClient(const EmoteMessage(Emote.heart)).emote,
        Emote.heart,
      );
      expect(roundTripClient(const StartTagMessage()), isA<StartTagMessage>());
    });

    test('join defaults stay compatible with older clients', () {
      final join =
          ClientMessage.decode('{"t":"join","name":"x"}') as JoinMessage;
      expect(
        (join.room, join.color, join.hat),
        (Rooms.defaultId, null, Hat.none),
      );

      final odd = ClientMessage.decode(
        '{"t":"join","name":"x","hat":"tophat"}',
      ) as JoinMessage;
      expect(odd.hat, Hat.none);
    });

    test('rejects malformed input', () {
      for (final raw in [
        'not json',
        '[1,2]',
        '{"t":"nope"}',
        '{"t":"join"}',
        '{"t":"join","name":5}',
        '{"t":"join","name":"x","color":"red"}',
        '{"t":"move","x":"1","y":2}',
        '{"t":"emote","e":"nope"}',
      ]) {
        expect(
          () => ClientMessage.decode(raw),
          throwsA(isA<ProtocolException>()),
          reason: raw,
        );
      }
    });
  });

  group('ServerMessage', () {
    test('round-trips every type', () {
      final welcome = roundTripServer(
        WelcomeMessage(
          selfId: 'p1',
          room: 'plaza-3',
          players: const [alice],
          tag: const TagMessage(
            phase: TagPhase.started,
            itId: 'p1',
            remainingMs: 4000,
          ),
        ),
      );
      expect((welcome.selfId, welcome.room), ('p1', 'plaza-3'));
      expect(welcome.players, [alice]);
      expect(welcome.tag!.itId, 'p1');
      expect(welcome.tag!.remainingMs, 4000);

      expect(
        roundTripServer(const WelcomeMessage(selfId: 'p', players: [])).tag,
        isNull,
      );
      expect(roundTripServer(const PlayerJoinedMessage(alice)).player, alice);
      expect(roundTripServer(const PlayerLeftMessage('p1')).id, 'p1');

      final moved = roundTripServer(const PlayerMovedMessage('p1', 5, 6));
      expect((moved.id, moved.x, moved.y), ('p1', 5.0, 6.0));

      final chat = roundTripServer(const PlayerChatMessage('p1', 'yo'));
      expect((chat.id, chat.text), ('p1', 'yo'));

      final emoted = roundTripServer(
        const PlayerEmotedMessage('p1', Emote.party),
      );
      expect((emoted.id, emoted.emote), ('p1', Emote.party));

      final tag = roundTripServer(
        const TagMessage(
          phase: TagPhase.tagged,
          itId: 'p2',
          byId: 'p1',
          remainingMs: 1234,
        ),
      );
      expect(
        (tag.phase, tag.itId, tag.byId, tag.remainingMs),
        (TagPhase.tagged, 'p2', 'p1', 1234),
      );

      final ended = roundTripServer(const TagMessage(phase: TagPhase.ended));
      expect((ended.phase, ended.itId), (TagPhase.ended, null));

      expect(roundTripServer(const ErrorMessage('bad')).reason, 'bad');
    });

    test('rejects malformed messages', () {
      for (final raw in [
        '{"t":"joined","player":{"id":1}}',
        '{"t":"tag","phase":"later"}',
      ]) {
        expect(
          () => ServerMessage.decode(raw),
          throwsA(isA<ProtocolException>()),
          reason: raw,
        );
      }
    });
  });

  test('rooms and palette', () {
    expect(Rooms.ids, contains(Rooms.defaultId));
    expect(Rooms.label('plaza-2'), '광장 2');
    expect(Palette.isValid(Palette.colors.first), isTrue);
    expect(Palette.isValid(0xFF000000), isFalse);
    final info = RoomInfo.fromJson(
      const RoomInfo(id: 'plaza-1', count: 30, capacity: 30).toJson(),
    );
    expect(info.isFull, isTrue);
  });
}
