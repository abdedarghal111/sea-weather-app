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
      // Sin esto, en Android moderno (edge-to-edge por defecto) el contenido
      // se dibuja detrás de la barra de navegación del sistema (los 3
      // botones clásicos o el gesto inferior). El AppBar de cada pantalla ya
      // respeta la barra de estado superior por sí solo, así que aquí solo
      // hace falta reservar espacio abajo (y a los lados, por si acaso).
      builder: (context, child) => SafeArea(top: false, child: child!),
      home: const SavedLocationsScreen(),
    );
  }
}
