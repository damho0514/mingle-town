import 'dart:async';

import 'package:flame/events.dart';
import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mingle_protocol/mingle_protocol.dart';

import '../audio/game_audio.dart';
import '../net/game_connection.dart';
import 'character.dart';
import 'controls.dart';
import 'ground.dart';
import 'tree.dart';

/// A tag round as the UI should show it.
class TagStatus {
  const TagStatus({
    required this.itId,
    required this.itName,
    required this.endsAt,
  });
  final String? itId;
  final String itName;
  final DateTime endsAt;
}

/// The shared space. Mirrors server state; the local player moves with
/// keyboard, joystick or tap and streams its position to the server.
class MingleTownGame extends FlameGame with KeyboardEvents {
  MingleTownGame({
    required this.connection,
    required this.join,
    GameAudio? audio,
    this.touchControls = false,
    this.onChatRequested,
    DateTime Function()? clock,
  }) : audio = audio ?? SilentAudio(),
       _clock = clock ?? DateTime.now;

  final GameConnection connection;
  final JoinMessage join;
  final GameAudio audio;

  /// Show an on-screen joystick (phones and tablets).
  final bool touchControls;

  /// Called when the player presses Enter to start typing.
  final VoidCallback? onChatRequested;
  final DateTime Function() _clock;

  final Map<String, Character> characters = {};
  String? selfId;
  String room = Rooms.defaultId;

  /// Number of players currently in the room (including you).
  final ValueNotifier<int> playerCount = ValueNotifier(0);

  /// The running tag round, or null.
  final ValueNotifier<TagStatus?> tag = ValueNotifier(null);

  /// One-line announcements ("X님이 술래가 됐어요!") for the HUD.
  final StreamController<String> _notices = StreamController.broadcast();
  Stream<String> get notices => _notices.stream;

  StreamSubscription<ServerMessage>? _subscription;
  TouchJoystick? joystick;
  Set<LogicalKeyboardKey> _keys = {};
  Vector2? _lastSent;
  double _sendCooldown = 0;
  double _stepTimer = 0;

  Character? get self => characters[selfId];

  @override
  Color backgroundColor() => const Color(0xFF33691E);

  @override
  Future<void> onLoad() async {
    world.add(Ground(onTap: walkTo));
    world.addAll(WorldMap.instance.trees.map(Tree.new));
    if (touchControls) camera.viewport.add(joystick = TouchJoystick());
    _subscription = connection.messages.listen(handleMessage);
    connection.send(join);
  }

  // ---------------------------------------------------------------------------
  // Input
  // ---------------------------------------------------------------------------

  @override
  KeyEventResult onKeyEvent(
    KeyEvent event,
    Set<LogicalKeyboardKey> keysPressed,
  ) {
    _keys = keysPressed;
    if (event is KeyDownEvent && event.logicalKey == LogicalKeyboardKey.enter) {
      onChatRequested?.call();
      return KeyEventResult.handled;
    }
    return movementKeys.contains(event.logicalKey)
        ? KeyEventResult.handled
        : KeyEventResult.ignored;
  }

  /// Current stick/keyboard direction (length 0..1).
  Vector2 get inputDirection {
    final keys = keyboardDirection(_keys);
    if (keys.length2 > 0) return keys.normalized();
    final stick = joystick;
    if (stick != null && !stick.delta.isZero()) return stick.relativeDelta;
    return Vector2.zero();
  }

  /// Walks the local character to [target] (tap-to-move).
  void walkTo(Vector2 target) {
    final me = self;
    if (me == null) return;
    final p = WorldMap.instance.resolve((x: target.x, y: target.y));
    me.moveTo(Vector2(p.x, p.y));
  }

  @override
  void update(double dt) {
    self?.input.setFrom(inputDirection);
    super.update(dt);
    final me = self;
    if (me == null) return;

    camera.viewfinder.position = cameraTarget(
      me.position,
      camera.viewport.virtualSize,
    );
    _streamPosition(me, dt);

    if (me.walking) {
      _stepTimer -= dt;
      if (_stepTimer <= 0) {
        audio.play(Sfx.step);
        _stepTimer = 0.32;
      }
    } else {
      _stepTimer = 0;
    }
  }

  /// Sends our position at most every [MoveRateLimit.sendInterval], plus a
  /// final update when we stop so everyone sees where we ended up.
  void _streamPosition(Character me, double dt) {
    _sendCooldown -= dt;
    final last = _lastSent;
    if (last != null && last.distanceTo(me.position) < 0.5) return;
    if (_sendCooldown > 0) return;
    connection.send(MoveMessage(me.position.x, me.position.y));
    _lastSent = me.position.clone();
    _sendCooldown = MoveRateLimit.sendInterval.inMicroseconds / 1e6;
  }

