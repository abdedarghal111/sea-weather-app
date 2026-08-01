import 'package:flutter/material.dart';

import 'screens/spots_list_screen.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Tiempo de playa',
      theme: ThemeData(colorSchemeSeed: Colors.blue, useMaterial3: true),
      home: const SpotsListScreen(),
    );
  }
}
