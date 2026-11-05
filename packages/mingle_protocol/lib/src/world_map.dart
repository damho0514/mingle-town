import 'dart:math' as math;

import 'limits.dart';

/// A 2D point in world units.
typedef WorldPoint = ({double x, double y});

/// Scenery placement and walkability of the world, shared by every client
/// and the server.
///
/// Generated from a fixed seed with a portable PRNG, so the web build, the
/// mobile builds and the server all get exactly the same map.
class WorldMap {
  WorldMap._(this.trees, this.flowers);

  static final WorldMap instance = WorldMap._generate();

  static const WorldPoint center = (
    x: Limits.worldWidth / 2,
    y: Limits.worldHeight / 2,
  );
  static const double plazaRadius = 180;
  static const double fountainRadius = 50;
  static const double pathHalfWidth = 40;
  static const WorldPoint pondCenter = (x: 1230, y: 380);
  static const WorldPoint pondRadii = (x: 170, y: 110);

  /// Solid part of a tree around its base.
  static const double trunkRadius = 16;

  /// Tree bases (bottom-centre of the sprite).
  final List<WorldPoint> trees;

  /// Flower positions with an ARGB colour.
  final List<(WorldPoint, int)> flowers;

  static const _flowerColors = [
    0xFFFFFFFF,
    0xFFFF8A80,
    0xFFFFD54F,
    0xFFB39DDB,
    0xFFF48FB1,
  ];

  static double _dist(WorldPoint a, WorldPoint b) =>
      math.sqrt((a.x - b.x) * (a.x - b.x) + (a.y - b.y) * (a.y - b.y));

  /// True where scenery may be placed: not on paths, plaza or pond.
  static bool isOpenGround(WorldPoint p, {double margin = 0}) {
    if (_dist(p, center) < plazaRadius + margin) return false;
    if ((p.x - center.x).abs() < pathHalfWidth + margin ||
        (p.y - center.y).abs() < pathHalfWidth + margin) {
      return false;
    }
    final dx = (p.x - pondCenter.x) / (pondRadii.x + margin);
    final dy = (p.y - pondCenter.y) / (pondRadii.y + margin);
    return dx * dx + dy * dy > 1;
  }

  // ---------------------------------------------------------------------------
  // Collision
  // ---------------------------------------------------------------------------

  /// Whether a character standing at [p] overlaps something solid.
  bool isBlocked(WorldPoint p, {double radius = Limits.playerRadius}) {
    const r = Limits.playerRadius;
    if (p.x < r ||
        p.y < r ||
        p.x > Limits.worldWidth - r ||
        p.y > Limits.worldHeight - r) {
      return true;
    }
    if (_dist(p, center) < fountainRadius + radius) return true;
    if (_insidePond(p, radius)) return true;
    for (final t in trees) {
      if (_dist(p, t) < trunkRadius + radius) return true;
    }
    return false;
  }

  /// Nearest walkable spot to [p]: pushes a character out of anything solid
  /// and back inside the world. Applying it after every step makes movement
  /// slide along obstacles instead of stopping dead.
  WorldPoint resolve(WorldPoint p) {
    const r = Limits.playerRadius;
    var x = p.x, y = p.y;
    for (var i = 0; i < 4; i++) {
      var moved = false;

      (x, y, moved) = _pushOutOfCircle(x, y, center, fountainRadius + r, moved);
      for (final t in _treesNear(x, y)) {
        (x, y, moved) = _pushOutOfCircle(x, y, t, trunkRadius + r, moved);
      }

      // Pond: push out radially in the ellipse's normalised space.
      final rx = pondRadii.x + r, ry = pondRadii.y + r;
      final u = (x - pondCenter.x) / rx, v = (y - pondCenter.y) / ry;
      final len = math.sqrt(u * u + v * v);
      if (len < 1) {
        final nu = len == 0 ? 1.0 : u / len, nv = len == 0 ? 0.0 : v / len;
        x = pondCenter.x + nu * rx * 1.001;
        y = pondCenter.y + nv * ry * 1.001;
        moved = true;
      }

      x = x.clamp(r, Limits.worldWidth - r);
      y = y.clamp(r, Limits.worldHeight - r);
      if (!moved) break;
    }
    return (x: x, y: y);
  }

  static (double, double, bool) _pushOutOfCircle(
    double x,
    double y,
    WorldPoint c,
    double minDist,
    bool moved,
  ) {
    final dx = x - c.x, dy = y - c.y;
    final d = math.sqrt(dx * dx + dy * dy);
    if (d >= minDist) return (x, y, moved);
    if (d == 0) return (c.x + minDist, c.y, true);
    final k = minDist * 1.001 / d;
    return (c.x + dx * k, c.y + dy * k, true);
  }

  Iterable<WorldPoint> _treesNear(double x, double y) {
    const reach = trunkRadius + Limits.playerRadius + 1;
    return trees.where(
      (t) => (t.x - x).abs() < reach && (t.y - y).abs() < reach,
    );
  }

  static bool _insidePond(WorldPoint p, double radius) {
    final dx = (p.x - pondCenter.x) / (pondRadii.x + radius);
    final dy = (p.y - pondCenter.y) / (pondRadii.y + radius);
    return dx * dx + dy * dy < 1;
  }

  // ---------------------------------------------------------------------------
  // Generation
  // ---------------------------------------------------------------------------

  static WorldMap _generate() {
    final rng = _ParkMiller(20261105);
    const w = Limits.worldWidth, h = Limits.worldHeight;
    final trees = <WorldPoint>[];

    // A loose hedge of trees around the border.
    for (var t = 60.0; t < w - 30; t += 95) {
      for (final base in [
        (x: t, y: 50.0),
        (x: t, y: h - 20),
        (x: 30.0, y: t),
        (x: w - 30, y: t),
      ]) {
        final p = (
          x: base.x + rng.range(-15, 15),
          y: base.y + rng.range(-10, 10),
        );
        if (isOpenGround(p, margin: 20)) trees.add(p);
      }
    }

    // Scattered groves inside, kept clear of paths, plaza, pond and each other.
    for (var i = 0; i < 400 && trees.length < 110; i++) {
      final p = (x: rng.range(120, w - 120), y: rng.range(140, h - 100));
      if (!isOpenGround(p, margin: 60)) continue;
      if (trees.any((t) => _dist(t, p) < 85)) continue;
      trees.add(p);
    }

    final flowers = <(WorldPoint, int)>[];
    for (var i = 0; i < 1000 && flowers.length < 160; i++) {
      final p = (x: rng.range(20, w - 20), y: rng.range(20, h - 20));
      if (!isOpenGround(p, margin: 8)) continue;
      if (trees.any((t) => _dist(t, p) < 30)) continue;
      flowers.add((p, _flowerColors[rng.nextInt(_flowerColors.length)]));
    }
    return WorldMap._(List.unmodifiable(trees), List.unmodifiable(flowers));
  }
}

/// Lehmer / Park–Miller PRNG. Products stay below 2^53, so results are
/// identical on the Dart VM and when compiled to JavaScript.
class _ParkMiller {
  _ParkMiller(int seed) : _state = seed % _m;
  static const _m = 2147483647;
  int _state;

  double next() {
    _state = (_state * 48271) % _m;
    return _state / _m;
  }

  double range(double min, double max) => min + next() * (max - min);
  int nextInt(int max) => (next() * max).floor() % max;
}
