import 'package:flame/components.dart';
import 'package:flame/events.dart';
import 'package:flutter/material.dart';
import 'package:mingle_protocol/mingle_protocol.dart';

/// The walkable floor. Reports taps in world coordinates.
class Ground extends RectangleComponent with TapCallbacks {
  Ground({required this.onTap})
    : super(
        size: Vector2(Limits.worldWidth, Limits.worldHeight),
        paint: Paint()..color = const Color(0xFF8BC34A),
        priority: -1 << 20,
      );

  final void Function(Vector2 worldPosition) onTap;

  static const double _cell = 100;
  static final _gridPaint = Paint()
    ..color = const Color(0x22000000)
    ..strokeWidth = 1;

  @override
  void render(Canvas canvas) {
    super.render(canvas);
    for (var x = _cell; x < size.x; x += _cell) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.y), _gridPaint);
    }
    for (var y = _cell; y < size.y; y += _cell) {
      canvas.drawLine(Offset(0, y), Offset(size.x, y), _gridPaint);
    }
  }

  @override
  void onTapUp(TapUpEvent event) => onTap(event.localPosition);
}
