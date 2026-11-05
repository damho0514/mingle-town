import 'dart:io';

/// Default server address. Override with `--dart-define=SERVER_URL=ws://...`.
///
/// The Android emulator reaches the host machine via 10.0.2.2; the iOS
/// simulator shares the host's localhost. Real devices need the host's LAN IP.
String defaultServerUrl() {
  const fromEnv = String.fromEnvironment('SERVER_URL');
  if (fromEnv.isNotEmpty) return fromEnv;
  return Platform.isAndroid ? 'ws://10.0.2.2:8080' : 'ws://localhost:8080';
}
