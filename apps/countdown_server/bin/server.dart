import 'dart:io';

import 'package:countdown_server/src/server.dart';

void main(List<String> args) async {
  final port = int.parse(Platform.environment['PORT'] ?? '8080');
  final server = await startServer(port);
  print('Countdown server listening on ws://localhost:${server.port}/ws');
}
