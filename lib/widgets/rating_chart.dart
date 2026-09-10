import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import 'time_series_chart.dart';

/// Gráfica de una valoración (0 a 1) a lo largo del tiempo, con las mismas 5
/// bandas de color que [RatingGauge] de fondo: es el termómetro actual
/// "desenrollado" en el eje de tiempo en vez de un único marcador.
class RatingChart extends StatelessWidget {
  final String title;
  final List<DateTime> times;
  final List<double> scores;
  final String Function(DateTime time) labelBuilder;

  /// Posición fraccionaria en [times] a marcar como "ahora"; ver
  /// [TimeSeriesChart.highlightPosition].
  final double? highlightPosition;

  const RatingChart({
    super.key,
    required this.title,
    required this.times,
    required this.scores,
    required this.labelBuilder,
    this.highlightPosition,
  });

  static const _bandColors = [
    Colors.red,
    Colors.deepOrange,
    Colors.amber,
    Colors.lightGreen,
    Colors.green,
  ];

  @override
  Widget build(BuildContext context) {
    if (times.isEmpty || times.length != scores.length) {
      return const SizedBox.shrink();
    }

    return TimeSeriesChart(
      title: title,
      height: 150,
      times: times,
      labelBuilder: labelBuilder,
      highlightPosition: highlightPosition,
      minY: 0,
      maxY: 1,
      gridStep: 0.2,
      bands: [
        for (var i = 0; i < _bandColors.length; i++)
          HorizontalRangeAnnotation(
            y1: i * 0.2,
            y2: (i + 1) * 0.2,
            color: _bandColors[i].withValues(alpha: 0.18),
          ),
      ],
      spots: [for (var i = 0; i < scores.length; i++) FlSpot(i.toDouble(), scores[i])],
      lineColor: Colors.black87,
      valueLabelBuilder: (value) => '${(value * 100).round()}%',
    );
  }
}
