import 'package:flutter/foundation.dart';

/// Default server address. Override with `--dart-define=SERVER_URL=ws://...`.
///
/// - Web: same host that served the page, port 8080.
/// - Android emulator: the host machine is reachable at 10.0.2.2.
/// - iOS simulator: shares the host's localhost.
/// Real devices need the host's LAN IP (editable in the lobby).
String defaultServerUrl() {
  const fromEnv = String.fromEnvironment('SERVER_URL');
  if (fromEnv.isNotEmpty) return fromEnv;
  if (kIsWeb) {
    final host = Uri.base.host.isEmpty ? 'localhost' : Uri.base.host;
    return 'ws://$host:8080';
  }
  return defaultTargetPlatform == TargetPlatform.android
      ? 'ws://10.0.2.2:8080'
      : 'ws://localhost:8080';
}
