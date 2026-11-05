import 'package:flame/components.dart';
import 'package:flutter/material.dart';

/// Local player's character. Moves toward a target at constant speed.
class Player extends CircleComponent {
  Player({super.position})
      : super(
          radius: 20,
          anchor: Anchor.center,
          paint: Paint()..color = const Color(0xFFFF7043),
        );

  static const double speed = 200;
  Vector2? _target;

  void moveTo(Vector2 target) => _target = target.clone();

  @override
  void update(double dt) {
    super.update(dt);
    final target = _target;
    if (target == null) return;

    final toTarget = target - position;
    final step = speed * dt;
    if (toTarget.length <= step) {
      position.setFrom(target);
      _target = null;
    } else {
      position += toTarget.normalized() * step;
    }
  }
}
