import 'dart:async';

import 'package:flame/game.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:mingle_protocol/mingle_protocol.dart';

import '../audio/game_audio.dart';
import '../game/character.dart';
import '../game/mingle_town_game.dart';
import '../net/game_connection.dart';
import '../prefs.dart';

bool get isTouchPlatform =>
    defaultTargetPlatform == TargetPlatform.android ||
    defaultTargetPlatform == TargetPlatform.iOS;

class GameScreen extends StatefulWidget {
  const GameScreen({
    super.key,
    required this.connection,
    required this.join,
    this.audio,
    this.prefs,
    this.touchControls,
  });

  final GameConnection connection;
  final JoinMessage join;
  final GameAudio? audio;
  final PlayerPrefs? prefs;

  /// Show the joystick; defaults to on for phones and tablets.
  final bool? touchControls;

  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen> {
  late final GameAudio _audio = widget.audio ?? SilentAudio();
  late final bool _touch = widget.touchControls ?? isTouchPlatform;
  late final MingleTownGame _game = MingleTownGame(
    connection: widget.connection,
    join: widget.join,
    audio: _audio,
    touchControls: _touch,
    onChatRequested: () => _chatFocus.requestFocus(),
  );
  final _chat = TextEditingController();
  final _gameFocus = FocusNode(debugLabel: 'game');
  final _chatFocus = FocusNode(debugLabel: 'chat');
  StreamSubscription<String>? _noticeSub;
  Timer? _noticeTimer;
  String? _notice;
  bool _leaving = false;
  bool _showEmotes = false;

  @override
  void initState() {
    super.initState();
    _audio.startMusic();
    _noticeSub = _game.notices.listen(_showNotice);
    widget.connection.done.then((_) {
      if (!mounted || _leaving) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('서버와 연결이 끊어졌어요.')));
      Navigator.of(context).pop();
    });
  }

  @override
  void dispose() {
    _leaving = true;
    _audio.stopMusic();
    unawaited(_audio.dispose());
    widget.connection.close();
    _noticeSub?.cancel();
    _noticeTimer?.cancel();
    _chat.dispose();
    _gameFocus.dispose();
    _chatFocus.dispose();
    super.dispose();
  }

  void _showNotice(String text) {
    setState(() => _notice = text);
    _noticeTimer?.cancel();
    _noticeTimer = Timer(const Duration(seconds: 3), () {
      if (mounted) setState(() => _notice = null);
    });
  }

  void _send() {
    _game.sendChat(_chat.text);
    _chat.clear();
    // Back to the game so WASD moves again (desktop/web).
    if (!_touch) _gameFocus.requestFocus();
  }

  void _toggleMute() {
    final muted = !_audio.muted.value;
    _audio.isMuted = muted;
    final prefs = widget.prefs;
    if (prefs != null) {
      prefs.muted = muted;
      unawaited(prefs.save());
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // Every child is positioned so the Stack fills the body; a
          // non-positioned child would shrink it (and the game) to its size.
          Positioned.fill(
            child: ClipRect(
              child: Listener(
                onPointerDown: (_) {
                  if (!_gameFocus.hasFocus) _gameFocus.requestFocus();
                },
                child: GameWidget(
                  game: _game,
                  focusNode: _gameFocus,
                  autofocus: true,
                ),
              ),
            ),
          ),
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(8),
                child: Column(
                  children: [
                    _topBar(context),
                    const SizedBox(height: 6),
                    ValueListenableBuilder<TagStatus?>(
                      valueListenable: _game.tag,
                      builder: (context, tag, _) => tag == null
                          ? const SizedBox.shrink()
                          : _TagBanner(status: tag, selfId: _game.selfId),
                    ),
                    AnimatedSwitcher(
                      duration: const Duration(milliseconds: 200),
                      child: _notice == null
                          ? const SizedBox.shrink()
                          : Padding(
                              key: ValueKey(_notice),
                              padding: const EdgeInsets.only(top: 6),
                              child: _Pill(
                                text: _notice!,
                                color: Colors.black.withValues(alpha: 0.7),
                              ),
                            ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          if (!_touch)
            const Positioned(
              right: 12,
              bottom: 8,
              child: Text(
                'WASD·방향키 이동 · 클릭 이동 · Enter 채팅',
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 12,
                  shadows: [Shadow(blurRadius: 3)],
                ),
              ),
            ),
        ],
      ),
      bottomNavigationBar: _chatBar(context),
    );
  }

  Widget _topBar(BuildContext context) {
    return Row(
      children: [
        IconButton.filledTonal(
          tooltip: '나가기',
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
        ),
        const SizedBox(width: 6),
        ValueListenableBuilder<int>(
          valueListenable: _game.playerCount,
          builder: (context, count, _) => Chip(
            avatar: const Icon(Icons.people_alt, size: 18),
            label: Text('${Rooms.label(widget.join.room)} · $count명'),
          ),
        ),
        const Spacer(),
        ValueListenableBuilder<int>(
          valueListenable: _game.playerCount,
          builder: (context, count, _) => ValueListenableBuilder<TagStatus?>(
            valueListenable: _game.tag,
            builder: (context, tag, _) => IconButton.filledTonal(
              tooltip: '술래잡기 시작',
              icon: const Icon(Icons.directions_run),
              onPressed: tag == null && count >= TagRules.minPlayers
                  ? _game.startTag
                  : null,
            ),
          ),
        ),
        const SizedBox(width: 6),
        ValueListenableBuilder<bool>(
          valueListenable: _audio.muted,
          builder: (context, muted, _) => IconButton.filledTonal(
            tooltip: muted ? '소리 켜기' : '소리 끄기',
            icon: Icon(muted ? Icons.volume_off : Icons.volume_up),
            onPressed: _toggleMute,
          ),
        ),
      ],
    );
  }

  Widget _chatBar(BuildContext context) {
    return Material(
      color: Theme.of(context).colorScheme.surface,
      child: SafeArea(
        child: Padding(
          padding: EdgeInsets.fromLTRB(
            12,
            8,
            12,
            8 + MediaQuery.viewInsetsOf(context).bottom,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (_showEmotes)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      for (final e in Emote.values)
                        IconButton(
                          tooltip: e.name,
                          onPressed: () => _game.sendEmote(e),
                          icon: Text(
                            Character.emojiFor(e),
                            style: const TextStyle(fontSize: 26),
                          ),
                        ),
                    ],
                  ),
                ),
              Row(
                children: [
                  IconButton(
                    tooltip: '감정 표현',
                    isSelected: _showEmotes,
                    icon: const Icon(Icons.emoji_emotions_outlined),
                    selectedIcon: const Icon(Icons.emoji_emotions),
                    onPressed: () => setState(() => _showEmotes = !_showEmotes),
                  ),
                  Expanded(
                    child: TextField(
                      controller: _chat,
                      focusNode: _chatFocus,
                      maxLength: Limits.maxChatLength,
                      textInputAction: TextInputAction.send,
                      onSubmitted: (_) => _send(),
                      decoration: const InputDecoration(
                        hintText: '메시지 보내기',
                        counterText: '',
                        isDense: true,
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton.filled(
                    tooltip: '보내기',
                    icon: const Icon(Icons.send),
                    onPressed: _send,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// "술래: X · 42초", ticking down.
class _TagBanner extends StatefulWidget {
  const _TagBanner({required this.status, required this.selfId});
  final TagStatus status;
  final String? selfId;

  @override
  State<_TagBanner> createState() => _TagBannerState();
}

class _TagBannerState extends State<_TagBanner> {
  late final Timer _tick;

  @override
  void initState() {
    super.initState();
    _tick = Timer.periodic(
      const Duration(milliseconds: 250),
      (_) => setState(() {}),
    );
  }

  @override
  void dispose() {
    _tick.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.status;
    final left = s.endsAt.difference(DateTime.now());
    final secs = left.isNegative ? 0 : (left.inMilliseconds / 1000).ceil();
    final me = s.itId != null && s.itId == widget.selfId;
    return _Pill(
      text: me
          ? '🏃 내가 술래! 다른 사람을 잡으세요 · $secs초'
          : '🏃 술래: ${s.itName} · 도망치세요! · $secs초',
      color: const Color(0xE6D50000),
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill({required this.text, required this.color});
  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
