import 'dart:convert';

import 'emote.dart';
import 'player_state.dart';

/// Thrown when an incoming frame is not a valid protocol message.
class ProtocolException implements Exception {
  ProtocolException(this.message);
  final String message;
  @override
  String toString() => 'ProtocolException: $message';
}

Map<String, Object?> _decodeObject(String raw) {
  final Object? decoded;
  try {
    decoded = jsonDecode(raw);
  } on FormatException catch (e) {
    throw ProtocolException('invalid JSON: ${e.message}');
  }
  if (decoded is! Map<String, Object?>) {
    throw ProtocolException('expected a JSON object');
  }
  return decoded;
}

T _field<T>(Map<String, Object?> json, String key) {
  final value = json[key];
  if (value is! T) throw ProtocolException('missing or invalid "$key"');
  return value;
}

Emote _emote(Map<String, Object?> json) {
  final name = _field<String>(json, 'e');
  return Emote.tryParse(name) ??
      (throw ProtocolException('unknown emote: $name'));
}

double _number(Map<String, Object?> json, String key) {
  final value = _field<num>(json, key).toDouble();
  if (!value.isFinite) throw ProtocolException('"$key" must be finite');
  return value;
}

// ---------------------------------------------------------------------------
// Client -> server
// ---------------------------------------------------------------------------

sealed class ClientMessage {
  const ClientMessage();

  Map<String, Object?> toJson();
  String encode() => jsonEncode(toJson());

  static ClientMessage decode(String raw) {
    final json = _decodeObject(raw);
    return switch (json['t']) {
      'join' => JoinMessage(_field<String>(json, 'name')),
      'move' => MoveMessage(_number(json, 'x'), _number(json, 'y')),
      'chat' => ChatMessage(_field<String>(json, 'text')),
      'emote' => EmoteMessage(_emote(json)),
      final t => throw ProtocolException('unknown client message type: $t'),
    };
  }
}

/// First message a client must send.
class JoinMessage extends ClientMessage {
  const JoinMessage(this.name);
  final String name;
  @override
  Map<String, Object?> toJson() => {'t': 'join', 'name': name};
}

/// Request to walk to a world position.
class MoveMessage extends ClientMessage {
  const MoveMessage(this.x, this.y);
  final double x;
  final double y;
  @override
  Map<String, Object?> toJson() => {'t': 'move', 'x': x, 'y': y};
}

class ChatMessage extends ClientMessage {
  const ChatMessage(this.text);
  final String text;
  @override
  Map<String, Object?> toJson() => {'t': 'chat', 'text': text};
}

class EmoteMessage extends ClientMessage {
  const EmoteMessage(this.emote);
  final Emote emote;
  @override
  Map<String, Object?> toJson() => {'t': 'emote', 'e': emote.name};
}

// ---------------------------------------------------------------------------
// Server -> client
// ---------------------------------------------------------------------------

sealed class ServerMessage {
  const ServerMessage();

  Map<String, Object?> toJson();
  String encode() => jsonEncode(toJson());

  static ServerMessage decode(String raw) {
    final json = _decodeObject(raw);
    try {
      return switch (json['t']) {
        'welcome' => WelcomeMessage(
          selfId: _field<String>(json, 'selfId'),
          players: _field<List<Object?>>(json, 'players')
              .map((p) => PlayerState.fromJson(p as Map<String, Object?>))
              .toList(),
        ),
        'joined' => PlayerJoinedMessage(
          PlayerState.fromJson(_field<Map<String, Object?>>(json, 'player')),
        ),
        'left' => PlayerLeftMessage(_field<String>(json, 'id')),
        'moved' => PlayerMovedMessage(
          _field<String>(json, 'id'),
          _number(json, 'x'),
          _number(json, 'y'),
        ),
        'chat' => PlayerChatMessage(
          _field<String>(json, 'id'),
          _field<String>(json, 'text'),
        ),
        'emoted' => PlayerEmotedMessage(
          _field<String>(json, 'id'),
          _emote(json),
        ),
        'error' => ErrorMessage(_field<String>(json, 'reason')),
        final t => throw ProtocolException('unknown server message type: $t'),
      };
    } on TypeError catch (e) {
      throw ProtocolException('malformed message: $e');
    }
  }
}

/// Sent once after a successful join: who you are and who is already here.
class WelcomeMessage extends ServerMessage {
  const WelcomeMessage({required this.selfId, required this.players});
  final String selfId;

  /// Everyone in the room, including yourself.
  final List<PlayerState> players;

  @override
  Map<String, Object?> toJson() => {
    't': 'welcome',
    'selfId': selfId,
    'players': [for (final p in players) p.toJson()],
  };
}

class PlayerJoinedMessage extends ServerMessage {
  const PlayerJoinedMessage(this.player);
  final PlayerState player;
  @override
  Map<String, Object?> toJson() => {'t': 'joined', 'player': player.toJson()};
}

class PlayerLeftMessage extends ServerMessage {
  const PlayerLeftMessage(this.id);
  final String id;
  @override
  Map<String, Object?> toJson() => {'t': 'left', 'id': id};
}

/// A player started walking to (x, y).
class PlayerMovedMessage extends ServerMessage {
  const PlayerMovedMessage(this.id, this.x, this.y);
  final String id;
  final double x;
  final double y;
  @override
  Map<String, Object?> toJson() => {'t': 'moved', 'id': id, 'x': x, 'y': y};
}

class PlayerChatMessage extends ServerMessage {
  const PlayerChatMessage(this.id, this.text);
  final String id;
  final String text;
  @override
  Map<String, Object?> toJson() => {'t': 'chat', 'id': id, 'text': text};
}

class PlayerEmotedMessage extends ServerMessage {
  const PlayerEmotedMessage(this.id, this.emote);
  final String id;
  final Emote emote;
  @override
  Map<String, Object?> toJson() => {'t': 'emoted', 'id': id, 'e': emote.name};
}

class ErrorMessage extends ServerMessage {
  const ErrorMessage(this.reason);
  final String reason;
  @override
  Map<String, Object?> toJson() => {'t': 'error', 'reason': reason};
}
