import 'dart:async';

import 'package:flutter/material.dart';
import 'package:mingle_protocol/mingle_protocol.dart';

import '../audio/game_audio.dart';
import '../config.dart';
import '../net/game_connection.dart';
import '../net/room_directory.dart';
import '../prefs.dart';
import '../widgets/avatar_preview.dart';
import 'game_screen.dart';

typedef Connector = Future<GameConnection> Function(Uri uri);

class LobbyScreen extends StatefulWidget {
  const LobbyScreen({
    super.key,
    this.connector = _defaultConnector,
    this.roomFetcher = _defaultRoomFetcher,
    this.loadPrefs = PlayerPrefs.load,
    this.audioFactory = _defaultAudio,
  });

  final Connector connector;
  final RoomFetcher roomFetcher;
  final Future<PlayerPrefs> Function() loadPrefs;
  final GameAudio Function({required bool muted}) audioFactory;

  static Future<GameConnection> _defaultConnector(Uri uri) =>
      WebSocketGameConnection.connect(uri);
  static Future<List<RoomInfo>> _defaultRoomFetcher(Uri uri) => fetchRooms(uri);
  static GameAudio _defaultAudio({required bool muted}) =>
      FlameGameAudio(muted: muted);

  static String hatLabel(Hat hat) => switch (hat) {
    Hat.none => '없음',
    Hat.cap => '캡모자',
    Hat.beanie => '비니',
    Hat.crown => '왕관',
    Hat.bow => '리본',
    Hat.flower => '꽃',
  };

  @override
  State<LobbyScreen> createState() => _LobbyScreenState();
}

class _LobbyScreenState extends State<LobbyScreen> {
  final _name = TextEditingController();
  final _server = TextEditingController(text: defaultServerUrl());
  PlayerPrefs _prefs = PlayerPrefs();
  Map<String, RoomInfo> _rooms = {};
  Timer? _roomRefresh;
  bool _connecting = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    widget.loadPrefs().then((prefs) {
      if (!mounted) return;
      setState(() {
        _prefs = prefs;
        _name.text = prefs.name;
        if (prefs.serverUrl != null) _server.text = prefs.serverUrl!;
      });
      _refreshRooms();
    });
    _roomRefresh = Timer.periodic(
      const Duration(seconds: 5),
      (_) => _refreshRooms(),
    );
  }

  @override
  void dispose() {
    _roomRefresh?.cancel();
    _name.dispose();
    _server.dispose();
    super.dispose();
  }

  Uri? get _serverUri {
    final uri = Uri.tryParse(_server.text.trim());
    final valid = uri != null && (uri.scheme == 'ws' || uri.scheme == 'wss');
    return valid ? uri : null;
  }

  Future<void> _refreshRooms() async {
    final uri = _serverUri;
    if (uri == null) return;
    try {
      final rooms = await widget.roomFetcher(uri);
      if (mounted) setState(() => _rooms = {for (final r in rooms) r.id: r});
    } catch (_) {
      if (mounted) setState(() => _rooms = {});
    }
  }

  Future<void> _enter() async {
    final name = _name.text.trim();
    final uri = _serverUri;
    if (name.isEmpty) {
      setState(() => _error = '닉네임을 입력해 주세요.');
      return;
    }
    if (uri == null) {
      setState(() => _error = '서버 주소는 ws:// 또는 wss:// 로 시작해야 해요.');
      return;
    }

    setState(() {
      _connecting = true;
      _error = null;
    });
    _prefs
      ..name = name
      ..serverUrl = _server.text.trim();
    unawaited(_prefs.save());
    try {
      final connection = await widget.connector(uri);
      final audio = widget.audioFactory(muted: _prefs.muted);
      await audio.load();
      if (!mounted) {
        await connection.close();
        return;
      }
      await Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => GameScreen(
            connection: connection,
            join: JoinMessage(
              name,
              room: _prefs.room,
              color: _prefs.color,
              hat: _prefs.hat,
            ),
            audio: audio,
            prefs: _prefs,
          ),
        ),
      );
      unawaited(_refreshRooms());
    } catch (_) {
      if (mounted) setState(() => _error = '서버에 연결할 수 없어요.');
    } finally {
      if (mounted) setState(() => _connecting = false);
    }
  }

  void _update(void Function() change) {
    setState(change);
    unawaited(_prefs.save());
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'Mingle Town',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.headlineMedium,
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    '캐릭터로 다른 사람들과 함께 놀아요',
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 20),
                  _avatarCard(theme),
                  const SizedBox(height: 16),
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
                  Text('방 선택', style: theme.textTheme.titleSmall),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    children: [for (final id in Rooms.ids) _roomChip(id)],
                  ),
                  ExpansionTile(
                    title: const Text('서버 설정'),
                    tilePadding: EdgeInsets.zero,
                    children: [
                      TextField(
                        controller: _server,
                        keyboardType: TextInputType.url,
                        autocorrect: false,
                        onSubmitted: (_) => _refreshRooms(),
                        decoration: const InputDecoration(
                          labelText: '서버 주소',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 8),
                    ],
                  ),
                  if (_error != null) ...[
                    Text(
                      _error!,
                      style: TextStyle(color: theme.colorScheme.error),
                    ),
                    const SizedBox(height: 12),
                  ],
                  FilledButton(
                    onPressed: _connecting ? null : _enter,
                    style: FilledButton.styleFrom(
                      minimumSize: const Size.fromHeight(48),
                    ),
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

  Widget _avatarCard(ThemeData theme) {
    return Card.outlined(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            AvatarPreview(color: _prefs.color, hat: _prefs.hat),
            const SizedBox(height: 12),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              alignment: WrapAlignment.center,
              children: [
                for (final c in Palette.colors)
                  Semantics(
                    button: true,
                    selected: c == _prefs.color,
                    label: '색상',
                    child: GestureDetector(
                      onTap: () => _update(() => _prefs.color = c),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 150),
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          color: Color(c),
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: c == _prefs.color
                                ? theme.colorScheme.onSurface
                                : Colors.transparent,
                            width: 3,
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              alignment: WrapAlignment.center,
              children: [
                for (final h in Hat.values)
                  ChoiceChip(
                    label: Text(LobbyScreen.hatLabel(h)),
                    selected: h == _prefs.hat,
                    onSelected: (_) => _update(() => _prefs.hat = h),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _roomChip(String id) {
    final info = _rooms[id];
    final full = info?.isFull ?? false;
    return ChoiceChip(
      label: Text(
        info == null
            ? Rooms.label(id)
            : '${Rooms.label(id)} · ${info.count}/${info.capacity}',
      ),
      selected: _prefs.room == id,
      onSelected: full ? null : (_) => _update(() => _prefs.room = id),
    );
  }
}
