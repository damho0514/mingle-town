import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:mingle_protocol/mingle_protocol.dart';

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
          Positioned.fill(child: GameWidget(game: _game)),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(8),
              child: IconButton.filledTonal(
                tooltip: '나가기',
                icon: const Icon(Icons.arrow_back),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ),
          ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: EdgeInsets.fromLTRB(
            12,
            8,
            12,
            8 + MediaQuery.viewInsetsOf(context).bottom,
          ),
          child: Row(
            children: [
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
        ),
      ),
    );
  }
}
