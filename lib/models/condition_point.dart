import 'beach_conditions.dart';

/// Un snapshot de [BeachConditions] anclado a un instante concreto (una hora
/// o un día), para poder dibujarlo como serie temporal reutilizando tal cual
/// los métodos rateX() de [BeachConditions].
class ConditionPoint {
  final DateTime time;
  final BeachConditions conditions;

  const ConditionPoint({required this.time, required this.conditions});

  Map<String, dynamic> toJson() => {
        'time': time.toIso8601String(),
        'conditions': conditions.toJson(),
      };

  factory ConditionPoint.fromJson(Map<String, dynamic> json) => ConditionPoint(
        time: DateTime.parse(json['time'] as String),
        conditions: BeachConditions.fromJson(json['conditions'] as Map<String, dynamic>),
      );
}