  /// Where the camera should look to keep [focus] centred without showing
  /// anything outside the world. Recomputed every frame so it adapts when
  /// the view resizes (keyboard, rotation).
  @visibleForTesting
  static Vector2 cameraTarget(Vector2 focus, Vector2 viewSize) {
    double axis(double v, double view, double world) =>
        view >= world ? world / 2 : v.clamp(view / 2, world - view / 2);
    // Aim slightly above the feet so the whole body sits in the middle.
    return Vector2(
      axis(focus.x, viewSize.x, Limits.worldWidth),
      axis(focus.y - 20, viewSize.y, Limits.worldHeight),
    );
  }

  // ---------------------------------------------------------------------------
  // Network
  // ---------------------------------------------------------------------------

  @visibleForTesting
  void handleMessage(ServerMessage message) {
    switch (message) {
      case WelcomeMessage(
        :final selfId,
        :final room,
        :final players,
        :final tag,
      ):
        this.selfId = selfId;
        this.room = room;
        players.forEach(_spawn);
        _lastSent = self?.position.clone();
        if (tag != null) _applyTag(tag, announce: false);
      case PlayerJoinedMessage(:final player):
        _spawn(player);
        audio.play(Sfx.join);
      case PlayerLeftMessage(:final id):
        characters.remove(id)?.removeFromParent();
        playerCount.value = characters.length;
      case PlayerMovedMessage(:final id, :final x, :final y):
        if (id != selfId) characters[id]?.syncTo(Vector2(x, y));
      case PlayerChatMessage(:final id, :final text):
        characters[id]?.say(text);
        audio.play(Sfx.pop);
      case PlayerEmotedMessage(:final id, :final emote):
        characters[id]?.react(emote);
        audio.play(Sfx.emote);
      case TagMessage():
        _applyTag(message, announce: true);
      case ErrorMessage(:final reason):
        final notice = _errorNotice(reason);
        if (notice != null) _notices.add(notice);
    }
  }

  void _applyTag(TagMessage m, {required bool announce}) {
    final itId = m.phase == TagPhase.ended ? null : m.itId;
    for (final c in characters.values) {
      c.isIt = false;
    }
    if (itId != null) characters[itId]?.isIt = true;
    String nameOf(String? id) => characters[id]?.name ?? '누군가';

    switch (m.phase) {
      case TagPhase.started:
      case TagPhase.tagged:
        tag.value = TagStatus(
          itId: itId,
          itName: nameOf(itId),
          endsAt: _clock().add(Duration(milliseconds: m.remainingMs)),
        );
      case TagPhase.ended:
        tag.value = null;
    }
    if (!announce) return;

    final me = itId != null && itId == selfId;
    switch (m.phase) {
      case TagPhase.started:
        _notices.add(
          me ? '술래잡기 시작! 내가 술래예요 🏃' : '술래잡기 시작! 술래는 ${nameOf(itId)}님',
        );
        audio.play(Sfx.tagStart);
      case TagPhase.tagged:
        _notices.add(
          m.byId == null
              ? '${nameOf(itId)}님이 새 술래예요'
              : me
              ? '${nameOf(m.byId)}님에게 잡혔어요! 이제 내가 술래'
              : '${nameOf(m.byId)}님이 ${nameOf(itId)}님을 잡았어요!',
        );
        audio.play(Sfx.tagged);
      case TagPhase.ended:
        final loser = m.itId;
        _notices.add(
          loser == null
              ? '술래잡기가 끝났어요'
              : loser == selfId
              ? '시간 종료! 내가 마지막 술래였어요 😢'
              : '시간 종료! ${nameOf(loser)}님이 마지막 술래',
        );
        audio.play(Sfx.tagEnd);
    }
  }

  static String? _errorNotice(String reason) => switch (reason) {
    'need more players' => '술래잡기는 2명 이상 있어야 해요',
    'tag already running' => '이미 술래잡기 중이에요',
    'slow down' => '잠시 후에 다시 보내 주세요',
    _ => null,
  };

  void sendChat(String text) {
    final trimmed = text.trim();
    if (trimmed.isNotEmpty) connection.send(ChatMessage(trimmed));
  }

  void sendEmote(Emote emote) => connection.send(EmoteMessage(emote));

  void startTag() => connection.send(const StartTagMessage());

  void _spawn(PlayerState state) {
    if (characters.containsKey(state.id)) return;
    final isSelf = state.id == selfId;
    final character = Character(
      state: state,
      isSelf: isSelf,
      map: isSelf ? WorldMap.instance : null,
    );
    characters[state.id] = character;
    world.add(character);
    playerCount.value = characters.length;
  }

  @override
  void onRemove() {
    _subscription?.cancel();
    _notices.close();
    super.onRemove();
  }
}
