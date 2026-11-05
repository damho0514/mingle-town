import 'dart:async';

import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:mingle_protocol/mingle_protocol.dart';

import '../net/game_connection.dart';
import 'character.dart';
import 'ground.dart';
import 'tree.dart';
import 'world_layout.dart';

/// The shared space. Mirrors server state; tap the ground to walk.
class MingleTownGame extends FlameGame {
  MingleTownGame({required this.connection, required this.playerName});

  final GameConnection connection;
  final String playerName;

  final Map<String, Character> characters = {};
  String? selfId;

  /// Number of players currently in the room (including you).
  final ValueNotifier<int> playerCount = ValueNotifier(0);
  StreamSubscription<ServerMessage>? _subscription;

  Character? get self => characters[selfId];

  @override
  Color backgroundColor() => const Color(0xFF33691E);

  @override
  Future<void> onLoad() async {
    world.add(Ground(onTap: walkTo));
    world.addAll(WorldLayout.instance.trees.map(Tree.new));
    _subscription = connection.messages.listen(handleMessage);
    connection.send(JoinMessage(playerName));
  }

  @visibleForTesting
  void handleMessage(ServerMessage message) {
    switch (message) {
      case WelcomeMessage(:final selfId, :final players):
        this.selfId = selfId;
        players.forEach(_spawn);
      case PlayerJoinedMessage(:final player):
        _spawn(player);
      case PlayerLeftMessage(:final id):
        characters.remove(id)?.removeFromParent();
        playerCount.value = characters.length;
      case PlayerMovedMessage(:final id, :final x, :final y):
        if (id != selfId) characters[id]?.moveTo(Vector2(x, y));
      case PlayerChatMessage(:final id, :final text):
        characters[id]?.say(text);
      case PlayerEmotedMessage(:final id, :final emote):
        characters[id]?.react(emote);
      case ErrorMessage(:final reason):
        debugPrint('server error: $reason');
    }
  }

  @override
  void update(double dt) {
    super.update(dt);
    final me = self;
    if (me != null) {
      camera.viewfinder.position = cameraTarget(
        me.position,
        camera.viewport.virtualSize,
      );
    }
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

  /// Walks the local character to [target] and tells the server.
  void walkTo(Vector2 target) {
    final me = self;
    if (me == null) return;
    final clamped = Vector2(
      target.x.clamp(0, Limits.worldWidth),
      target.y.clamp(0, Limits.worldHeight),
    );
    me.moveTo(clamped);
    connection.send(MoveMessage(clamped.x, clamped.y));
  }

  void sendChat(String text) {
    final trimmed = text.trim();
    if (trimmed.isNotEmpty) connection.send(ChatMessage(trimmed));
  }

  void sendEmote(Emote emote) => connection.send(EmoteMessage(emote));

  void _spawn(PlayerState state) {
    if (characters.containsKey(state.id)) return;
    final character = Character(state: state, isSelf: state.id == selfId);
    characters[state.id] = character;
    world.add(character);
    playerCount.value = characters.length;
  }

  @override
  void onRemove() {
    _subscription?.cancel();
    super.onRemove();
  }
}
