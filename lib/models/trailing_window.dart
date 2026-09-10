import 'dart:math' as math;

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

/// Media cuadrática (raíz de la media de los cuadrados) de las últimas
/// [windowSize] entradas terminando en [index], esa incluida.
///
/// Para el oleaje es la forma correcta de resumir una ventana de tiempo: la
/// energía de una ola crece con el CUADRADO de su altura, y el daño que un
/// temporal hace a la playa se mide como esa energía por el tiempo que dura
/// (el índice de Dolan y Davis, Hs²·t, es el estándar en erosión costera).
/// Con la ventana fija, la media cuadrática resume ese acumulado en metros:
/// pesa mucho más las horas de mar grande que una media normal, pero no se
/// dispara por un único pico de una hora como haría el máximo.
///
/// Devuelve null si el propio [index] no tiene dato: los arrays marinos se
/// rellenan de null pasado el horizonte real del modelo de olas, y ahí
/// arrastrar las horas anteriores sería inventarse el oleaje de un punto del
/// que no se sabe nada.
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
