// Agregados sobre una ventana de valores anteriores a un índice dado.

import 'dart:math' as math;

/// Suma de las últimas [windowSize] entradas de [values] terminando en
/// [index] (inclusive), recortada al histórico disponible. Los huecos null
/// cuentan como 0.
double trailingSum(List<num?> values, int index, int windowSize) {
  final start = (index - windowSize + 1).clamp(0, index);
  var sum = 0.0;
  for (var i = start; i <= index && i < values.length; i++) {
    sum += values[i]?.toDouble() ?? 0;
  }
  return sum;
}

/// Media de las entradas con dato de las últimas [windowSize] terminando en
/// [index] (inclusive). Devuelve null si la ventana entera está vacía.
double? trailingAverage(List<num?> values, int index, int windowSize) {
  final start = (index - windowSize + 1).clamp(0, index);
  var sum = 0.0;
  var count = 0;
  for (var i = start; i <= index && i < values.length; i++) {
    final v = values[i];
    if (v == null) continue;
    sum += v.toDouble();
    count++;
  }
  if (count == 0) return null;
  return sum / count;
}

/// Media cuadrática de las últimas [windowSize] entradas terminando en
/// [index] (inclusive).
///
/// Para el oleaje resume mejor la ventana que una media o un máximo: la
/// energía de la ola crece con el cuadrado de su altura, así que pesa más
/// las horas de mar grande sin dispararse por un pico aislado.
///
/// Devuelve null si el propio [index] no tiene dato: pasado el horizonte del
/// modelo de olas, arrastrar las horas anteriores sería inventar el valor.
double? trailingRms(List<num?>? values, int index, int windowSize) {
  if (values == null || index < 0 || index >= values.length || values[index] == null) {
    return null;
  }
  final start = (index - windowSize + 1).clamp(0, index);
  var sumOfSquares = 0.0;
  var count = 0;
  for (var i = start; i <= index; i++) {
    final v = values[i];
    if (v == null) continue;
    sumOfSquares += v * v;
    count++;
  }
  if (count == 0) return null;
  return math.sqrt(sumOfSquares / count);
}
