import 'dart:async';
import 'dart:math';

import 'package:mingle_protocol/mingle_protocol.dart';

import 'lobby.dart';
import 'session.dart';

/// A shared space: tracks its players, fans out updates and runs tag rounds.
class Room {
  Room(this.id, this._lobby);

  final String id;
  final Lobby _lobby;
  final Map<String, Session> _joined = {};

  // Tag round state.
  String? _itId;
  DateTime? _tagEndsAt;
  DateTime _tagCooldownUntil = DateTime.fromMillisecondsSinceEpoch(0);
  Timer? _tagTimer;

  int get playerCount => _joined.length;
  bool get tagRunning => _tagEndsAt != null;
  String? get itId => _itId;

  Iterable<PlayerState> get players => _joined.values.map((s) => s.player!);

  void join(Session session, JoinMessage message) {
    final random = _lobby.random;
    final id = _lobby.nextPlayerId();
    // Spawn on a ring around the central plaza's fountain.
    final angle = random.nextDouble() * 2 * pi;
    final distance = 90 + random.nextDouble() * 70;
    final player = PlayerState(
      id: id,
      name: _sanitizeName(message.name, id),
      color: Palette.isValid(message.color ?? 0)
          ? message.color!
          : Palette.colors[random.nextInt(Palette.colors.length)],
      hat: message.hat,
      x: WorldMap.center.x + cos(angle) * distance,
      y: WorldMap.center.y + sin(angle) * distance,
    );
    session
      ..player = player
      ..room = this;
    _joined[id] = session;

    session.send(
      WelcomeMessage(
        selfId: id,
        room: this.id,
        players: players.toList(),
        tag: tagRunning
            ? TagMessage(
                phase: TagPhase.started,
                itId: _itId,
                remainingMs: _remainingMs,
              )
            : null,
      ),
    );
    _broadcast(PlayerJoinedMessage(player), except: session);
  }

  void move(Session session, double x, double y) {
    final p = WorldMap.instance.resolve((x: x, y: y));
    final player = session.player!.copyWith(x: p.x, y: p.y);
    session.player = player;
    _broadcast(
      PlayerMovedMessage(player.id, player.x, player.y),
      except: session,
    );
    if (tagRunning) _checkTag(player);
  }

  void chat(Session session, String rawText) {
    final text = _truncate(rawText.trim(), Limits.maxChatLength);
    if (text.isEmpty) return;
    _broadcast(PlayerChatMessage(session.player!.id, text));
  }

  void emote(Session session, Emote emote) {
    _broadcast(PlayerEmotedMessage(session.player!.id, emote));
  }

  void leave(Session session) {
    final player = session.player;
    if (player == null || _joined.remove(player.id) == null) return;
    _broadcast(PlayerLeftMessage(player.id));

    if (!tagRunning) return;
    if (playerCount < TagRules.minPlayers) {
      _endTag(loserId: null);
    } else if (player.id == _itId) {
      // The tagger ran away: hand "it" to someone else.
      _itId = _randomPlayerId();
      _tagCooldownUntil = _lobby.clock().add(TagRules.cooldown);
      _broadcast(
        TagMessage(
          phase: TagPhase.tagged,
          itId: _itId,
          remainingMs: _remainingMs,
        ),
      );
    }
  }

  // ---------------------------------------------------------------------------
  // Tag
  // ---------------------------------------------------------------------------

  void startTag(Session session) {
    if (tagRunning) {
      session.send(const ErrorMessage('tag already running'));
      return;
    }
    if (playerCount < TagRules.minPlayers) {
      session.send(const ErrorMessage('need more players'));
      return;
    }
    final now = _lobby.clock();
    _itId = _randomPlayerId();
    _tagEndsAt = now.add(TagRules.roundLength);
    // Give everyone a head start before the first tag can land.
    _tagCooldownUntil = now.add(TagRules.cooldown);
    _tagTimer = _lobby.timer(
      TagRules.roundLength,
      () => _endTag(loserId: _itId),
    );
    _broadcast(
      TagMessage(
        phase: TagPhase.started,
        itId: _itId,
        remainingMs: _remainingMs,
      ),
    );
  }

  void _checkTag(PlayerState mover) {
    final now = _lobby.clock();
    if (now.isBefore(_tagCooldownUntil)) return;
    final it = _joined[_itId]?.player;
    if (it == null) return;

    final candidates = mover.id == it.id
        ? players.where((p) => p.id != it.id)
        : [mover];
    for (final target in candidates) {
      final d = sqrt(pow(target.x - it.x, 2) + pow(target.y - it.y, 2));
      if (d <= TagRules.reach) {
        _itId = target.id;
        _tagCooldownUntil = now.add(TagRules.cooldown);
        _broadcast(
          TagMessage(
            phase: TagPhase.tagged,
            itId: target.id,
            byId: it.id,
            remainingMs: _remainingMs,
          ),
        );
        return;
      }
    }
  }

  void _endTag({required String? loserId}) {
    _tagTimer?.cancel();
    _tagTimer = null;
    _tagEndsAt = null;
    _itId = null;
    _broadcast(TagMessage(phase: TagPhase.ended, itId: loserId));
  }

  int get _remainingMs {
    final endsAt = _tagEndsAt;
    if (endsAt == null) return 0;
    return max(0, endsAt.difference(_lobby.clock()).inMilliseconds);
  }

  String _randomPlayerId() {
    final ids = _joined.keys.toList();
    return ids[_lobby.random.nextInt(ids.length)];
  }

  // ---------------------------------------------------------------------------

  void _broadcast(ServerMessage message, {Session? except}) {
    for (final s in _joined.values) {
      if (!identical(s, except)) s.send(message);
    }
  }

  static String _sanitizeName(String raw, String fallbackId) {
    final name = _truncate(
      raw.replaceAll(RegExp(r'\s+'), ' ').trim(),
      Limits.maxNameLength,
    );
    return name.isEmpty ? 'guest-$fallbackId' : name;
  }

  /// Truncates by code point without splitting surrogate pairs.
  static String _truncate(String s, int max) {
    final runes = s.runes;
    return runes.length <= max ? s : String.fromCharCodes(runes.take(max));
  }
}
