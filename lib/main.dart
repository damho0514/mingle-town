import 'package:flame/game.dart';
import 'package:flutter/material.dart';

import 'game/mingle_town_game.dart';

void main() {
  runApp(const MingleTownApp());
}

class MingleTownApp extends StatelessWidget {
  const MingleTownApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Mingle Town',
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        body: GameWidget(game: MingleTownGame()),
      ),
    );
  }
}
