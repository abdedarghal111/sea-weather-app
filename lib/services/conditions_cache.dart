import 'dart:convert';

import 'package:flutter/foundation.dart' show compute;
import 'package:shared_preferences/shared_preferences.dart';

import '../models/spot.dart';
import '../models/spot_conditions_bundle.dart';
import 'open_meteo_api.dart';

/// Deserializa el bundle completo (hasta ~384 puntos horarios, cada uno con
/// su propio [BeachConditions] anidado) fuera del isolate principal: hecho
/// en el hilo de UI, este `jsonDecode` + reconstrucción de objetos puede
/// bloquear varios frames en un móvil de gama baja. Debe ser una función de
/// nivel superior (no un closure/método de instancia) para poder pasarse a
/// [compute].
SpotConditionsBundle _decodeBundle(String raw) =>
    SpotConditionsBundle.fromJson(jsonDecode(raw) as Map<String, dynamic>);

/// Igual que [_decodeBundle] pero para serializar al guardar en caché.
String _encodeBundle(SpotConditionsBundle bundle) => jsonEncode(bundle.toJson());

/// Cachea las condiciones de cada spot durante [ttl] para no llamar a la API
/// en cada apertura de pantalla.
class ConditionsCache {
  static const ttl = Duration(minutes: 15);

  /// Peticiones en curso por spot, compartidas entre pantallas. Sin esto, dos
  /// reconstrucciones seguidas de la lista lanzan la misma consulta varias
  /// veces y la API responde 429 "too many concurrent requests" a las
  /// sobrantes.
  static final _inFlight = <String, Future<SpotConditionsBundle>>{};

  String _key(String cacheKey) => 'conditions_cache_$cacheKey';

  Future<SpotConditionsBundle?> _readStored(String cacheKey) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key(cacheKey));
    if (raw == null) return null;
    try {
      return await compute(_decodeBundle, raw);
    } catch (_) {
      // Caché de un esquema antiguo o corrupta: se trata como si no existiera.
      return null;
    }
  }

  Future<void> _store(String cacheKey, SpotConditionsBundle bundle) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = await compute(_encodeBundle, bundle);
    await prefs.setString(_key(cacheKey), raw);
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

    final pending = _inFlight[spot.cacheKey];
    if (pending != null) return pending;

    final request = _fetchAndStore(spot);
    _inFlight[spot.cacheKey] = request;
    try {
      return await request;
    } finally {
      _inFlight.remove(spot.cacheKey);
    }
  }

  Future<SpotConditionsBundle> _fetchAndStore(Spot spot) async {
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
