import 'condition_point.dart';
import 'beach_conditions.dart';

/// Agrupa el snapshot "ahora mismo" junto con la serie por horas (de hoy en
/// adelante) y por días (próximos días) para un spot, todo obtenido en las
/// mismas dos llamadas a Open-Meteo.
class SpotConditionsBundle {
  /// Versión del esquema de caché: al cambiar la forma de este bundle (p.ej.
  /// añadir listas anidadas nuevas) se sube este número para invalidar
  /// cachés antiguas de forma explícita, además del try/catch de parseo.
  static const schemaVersion = 3;

  final BeachConditions current;
  final List<ConditionPoint> hourly;
  final List<ConditionPoint> daily;

  const SpotConditionsBundle({
    required this.current,
    required this.hourly,
    required this.daily,
  });

  Map<String, dynamic> toJson() => {
        'schemaVersion': schemaVersion,
        'current': current.toJson(),
        'hourly': hourly.map((p) => p.toJson()).toList(),
        'daily': daily.map((p) => p.toJson()).toList(),
      };

  factory SpotConditionsBundle.fromJson(Map<String, dynamic> json) {
    if (json['schemaVersion'] != schemaVersion) {
      throw const FormatException('Esquema de caché obsoleto');
    }
    return SpotConditionsBundle(
      current: BeachConditions.fromJson(json['current'] as Map<String, dynamic>),
      hourly: (json['hourly'] as List<dynamic>)
          .map((e) => ConditionPoint.fromJson(e as Map<String, dynamic>))
          .toList(),
      daily: (json['daily'] as List<dynamic>)
          .map((e) => ConditionPoint.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }
}
