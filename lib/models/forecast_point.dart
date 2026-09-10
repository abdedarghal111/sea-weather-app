import 'weather_snapshot.dart';

/// Un [WeatherSnapshot] anclado a un instante concreto (una hora o un día),
/// para poder dibujarlo como serie temporal reutilizando tal cual los métodos
/// rateX() de [WeatherSnapshot].
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
