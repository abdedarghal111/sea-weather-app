import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import 'time_series_sampling.dart';

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

/// Gráfica de un parámetro crudo (temperatura, viento, oleaje, etc.) a lo
/// largo del tiempo, con rejilla y el eje Y en su unidad. Los valores nulos
/// (p. ej. datos marinos que no llegan tan lejos como los de tiempo) se
/// dibujan como un hueco real en la línea, no como un cero.
///
/// El eje Y se redondea a marcas "bonitas" y equiespaciadas ([_niceStep]),
/// separadas del mínimo/máximo real de los datos: los propios puntos de la
/// línea conservan su valor exacto, solo las etiquetas del eje se redondean.
///
/// Igual que [RatingTimeSeriesChart]: siempre ocupa el ancho disponible y
/// dibuja todos los puntos reales; si no caben todas las etiquetas/líneas
/// de rejilla con una separación legible, se etiquetan menos horas (una de
/// cada N) en vez de desbordar la pantalla y requerir scroll horizontal.
class RawParameterTimeSeriesChart extends StatelessWidget {
  final String title;
  final String unit;
  final List<DateTime> times;
  final List<double?> values;
  final String Function(DateTime time) labelBuilder;

  const RawParameterTimeSeriesChart({
    super.key,
    required this.title,
    required this.unit,
    required this.times,
    required this.values,
    required this.labelBuilder,
  });

  static const _pointSpacing = 44.0;

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

    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('$title ($unit)',
              style: const TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          SizedBox(
            height: 140,
            child: LayoutBuilder(
              builder: (context, constraints) {
                final labelEvery = labelStep(times.length, constraints.maxWidth, _pointSpacing);
                return SizedBox(
                  width: constraints.maxWidth,
                  child: LineChart(
                    LineChartData(
                      minX: 0,
                      maxX: (times.length - 1).toDouble(),
                      minY: minY,
                      maxY: maxY,
                      gridData: FlGridData(
                        drawVerticalLine: true,
                        verticalInterval: labelEvery.toDouble(),
                        horizontalInterval: step,
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
                      titlesData: FlTitlesData(
                        topTitles: const AxisTitles(
                            sideTitles: SideTitles(showTitles: false)),
                        rightTitles: const AxisTitles(
                            sideTitles: SideTitles(showTitles: false)),
                        leftTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            reservedSize: 36,
                            interval: step,
                            getTitlesWidget: (value, meta) => Text(
                              _formatTick(value, step),
                              style: const TextStyle(fontSize: 10),
                            ),
                          ),
                        ),
                        bottomTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            reservedSize: 24,
                            interval: labelEvery.toDouble(),
                            getTitlesWidget: (value, meta) {
                              final index = value.round();
                              if (index < 0 || index >= times.length) {
                                return const SizedBox.shrink();
                              }
                              return Padding(
                                padding: const EdgeInsets.only(top: 4),
                                child: Text(labelBuilder(times[index]),
                                    style: const TextStyle(fontSize: 10)),
                              );
                            },
                          ),
                        ),
                      ),
                      lineTouchData: LineTouchData(
                        touchTooltipData: LineTouchTooltipData(
                          getTooltipItems: (touchedSpots) =>
                              touchedSpots.map((spot) {
                            final index = spot.x.round();
                            final label = index >= 0 && index < times.length
                                ? labelBuilder(times[index])
                                : '';
                            return LineTooltipItem(
                              '$label\n${spot.y.toStringAsFixed(1)} $unit',
                              const TextStyle(
                                  color: Colors.white, fontSize: 12),
                            );
                          }).toList(),
                        ),
                      ),
                      lineBarsData: [
                        LineChartBarData(
                          spots: [
                            for (var i = 0; i < values.length; i++)
                              values[i] == null
                                  ? FlSpot.nullSpot
                                  : FlSpot(i.toDouble(), values[i]!),
                          ],
                          barWidth: 2,
                          color: Theme.of(context).colorScheme.primary,
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
