import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:mingle_protocol/mingle_protocol.dart';

import '../game/character.dart';
import '../game/mingle_town_game.dart';
import '../net/game_connection.dart';

class GameScreen extends StatefulWidget {
  const GameScreen({
    super.key,
    required this.connection,
    required this.playerName,
  });

  final GameConnection connection;
  final String playerName;

  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen> {
  late final MingleTownGame _game = MingleTownGame(
    connection: widget.connection,
    playerName: widget.playerName,
  );
  final _chat = TextEditingController();
  bool _leaving = false;
  bool _showEmotes = false;

  @override
  void initState() {
    super.initState();
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
    widget.connection.close();
    _chat.dispose();
    super.dispose();
  }

  void _send() {
    _game.sendChat(_chat.text);
    _chat.clear();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // Every child is positioned so the Stack fills the body; a
          // non-positioned child would shrink it (and the game) to its size.
          Positioned.fill(
            child: ClipRect(child: GameWidget(game: _game)),
          ),
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(8),
                child: Row(
                  children: [
                    IconButton.filledTonal(
                      tooltip: '나가기',
                      icon: const Icon(Icons.arrow_back),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                    const Spacer(),
                    ValueListenableBuilder<int>(
                      valueListenable: _game.playerCount,
                      builder: (context, count, _) => Chip(
                        avatar: const Icon(Icons.people_alt, size: 18),
                        label: Text('$count명 접속 중'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
      bottomNavigationBar: Material(
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
                      onPressed: () =>
                          setState(() => _showEmotes = !_showEmotes),
                    ),
                    Expanded(
                      child: TextField(
                        controller: _chat,
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
      ),
    );
  }
}
