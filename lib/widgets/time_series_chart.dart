// Armazón compartido por las gráficas temporales de la app.

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import 'time_series_sampling.dart';

/// Base común de las gráficas temporales: título, rejilla, etiquetas de
/// tiempo, línea de "ahora" y tooltip. Cada gráfica aporta los límites del
/// eje Y, las bandas de fondo y el formato de los valores.
///
/// Ocupa el ancho disponible y dibuja todos los puntos; si no caben todas
/// las etiquetas, se rotula una de cada N en vez de exigir scroll.
class TimeSeriesChart extends StatelessWidget {
  final String title;
  final double height;
  final List<DateTime> times;
  final String Function(DateTime time) labelBuilder;

  /// Posición fraccionaria en [times] (2.5 = a medio camino entre el punto 2
  /// y el 3) donde va la línea roja de "ahora", o `null` si el rango
  /// mostrado no lo incluye.
  final double? highlightPosition;

  final double minY;
  final double maxY;

  /// Separación entre líneas de la rejilla horizontal y entre marcas del
  /// eje Y.
  final double gridStep;

  /// Cómo se escribe una marca del eje Y, o `null` para no enseñar ese eje.
  final String Function(double value)? yAxisLabelBuilder;

  /// Franjas de color de fondo, si la gráfica las usa.
  final List<HorizontalRangeAnnotation> bands;

  final List<FlSpot> spots;
  final Color lineColor;

  /// Cómo se escribe el valor de un punto en el tooltip.
  final String Function(double value) valueLabelBuilder;

  const TimeSeriesChart({
    super.key,
    required this.title,
    required this.height,
    required this.times,
    required this.labelBuilder,
    required this.minY,
    required this.maxY,
    required this.gridStep,
    required this.spots,
    required this.lineColor,
    required this.valueLabelBuilder,
    this.highlightPosition,
    this.yAxisLabelBuilder,
    this.bands = const [],
  });

  /// Separación cómoda entre etiquetas del eje de tiempo.
  static const _pointSpacing = 44.0;

  static const _gridLine = FlLine(
    color: Colors.black,
    strokeWidth: 0.4,
    dashArray: [3, 6],
  );

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          SizedBox(
            height: height,
            child: LayoutBuilder(
              builder: (context, constraints) {
                final labelEvery =
                    labelInterval(times.length, constraints.maxWidth, _pointSpacing);
                return SizedBox(
                  width: constraints.maxWidth,
                  child: LineChart(_chartData(context, labelEvery)),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  LineChartData _chartData(BuildContext context, int labelEvery) {
    final yAxisLabel = yAxisLabelBuilder;

    return LineChartData(
      minX: 0,
      maxX: (times.length - 1).toDouble(),
      minY: minY,
      maxY: maxY,
      rangeAnnotations: RangeAnnotations(horizontalRangeAnnotations: bands),
      gridData: FlGridData(
        drawVerticalLine: true,
        verticalInterval: labelEvery.toDouble(),
        horizontalInterval: gridStep,
        getDrawingHorizontalLine: (value) => _gridLine,
        getDrawingVerticalLine: (value) => _gridLine,
      ),
      borderData: FlBorderData(show: false),
      extraLinesData: ExtraLinesData(
        verticalLines: [
          if (highlightPosition != null &&
              highlightPosition! >= 0 &&
              highlightPosition! <= times.length - 1)
            VerticalLine(x: highlightPosition!, color: Colors.red, strokeWidth: 1),
        ],
      ),
      titlesData: FlTitlesData(
        topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        leftTitles: AxisTitles(
          sideTitles: yAxisLabel == null
              ? const SideTitles(showTitles: false)
              : SideTitles(
                  showTitles: true,
                  reservedSize: 36,
                  interval: gridStep,
                  getTitlesWidget: (value, meta) => Text(
                    yAxisLabel(value),
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
              final label = _timeLabelAt(value.round());
              if (label == null) return const SizedBox.shrink();
              return Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(label, style: const TextStyle(fontSize: 10)),
              );
            },
          ),
        ),
      ),
      lineTouchData: LineTouchData(
        touchTooltipData: LineTouchTooltipData(
          getTooltipItems: (touchedSpots) => touchedSpots
              .map((spot) => LineTooltipItem(
                    '${_timeLabelAt(spot.x.round()) ?? ''}\n${valueLabelBuilder(spot.y)}',
                    const TextStyle(color: Colors.white, fontSize: 12),
                  ))
              .toList(),
        ),
      ),
      lineBarsData: [
        LineChartBarData(
          spots: spots,
          barWidth: 2,
          color: lineColor,
          dotData: const FlDotData(show: true),
        ),
      ],
    );
  }

  String? _timeLabelAt(int index) =>
      index >= 0 && index < times.length ? labelBuilder(times[index]) : null;
}
