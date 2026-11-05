import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mingle_town/game/mingle_town_game.dart';
import 'package:mingle_town/screens/game_screen.dart';

import 'fake_connection.dart';

void main() {
  testWidgets('game fills the whole area between the bars', (tester) async {
    final conn = FakeConnection();
    await tester.pumpWidget(
      MaterialApp(
        home: GameScreen(connection: conn, playerName: 'me'),
      ),
    );
    await tester.pump();

    final game = tester.getSize(find.byType(GameWidget<MingleTownGame>));
    final screen = tester.getSize(find.byType(Scaffold));
    // Only the chat bar at the bottom may take space away from the game.
    expect(game.width, screen.width);
    expect(game.height, greaterThan(screen.height - 120));

    // Leaving the screen closes the connection.
    await tester.pumpWidget(const SizedBox());
    expect(conn.closed, isTrue);
  });
}
