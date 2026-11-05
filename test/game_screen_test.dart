import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mingle_protocol/mingle_protocol.dart';
import 'package:mingle_town/audio/game_audio.dart';
import 'package:mingle_town/game/mingle_town_game.dart';
import 'package:mingle_town/screens/game_screen.dart';

import 'fake_connection.dart';

void main() {
  late FakeConnection conn;
  late SilentAudio audio;

  setUp(() {
    conn = FakeConnection();
    audio = SilentAudio();
  });

  Future<void> pump(WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: GameScreen(
          connection: conn,
          join: const JoinMessage('me', room: 'plaza-2'),
          audio: audio,
          touchControls: false,
        ),
      ),
    );
    await tester.pump();
  }

  const me = PlayerState(
    id: 'p1',
    name: 'me',
    color: 0xFFFF7043,
    x: 920,
    y: 800,
  );
  const bob = PlayerState(
    id: 'p2',
    name: 'bob',
    color: 0xFF42A5F5,
    x: 700,
    y: 700,
  );

  testWidgets('game fills the whole area between the bars', (tester) async {
    await pump(tester);
    final game = tester.getSize(find.byType(GameWidget<MingleTownGame>));
    final screen = tester.getSize(find.byType(Scaffold));
    expect(game.width, screen.width);
    expect(game.height, greaterThan(screen.height - 120));

    await tester.pumpWidget(const SizedBox());
    expect(conn.closed, isTrue);
  });

  testWidgets('room label, tag button state, banner and mute', (tester) async {
    await pump(tester);
    expect(find.textContaining('광장 2'), findsOneWidget);

    IconButton tagButton() => tester.widget<IconButton>(
      find.ancestor(
        of: find.byIcon(Icons.directions_run),
        matching: find.byType(IconButton),
      ),
    );
    expect(tagButton().onPressed, isNull, reason: 'alone: cannot start tag');

    conn.receive(const WelcomeMessage(selfId: 'p1', players: [me, bob]));
    await tester.pump();
    await tester.pump();
    expect(tagButton().onPressed, isNotNull);
    tagButton().onPressed!();
    expect(conn.sent.last, isA<StartTagMessage>());

    conn.receive(
      const TagMessage(phase: TagPhase.started, itId: 'p2', remainingMs: 42000),
    );
    await tester.pump();
    await tester.pump();
    expect(find.textContaining('술래: bob'), findsOneWidget);
    expect(find.text('술래잡기 시작! 술래는 bob님'), findsOneWidget);
    expect(tagButton().onPressed, isNull, reason: 'round already running');

    await tester.tap(find.byIcon(Icons.volume_up));
    await tester.pump();
    expect(audio.muted.value, isTrue);
    expect(find.byIcon(Icons.volume_off), findsOneWidget);

    await tester.pump(const Duration(seconds: 4));
    await tester.pump(const Duration(milliseconds: 300));
    expect(
      find.text('술래잡기 시작! 술래는 bob님'),
      findsNothing,
      reason: 'notices fade out',
    );
    await tester.pumpWidget(const SizedBox());
  });
}
