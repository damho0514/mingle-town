import 'dart:ui';

import 'package:flame/components.dart';
import 'package:mingle_protocol/mingle_protocol.dart';

/// Static scenery shared by every client.
///
/// Generated from a fixed seed with a portable PRNG so the web build and the
/// mobile builds lay out identical worlds.
class WorldLayout {
  WorldLayout._(this.trees, this.flowers);

  static final WorldLayout instance = WorldLayout._generate();

  static final Vector2 center = Vector2(
    Limits.worldWidth / 2,
    Limits.worldHeight / 2,
  );
  static const double plazaRadius = 180;
  static const double fountainRadius = 50;
  static const double pathHalfWidth = 40;
  static final Vector2 pondCenter = Vector2(1230, 380);
  static final Vector2 pondRadii = Vector2(170, 110);

  final List<Vector2> trees;
  final List<(Vector2, Color)> flowers;

  static const _flowerColors = [
    Color(0xFFFFFFFF),
    Color(0xFFFF8A80),
    Color(0xFFFFD54F),
    Color(0xFFB39DDB),
    Color(0xFFF48FB1),
  ];

  static bool isOpenGround(Vector2 p, {double margin = 0}) {
    if (p.distanceTo(center) < plazaRadius + margin) return false;
    if ((p.x - center.x).abs() < pathHalfWidth + margin ||
        (p.y - center.y).abs() < pathHalfWidth + margin) {
      return false;
    }
    final dx = (p.x - pondCenter.x) / (pondRadii.x + margin);
    final dy = (p.y - pondCenter.y) / (pondRadii.y + margin);
    return dx * dx + dy * dy > 1;
  }

  static WorldLayout _generate() {
    final rng = _ParkMiller(20261105);
    const w = Limits.worldWidth, h = Limits.worldHeight;
    final trees = <Vector2>[];

    // A loose hedge of trees around the border.
    for (var t = 60.0; t < w - 30; t += 95) {
      for (final p in [
        Vector2(t, 50),
        Vector2(t, h - 20),
        Vector2(30, t),
        Vector2(w - 30, t),
      ]) {
        p.add(Vector2(rng.range(-15, 15), rng.range(-10, 10)));
        if (isOpenGround(p, margin: 20)) trees.add(p);
      }
    }

    // Scattered groves inside, kept clear of paths, plaza, pond and each other.
    for (var i = 0; i < 400 && trees.length < 110; i++) {
      final p = Vector2(rng.range(120, w - 120), rng.range(140, h - 100));
      if (!isOpenGround(p, margin: 60)) continue;
      if (trees.any((t) => t.distanceTo(p) < 85)) continue;
      trees.add(p);
    }

    final flowers = <(Vector2, Color)>[];
    for (var i = 0; i < 1000 && flowers.length < 160; i++) {
      final p = Vector2(rng.range(20, w - 20), rng.range(20, h - 20));
      if (!isOpenGround(p, margin: 8)) continue;
      if (trees.any((t) => t.distanceTo(p) < 30)) continue;
      flowers.add((p, _flowerColors[rng.nextInt(_flowerColors.length)]));
    }
    return WorldLayout._(trees, flowers);
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
