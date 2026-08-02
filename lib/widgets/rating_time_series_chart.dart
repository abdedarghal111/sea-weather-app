import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import 'time_series_sampling.dart';

/// Gráfica de una valoración (0 a 1) a lo largo del tiempo, con las mismas 5
/// bandas de color que [RatingGauge] de fondo: es el termómetro actual
/// "desenrollado" en el eje de tiempo en vez de un único marcador.
///
/// Siempre ocupa el ancho disponible y dibuja todos los puntos reales (la
/// forma completa de los datos); si no caben todas las etiquetas/líneas de
/// rejilla con una separación legible, se etiquetan menos horas (una de
/// cada N) en vez de desbordar la pantalla y requerir scroll horizontal.
class RatingTimeSeriesChart extends StatelessWidget {
  final String title;
  final List<DateTime> times;
  final List<double> scores;
  final String Function(DateTime time) labelBuilder;

  /// Posición fraccionaria en [times] (p. ej. 2.5 = a medio camino entre el
  /// punto 2 y el 3) a marcar con una línea vertical roja, típicamente la
  /// hora y minuto actuales; `null` si no aplica (el rango mostrado no
  /// incluye "ahora").
  final double? highlightX;

  const RatingTimeSeriesChart({
    super.key,
    required this.title,
    required this.times,
    required this.scores,
    required this.labelBuilder,
    this.highlightX,
  });

  static const _bandColors = [
    Colors.red,
    Colors.deepOrange,
    Colors.amber,
    Colors.lightGreen,
    Colors.green,
  ];

  static const _pointSpacing = 44.0;

  @override
  Widget build(BuildContext context) {
    if (times.isEmpty || times.length != scores.length) {
      return const SizedBox.shrink();
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          SizedBox(
            height: 150,
            child: LayoutBuilder(
              builder: (context, constraints) {
                final step = labelStep(times.length, constraints.maxWidth, _pointSpacing);
                return SizedBox(
                  width: constraints.maxWidth,
                  child: LineChart(
                    LineChartData(
                      minY: 0,
                      maxY: 1,
                      minX: 0,
                      maxX: (times.length - 1).toDouble(),
                      rangeAnnotations: RangeAnnotations(
                        horizontalRangeAnnotations: [
                          for (var i = 0; i < _bandColors.length; i++)
                            HorizontalRangeAnnotation(
                              y1: i * 0.2,
                              y2: (i + 1) * 0.2,
                              color: _bandColors[i].withValues(alpha: 0.18),
                            ),
                        ],
                      ),
                      gridData: FlGridData(
                        drawVerticalLine: true,
                        verticalInterval: step.toDouble(),
                        horizontalInterval: 0.2,
                        getDrawingHorizontalLine: (value) => const FlLine(
                          color: Colors.black,
                          strokeWidth: 0.4,
                          dashArray: [3, 6],
                        ),
                        getDrawingVerticalLine: (value) => const FlLine(
                          color: Colors.black,
                          strokeWidth: 0.4,
                          dashArray: [3, 6],
                        ),
                      ),
                      borderData: FlBorderData(show: false),
                      extraLinesData: ExtraLinesData(
                        verticalLines: [
                          if (highlightX != null &&
                              highlightX! >= 0 &&
                              highlightX! <= times.length - 1)
                            VerticalLine(
                              x: highlightX!,
                              color: Colors.red,
                              strokeWidth: 1,
                            ),
                        ],
                      ),
                      titlesData: FlTitlesData(
                        topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                        rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                        leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                        bottomTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            reservedSize: 24,
                            interval: step.toDouble(),
                            getTitlesWidget: (value, meta) {
                              final index = value.round();
                              if (index < 0 || index >= times.length) {
                                return const SizedBox.shrink();
                              }
                              return Padding(
                                padding: const EdgeInsets.only(top: 4),
                                child: Text(labelBuilder(times[index]), style: const TextStyle(fontSize: 10)),
                              );
                            },
                          ),
                        ),
                      ),
                      lineTouchData: LineTouchData(
                        touchTooltipData: LineTouchTooltipData(
                          getTooltipItems: (touchedSpots) => touchedSpots.map((spot) {
                            final index = spot.x.round();
                            final label = index >= 0 && index < times.length ? labelBuilder(times[index]) : '';
                            return LineTooltipItem(
                              '$label\n${(spot.y * 100).round()}%',
                              const TextStyle(color: Colors.white, fontSize: 12),
                            );
                          }).toList(),
                        ),
                      ),
                      lineBarsData: [
                        LineChartBarData(
                          spots: [for (var i = 0; i < scores.length; i++) FlSpot(i.toDouble(), scores[i])],
                          barWidth: 2,
                          color: Colors.black87,
                          dotData: const FlDotData(show: true),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
