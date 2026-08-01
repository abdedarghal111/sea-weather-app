import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/spot.dart';
import '../models/spot_conditions_bundle.dart';
import 'open_meteo_api.dart';

/// Cachea las condiciones de cada spot durante [ttl] para no llamar a la API
/// en cada apertura de pantalla.
class ConditionsCache {
  static const ttl = Duration(minutes: 15);

  String _key(String cacheKey) => 'conditions_cache_$cacheKey';

  Future<SpotConditionsBundle?> _readStored(String cacheKey) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key(cacheKey));
    if (raw == null) return null;
    try {
      return SpotConditionsBundle.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    } catch (_) {
      // Caché de un esquema antiguo o corrupta: se trata como si no existiera.
      return null;
    }
  }

  Future<void> _store(String cacheKey, SpotConditionsBundle bundle) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key(cacheKey), jsonEncode(bundle.toJson()));
  }

  /// Devuelve condiciones para [spot]: usa la caché si tiene menos de 15
  /// minutos, o llama a la API y actualiza la caché en caso contrario.
  /// Con [forceRefresh] se ignora la caché (pull-to-refresh).
  Future<SpotConditionsBundle> getConditions(Spot spot, {bool forceRefresh = false}) async {
    if (!forceRefresh) {
      final cached = await _readStored(spot.cacheKey);
      if (cached != null && DateTime.now().difference(cached.current.fetchedAt) < ttl) {
        return cached;
      }
    }

    try {
      final fresh = await OpenMeteoApi.fetchConditionsBundle(spot);
      await _store(spot.cacheKey, fresh);
      return fresh;
    } catch (_) {
      final stale = await _readStored(spot.cacheKey);
      if (stale != null) return stale;
      rethrow;
    }
  }
}
