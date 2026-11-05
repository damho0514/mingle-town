import 'package:flutter/material.dart';

import 'screens/lobby_screen.dart';

void main() {
  runApp(const MingleTownApp());
}

class MingleTownApp extends StatelessWidget {
  const MingleTownApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Mingle Town',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorSchemeSeed: const Color(0xFF8BC34A),
        useMaterial3: true,
      ),
      home: const LobbyScreen(),
    );
  }
}
