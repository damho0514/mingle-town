import 'package:flame/components.dart';
import 'package:flame/effects.dart';
import 'package:flame_test/flame_test.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart' show KeyEventResult;
import 'package:flutter_test/flutter_test.dart';
import 'package:mingle_protocol/mingle_protocol.dart';
import 'package:mingle_town/audio/game_audio.dart';
import 'package:mingle_town/game/character.dart';
import 'package:mingle_town/game/ground.dart';
import 'package:mingle_town/game/mingle_town_game.dart';
import 'package:mingle_town/game/tree.dart';

import 'fake_connection.dart';

const me = PlayerState(id: 'p1', name: 'me', color: 0xFFFF7043, x: 920, y: 800);
const bob = PlayerState(
  id: 'p2',
  name: 'bob',
  color: 0xFF42A5F5,
  x: 700,
  y: 700,
);

void main() {
  late FakeConnection conn;
  late SilentAudio audio;
  late bool chatRequested;

  setUp(() {
    conn = FakeConnection();
    audio = SilentAudio();
    chatRequested = false;
  });

  MingleTownGame create() => MingleTownGame(
    connection: conn,
    join: const JoinMessage('me', room: 'plaza-2', hat: Hat.cap),
    audio: audio,
    onChatRequested: () => chatRequested = true,
  );

  Future<void> welcome(MingleTownGame game, {TagMessage? tag}) async {
    game.handleMessage(
      WelcomeMessage(
        selfId: 'p1',
        room: 'plaza-2',
        players: const [me, bob],
        tag: tag,
      ),
    );
    await game.ready();
  }

  List<MoveMessage> moves() => conn.sent.whereType<MoveMessage>().toList();

  testWithGame('sends the join with the chosen look and room', create, (
    game,
  ) async {
    final join = conn.sent.single as JoinMessage;
    expect((join.name, join.room, join.hat), ('me', 'plaza-2', Hat.cap));
  });

  testWithGame('welcome spawns everyone; only self collides', create, (
    game,
  ) async {
    await welcome(game);
    expect(game.characters.keys, ['p1', 'p2']);
    expect(game.room, 'plaza-2');
    expect(game.self!.isSelf, isTrue);
    expect(game.self!.map, isNotNull);
    expect(game.characters['p2']!.map, isNull);
    expect(game.playerCount.value, 2);
  });

  testWithGame('remote positions glide; own echoes are ignored', create, (
    game,
  ) async {
    await welcome(game);
    game.handleMessage(const PlayerMovedMessage('p2', 720, 700));
    game.handleMessage(const PlayerMovedMessage('p1', 0, 0));
    game.update(0.2);
    expect(game.characters['p2']!.position.x, closeTo(720, 0.01));
    expect(game.self!.position, Vector2(920, 800));
  });

  testWithGame(
    'keyboard moves the player and streams throttled positions',
    create,
    (game) async {
      await welcome(game);
      game.onKeyEvent(
        const KeyDownEvent(
          physicalKey: PhysicalKeyboardKey.keyD,
          logicalKey: LogicalKeyboardKey.keyD,
          timeStamp: Duration.zero,
        ),
        {LogicalKeyboardKey.keyD},
      );
      // 0.5s of frames at 60fps.
      for (var i = 0; i < 30; i++) {
        game.update(1 / 60);
      }
      expect(game.self!.position.x, greaterThan(920 + Limits.walkSpeed * 0.4));
      expect(
        moves().length,
        inInclusiveRange(4, 6),
        reason: 'about one update per 100ms',
      );

      game.onKeyEvent(
        const KeyUpEvent(
          physicalKey: PhysicalKeyboardKey.keyD,
          logicalKey: LogicalKeyboardKey.keyD,
          timeStamp: Duration.zero,
        ),
        {},
      );
      for (var i = 0; i < 30; i++) {
        game.update(1 / 60);
      }
      expect(
        moves().last.x,
        game.self!.position.x,
        reason: 'final resting position is sent',
      );
      final count = moves().length;
      game.update(1);
      expect(
        moves().length,
        count,
        reason: 'nothing sent while standing still',
      );
    },
  );

  testWithGame('Enter asks the UI to open chat', create, (game) async {
    final result = game.onKeyEvent(
      const KeyDownEvent(
        physicalKey: PhysicalKeyboardKey.enter,
        logicalKey: LogicalKeyboardKey.enter,
        timeStamp: Duration.zero,
      ),
      {LogicalKeyboardKey.enter},
    );
    expect(chatRequested, isTrue);
    expect(result, KeyEventResult.handled);
  });

  testWithGame('walkTo targets walkable ground and plays footsteps', create, (
    game,
  ) async {
    await welcome(game);
    game.walkTo(Vector2(WorldMap.center.x, WorldMap.center.y)); // fountain
    for (var i = 0; i < 60; i++) {
      game.update(1 / 60);
    }
    final p = game.self!.position;
    expect(WorldMap.instance.isBlocked((x: p.x, y: p.y)), isFalse);
    expect(audio.played, contains(Sfx.step));
  });

  testWithGame(
    'join, leave, chat and emotes update the world with sounds',
    create,
    (game) async {
      await welcome(game);
      game.handleMessage(
        const PlayerJoinedMessage(
          PlayerState(id: 'p3', name: 'carol', color: 0xFF000000, x: 1, y: 1),
        ),
      );
      await game.ready();
      expect(game.characters, contains('p3'));

      game.handleMessage(const PlayerChatMessage('p2', '안녕'));
      game.handleMessage(const PlayerEmotedMessage('p2', Emote.party));
      await game.ready();
      final bobChar = game.characters['p2']!;
      expect(bobChar.children.whereType<ChatBubble>(), hasLength(1));
      final pop = bobChar.children.whereType<TextComponent>().where(
        (t) => t.text == Character.emojiFor(Emote.party),
      );
      expect(pop.single.children.whereType<RemoveEffect>(), hasLength(1));
      expect(audio.played, containsAll([Sfx.join, Sfx.pop, Sfx.emote]));

      game.handleMessage(const PlayerLeftMessage('p2'));
      await game.ready();
      expect(game.characters, isNot(contains('p2')));
      expect(game.playerCount.value, 2);
    },
  );

  testWithGame('tag round: status, markers, notices and sounds', create, (
    game,
  ) async {
    await welcome(game);
    final notices = <String>[];
    game.notices.listen(notices.add);

    game.handleMessage(
      const TagMessage(phase: TagPhase.started, itId: 'p2', remainingMs: 60000),
    );
    await game.ready();
    expect(game.tag.value!.itName, 'bob');
    expect(game.characters['p2']!.isIt, isTrue);

    game.handleMessage(
      const TagMessage(
        phase: TagPhase.tagged,
        itId: 'p1',
        byId: 'p2',
        remainingMs: 30000,
      ),
    );
    await game.ready();
    expect(game.self!.isIt, isTrue);
    expect(game.characters['p2']!.isIt, isFalse);

    game.handleMessage(const TagMessage(phase: TagPhase.ended, itId: 'p1'));
    await game.ready();
    await Future<void>.delayed(Duration.zero);
    expect(game.tag.value, isNull);
    expect(game.self!.isIt, isFalse);
    expect(notices, [
      '술래잡기 시작! 술래는 bob님',
      'bob님에게 잡혔어요! 이제 내가 술래',
      '시간 종료! 내가 마지막 술래였어요 😢',
    ]);
    expect(
      audio.played,
      containsAllInOrder([Sfx.tagStart, Sfx.tagged, Sfx.tagEnd]),
    );
  });

  testWithGame('late joiners see a running round silently', create, (
    game,
  ) async {
    await welcome(
      game,
      tag: const TagMessage(
        phase: TagPhase.started,
        itId: 'p2',
        remainingMs: 5000,
      ),
    );
    expect(game.tag.value!.itId, 'p2');
    expect(game.characters['p2']!.isIt, isTrue);
    expect(audio.played, isNot(contains(Sfx.tagStart)));
  });

  testWithGame('server errors become friendly notices', create, (game) async {
    final notices = <String>[];
    game.notices.listen(notices.add);
    game.handleMessage(const ErrorMessage('need more players'));
    game.handleMessage(const ErrorMessage('something internal'));
    await Future<void>.delayed(Duration.zero);
    expect(notices, ['술래잡기는 2명 이상 있어야 해요']);
  });

  testWithGame('outgoing actions', create, (game) async {
    game.sendChat('   ');
    game.sendChat('  hi ');
    game.sendEmote(Emote.wave);
    game.startTag();
    expect(conn.sent.whereType<ChatMessage>().map((m) => m.text), ['hi']);
    expect((conn.sent.whereType<EmoteMessage>().single).emote, Emote.wave);
    expect(conn.sent.last, isA<StartTagMessage>());
  });

  test('camera centres on the player but never shows outside the world', () {
    final view = Vector2(400, 800);
    expect(
      MingleTownGame.cameraTarget(Vector2(800, 820), view),
      Vector2(800, 800),
    );
    expect(
      MingleTownGame.cameraTarget(Vector2(10, 10), view),
      Vector2(200, 400),
    );
    expect(
      MingleTownGame.cameraTarget(Vector2.all(5000), Vector2.all(5000)),
      Vector2(Limits.worldWidth / 2, Limits.worldHeight / 2),
    );
  });

  testWithGame('camera tracks the local player', create, (game) async {
    await welcome(game);
    game.update(0);
    expect(
      game.camera.viewfinder.position,
      MingleTownGame.cameraTarget(
        game.self!.position,
        game.camera.viewport.virtualSize,
      ),
    );
  });

  testWithGame('scenery is loaded into the world', create, (game) async {
    await game.ready();
    // Ground must sort below everything (and stay negative on the web too).
    expect(Ground.layer, isNegative);
    final ground = game.world.children.whereType<Ground>().single;
    expect(game.world.children.first, ground);
    expect(
      game.world.children.whereType<Tree>().length,
      WorldMap.instance.trees.length,
    );
  });

  testWithGame(
    'touch devices get a joystick',
    () => MingleTownGame(
      connection: conn,
      join: const JoinMessage('me'),
      touchControls: true,
    ),
    (game) async {
      await game.ready();
      expect(game.joystick, isNotNull);
      expect(game.joystick!.isMounted, isTrue);
    },
  );
}
