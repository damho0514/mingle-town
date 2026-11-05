import 'package:flame/components.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mingle_town/game/controls.dart';

void main() {
  test('WASD and arrows map to directions', () {
    expect(keyboardDirection({}), Vector2.zero());
    expect(keyboardDirection({LogicalKeyboardKey.keyW}), Vector2(0, -1));
    expect(keyboardDirection({LogicalKeyboardKey.arrowDown}), Vector2(0, 1));
    expect(
      keyboardDirection({LogicalKeyboardKey.keyA, LogicalKeyboardKey.arrowUp}),
      Vector2(-1, -1),
    );
    expect(
      keyboardDirection({LogicalKeyboardKey.keyD, LogicalKeyboardKey.keyA}),
      Vector2.zero(),
      reason: 'opposites cancel',
    );
  });
}
