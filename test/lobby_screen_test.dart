import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mingle_protocol/mingle_protocol.dart';
import 'package:mingle_town/audio/game_audio.dart';
import 'package:mingle_town/net/game_connection.dart';
import 'package:mingle_town/prefs.dart';
import 'package:mingle_town/screens/game_screen.dart';
import 'package:mingle_town/screens/lobby_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'fake_connection.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  Future<void> pump(
    WidgetTester tester, {
    required Future<GameConnection> Function(Uri) connector,
    List<RoomInfo> rooms = const [],
    PlayerPrefs? prefs,
  }) async {
    tester.view.physicalSize = const Size(800, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        home: LobbyScreen(
          connector: connector,
          roomFetcher: (_) async => rooms,
          loadPrefs: () async => prefs ?? PlayerPrefs(),
          audioFactory: ({required muted}) => SilentAudio(muted: muted),
        ),
      ),
    );
    await tester.pump();
  }

  Finder field(String label) => find.widgetWithText(TextField, label);

  testWidgets('requires a nickname', (tester) async {
    var called = false;
    await pump(
      tester,
      connector: (_) async {
        called = true;
        throw UnimplementedError();
      },
    );
    await tester.tap(find.text('입장하기'));
    await tester.pump();
    expect(find.text('닉네임을 입력해 주세요.'), findsOneWidget);
    expect(called, isFalse);
  });

  testWidgets('shows an error when the server is unreachable', (tester) async {
    await pump(tester, connector: (_) async => throw Exception('refused'));
    await tester.enterText(field('닉네임'), 'alice');
    await tester.tap(find.text('입장하기'));
    await tester.pumpAndSettle();
    expect(find.text('서버에 연결할 수 없어요.'), findsOneWidget);
  });

  testWidgets('rejects non-websocket URLs', (tester) async {
    await pump(tester, connector: (_) async => throw UnimplementedError());
    await tester.tap(find.text('서버 설정'));
    await tester.pumpAndSettle();
    await tester.enterText(field('서버 주소'), 'http://x');
    await tester.enterText(field('닉네임'), 'alice');
    await tester.tap(find.text('입장하기'));
    await tester.pump();
    expect(find.textContaining('ws://'), findsWidgets);
    expect(find.text('서버 주소는 ws:// 또는 wss:// 로 시작해야 해요.'), findsOneWidget);
  });

  testWidgets('shows room occupancy and disables full rooms', (tester) async {
    await pump(
      tester,
      connector: (_) async => throw UnimplementedError(),
      rooms: const [
        RoomInfo(id: 'plaza-1', count: 3, capacity: 30),
        RoomInfo(id: 'plaza-2', count: 30, capacity: 30),
        RoomInfo(id: 'plaza-3', count: 0, capacity: 30),
      ],
    );
    await tester.pump();
    expect(find.text('광장 1 · 3/30'), findsOneWidget);
    final full = tester.widget<ChoiceChip>(
      find.widgetWithText(ChoiceChip, '광장 2 · 30/30'),
    );
    expect(full.onSelected, isNull);
  });

  testWidgets('enters the chosen room with the chosen look', (tester) async {
    final conn = FakeConnection();
    Uri? connectedTo;
    await pump(
      tester,
      connector: (uri) async {
        connectedTo = uri;
        return conn;
      },
      prefs: PlayerPrefs(serverUrl: 'ws://example.test:9'),
    );

    await tester.tap(find.widgetWithText(ChoiceChip, '왕관'));
    await tester.tap(find.widgetWithText(ChoiceChip, '광장 3'));
    await tester.enterText(field('닉네임'), 'alice');
    await tester.tap(find.text('입장하기'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    expect(connectedTo, Uri.parse('ws://example.test:9'));
    expect(find.byType(GameScreen), findsOneWidget);
    final join = conn.sent.whereType<JoinMessage>().single;
    expect((join.name, join.room, join.hat), ('alice', 'plaza-3', Hat.crown));

    final saved = await PlayerPrefs.load();
    expect(
      (saved.name, saved.room, saved.hat),
      ('alice', 'plaza-3', Hat.crown),
    );
  });
}
