import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/location.dart';

class LocationsRepository {
  // El valor de la clave no se toca aunque el nombre sí: cambiarlo dejaría
  // fuera de alcance las localidades ya guardadas en el dispositivo.
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

  Future<void> _save(List<Location> locations) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = jsonEncode(locations.map((l) => l.toJson()).toList());
    await prefs.setString(_storageKey, raw);
  }
}
