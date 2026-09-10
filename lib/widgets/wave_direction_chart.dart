import 'package:flutter/material.dart';

import 'direction_arrows_chart.dart';

/// Dirección de las olas hora a hora o día a día. [directions] son grados de
/// los que VIENEN las olas; las flechas apuntan hacia dónde avanzan.
class WaveDirectionChart extends StatelessWidget {
  final List<DateTime> times;
  final List<double?> directions;
  final String Function(DateTime time) labelBuilder;
  final double? highlightX;

  const WaveDirectionChart({
    super.key,
    required this.times,
    required this.directions,
    required this.labelBuilder,
    this.highlightX,
  });

  @override
  Widget build(BuildContext context) => DirectionArrowsChart(
        title: 'Dirección de las olas',
        explanation: 'Las flechas indican hacia dónde avanzan las olas. De '
            'frente contra la orilla: rompen donde te bañas y levantan arena. '
            'De lado, en paralelo a la costa: rompen menos y el agua queda '
            'más clara, pero arrastra. Hacia mar adentro: se alejan de tu '
            'playa, orilla tranquila.',
        times: times,
        directions: directions,
        labelBuilder: labelBuilder,
        highlightX: highlightX,
      );
}
