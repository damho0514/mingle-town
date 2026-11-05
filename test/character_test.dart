import 'package:flame/components.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mingle_protocol/mingle_protocol.dart';
import 'package:mingle_town/game/character.dart';

Character at(double x, double y, {WorldMap? map}) => Character(
  state: PlayerState(id: 'p1', name: 'a', color: 0xFF000000, x: x, y: y),
  map: map,
);

void main() {
  test('walks toward a target at walking speed and stops on arrival', () {
    final c = at(900, 800);
    c.moveTo(Vector2(1000, 800));
    c.update(0.25);
    expect(c.position.x, closeTo(900 + Limits.walkSpeed * 0.25, 0.001));
    expect(c.walking, isTrue);
    c.update(1);
    expect(c.position, Vector2(1000, 800));
    expect(c.isMoving, isFalse);
    c.update(0.1);
    expect(c.walking, isFalse);
  });

  test('input direction moves the character and cancels tap targets', () {
    final c = at(900, 800);
    c.moveTo(Vector2(900, 1000));
    c.input.setValues(1, 0);
    c.update(0.5);
    expect(c.position.x, closeTo(900 + Limits.walkSpeed * 0.5, 0.001));
    expect(c.position.y, 800);
    c.input.setZero();
    c.update(0.5);
    expect(c.position.y, 800, reason: 'tap target was cancelled');
  });

  test('collides with the world: cannot walk into the fountain', () {
    final map = WorldMap.instance;
    final c = at(WorldMap.center.x + 120, WorldMap.center.y, map: map);
    c.input.setValues(-1, 0);
    for (var i = 0; i < 60; i++) {
      c.update(1 / 60);
      expect(map.isBlocked((x: c.position.x, y: c.position.y)), isFalse);
    }
    expect(
      c.position.distanceTo(Vector2(WorldMap.center.x, WorldMap.center.y)),
      greaterThanOrEqualTo(
        WorldMap.fountainRadius + Limits.playerRadius - 0.01,
      ),
    );
  });

  test('gives up on a tap target it cannot reach', () {
    final c = at(
      WorldMap.center.x + 120,
      WorldMap.center.y,
      map: WorldMap.instance,
    );
    // Aim straight at the fountain's centre: can't get there.
    c.moveTo(Vector2(WorldMap.center.x, WorldMap.center.y));
    for (var i = 0; i < 120; i++) {
      c.update(1 / 60);
    }
    expect(c.isMoving, isFalse);
  });

  test('remote sync glides when close and snaps when far', () {
    final c = at(900, 800);
    c.syncTo(Vector2(920, 800));
    expect(c.isMoving, isTrue);
    c.update(0.12);
    expect(c.position.x, closeTo(920, 0.01));

    c.syncTo(Vector2(1500, 1500));
    expect(c.position, Vector2(1500, 1500));
    expect(c.isMoving, isFalse);
  });

  test('faces the direction it walks', () {
    final c = at(50, 0);
    c.moveTo(Vector2(0, 0));
    expect(c.facing, -1);
    c.moveTo(Vector2(100, 0));
    expect(c.facing, 1);
    c.moveTo(Vector2(50, 300)); // straight down keeps the last facing
    expect(c.facing, 1);
  });

  test('every emote has an emoji', () {
    for (final e in Emote.values) {
      expect(Character.emojiFor(e), isNotEmpty);
    }
  });
}
