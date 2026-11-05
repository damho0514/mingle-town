import 'dart:math' as math;

import 'package:flame/components.dart';
import 'package:flame/effects.dart';
import 'package:flutter/material.dart';
import 'package:mingle_protocol/mingle_protocol.dart';

import 'avatar_painter.dart';

/// A player's avatar: painted body with a walk cycle, name tag, chat bubble
/// and emote pop-ups. [position] is where the feet touch the ground.
///
/// The local player is driven by [input] (keyboard / joystick) or [moveTo]
/// (tap) and collides with the [map]. Remote players follow network updates
/// via [syncTo].
class Character extends PositionComponent {
  Character({required PlayerState state, this.isSelf = false, this.map})
    : name = state.name,
      avatar = AvatarPainter(color: Color(state.color), hat: state.hat),
      super(
        position: Vector2(state.x, state.y),
        size: Vector2(AvatarPainter.size.width, AvatarPainter.size.height),
        anchor: Anchor.bottomCenter,
        priority: state.y.round(),
      );

  /// Walk-cycle radians per second.
  static const double _stride = 14;

  /// Remote players further than this from their reported position snap.
  static const double snapDistance = 300;

  final String name;
  final AvatarPainter avatar;
  final bool isSelf;

  /// Collision map; null for remote players (the server already resolved).
  final WorldMap? map;

  /// Desired walking direction from keyboard/joystick (length 0..1).
  final Vector2 input = Vector2.zero();

  Vector2? _target;
  double _speed = Limits.walkSpeed;
  double _stuck = 0;
  ChatBubble? _bubble;
  TextComponent? _itBadge;
  double _phase = 0;

  /// -1 facing left, 1 facing right.
  double facing = 1;

  /// Whether the character actually moved this frame.
  bool walking = false;

  bool get isMoving => _target != null || input.length2 > 0;

  bool _isIt = false;
  bool get isIt => _isIt;
  set isIt(bool value) {
    if (_isIt == value) return;
    _isIt = value;
    if (value) {
      add(
        _itBadge = TextComponent(
          text: '술래',
          position: Vector2(size.x / 2, -14),
          anchor: Anchor.bottomCenter,
          priority: 1,
          textRenderer: TextPaint(
            style: const TextStyle(
              color: Color(0xFFFF1744),
              fontSize: 12,
              fontWeight: FontWeight.w900,
              shadows: [Shadow(color: Colors.white, blurRadius: 3)],
            ),
          ),
        ),
      );
    } else {
      _itBadge?.removeFromParent();
      _itBadge = null;
    }
  }

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

  /// Walk to [target] (tap-to-move).
  void moveTo(Vector2 target, {double speed = Limits.walkSpeed}) {
    _target = target.clone();
    _speed = speed;
    _stuck = 0;
    final dx = target.x - position.x;
    if (dx.abs() > 1) facing = dx.sign;
  }

  /// Follow a networked position: glide there, or snap if it's far away.
  void syncTo(Vector2 p) {
    final d = p.distanceTo(position);
    if (d > snapDistance) {
      position.setFrom(p);
      _target = null;
      priority = p.y.round();
    } else if (d > 0.5) {
      // Arrive within about one network tick, never slower than walking.
      moveTo(p, speed: math.max(Limits.walkSpeed, d / 0.12));
    }
  }

  /// Shows [text] above the character for a few seconds.
  void say(String text) {
    _bubble?.removeFromParent();
    add(
      _bubble = ChatBubble(text)
        ..position = Vector2(size.x / 2, _isIt ? -32 : -6),
    );
  }

  /// Pops [emote] above the head; it floats up and disappears.
  void react(Emote emote) {
    add(
      TextComponent(
        text: emojiFor(emote),
        position: Vector2(size.x / 2, -4),
        anchor: Anchor.bottomCenter,
        textRenderer: TextPaint(style: const TextStyle(fontSize: 30)),
        priority: 2,
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
    final step = _plannedStep(dt);
    if (step == null) {
      walking = false;
      // Ease the legs back to standing.
      _phase %= math.pi;
      _phase = _phase < 0.2 || _phase > math.pi - 0.2
          ? 0
          : _phase + dt * _stride;
      return;
    }

    final before = position.clone();
    var next = position + step;
    final map = this.map;
    if (map != null) {
      final r = map.resolve((x: next.x, y: next.y));
      next = Vector2(r.x, r.y);
    }
    position.setFrom(next);

    final moved = position.distanceTo(before);
    walking = moved > 0.01;
    if (step.x.abs() > 0.01) facing = step.x.sign;
    if (walking) _phase += dt * _stride;
    priority = position.y.round();

    final target = _target;
    if (target != null) {
      if (position.distanceTo(target) < 0.5) {
        _target = null;
      } else if (moved < step.length * 0.2) {
        // Pressed against something we can't slide around: give up.
        _stuck += dt;
        if (_stuck > 0.25) _target = null;
      } else {
        _stuck = 0;
      }
    }
  }

  Vector2? _plannedStep(double dt) {
    if (input.length2 > 0) {
      _target = null;
      final dir = input.length2 > 1 ? input.normalized() : input;
      return dir * Limits.walkSpeed * dt;
    }
    final target = _target;
    if (target == null) return null;
    final toTarget = target - position;
    final max = _speed * dt;
    return toTarget.length <= max ? toTarget : toTarget.normalized() * max;
  }

  @override
  void render(Canvas canvas) {
    avatar.paint(
      canvas,
      phase: _phase,
      facing: facing,
      selfRing: isSelf,
      itRing: _isIt,
    );
  }
}

class ChatBubble extends TextBoxComponent {
  ChatBubble(String text)
    : super(
        text: text,
        anchor: Anchor.bottomCenter,
        priority: 3,
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
