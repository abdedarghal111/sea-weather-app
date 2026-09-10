// Previsión completa de una localidad: ahora, por horas y por días.

import 'forecast_point.dart';
import 'weather_snapshot.dart';

/// Agrupa el snapshot de "ahora" con las series por horas y por días de una
/// localidad, todo obtenido en las mismas dos llamadas a Open-Meteo.
class LocationForecast {
  /// Versión del esquema serializado: subirla invalida las cachés antiguas
  /// al cambiar la forma de la previsión.
  static const schemaVersion = 9;

  final WeatherSnapshot now;
  final List<ForecastPoint> hourly;
  final List<ForecastPoint> daily;

  const LocationForecast({
    required this.now,
    required this.hourly,
    required this.daily,
  });

  Map<String, dynamic> toJson() => {
        'schemaVersion': schemaVersion,
        'now': now.toJson(),
        'hourly': hourly.map((p) => p.toJson()).toList(),
        'daily': daily.map((p) => p.toJson()).toList(),
      };

  factory LocationForecast.fromJson(Map<String, dynamic> json) {
    if (json['schemaVersion'] != schemaVersion) {
      throw const FormatException('Esquema de caché obsoleto');
    }
    return LocationForecast(
      now: WeatherSnapshot.fromJson(json['now'] as Map<String, dynamic>),
      hourly: (json['hourly'] as List<dynamic>)
          .map((e) => ForecastPoint.fromJson(e as Map<String, dynamic>))
          .toList(),
      daily: (json['daily'] as List<dynamic>)
          .map((e) => ForecastPoint.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }
}
