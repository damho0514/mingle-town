import 'package:flame/components.dart';
import 'package:flutter/material.dart';
import 'package:mingle_protocol/mingle_protocol.dart';

/// A player's avatar: body, name tag and transient chat bubble.
///
/// Walks toward the latest target at a constant [speed].
class Character extends PositionComponent {
  Character({required PlayerState state, this.isSelf = false})
    : name = state.name,
      color = Color(state.color),
      super(
        position: Vector2(state.x, state.y),
        size: Vector2.all(radius * 2),
        anchor: Anchor.center,
      );

  static const double radius = 20;
  static const double speed = 200;

  final String name;
  final Color color;
  final bool isSelf;

  Vector2? _target;
  ChatBubble? _bubble;

  bool get isMoving => _target != null;

  @override
  Future<void> onLoad() async {
    if (isSelf) {
      add(
        CircleComponent(
          radius: radius + 4,
          position: size / 2,
          anchor: Anchor.center,
          paint: Paint()
            ..color = Colors.white
            ..style = PaintingStyle.stroke
            ..strokeWidth = 3,
        ),
      );
    }
    add(
      CircleComponent(
        radius: radius,
        position: size / 2,
        anchor: Anchor.center,
        paint: Paint()..color = color,
      ),
    );
    add(
      TextComponent(
        text: name,
        position: Vector2(size.x / 2, size.y + 4),
        anchor: Anchor.topCenter,
        textRenderer: TextPaint(
          style: const TextStyle(
            color: Colors.white,
            fontSize: 13,
            fontWeight: FontWeight.w600,
            shadows: [Shadow(blurRadius: 3)],
          ),
        ),
      ),
    );
  }

  void moveTo(Vector2 target) => _target = target.clone();

  /// Shows [text] above the character for a few seconds.
  void say(String text) {
    _bubble?.removeFromParent();
    add(_bubble = ChatBubble(text)..position = Vector2(size.x / 2, -6));
  }

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
    // Draw characters lower on screen in front of those above them.
    priority = position.y.round();
  }
}

class ChatBubble extends TextBoxComponent {
  ChatBubble(String text)
    : super(
        text: text,
        anchor: Anchor.bottomCenter,
        textRenderer: TextPaint(
          style: const TextStyle(color: Colors.black87, fontSize: 13),
        ),
        boxConfig: const TextBoxConfig(
          maxWidth: 180,
          growingBox: true,
          dismissDelay: 4,
          margins: EdgeInsets.symmetric(horizontal: 8, vertical: 5),
        ),
      );

  static final _background = Paint()..color = Colors.white;

  @override
  void drawBackground(Canvas c) {
    c.drawRRect(
      RRect.fromRectAndRadius(size.toRect(), const Radius.circular(10)),
      _background,
    );
  }
}
