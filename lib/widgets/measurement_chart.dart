// Gráfica de una medida en su unidad, con eje Y de marcas redondeadas.

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import 'time_series_chart.dart';

/// Redondea [roughStep] al siguiente 1, 2 o 5 por potencia de 10 (0.1, 0.2,
/// 0.5, 1, 2, 5...) para que el eje Y tenga marcas redondas.
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

/// Gráfica de una medida (temperatura, viento, oleaje...) a lo largo del
/// tiempo, con el eje Y en su unidad. Los valores nulos dejan un hueco en la
/// línea en vez de dibujarse como cero.
///
/// El redondeo de [_niceStep] afecta solo a las marcas del eje: los puntos
/// conservan su valor exacto.
class MeasurementChart extends StatelessWidget {
  final String title;
  final String unit;
  final List<DateTime> times;
  final List<double?> values;
  final String Function(DateTime time) labelBuilder;

  /// Ver [TimeSeriesChart.highlightPosition].
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
