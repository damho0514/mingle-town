import 'dart:math';

import 'package:mingle_protocol/mingle_protocol.dart';

typedef SendFn = void Function(ServerMessage message);

/// A single shared space. Holds every joined player and fans out updates.
///
/// Transport-agnostic: each connection is a [Session] created by [connect].
class Room {
  Room({Random? random}) : _random = random ?? Random();

  final Random _random;
  final Map<String, Session> _joined = {};
  int _nextId = 1;

  static const _palette = [
    0xFFFF7043,
    0xFF42A5F5,
    0xFFAB47BC,
    0xFFFFCA28,
    0xFF26A69A,
    0xFFEC407A,
    0xFF8D6E63,
    0xFF5C6BC0,
  ];

  /// Max accepted frame size in characters; larger frames are dropped.
  static const maxFrameLength = 1024;

  int get playerCount => _joined.length;

  Session connect(SendFn send) => Session._(this, send);

  void _join(Session session, String rawName) {
    final id = 'p${_nextId++}';
    final player = PlayerState(
      id: id,
      name: _sanitizeName(rawName, id),
      color: _palette[_random.nextInt(_palette.length)],
      x: Limits.worldWidth / 2 + _random.nextDouble() * 200 - 100,
      y: Limits.worldHeight / 2 + _random.nextDouble() * 200 - 100,
    );
    session._player = player;
    _joined[id] = session;

    session._send(
      WelcomeMessage(
        selfId: id,
        players: [for (final s in _joined.values) s._player!],
      ),
    );
    _broadcast(PlayerJoinedMessage(player), except: session);
  }

  void _move(Session session, double x, double y) {
    final player = session._player!.copyWith(
      x: x.clamp(0, Limits.worldWidth).toDouble(),
      y: y.clamp(0, Limits.worldHeight).toDouble(),
    );
    session._player = player;
    _broadcast(
      PlayerMovedMessage(player.id, player.x, player.y),
      except: session,
    );
  }

  void _chat(Session session, String rawText) {
    final text = _truncate(rawText.trim(), Limits.maxChatLength);
    if (text.isEmpty) return;
    _broadcast(PlayerChatMessage(session._player!.id, text));
  }

  void _leave(Session session) {
    final player = session._player;
    if (player == null || _joined.remove(player.id) == null) return;
    _broadcast(PlayerLeftMessage(player.id));
  }

  void _broadcast(ServerMessage message, {Session? except}) {
    for (final s in _joined.values) {
      if (!identical(s, except)) s._send(message);
    }
  }

  static String _sanitizeName(String raw, String fallbackId) {
    final name = _truncate(
      raw.replaceAll(RegExp(r'\s+'), ' ').trim(),
      Limits.maxNameLength,
    );
    return name.isEmpty ? 'guest-$fallbackId' : name;
  }

  /// Truncates by user-perceived length without splitting surrogate pairs.
  static String _truncate(String s, int max) {
    final runes = s.runes;
    return runes.length <= max ? s : String.fromCharCodes(runes.take(max));
  }
}

/// One client connection to a [Room].
class Session {
  Session._(this._room, this._send);

  final Room _room;
  final SendFn _send;
  PlayerState? _player;
  bool _closed = false;

  PlayerState? get player => _player;

  /// Handles one raw text frame from the client.
  void handle(String raw) {
    if (_closed) return;
    if (raw.length > Room.maxFrameLength) {
      _send(const ErrorMessage('frame too large'));
      return;
    }
    final ClientMessage message;
    try {
      message = ClientMessage.decode(raw);
    } on ProtocolException catch (e) {
      _send(ErrorMessage(e.message));
      return;
    }

    switch (message) {
      case JoinMessage(:final name):
        if (_player != null) {
          _send(const ErrorMessage('already joined'));
        } else {
          _room._join(this, name);
        }
      case MoveMessage(:final x, :final y) when _player != null:
        _room._move(this, x, y);
      case ChatMessage(:final text) when _player != null:
        _room._chat(this, text);
      case MoveMessage() || ChatMessage():
        _send(const ErrorMessage('join first'));
    }
  }

  /// Call when the underlying connection ends. Idempotent.
  void close() {
    if (_closed) return;
    _closed = true;
    _room._leave(this);
  }
}
