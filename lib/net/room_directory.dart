import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:mingle_protocol/mingle_protocol.dart';

typedef RoomFetcher = Future<List<RoomInfo>> Function(Uri serverUri);

/// Reads `GET /rooms` from the game server behind a ws:// or wss:// URL.
Future<List<RoomInfo>> fetchRooms(Uri serverUri, {http.Client? client}) async {
  final url = serverUri.replace(
    scheme: serverUri.scheme == 'wss' ? 'https' : 'http',
    path: '/rooms',
  );
  final c = client ?? http.Client();
  try {
    final res = await c.get(url).timeout(const Duration(seconds: 3));
    if (res.statusCode != 200) throw StateError('HTTP ${res.statusCode}');
    final body = jsonDecode(res.body) as Map<String, Object?>;
    return [
      for (final r in body['rooms'] as List)
        RoomInfo.fromJson(r as Map<String, Object?>),
    ];
  } finally {
    if (client == null) c.close();
  }
}
