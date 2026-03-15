import 'package:flutter/material.dart';

import 'src/app_navigator.dart';

const _wsUrl = String.fromEnvironment(
  'WS_URL',
  defaultValue: 'ws://localhost:8080/ws',
);

void main() {
  runApp(
    MaterialApp(
      title: 'Countdown',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.indigo),
        useMaterial3: true,
      ),
      home: CountdownApp(
        serverUri: Uri.parse(_wsUrl),
      ),
    ),
  );
}
