import 'package:mingle_protocol/mingle_protocol.dart';

import 'lobby.dart';
import 'room.dart';

typedef SendFn = void Function(ServerMessage message);

/// One client connection. Validates and rate-limits input, then forwards it
/// to the [Room] the client joined.
class Session {
  Session(this._lobby, this.send);

  /// Max accepted frame size in characters; larger frames are dropped.
  static const maxFrameLength = 1024;

  final Lobby _lobby;
  final SendFn send;

  Room? room;
  PlayerState? player;
  bool _closed = false;
  final List<DateTime> _recentSocial = [];
  final List<DateTime> _recentMoves = [];

  /// Handles one raw text frame from the client.
  void handle(String raw) {
    if (_closed) return;
    if (raw.length > maxFrameLength) {
      send(const ErrorMessage('frame too large'));
      return;
    }
    final ClientMessage message;
    try {
      message = ClientMessage.decode(raw);
    } on ProtocolException catch (e) {
      send(ErrorMessage(e.message));
      return;
    }

    final room = this.room;
    if (message is JoinMessage) {
      _join(message);
    } else if (room == null) {
      send(const ErrorMessage('join first'));
    } else {
      switch (message) {
        case MoveMessage(:final x, :final y):
          if (_allow(
            _recentMoves,
            MoveRateLimit.perSecond,
            const Duration(seconds: 1),
          )) {
            room.move(this, x, y);
          }
        case ChatMessage(:final text):
          if (_allowSocial()) room.chat(this, text);
        case EmoteMessage(:final emote):
          if (_allowSocial()) room.emote(this, emote);
        case StartTagMessage():
          room.startTag(this);
        case JoinMessage():
          break; // handled above
      }
    }
  }

  void _join(JoinMessage message) {
    if (room != null) {
      send(const ErrorMessage('already joined'));
      return;
    }
    final target = _lobby.rooms[message.room];
    if (target == null) {
      send(const ErrorMessage('unknown room'));
    } else if (target.playerCount >= Rooms.capacity) {
      send(const ErrorMessage('room full'));
    } else {
      target.join(this, message);
    }
  }

  bool _allowSocial() {
    if (_allow(_recentSocial, SocialRateLimit.burst, SocialRateLimit.window)) {
      return true;
    }
    send(const ErrorMessage('slow down'));
    return false;
  }

  /// Sliding-window limiter.
  bool _allow(List<DateTime> recent, int max, Duration window) {
    final now = _lobby.clock();
    recent.removeWhere((t) => now.difference(t) >= window);
    if (recent.length >= max) return false;
    recent.add(now);
    return true;
  }

  /// Call when the underlying connection ends. Idempotent.
  void close() {
    if (_closed) return;
    _closed = true;
    room?.leave(this);
  }
}
