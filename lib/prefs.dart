import 'package:mingle_protocol/mingle_protocol.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Lobby choices remembered between launches.
class PlayerPrefs {
  PlayerPrefs({
    this.name = '',
    int? color,
    this.hat = Hat.none,
    this.room = Rooms.defaultId,
    this.serverUrl,
    this.muted = false,
  }) : color = color ?? Palette.colors.first;

  String name;
  int color;
  Hat hat;
  String room;
  String? serverUrl;
  bool muted;

  static const _prefix = 'mingle.';

  static Future<PlayerPrefs> load() async {
    try {
      final p = await SharedPreferences.getInstance();
      final color = p.getInt('${_prefix}color');
      final room = p.getString('${_prefix}room');
      return PlayerPrefs(
        name: p.getString('${_prefix}name') ?? '',
        color: color != null && Palette.isValid(color) ? color : null,
        hat: Hat.tryParse(p.getString('${_prefix}hat') ?? '') ?? Hat.none,
        room: Rooms.ids.contains(room) ? room! : Rooms.defaultId,
        serverUrl: p.getString('${_prefix}server'),
        muted: p.getBool('${_prefix}muted') ?? false,
      );
    } catch (_) {
      return PlayerPrefs();
    }
  }

  Future<void> save() async {
    try {
      final p = await SharedPreferences.getInstance();
      await p.setString('${_prefix}name', name);
      await p.setInt('${_prefix}color', color);
      await p.setString('${_prefix}hat', hat.name);
      await p.setString('${_prefix}room', room);
      if (serverUrl != null) await p.setString('${_prefix}server', serverUrl!);
      await p.setBool('${_prefix}muted', muted);
    } catch (_) {
      // Preferences are a convenience; never block playing on them.
    }
  }
}
