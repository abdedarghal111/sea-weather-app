import 'dart:convert';

import 'package:flutter/foundation.dart' show compute;
import 'package:shared_preferences/shared_preferences.dart';

import '../models/location.dart';
import '../models/location_forecast.dart';
import 'open_meteo_api.dart';

/// Deserializa la previsión completa (hasta ~384 puntos horarios, cada uno con
/// su propio [WeatherSnapshot] anidado) fuera del isolate principal: hecho
/// en el hilo de UI, este `jsonDecode` + reconstrucción de objetos puede
/// bloquear varios frames en un móvil de gama baja. Debe ser una función de
/// nivel superior (no un closure/método de instancia) para poder pasarse a
/// [compute].
LocationForecast _decodeForecast(String raw) =>
    LocationForecast.fromJson(jsonDecode(raw) as Map<String, dynamic>);

/// Igual que [_decodeForecast] pero para serializar al guardar en caché.
String _encodeForecast(LocationForecast forecast) => jsonEncode(forecast.toJson());

/// Cachea la previsión de cada localidad durante [ttl] para no llamar a la API
/// en cada apertura de pantalla.
class ForecastCache {
  static const ttl = Duration(minutes: 15);

  /// Peticiones en curso por localidad, compartidas entre pantallas. Sin esto,
  /// dos reconstrucciones seguidas de la lista lanzan la misma consulta varias
  /// veces y la API responde 429 "too many concurrent requests" a las
  /// sobrantes.
  static final _inFlight = <String, Future<LocationForecast>>{};

  String _key(String coordinatesKey) => 'conditions_cache_$coordinatesKey';

  Future<LocationForecast?> _readStored(String coordinatesKey) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key(coordinatesKey));
    if (raw == null) return null;
    try {
      return await compute(_decodeForecast, raw);
    } catch (_) {
      // Caché de un esquema antiguo o corrupta: se trata como si no existiera.
      return null;
    }
  }

  Future<void> _store(String coordinatesKey, LocationForecast forecast) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = await compute(_encodeForecast, forecast);
    await prefs.setString(_key(coordinatesKey), raw);
  }

  /// Devuelve la previsión de [location]: usa la caché si tiene menos de 15
  /// minutos, o llama a la API y actualiza la caché en caso contrario.
  /// Con [forceRefresh] se ignora la caché (pull-to-refresh).
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
