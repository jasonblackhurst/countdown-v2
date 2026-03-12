import 'package:flutter/material.dart';

import 'src/app_navigator.dart';

void main() {
  runApp(
    MaterialApp(
      title: 'Countdown',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.indigo),
        useMaterial3: true,
      ),
      home: CountdownApp(
        serverUri: Uri.parse('ws://localhost:8080/ws'),
      ),
    ),
  );
}
