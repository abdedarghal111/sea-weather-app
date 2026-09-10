// Gráfica de dirección del viento con su explicación para el usuario.

import 'package:flutter/material.dart';

import 'direction_arrows_chart.dart';

/// Dirección del viento hora a hora o día a día. [directions] son grados de
/// los que viene el viento; las flechas apuntan hacia dónde se dirige.
class WindDirectionChart extends StatelessWidget {
  final List<DateTime> times;
  final List<double?> directions;
  final String Function(DateTime time) labelBuilder;
  final double? highlightPosition;

  const WindDirectionChart({
    super.key,
    required this.times,
    required this.directions,
    required this.labelBuilder,
    this.highlightPosition,
  });

  @override
  Widget build(BuildContext context) => DirectionArrowsChart(
        title: 'Dirección del viento',
        explanation: 'Las flechas indican hacia dónde sopla el viento. Si sopla '
            'desde el mar hacia la orilla, suele empeorar la visibilidad y '
            'agitar más el agua; si sopla desde tierra hacia el mar, suele '
            'calmarla y dejarla más clara; si sopla en paralelo a la costa '
            '(de lado), el efecto suele ser menor, aunque puede generar '
            'corriente lateral.',
        times: times,
        directions: directions,
        labelBuilder: labelBuilder,
        highlightPosition: highlightPosition,
      );
}
