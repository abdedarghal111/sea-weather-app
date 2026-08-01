import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/spot.dart';

class SpotsRepository {
  static const _storageKey = 'saved_spots';

  Future<List<Spot>> loadSpots() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_storageKey);
    if (raw == null) return [];

    final list = jsonDecode(raw) as List<dynamic>;
    return list.map((e) => Spot.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<void> addSpot(Spot spot) async {
    final spots = await loadSpots();
    spots.add(spot);
    await _save(spots);
  }

  Future<void> removeSpot(String id) async {
    final spots = await loadSpots();
    spots.removeWhere((s) => s.id == id);
    await _save(spots);
  }

  Future<void> _save(List<Spot> spots) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = jsonEncode(spots.map((s) => s.toJson()).toList());
    await prefs.setString(_storageKey, raw);
  }
}
