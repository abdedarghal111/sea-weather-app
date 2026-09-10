// Cálculo de cuántas etiquetas caben en el eje de tiempo de una gráfica.

/// Cada cuántos puntos, de [totalPoints], hay que dibujar una etiqueta y una
/// línea de rejilla para que quepan en [availableWidth] con una separación
/// de [spacing] cada una. No afecta a los puntos de la línea, que se dibujan
/// todos.
int labelInterval(int totalPoints, double availableWidth, double spacing) {
  if (totalPoints <= 1) return 1;
  final maxLabels = (availableWidth / spacing).floor().clamp(1, totalPoints);
  return (totalPoints / maxLabels).ceil();
}
