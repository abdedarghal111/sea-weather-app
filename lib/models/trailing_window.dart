/// Suma de las últimas [windowSize] entradas de [values] terminando en
/// [index] (inclusive), recortada al histórico disponible. Los huecos null de
/// la respuesta de la API se saltan.
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

/// Máximo de las entradas con dato de las últimas [windowSize] terminando en
/// [index] (inclusive). Devuelve null si la ventana entera está vacía.
double? trailingMax(List<num?> values, int index, int windowSize) {
  final start = (index - windowSize + 1).clamp(0, index);
  num? max;
  for (var i = start; i <= index && i < values.length; i++) {
    final v = values[i];
    if (v == null) continue;
    if (max == null || v > max) max = v;
  }
  return max?.toDouble();
}
