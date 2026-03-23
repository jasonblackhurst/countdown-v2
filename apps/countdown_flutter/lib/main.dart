import 'package:flutter/material.dart';

import 'src/app_navigator.dart';
import 'src/theme.dart';

const _wsUrl = String.fromEnvironment(
  'WS_URL',
  defaultValue: 'ws://localhost:8080/ws',
);

void main() {
  runApp(
    MaterialApp(
      title: 'Countdown',
      theme: countdownTheme(),
      home: CountdownApp(serverUri: Uri.parse(_wsUrl)),
    ),
  );
}
