import 'package:flutter/material.dart';

import 'screens/roamly_shell.dart';
import 'theme/roamly_theme.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const RoamlyApp());
}

class RoamlyApp extends StatelessWidget {
  const RoamlyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Roamly',
      theme: buildRoamlyTheme(),
      home: const RoamlyShell(),
    );
  }
}
