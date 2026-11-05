import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:mingle_town/audio/game_audio.dart';

void main() {
  test('channel rotates players and drops sounds when all are busy', () async {
    final started = <int>[];
    final pending = <Completer<void>>[];
    final channel = SfxChannel(2, (i) {
      started.add(i);
      final c = Completer<void>();
      pending.add(c);
      return c.future;
    });

    expect(channel.trigger(), isTrue);
    expect(channel.trigger(), isTrue);
    expect(channel.trigger(), isFalse, reason: 'both players busy: dropped');
    expect(started, [0, 1]);

    pending.first.complete();
    await Future<void>.delayed(Duration.zero);
    expect(channel.trigger(), isTrue);
    expect(started, [0, 1, 0]);
  });

  test('a failing player frees its slot', () async {
    final channel = SfxChannel(1, (_) async => throw Exception('no device'));
    expect(channel.trigger(), isTrue);
    await Future<void>.delayed(Duration.zero);
    expect(channel.trigger(), isTrue);
  });
}
