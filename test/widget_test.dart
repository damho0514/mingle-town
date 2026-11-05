import 'package:flame/components.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:mingle_town/game/player.dart';

void main() {
  test('Player moves toward target and stops on arrival', () {
    final player = Player(position: Vector2.zero());
    player.moveTo(Vector2(100, 0));

    player.update(0.25); // 200 px/s * 0.25 s = 50 px
    expect(player.position.x, closeTo(50, 0.001));

    player.update(1);
    expect(player.position, Vector2(100, 0));
  });
}
