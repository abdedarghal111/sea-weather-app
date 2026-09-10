// Persistencia de las localidades guardadas por el usuario.

import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/location.dart';

class LocationsRepository {
  // Cambiar este valor dejaría inaccesibles las localidades ya guardadas en
  // el dispositivo.
  static const _storageKey = 'saved_spots';

  Future<List<Location>> loadLocations() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_storageKey);
    if (raw == null) return [];

    final list = jsonDecode(raw) as List<dynamic>;
    return list.map((e) => Location.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<void> addLocation(Location location) async {
    final locations = await loadLocations();
    locations.add(location);
    await _save(locations);
  }

  Future<void> removeLocation(String id) async {
    final locations = await loadLocations();
    locations.removeWhere((l) => l.id == id);
    await _save(locations);
  }

  Future<void> renameLocation(String id, String name) async {
    final locations = await loadLocations();
    final index = locations.indexWhere((l) => l.id == id);
    if (index == -1) return;
    locations[index] = locations[index].copyWith(name: name);
    await _save(locations);
  }

  // El orden de la lista guardada es el que ve el usuario en la pantalla
  // principal, así que reordenarla es todo lo que hay que persistir.
  Future<void> saveOrder(List<Location> locations) => _save(locations);

  Future<void> _save(List<Location> locations) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = jsonEncode(locations.map((l) => l.toJson()).toList());
    await prefs.setString(_storageKey, raw);
  }
}
