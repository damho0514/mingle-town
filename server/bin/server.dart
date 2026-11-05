import 'dart:io';

import 'package:mingle_server/mingle_server.dart';

Future<void> main() async {
  final port = int.tryParse(Platform.environment['PORT'] ?? '') ?? 8080;
  final server = await startServer(port: port);
  stdout.writeln(
    'Mingle Town server listening on ws://${server.address.host}:${server.port}',
  );
}
