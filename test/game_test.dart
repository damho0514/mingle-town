import 'package:flame/components.dart';
import 'package:flame/effects.dart';
import 'package:flame_test/flame_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mingle_protocol/mingle_protocol.dart';
import 'package:mingle_town/game/character.dart';
import 'package:mingle_town/game/mingle_town_game.dart';
import 'package:mingle_town/game/tree.dart';

import 'fake_connection.dart';

const me = PlayerState(id: 'p1', name: 'me', color: 0xFFFF7043, x: 800, y: 800);
const bob = PlayerState(
  id: 'p2',
  name: 'bob',
  color: 0xFF42A5F5,
  x: 700,
  y: 700,
);

void main() {
  late FakeConnection conn;
  setUp(() => conn = FakeConnection());

  MingleTownGame create() => MingleTownGame(connection: conn, playerName: 'me');

  Future<void> welcome(MingleTownGame game) async {
    game.handleMessage(const WelcomeMessage(selfId: 'p1', players: [me, bob]));
    await game.ready();
  }

  testWithGame('sends join on load', create, (game) async {
    expect(conn.sent.single, isA<JoinMessage>());
    expect((conn.sent.single as JoinMessage).name, 'me');
  });

  testWithGame('welcome spawns everyone and marks self', create, (game) async {
    await welcome(game);
    expect(game.characters.keys, ['p1', 'p2']);
    expect(game.self!.isSelf, isTrue);
    expect(game.characters['p2']!.isSelf, isFalse);
    expect(game.world.children.whereType<Character>().length, 2);
    expect(game.playerCount.value, 2);
  });

  testWithGame('remote moves animate, own echoes are ignored', create, (
    game,
  ) async {
    await welcome(game);
    game.handleMessage(const PlayerMovedMessage('p2', 900, 700));
    game.handleMessage(const PlayerMovedMessage('p1', 0, 0));
    game.update(0.5);
    expect(game.characters['p2']!.position.x, closeTo(800, 0.001));
    expect(game.self!.position, Vector2(800, 800));
  });

  testWithGame('walkTo moves locally, clamps and notifies server', create, (
    game,
  ) async {
    await welcome(game);
    game.walkTo(Vector2(-10, 5000));
    final move = conn.sent.last as MoveMessage;
    expect((move.x, move.y), (0.0, Limits.worldHeight));
    expect(game.self!.isMoving, isTrue);
  });

  testWithGame('join, leave and chat update the world', create, (game) async {
    await welcome(game);
    game.handleMessage(
      const PlayerJoinedMessage(
        PlayerState(id: 'p3', name: 'carol', color: 0xFF000000, x: 1, y: 1),
      ),
    );
    await game.ready();
    expect(game.characters, contains('p3'));

    game.handleMessage(const PlayerChatMessage('p2', '안녕'));
    await game.ready();
    expect(
      game.characters['p2']!.children.whereType<ChatBubble>(),
      hasLength(1),
    );

    game.handleMessage(const PlayerLeftMessage('p2'));
    await game.ready();
    expect(game.characters, isNot(contains('p2')));
    expect(game.world.children.whereType<Character>().length, 2);
    expect(game.playerCount.value, 2);
  });

  testWithGame('emotes pop up above the character and send to server', create, (
    game,
  ) async {
    await welcome(game);
    game.handleMessage(const PlayerEmotedMessage('p2', Emote.party));
    await game.ready();
    final pops = game.characters['p2']!.children
        .whereType<TextComponent>()
        .where((t) => t.text == Character.emojiFor(Emote.party));
    expect(pops, hasLength(1));
    expect(pops.single.children.whereType<RemoveEffect>(), hasLength(1));

    game.sendEmote(Emote.wave);
    expect((conn.sent.last as EmoteMessage).emote, Emote.wave);
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
      MingleTownGame.cameraTarget(
        Vector2(Limits.worldWidth, Limits.worldHeight),
        view,
      ),
      Vector2(Limits.worldWidth - 200, Limits.worldHeight - 400),
    );
    // A view larger than the world just centres it.
    expect(
      MingleTownGame.cameraTarget(Vector2(10, 10), Vector2.all(5000)),
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
    expect(game.world.children.whereType<Tree>(), isNotEmpty);
  });

  testWithGame('sendChat trims and skips blanks', create, (game) async {
    game.sendChat('   ');
    game.sendChat('  hi ');
    expect(conn.sent.whereType<ChatMessage>().map((m) => m.text), ['hi']);
  });
}
