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

/// Igual que [trailingMax], pero exige que el propio [index] tenga dato: si no
/// lo tiene, devuelve null en vez del máximo de las entradas anteriores.
///
/// Es lo que necesitan los arrays marinos, que son más cortos que los
/// meteorológicos y se rellenan de null a partir del horizonte real del
/// modelo de olas: ahí, arrastrar el máximo de horas anteriores daría un
/// oleaje reciente inventado para un punto del que no se sabe nada.
double? trailingMaxIfPresent(List<num?>? values, int index, int windowSize) {
  if (values == null || index >= values.length || values[index] == null) return null;
  final start = (index - windowSize + 1).clamp(0, index);
  num? max;
  for (var i = start; i <= index; i++) {
    final v = values[i];
    if (v == null) continue;
    if (max == null || v > max) max = v;
  }
  return max?.toDouble();
}
