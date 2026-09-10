// Punto de entrada de la app: tema global y pantalla inicial.

import 'package:flutter/material.dart';

import 'screens/saved_locations_screen.dart';

void main() {
  runApp(const SeaWeatherApp());
}

class SeaWeatherApp extends StatelessWidget {
  const SeaWeatherApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Tiempo de playa',
      theme: ThemeData(colorSchemeSeed: Colors.blue, useMaterial3: true),
      // En Android edge-to-edge el contenido queda bajo la barra de
      // navegación; arriba ya lo resuelve el AppBar de cada pantalla.
      builder: (context, child) => SafeArea(top: false, child: child!),
      home: const SavedLocationsScreen(),
    );
  }
}
