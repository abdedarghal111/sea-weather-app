/// Cada cuántos puntos (de un total de [totalPoints]) hay que dibujar una
/// etiqueta y una línea de rejilla para que quepan en [availableWidth] sin
/// solaparse, dada una separación cómoda [spacing] por etiqueta.
///
/// La línea del gráfico sigue dibujando TODOS los puntos reales (la forma
/// completa de los datos); esto solo decide qué subconjunto de horas se
/// etiqueta y marca con rejilla para no saturar pantallas estrechas.
int labelStep(int totalPoints, double availableWidth, double spacing) {
  if (totalPoints <= 1) return 1;
  final maxLabels = (availableWidth / spacing).floor().clamp(1, totalPoints);
  return (totalPoints / maxLabels).ceil();
}
