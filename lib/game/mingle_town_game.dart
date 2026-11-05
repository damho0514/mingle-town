import 'dart:async';

import 'package:flame/experimental.dart' show Rectangle;
import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:mingle_protocol/mingle_protocol.dart';

import '../net/game_connection.dart';
import 'character.dart';
import 'ground.dart';

/// The shared space. Mirrors server state; tap the ground to walk.
class MingleTownGame extends FlameGame {
  MingleTownGame({required this.connection, required this.playerName});

  final GameConnection connection;
  final String playerName;

  final Map<String, Character> characters = {};
  String? selfId;
  StreamSubscription<ServerMessage>? _subscription;

  Character? get self => characters[selfId];

  @override
  Color backgroundColor() => const Color(0xFF33691E);

  @override
  Future<void> onLoad() async {
    world.add(Ground(onTap: walkTo));
    camera.setBounds(
      Rectangle.fromLTRB(0, 0, Limits.worldWidth, Limits.worldHeight),
      considerViewport: true,
    );
    _subscription = connection.messages.listen(handleMessage);
    connection.send(JoinMessage(playerName));
  }

  @visibleForTesting
  void handleMessage(ServerMessage message) {
    switch (message) {
      case WelcomeMessage(:final selfId, :final players):
        this.selfId = selfId;
        players.forEach(_spawn);
        final me = self;
        if (me != null) camera.follow(me);
      case PlayerJoinedMessage(:final player):
        _spawn(player);
      case PlayerLeftMessage(:final id):
        characters.remove(id)?.removeFromParent();
      case PlayerMovedMessage(:final id, :final x, :final y):
        if (id != selfId) characters[id]?.moveTo(Vector2(x, y));
      case PlayerChatMessage(:final id, :final text):
        characters[id]?.say(text);
      case ErrorMessage(:final reason):
        debugPrint('server error: $reason');
    }
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

  void _spawn(PlayerState state) {
    if (characters.containsKey(state.id)) return;
    final character = Character(state: state, isSelf: state.id == selfId)
      ..priority = state.y.round();
    characters[state.id] = character;
    world.add(character);
  }

  @override
  void onRemove() {
    _subscription?.cancel();
    super.onRemove();
  }
}
