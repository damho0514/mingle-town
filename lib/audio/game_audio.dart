import 'dart:async';

import 'package:flame_audio/flame_audio.dart';
import 'package:flutter/foundation.dart';

enum Sfx {
  step('step.wav', 0.35),
  pop('pop.wav', 0.6),
  emote('emote.wav', 0.6),
  join('join.wav', 0.5),
  tagStart('tag_start.wav', 0.6),
  tagged('tagged.wav', 0.7),
  tagEnd('tag_end.wav', 0.6);

  const Sfx(this.file, this.volume);
  final String file;
  final double volume;
}

/// Sound effects and background music. All methods are fire-and-forget and
/// never throw: a missing audio device must not break the game.
abstract class GameAudio {
  ValueListenable<bool> get muted;
  set isMuted(bool value);

  Future<void> load();
  void play(Sfx sfx);
  void startMusic();
  void stopMusic();
}

/// No-op implementation for tests and headless runs.
class SilentAudio implements GameAudio {
  SilentAudio({bool muted = false}) : _muted = ValueNotifier(muted);
  final ValueNotifier<bool> _muted;
  final played = <Sfx>[];

  @override
  ValueListenable<bool> get muted => _muted;
  @override
  set isMuted(bool value) => _muted.value = value;
  @override
  Future<void> load() async {}
  @override
  void play(Sfx sfx) => played.add(sfx);
  @override
  void startMusic() {}
  @override
  void stopMusic() {}
}

class FlameGameAudio implements GameAudio {
  FlameGameAudio({bool muted = false}) : _muted = ValueNotifier(muted);

  static const _musicFile = 'bgm.wav';
  static const _musicVolume = 0.3;

  final ValueNotifier<bool> _muted;
  AudioPool? _steps;
  bool _musicWanted = false;
  static bool _bgmInitialized = false;

  @override
  ValueListenable<bool> get muted => _muted;

  @override
  set isMuted(bool value) {
    if (_muted.value == value) return;
    _muted.value = value;
    if (!_musicWanted) return;
    _guard(value ? FlameAudio.bgm.pause() : _playMusic());
  }

  @override
  Future<void> load() async {
    try {
      await FlameAudio.audioCache.loadAll([
        for (final s in Sfx.values) s.file,
        _musicFile,
      ]);
      _steps = await FlameAudio.createPool(Sfx.step.file, maxPlayers: 3);
      if (!_bgmInitialized) {
        await FlameAudio.bgm.initialize();
        _bgmInitialized = true;
      }
    } catch (e) {
      debugPrint('audio unavailable: $e');
    }
  }

  @override
  void play(Sfx sfx) {
    if (_muted.value) return;
    final steps = _steps;
    if (sfx == Sfx.step && steps != null) {
      _guard(steps.start(volume: sfx.volume));
    } else {
      _guard(FlameAudio.play(sfx.file, volume: sfx.volume));
    }
  }

  @override
  void startMusic() {
    _musicWanted = true;
    if (!_muted.value) _guard(_playMusic());
  }

  @override
  void stopMusic() {
    _musicWanted = false;
    _guard(FlameAudio.bgm.stop());
  }

  Future<void> _playMusic() =>
      FlameAudio.bgm.play(_musicFile, volume: _musicVolume);

  static void _guard(Future<Object?> f) {
    unawaited(
      f.then(
        (_) {},
        onError: (Object e) {
          debugPrint('audio error: $e');
        },
      ),
    );
  }
}
