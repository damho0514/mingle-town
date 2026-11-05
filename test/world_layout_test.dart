import 'package:flame/components.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mingle_protocol/mingle_protocol.dart';
import 'package:mingle_town/game/world_layout.dart';

void main() {
  final layout = WorldLayout.instance;

  test('generates scenery inside the world', () {
    expect(layout.trees.length, greaterThan(40));
    expect(layout.flowers.length, greaterThan(50));
    for (final t in layout.trees) {
      expect(t.x, inInclusiveRange(0, Limits.worldWidth));
      expect(t.y, inInclusiveRange(0, Limits.worldHeight));
    }
  });

  test('keeps paths, plaza and pond clear of trees', () {
    for (final t in layout.trees) {
      expect(WorldLayout.isOpenGround(t), isTrue, reason: '$t');
    }
    expect(WorldLayout.isOpenGround(WorldLayout.center), isFalse);
    expect(WorldLayout.isOpenGround(WorldLayout.pondCenter), isFalse);
    expect(
      WorldLayout.isOpenGround(Vector2(100, WorldLayout.center.y)),
      isFalse,
    );
  });

  test('server spawn ring lands on the plaza, off the fountain', () {
    for (final d in [90.0, 160.0]) {
      final p = WorldLayout.center + Vector2(d, 0);
      expect(
        p.distanceTo(WorldLayout.center),
        inExclusiveRange(WorldLayout.fountainRadius, WorldLayout.plazaRadius),
      );
    }
  });
}
