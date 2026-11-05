import 'package:flutter/material.dart';
import 'package:mingle_protocol/mingle_protocol.dart';

import '../config.dart';
import '../net/game_connection.dart';
import 'game_screen.dart';

typedef Connector = Future<GameConnection> Function(Uri uri);

class LobbyScreen extends StatefulWidget {
  const LobbyScreen({super.key, this.connector = _defaultConnector});

  final Connector connector;

  static Future<GameConnection> _defaultConnector(Uri uri) =>
      WebSocketGameConnection.connect(uri);

  @override
  State<LobbyScreen> createState() => _LobbyScreenState();
}

class _LobbyScreenState extends State<LobbyScreen> {
  final _name = TextEditingController();
  final _server = TextEditingController(text: defaultServerUrl());
  bool _connecting = false;
  String? _error;

  @override
  void dispose() {
    _name.dispose();
    _server.dispose();
    super.dispose();
  }

  Future<void> _enter() async {
    final name = _name.text.trim();
    final uri = Uri.tryParse(_server.text.trim());
    if (name.isEmpty) {
      setState(() => _error = '닉네임을 입력해 주세요.');
      return;
    }
    if (uri == null || !(uri.scheme == 'ws' || uri.scheme == 'wss')) {
      setState(() => _error = '서버 주소는 ws:// 또는 wss:// 로 시작해야 해요.');
      return;
    }

    setState(() {
      _connecting = true;
      _error = null;
    });
    try {
      final connection = await widget.connector(uri);
      if (!mounted) {
        await connection.close();
        return;
      }
      await Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => GameScreen(connection: connection, playerName: name),
        ),
      );
    } catch (_) {
      if (mounted) setState(() => _error = '서버에 연결할 수 없어요.');
    } finally {
      if (mounted) setState(() => _connecting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 360),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'Mingle Town',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.headlineMedium,
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    '캐릭터로 다른 사람들과 함께 놀아요',
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 32),
                  TextField(
                    controller: _name,
                    maxLength: Limits.maxNameLength,
                    textInputAction: TextInputAction.go,
                    onSubmitted: (_) => _enter(),
                    decoration: const InputDecoration(
                      labelText: '닉네임',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _server,
                    keyboardType: TextInputType.url,
                    autocorrect: false,
                    decoration: const InputDecoration(
                      labelText: '서버 주소',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  if (_error != null) ...[
                    const SizedBox(height: 12),
                    Text(
                      _error!,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                  ],
                  const SizedBox(height: 20),
                  FilledButton(
                    onPressed: _connecting ? null : _enter,
                    child: _connecting
                        ? const SizedBox.square(
                            dimension: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text('입장하기'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
