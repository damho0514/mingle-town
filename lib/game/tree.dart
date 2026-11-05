import 'dart:ui';

import 'package:flame/components.dart';
import 'package:mingle_protocol/mingle_protocol.dart';

/// A tree whose base sits at [position]; depth-sorted with characters.
class Tree extends PositionComponent {
  Tree(WorldPoint base)
    : super(
        position: Vector2(base.x, base.y),
        size: Vector2(64, 90),
        anchor: Anchor.bottomCenter,
        priority: base.y.round(),
      );

  static final _shadow = Paint()..color = const Color(0x33000000);
  static final _trunk = Paint()..color = const Color(0xFF795548);
  static final _leavesDark = Paint()..color = const Color(0xFF2E7D32);
  static final _leaves = Paint()..color = const Color(0xFF43A047);
  static final _leavesLight = Paint()..color = const Color(0xFF66BB6A);

  @override
  void render(Canvas canvas) {
    final w = size.x, h = size.y;
    canvas
      ..drawOval(
        Rect.fromCenter(center: Offset(w / 2, h - 3), width: 50, height: 14),
        _shadow,
      )
      ..drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(w / 2 - 6, h - 32, 12, 30),
          const Radius.circular(3),
        ),
        _trunk,
      )
      ..drawCircle(Offset(w / 2, h - 50), 28, _leavesDark)
      ..drawCircle(Offset(w / 2 - 12, h - 56), 18, _leaves)
      ..drawCircle(Offset(w / 2 + 12, h - 58), 18, _leaves)
      ..drawCircle(Offset(w / 2, h - 70), 18, _leaves)
      ..drawCircle(Offset(w / 2 - 6, h - 72), 8, _leavesLight);
  }
}
