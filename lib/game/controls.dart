import 'package:flame/components.dart';
import 'package:flame/events.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Direction from WASD / arrow keys (unnormalised, each axis -1..1).
Vector2 keyboardDirection(Set<LogicalKeyboardKey> keys) {
  bool any(List<LogicalKeyboardKey> k) => k.any(keys.contains);
  final x =
      (any([LogicalKeyboardKey.arrowRight, LogicalKeyboardKey.keyD]) ? 1 : 0) -
      (any([LogicalKeyboardKey.arrowLeft, LogicalKeyboardKey.keyA]) ? 1 : 0);
  final y =
      (any([LogicalKeyboardKey.arrowDown, LogicalKeyboardKey.keyS]) ? 1 : 0) -
      (any([LogicalKeyboardKey.arrowUp, LogicalKeyboardKey.keyW]) ? 1 : 0);
  return Vector2(x.toDouble(), y.toDouble());
}

final movementKeys = {
  LogicalKeyboardKey.arrowUp,
  LogicalKeyboardKey.arrowDown,
  LogicalKeyboardKey.arrowLeft,
  LogicalKeyboardKey.arrowRight,
  LogicalKeyboardKey.keyW,
  LogicalKeyboardKey.keyA,
  LogicalKeyboardKey.keyS,
  LogicalKeyboardKey.keyD,
};

/// On-screen joystick for touch devices. Also swallows taps on itself so they
/// don't count as tap-to-move on the ground underneath.
class TouchJoystick extends JoystickComponent with TapCallbacks {
  TouchJoystick()
    : super(
        knob: CircleComponent(
          radius: 26,
          paint: Paint()..color = const Color(0xCCFFFFFF),
        ),
        background: CircleComponent(
          radius: 60,
          paint: Paint()..color = const Color(0x44000000),
        ),
        margin: const EdgeInsets.only(left: 36, bottom: 36),
      );
}
