import 'dart:async';
import 'dart:math';

import 'package:mingle_protocol/mingle_protocol.dart';
import 'package:mingle_server/mingle_server.dart';
import 'package:test/test.dart';

class FakeTimer implements Timer {
  FakeTimer(this.delay, this.callback);
  final Duration delay;
  final void Function() callback;
  bool cancelled = false;
  void fire() => callback();
  @override
  void cancel() => cancelled = true;
  @override
  bool get isActive => !cancelled;
  @override
  int get tick => 0;
}

class FakeClient {
  FakeClient(Lobby lobby) {
    session = lobby.connect(inbox.add);
  }
  late final Session session;
  final inbox = <ServerMessage>[];

  String get id => session.player!.id;
  void send(ClientMessage m) => session.handle(m.encode());
  T last<T extends ServerMessage>() => inbox.whereType<T>().last;
  Iterable<T> all<T extends ServerMessage>() => inbox.whereType<T>();
}

void main() {
  late Lobby lobby;
  late DateTime now;
  late List<FakeTimer> timers;

  setUp(() {
    now = DateTime(2026);
    timers = [];
    lobby = Lobby(
      random: Random(1),
      clock: () => now,
      timer: (d, cb) => FakeTimer(d, cb)..also(timers.add),
    );
  });

  FakeClient joined(String name, {String room = Rooms.defaultId}) =>
      FakeClient(lobby)..send(JoinMessage(name, room: room));

  group('joining', () {
    test('welcome lists everyone; others are notified', () {
      final a = joined('alice');
      final b = joined('bob');

      final welcome = b.last<WelcomeMessage>();
      expect(welcome.players.map((p) => p.name), ['alice', 'bob']);
      expect(welcome.selfId, b.id);
      expect(welcome.room, Rooms.defaultId);
      expect(a.last<PlayerJoinedMessage>().player.name, 'bob');
      expect(b.all<PlayerJoinedMessage>(), isEmpty);
    });

    test('rooms are isolated', () {
      final a = joined('alice', room: 'plaza-1');
      final b = joined('bob', room: 'plaza-2');
      expect(a.all<PlayerJoinedMessage>(), isEmpty);
      expect(b.last<WelcomeMessage>().players.single.name, 'bob');

      a.send(const ChatMessage('hi'));
      expect(b.all<PlayerChatMessage>(), isEmpty);
      expect(
        {for (final r in lobby.roomInfo) r.id: r.count},
        {'plaza-1': 1, 'plaza-2': 1, 'plaza-3': 0},
      );
    });

    test('keeps chosen appearance, falls back on invalid colour', () {
      final a = FakeClient(lobby)
        ..send(JoinMessage('a', color: Palette.colors[3], hat: Hat.crown));
      expect(
        (a.session.player!.color, a.session.player!.hat),
        (Palette.colors[3], Hat.crown),
      );

      final b = FakeClient(lobby)
        ..send(const JoinMessage('b', color: 0xFF123456));
      expect(Palette.isValid(b.session.player!.color), isTrue);
    });

    test('spawns on open ground', () {
      for (var i = 0; i < 20; i++) {
        final p = joined('p$i').session.player!;
        expect(WorldMap.instance.isBlocked((x: p.x, y: p.y)), isFalse);
      }
    });

    test('rejects unknown and full rooms', () {
      final x = FakeClient(lobby)..send(const JoinMessage('x', room: 'moon'));
      expect(x.last<ErrorMessage>().reason, 'unknown room');

      for (var i = 0; i < Rooms.capacity; i++) {
        joined('p$i', room: 'plaza-3');
      }
      final late = joined('late', room: 'plaza-3');
      expect(late.last<ErrorMessage>().reason, 'room full');
      expect(late.session.room, isNull);
    });

    test('names are sanitized', () {
      expect(joined('   ').session.player!.name, startsWith('guest-'));
      final b = joined('a  b${'z' * 50}').session.player!.name;
      expect(b, startsWith('a b'));
      expect(b.length, Limits.maxNameLength);
    });

    test('rejects actions before join, double join and garbage', () {
      final a = FakeClient(lobby);
      a.send(const MoveMessage(1, 1));
      expect(a.last<ErrorMessage>().reason, 'join first');
      a.session.handle('garbage');
      expect(a.inbox.last, isA<ErrorMessage>());
      a.session.handle('x' * (Session.maxFrameLength + 1));
      expect(a.last<ErrorMessage>().reason, 'frame too large');

      a.send(const JoinMessage('alice'));
      a.send(const JoinMessage('again'));
      expect(a.last<ErrorMessage>().reason, 'already joined');
      expect(lobby.playerCount, 1);
    });

    test('close removes the player once and notifies others', () {
      final a = joined('alice');
      final b = joined('bob');
      a.session
        ..close()
        ..close();
      expect(b.all<PlayerLeftMessage>().length, 1);
      expect(lobby.playerCount, 1);
      FakeClient(lobby).session.close(); // never joined: harmless
    });
  });

  group('movement', () {
    test('positions are pushed out of obstacles and broadcast to others', () {
      final a = joined('alice');
      final b = joined('bob');
      a.inbox.clear();

      a.send(MoveMessage(WorldMap.center.x, WorldMap.center.y)); // fountain
      final moved = b.last<PlayerMovedMessage>();
      expect(WorldMap.instance.isBlocked((x: moved.x, y: moved.y)), isFalse);
      expect(a.inbox, isEmpty);

      a.send(const MoveMessage(-50, 99999));
      final edge = b.last<PlayerMovedMessage>();
      expect(edge.x, greaterThan(0));
      expect(edge.y, lessThan(Limits.worldHeight));

      // A late joiner sees the latest position.
      final c = joined('carol');
      final seen = c.last<WelcomeMessage>().players.firstWhere(
        (p) => p.name == 'alice',
      );
      expect((seen.x, seen.y), (edge.x, edge.y));
    });

    test('move updates are rate limited per second', () {
      final a = joined('alice');
      final b = joined('bob');
      for (var i = 0; i < MoveRateLimit.perSecond + 10; i++) {
        a.send(MoveMessage(900 + i.toDouble(), 800));
      }
      expect(b.all<PlayerMovedMessage>().length, MoveRateLimit.perSecond);
      now = now.add(const Duration(seconds: 1));
      a.send(const MoveMessage(950, 800));
      expect(b.all<PlayerMovedMessage>().length, MoveRateLimit.perSecond + 1);
    });
  });

  group('social', () {
    test('chat is trimmed, truncated and echoed to everyone', () {
      final a = joined('alice');
      final b = joined('bob');
      a.send(ChatMessage('  ${'x' * 500}  '));
      expect(a.last<PlayerChatMessage>().text.length, Limits.maxChatLength);
      expect(b.last<PlayerChatMessage>().id, a.id);
      final before = b.inbox.length;
      a.send(const ChatMessage('   '));
      expect(b.inbox.length, before);
    });

    test('emotes reach everyone; chat + emotes share a rate limit', () {
      final a = joined('alice');
      final b = joined('bob');
      a.send(const EmoteMessage(Emote.wave));
      expect(b.last<PlayerEmotedMessage>().emote, Emote.wave);

      for (var i = 1; i < SocialRateLimit.burst; i++) {
        a.send(ChatMessage('m$i'));
      }
      a.send(const ChatMessage('too much'));
      expect(a.last<ErrorMessage>().reason, 'slow down');
      expect(
        b.all<PlayerChatMessage>().map((m) => m.text),
        isNot(contains('too much')),
      );

      now = now.add(SocialRateLimit.window);
      a.send(const ChatMessage('ok again'));
      expect(b.last<PlayerChatMessage>().text, 'ok again');
    });
  });

  group('tag', () {
    // Puts two players right next to each other on open ground.
    (FakeClient, FakeClient) twoPlayers() {
      final a = joined('alice');
      final b = joined('bob');
      a.send(const MoveMessage(950, 800));
      b.send(const MoveMessage(1100, 800));
      return (a, b);
    }

    test('needs at least two players and only one round at a time', () {
      final a = joined('alice');
      a.send(const StartTagMessage());
      expect(a.last<ErrorMessage>().reason, 'need more players');

      joined('bob');
      a.send(const StartTagMessage());
      expect(a.last<TagMessage>().phase, TagPhase.started);
      a.send(const StartTagMessage());
      expect(a.last<ErrorMessage>().reason, 'tag already running');
    });

    test('start announces "it" and the time left to everyone', () {
      final (a, b) = twoPlayers();
      a.send(const StartTagMessage());
      final start = b.last<TagMessage>();
      expect(start.phase, TagPhase.started);
      expect([a.id, b.id], contains(start.itId));
      expect(start.remainingMs, TagRules.roundLength.inMilliseconds);
      expect(timers.single.delay, TagRules.roundLength);

      // Late joiners learn about the running round.
      now = now.add(const Duration(seconds: 10));
      final c = joined('carol');
      final tag = c.last<WelcomeMessage>().tag!;
      expect(tag.itId, start.itId);
      expect(tag.remainingMs, 50000);
    });

    test('touching passes "it", with a cooldown against tag-backs', () {
      final (a, b) = twoPlayers();
      a.send(const StartTagMessage());
      final it = a.last<TagMessage>().itId == a.id ? a : b;
      final runner = identical(it, a) ? b : a;

      // Within the head-start cooldown, touching does nothing.
      it.send(const MoveMessage(1080, 800));
      expect(runner.all<TagMessage>().length, 1);

      now = now.add(TagRules.cooldown);
      it.send(const MoveMessage(1085, 800));
      final tagged = runner.last<TagMessage>();
      expect(
        (tagged.phase, tagged.itId, tagged.byId),
        (TagPhase.tagged, runner.id, it.id),
      );

      // Immediate tag-back is blocked by the cooldown...
      runner.send(const MoveMessage(1084, 800));
      expect(it.all<TagMessage>().length, 2);
      // ...but works once it expires.
      now = now.add(TagRules.cooldown);
      runner.send(const MoveMessage(1086, 800));
      expect(it.last<TagMessage>().itId, it.id);
    });

    test('far apart players are not tagged', () {
      final (a, b) = twoPlayers();
      a.send(const StartTagMessage());
      now = now.add(TagRules.cooldown);
      a.send(const MoveMessage(900, 800));
      b.send(const MoveMessage(1200, 800));
      expect(a.all<TagMessage>().length, 1);
    });

    test('timer ends the round; whoever is "it" loses', () {
      final (a, b) = twoPlayers();
      a.send(const StartTagMessage());
      final it = a.last<TagMessage>().itId;
      timers.single.fire();
      for (final c in [a, b]) {
        final end = c.last<TagMessage>();
        expect((end.phase, end.itId), (TagPhase.ended, it));
      }
      a.send(const StartTagMessage()); // can start again
      expect(a.last<TagMessage>().phase, TagPhase.started);
    });

    test('"it" leaving hands the role on, or ends the round', () {
      final a = joined('alice');
      final b = joined('bob');
      final c = joined('carol');
      a.send(const StartTagMessage());
      final itId = a.last<TagMessage>().itId;
      final it = [a, b, c].firstWhere((x) => x.id == itId);
      final rest = [a, b, c].where((x) => !identical(x, it)).toList();

      it.session.close();
      final handoff = rest.first.last<TagMessage>();
      expect(handoff.phase, TagPhase.tagged);
      expect(rest.map((x) => x.id), contains(handoff.itId));

      rest.first.session.close();
      final end = rest.last.last<TagMessage>();
      expect((end.phase, end.itId), (TagPhase.ended, null));
      expect(timers.single.cancelled, isTrue);
    });
  });
}

extension<T> on T {
  T also(void Function(T) f) {
    f(this);
    return this;
  }
}
