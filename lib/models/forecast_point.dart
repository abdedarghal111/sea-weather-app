// Punto de una serie temporal de previsión: instante más condiciones.

import 'weather_snapshot.dart';

/// Un [WeatherSnapshot] anclado a un instante (una hora o un día), para
/// dibujarlo como serie temporal reutilizando sus métodos `rateX()`.
class ForecastPoint {
  final DateTime time;
  final WeatherSnapshot weather;

  const ForecastPoint({required this.time, required this.weather});

  Map<String, dynamic> toJson() => {
        'time': time.toIso8601String(),
        'weather': weather.toJson(),
      };

  factory ForecastPoint.fromJson(Map<String, dynamic> json) => ForecastPoint(
        time: DateTime.parse(json['time'] as String),
        weather: WeatherSnapshot.fromJson(json['weather'] as Map<String, dynamic>),
      );
}
