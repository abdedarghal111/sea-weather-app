import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import 'time_series_chart.dart';

/// Redondea [roughStep] al siguiente "número bonito" (1, 2 o 5 por potencia
/// de 10: 0.1, 0.2, 0.5, 1, 2, 5, 10, 20...), para que el eje Y tenga marcas
/// enteras/redondas y equiespaciadas en vez de decimales pegados al mínimo y
/// máximo exactos de los datos.
double _niceStep(double roughStep) {
  if (roughStep <= 0) return 1;
  var magnitude = 1.0;
  var step = roughStep;
  while (step >= 10) {
    step /= 10;
    magnitude *= 10;
  }
  while (step < 1) {
    step *= 10;
    magnitude /= 10;
  }
  final niceFraction = step < 1.5
      ? 1.0
      : step < 3
          ? 2.0
          : step < 7
              ? 5.0
              : 10.0;
  return niceFraction * magnitude;
}

String _formatTick(double value, double step) {
  if (step >= 1) return value.round().toString();
  if (step >= 0.1) return value.toStringAsFixed(1);
  return value.toStringAsFixed(2);
}

/// Gráfica de una medida concreta (temperatura, viento, oleaje, etc.) a lo
/// largo del tiempo, con rejilla y el eje Y en su unidad. Los valores nulos
/// (p. ej. datos marinos que no llegan tan lejos como los de tiempo) se
/// dibujan como un hueco real en la línea, no como un cero.
///
/// El eje Y se redondea a marcas "bonitas" y equiespaciadas ([_niceStep]),
/// separadas del mínimo/máximo real de los datos: los propios puntos de la
/// línea conservan su valor exacto, solo las etiquetas del eje se redondean.
class MeasurementChart extends StatelessWidget {
  final String title;
  final String unit;
  final List<DateTime> times;
  final List<double?> values;
  final String Function(DateTime time) labelBuilder;

  /// Posición fraccionaria en [times] a marcar como "ahora"; ver
  /// [TimeSeriesChart.highlightPosition].
  final double? highlightPosition;

  const MeasurementChart({
    super.key,
    required this.title,
    required this.unit,
    required this.times,
    required this.values,
    required this.labelBuilder,
    this.highlightPosition,
  });

  @override
  Widget build(BuildContext context) {
    if (times.isEmpty || times.length != values.length) {
      return const SizedBox.shrink();
    }
    final knownValues = values.whereType<double>().toList();
    if (knownValues.isEmpty) {
      return const SizedBox.shrink();
    }

    final dataMin = knownValues.reduce((a, b) => a < b ? a : b);
    final dataMax = knownValues.reduce((a, b) => a > b ? a : b);
    final step = _niceStep((dataMax - dataMin) / 4);
    final minY = (dataMin / step).floor() * step;
    var maxY = (dataMax / step).ceil() * step;
    if (maxY <= minY) maxY = minY + step;

    return TimeSeriesChart(
      title: '$title ($unit)',
      height: 140,
      times: times,
      labelBuilder: labelBuilder,
      highlightPosition: highlightPosition,
      minY: minY,
      maxY: maxY,
      gridStep: step,
      yAxisLabelBuilder: (value) => _formatTick(value, step),
      spots: [
        for (var i = 0; i < values.length; i++)
          values[i] == null ? FlSpot.nullSpot : FlSpot(i.toDouble(), values[i]!),
      ],
      lineColor: Theme.of(context).colorScheme.primary,
      valueLabelBuilder: (value) => '${value.toStringAsFixed(1)} $unit',
    );
  }
}
