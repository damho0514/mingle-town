import 'package:flame/events.dart';
import 'package:flame/game.dart';
import 'package:flutter/material.dart';

import 'player.dart';

/// Root game. Tap anywhere to move your character there.
class MingleTownGame extends FlameGame with TapCallbacks {
  late final Player player;

  @override
  Color backgroundColor() => const Color(0xFF8BC34A);

  @override
  Future<void> onLoad() async {
    player = Player(position: size / 2);
    add(player);
  }

  @override
  void onTapUp(TapUpEvent event) {
    player.moveTo(event.canvasPosition);
  }
}
