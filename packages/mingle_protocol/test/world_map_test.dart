import 'dart:math' show pow, sqrt;

import 'package:mingle_protocol/mingle_protocol.dart';
import 'package:test/test.dart';

double dist(WorldPoint a, WorldPoint b) => sqrt(pow(a.x - b.x, 2) + pow(a.y - b.y, 2));

void main() {
  final map = WorldMap.instance;

  test('generates scenery inside the world, off paths, plaza and pond', () {
    expect(map.trees.length, greaterThan(40));
    expect(map.flowers.length, greaterThan(50));
    for (final t in map.trees) {
      expect(WorldMap.isOpenGround(t), isTrue, reason: '$t');
      expect(t.x, inInclusiveRange(0, Limits.worldWidth));
      expect(t.y, inInclusiveRange(0, Limits.worldHeight));
    }
  });

  test('layout is stable (same on every platform and the server)', () {
    // Pin a few values so an accidental change to the generator is noticed:
    // clients and server must agree on where trees are.
    expect(map.trees.length, 110);
    expect(map.trees.first.x, closeTo(57.83, 0.01));
    expect(map.trees.first.y, closeTo(47.61, 0.01));
  });

  test('blocked: fountain, pond, trees and world edges', () {
    expect(map.isBlocked(WorldMap.center), isTrue);
    expect(map.isBlocked(WorldMap.pondCenter), isTrue);
    expect(map.isBlocked(map.trees[10]), isTrue);
    expect(map.isBlocked((x: 2, y: 800)), isTrue);
    expect(
      map.isBlocked((x: WorldMap.center.x + 120, y: WorldMap.center.y)),
      isFalse,
    );
  });

  test('resolve pushes out of obstacles and leaves open ground alone', () {
    const open = (x: 920.0, y: 800.0);
    expect(map.resolve(open), open);

    for (final p in [
      WorldMap.center,
      (x: WorldMap.center.x + 30, y: WorldMap.center.y + 5),
      WorldMap.pondCenter,
      (x: WorldMap.pondCenter.x + 100, y: WorldMap.pondCenter.y + 20),
      map.trees[20],
      (x: map.trees[30].x + 3, y: map.trees[30].y - 2),
      (x: -50.0, y: 9999.0),
    ]) {
      final r = map.resolve(p);
      expect(map.isBlocked(r), isFalse, reason: '$p -> $r');
    }
  });

  test('walking into a tree slides around it instead of stopping', () {
    final tree = map.trees.firstWhere(
      (t) =>
          !map.isBlocked((x: t.x - 60, y: t.y + 4)) &&
          !map.isBlocked((x: t.x + 60, y: t.y + 4)),
    );
    var p = (x: tree.x - 60, y: tree.y + 4);
    // Walk straight right for 1 second in small steps.
    for (var i = 0; i < 60; i++) {
      p = map.resolve((x: p.x + Limits.walkSpeed / 60, y: p.y));
      expect(map.isBlocked(p), isFalse);
    }
    expect(p.x, greaterThan(tree.x + 20), reason: 'got past the tree');
  });
}
