/// Suma de las últimas [windowSize] entradas de [values] terminando en
/// [index] (inclusive), recortada al histórico disponible.
double trailingSum(List<num> values, int index, int windowSize) {
  final start = (index - windowSize + 1).clamp(0, index);
  var sum = 0.0;
  for (var i = start; i <= index; i++) {
    sum += values[i].toDouble();
  }
  return sum;
}

/// Media de las últimas [windowSize] entradas de [values] terminando en
/// [index] (inclusive), recortada al histórico disponible.
double trailingAverage(List<num> values, int index, int windowSize) {
  final start = (index - windowSize + 1).clamp(0, index);
  final count = index - start + 1;
  return trailingSum(values, index, windowSize) / count;
}

/// Máximo de las últimas [windowSize] entradas de [values] terminando en
/// [index] (inclusive), recortada al histórico disponible.
double trailingMax(List<num> values, int index, int windowSize) {
  final start = (index - windowSize + 1).clamp(0, index);
  var max = values[start].toDouble();
  for (var i = start + 1; i <= index; i++) {
    if (values[i] > max) max = values[i].toDouble();
  }
  return max;
}
