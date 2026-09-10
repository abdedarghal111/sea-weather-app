// Caché en disco de la previsión de cada localidad.

import 'dart:convert';

import 'package:flutter/foundation.dart' show compute;
import 'package:shared_preferences/shared_preferences.dart';

import '../models/location.dart';
import '../models/location_forecast.dart';
import 'open_meteo_api.dart';

/// Deserializa la previsión completa (cientos de puntos horarios) fuera del
/// isolate principal, donde bloquearía varios frames. Es una función de
/// nivel superior porque [compute] no admite closures ni métodos.
LocationForecast _decodeForecast(String raw) =>
    LocationForecast.fromJson(jsonDecode(raw) as Map<String, dynamic>);

/// Contrapartida de [_decodeForecast] para guardar en caché.
String _encodeForecast(LocationForecast forecast) => jsonEncode(forecast.toJson());

/// Cachea la previsión de cada localidad durante [ttl] para no llamar a la
/// API en cada apertura de pantalla.
class ForecastCache {
  static const ttl = Duration(minutes: 15);

  /// Peticiones en curso por localidad, compartidas entre pantallas: sin
  /// esto, dos rebuilds seguidos repiten la consulta y la API responde 429.
  static final _inFlight = <String, Future<LocationForecast>>{};

  String _key(String coordinatesKey) => 'conditions_cache_$coordinatesKey';

  Future<LocationForecast?> _readStored(String coordinatesKey) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key(coordinatesKey));
    if (raw == null) return null;
    try {
      return await compute(_decodeForecast, raw);
    } catch (_) {
      // Caché corrupta o de un esquema antiguo: como si no existiera.
      return null;
    }
  }

  Future<void> _store(String coordinatesKey, LocationForecast forecast) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = await compute(_encodeForecast, forecast);
    await prefs.setString(_key(coordinatesKey), raw);
  }

  /// Previsión de [location]: la caché si sigue dentro del [ttl], o una
  /// consulta a la API que la actualiza. Con [forceRefresh] se ignora la
  /// caché (pull-to-refresh).
  Future<LocationForecast> forecastFor(Location location, {bool forceRefresh = false}) async {
    if (!forceRefresh) {
      final cached = await _readStored(location.coordinatesKey);
      if (cached != null && DateTime.now().difference(cached.now.fetchedAt) < ttl) {
        return cached;
      }
    }

    final pending = _inFlight[location.coordinatesKey];
    if (pending != null) return pending;

    final request = _fetchAndStore(location);
    _inFlight[location.coordinatesKey] = request;
    try {
      return await request;
    } finally {
      _inFlight.remove(location.coordinatesKey);
    }
  }

  /// Consulta la API y guarda el resultado; si falla, sirve la caché
  /// caducada antes que dejar la pantalla sin datos.
  Future<LocationForecast> _fetchAndStore(Location location) async {
    try {
      final fresh = await OpenMeteoApi.fetchForecast(location);
      await _store(location.coordinatesKey, fresh);
      return fresh;
    } catch (_) {
      final stale = await _readStored(location.coordinatesKey);
      if (stale != null) return stale;
      rethrow;
    }
  }
}
