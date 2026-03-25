import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'src/app_navigator.dart';
import 'src/theme.dart';

const _wsUrl = String.fromEnvironment(
  'WS_URL',
  defaultValue: 'ws://localhost:8080/ws',
);

void main() {
  // On web, check for ?pile=true query parameter
  final isPileMode =
      kIsWeb && Uri.base.queryParameters['pile']?.toLowerCase() == 'true';

  runApp(
    MaterialApp(
      title: 'Countdown',
      theme: countdownTheme(),
      home: CountdownApp(
        serverUri: Uri.parse(_wsUrl),
        pileViewerMode: isPileMode,
      ),
    ),
  );
}
