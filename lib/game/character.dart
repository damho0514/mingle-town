import 'dart:math' as math;

import 'package:flame/components.dart';
import 'package:flame/effects.dart';
import 'package:flutter/material.dart';
import 'package:mingle_protocol/mingle_protocol.dart';

/// A player's avatar: painted body with a walk cycle, name tag, chat bubble
/// and emote pop-ups. [position] is where the feet touch the ground.
class Character extends PositionComponent {
  Character({required PlayerState state, this.isSelf = false})
    : name = state.name,
      color = Color(state.color),
      super(
        position: Vector2(state.x, state.y),
        size: Vector2(36, 52),
        anchor: Anchor.bottomCenter,
        priority: state.y.round(),
      );

  static const double speed = 200;

  /// Walk-cycle radians per second.
  static const double _stride = 14;

  final String name;
  final Color color;
  final bool isSelf;

  Vector2? _target;
  ChatBubble? _bubble;
  double _phase = 0;

  /// -1 facing left, 1 facing right.
  double facing = 1;

  bool get isMoving => _target != null;

  late final Paint _body = Paint()..color = color;
  late final Paint _hair = Paint()
    ..color = Color.lerp(color, Colors.black, 0.45)!;
  static final _skin = Paint()..color = const Color(0xFFFFDDB8);
  static final _legs = Paint()..color = const Color(0xFF37474F);
  static final _eyes = Paint()..color = const Color(0xFF263238);
  static final _blush = Paint()..color = const Color(0x55FF8A80);
  static final _shadow = Paint()..color = const Color(0x33000000);
  static final _ring = Paint()
    ..color = Colors.white
    ..style = PaintingStyle.stroke
    ..strokeWidth = 2.5;

  @override
  Future<void> onLoad() async {
    add(
      TextComponent(
        text: name,
        position: Vector2(size.x / 2, size.y + 4),
        anchor: Anchor.topCenter,
        textRenderer: TextPaint(
          style: TextStyle(
            color: isSelf ? const Color(0xFFFFF59D) : Colors.white,
            fontSize: 13,
            fontWeight: FontWeight.w700,
            shadows: const [Shadow(blurRadius: 3)],
          ),
        ),
      ),
    );
  }

  void moveTo(Vector2 target) {
    _target = target.clone();
    final dx = target.x - position.x;
    if (dx.abs() > 1) facing = dx.sign;
  }

  /// Shows [text] above the character for a few seconds.
  void say(String text) {
    _bubble?.removeFromParent();
    add(_bubble = ChatBubble(text)..position = Vector2(size.x / 2, -6));
  }

  /// Pops [emote] above the head; it floats up and disappears.
  void react(Emote emote) {
    add(
      TextComponent(
        text: emojiFor(emote),
        position: Vector2(size.x / 2, -4),
        anchor: Anchor.bottomCenter,
        textRenderer: TextPaint(style: const TextStyle(fontSize: 30)),
        priority: 1,
        children: [
          MoveByEffect(
            Vector2(0, -28),
            EffectController(duration: 1.6, curve: Curves.easeOut),
          ),
          RemoveEffect(delay: 1.8),
        ],
      ),
    );
  }

  static String emojiFor(Emote e) => switch (e) {
    Emote.wave => '👋',
    Emote.heart => '❤️',
    Emote.laugh => '😂',
    Emote.wow => '😮',
    Emote.sad => '😢',
    Emote.party => '🎉',
  };

  @override
  void update(double dt) {
    super.update(dt);
    final target = _target;
    if (target == null) {
      // Ease the legs back to standing.
      _phase = _phase % math.pi;
      _phase = _phase < 0.2 || _phase > math.pi - 0.2
          ? 0
          : _phase + dt * _stride;
      return;
    }

    _phase += dt * _stride;
    final toTarget = target - position;
    final step = speed * dt;
    if (toTarget.length <= step) {
      position.setFrom(target);
      _target = null;
    } else {
      position += toTarget.normalized() * step;
    }
    // Characters lower on screen are drawn in front.
    priority = position.y.round();
  }

  @override
  void render(Canvas canvas) {
    final cx = size.x / 2;
    final feet = size.y - 2;
    final swing = math.sin(_phase);
    final bob = -swing.abs() * 2;

    canvas.drawOval(
      Rect.fromCenter(center: Offset(cx, feet), width: 30, height: 10),
      _shadow,
    );
    if (isSelf) {
      canvas.drawOval(
        Rect.fromCenter(center: Offset(cx, feet), width: 42, height: 15),
        _ring,
      );
    }

    // Legs swing opposite each other.
    for (final (dx, s) in [(-6.0, swing), (6.0, -swing)]) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(cx + dx - 3, feet - 13 + s * 2.5, 6, 11 - s * 2.5),
          const Radius.circular(3),
        ),
        _legs,
      );
    }

    // Body.
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(cx - 12, feet - 30 + bob, 24, 20),
        const Radius.circular(9),
      ),
      _body,
    );

    // Head: face, hair cap, eyes looking where we walk.
    final head = Offset(cx, feet - 40 + bob);
    const r = 13.0;
    canvas
      ..drawCircle(head, r, _skin)
      ..drawArc(
        Rect.fromCircle(center: head.translate(0, -1), radius: r + 1),
        math.pi,
        math.pi,
        true,
        _hair,
      );
    final look = facing * 3;
    for (final ex in [-4.5, 4.5]) {
      canvas.drawCircle(head.translate(ex + look, 3), 1.9, _eyes);
    }
    canvas.drawCircle(head.translate(facing * 8, 7), 2.6, _blush);
  }
}

class ChatBubble extends TextBoxComponent {
  ChatBubble(String text)
    : super(
        text: text,
        anchor: Anchor.bottomCenter,
        priority: 2,
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
