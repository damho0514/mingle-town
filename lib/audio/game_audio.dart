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

  /// Releases every native player. The instance can't be used afterwards.
  Future<void> dispose();
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
  @override
  Future<void> dispose() async {}
}

/// A fixed set of players for one sound, used round-robin.
///
/// Never creates players on demand: if every player is still busy starting
/// up, the sound is skipped. That bounds native resources no matter how
/// often sounds fire (the previous create-a-player-per-sound approach leaked
/// until the Android app ran out of memory).
class SfxChannel {
  SfxChannel(this.size, this._restart);

  final int size;
  final Future<void> Function(int index) _restart;
  int _next = 0;
  int _inFlight = 0;

  /// Starts the sound on the next player; returns false if it was dropped.
  bool trigger() {
    if (_inFlight >= size) return false;
    final index = _next;
    _next = (_next + 1) % size;
    _inFlight++;
    unawaited(
      _restart(index)
          .then(
            (_) {},
            onError: (Object e) {
              debugPrint('audio error: $e');
            },
          )
          .whenComplete(() => _inFlight--),
    );
    return true;
  }
}

class FlameGameAudio implements GameAudio {
  FlameGameAudio({bool muted = false}) : _muted = ValueNotifier(muted);

  static const _musicFile = 'bgm.wav';
  static const _musicVolume = 0.3;
  static bool _bgmInitialized = false;

  final ValueNotifier<bool> _muted;
  final Map<Sfx, SfxChannel> _channels = {};
  final List<AudioPlayer> _players = [];
  bool _musicWanted = false;
  bool _disposed = false;

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
    final context = AudioContextConfig(
      focus: AudioContextConfigFocus.mixWithOthers,
    ).build();
    try {
      for (final sfx in Sfx.values) {
        final players = <AudioPlayer>[];
        for (var i = 0; i < (sfx == Sfx.step ? 3 : 2); i++) {
          final player = AudioPlayer()..audioCache = FlameAudio.audioCache;
          await player.setPlayerMode(PlayerMode.lowLatency);
          await player.setAudioContext(context);
          await player.setReleaseMode(ReleaseMode.stop);
          await player.setSource(AssetSource(sfx.file));
          await player.setVolume(sfx.volume);
          players.add(player);
        }
        _players.addAll(players);
        _channels[sfx] = SfxChannel(players.length, (i) async {
          final p = players[i];
          await p.stop();
          await p.resume();
        });
      }
      await FlameAudio.audioCache.load(_musicFile);
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
    if (_muted.value || _disposed) return;
    _channels[sfx]?.trigger();
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

  @override
  Future<void> dispose() async {
    _disposed = true;
    _channels.clear();
    final players = List.of(_players);
    _players.clear();
    await Future.wait(players.map((p) => p.dispose().catchError((_) {})));
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
