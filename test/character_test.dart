import 'package:flame/components.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mingle_protocol/mingle_protocol.dart';
import 'package:mingle_town/game/character.dart';

void main() {
  test('walks toward target at constant speed and stops on arrival', () {
    final c = Character(
      state: const PlayerState(
        id: 'p1',
        name: 'a',
        color: 0xFF000000,
        x: 0,
        y: 0,
      ),
    );
    c.moveTo(Vector2(100, 0));

    c.update(0.25); // 200 px/s * 0.25 s = 50 px
    expect(c.position.x, closeTo(50, 0.001));
    expect(c.isMoving, isTrue);

    c.update(1);
    expect(c.position, Vector2(100, 0));
    expect(c.isMoving, isFalse);
  });
}
