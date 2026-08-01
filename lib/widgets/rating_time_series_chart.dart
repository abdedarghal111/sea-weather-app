import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

/// Gráfica de una valoración (0 a 1) a lo largo del tiempo, con las mismas 5
/// bandas de color que [RatingGauge] de fondo: es el termómetro actual
/// "desenrollado" en el eje de tiempo en vez de un único marcador.
///
/// Se dibuja con un ancho proporcional al número de puntos (una etiqueta y
/// una línea de rejilla por cada hora/día) y se desliza en horizontal si no
/// caben todos en la pantalla, en vez de repartir solo unas pocas etiquetas.
class RatingTimeSeriesChart extends StatelessWidget {
  final String title;
  final List<DateTime> times;
  final List<double> scores;
  final String Function(DateTime time) labelBuilder;

  const RatingTimeSeriesChart({
    super.key,
    required this.title,
    required this.times,
    required this.scores,
    required this.labelBuilder,
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
                final chartWidth = constraints.maxWidth > times.length * _pointSpacing
                    ? constraints.maxWidth
                    : times.length * _pointSpacing;
                return SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: SizedBox(
                    width: chartWidth,
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
                          verticalInterval: 1,
                          horizontalInterval: 0.2,
                        ),
                        borderData: FlBorderData(show: false),
                        titlesData: FlTitlesData(
                          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                          leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                          bottomTitles: AxisTitles(
                            sideTitles: SideTitles(
                              showTitles: true,
                              reservedSize: 24,
                              interval: 1,
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
