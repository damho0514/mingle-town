import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mingle_town/screens/lobby_screen.dart';

void main() {
  Future<void> pump(WidgetTester tester, Connector connector) =>
      tester.pumpWidget(MaterialApp(home: LobbyScreen(connector: connector)));

  testWidgets('requires a nickname', (tester) async {
    var called = false;
    await pump(tester, (_) async {
      called = true;
      throw UnimplementedError();
    });
    await tester.tap(find.text('입장하기'));
    await tester.pump();
    expect(find.text('닉네임을 입력해 주세요.'), findsOneWidget);
    expect(called, isFalse);
  });

  testWidgets('shows an error when the server is unreachable', (tester) async {
    Uri? requested;
    await pump(tester, (uri) async {
      requested = uri;
      throw Exception('refused');
    });
    await tester.enterText(find.byType(TextField).first, 'alice');
    await tester.enterText(find.byType(TextField).last, 'ws://example.test:9');
    await tester.tap(find.text('입장하기'));
    await tester.pumpAndSettle();
    expect(requested, Uri.parse('ws://example.test:9'));
    expect(find.text('서버에 연결할 수 없어요.'), findsOneWidget);
  });

  testWidgets('rejects non-websocket URLs', (tester) async {
    await pump(tester, (_) async => throw UnimplementedError());
    await tester.enterText(find.byType(TextField).first, 'alice');
    await tester.enterText(find.byType(TextField).last, 'http://x');
    await tester.tap(find.text('입장하기'));
    await tester.pump();
    expect(find.textContaining('ws://'), findsOneWidget);
  });
}
