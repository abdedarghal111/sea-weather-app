import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'time_series_sampling.dart';

/// Fila de flechas mostrando hacia dónde sopla el viento en cada hora o día,
/// en vez de un valor numérico: el usuario compara la flecha con la
/// orientación de su playa y decide él mismo si el viento le conviene, sin
/// que la app necesite conocer esa orientación.
///
/// [directions] son grados de los que VIENE el viento (convención
/// meteorológica, 0°/360° = norte); cada flecha se dibuja rotada 180° para
/// apuntar hacia dónde se dirige.
class WindDirectionChart extends StatelessWidget {
  final List<DateTime> times;
  final List<double?> directions;
  final String Function(DateTime time) labelBuilder;
  final double? highlightX;

  const WindDirectionChart({
    super.key,
    required this.times,
    required this.directions,
    required this.labelBuilder,
    this.highlightX,
  });

  static const _pointSpacing = 32.0;

  @override
  Widget build(BuildContext context) {
    if (times.isEmpty || times.length != directions.length) {
      return const SizedBox.shrink();
    }
    if (directions.every((d) => d == null)) {
      return const SizedBox.shrink();
    }

    final highlightIndex = highlightX?.round();

    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Dirección del viento',
              style: TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Text(
              'Las flechas indican hacia dónde sopla el viento. Si sopla '
              'desde el mar hacia la orilla, suele empeorar la visibilidad y '
              'agitar más el agua; si sopla desde tierra hacia el mar, suele '
              'calmarla y dejarla más clara; si sopla en paralelo a la costa '
              '(de lado), el efecto suele ser menor, aunque puede generar '
              'corriente lateral.',
              style: TextStyle(fontSize: 12),
            ),
          ),
          const SizedBox(height: 12),
          LayoutBuilder(
            builder: (context, constraints) {
              final labelEvery =
                  labelStep(times.length, constraints.maxWidth, _pointSpacing);
              return SizedBox(
                width: constraints.maxWidth,
                height: 60,
                child: Row(
                  children: [
                    for (var i = 0; i < times.length; i++)
                      Expanded(
                        child: _ArrowCell(
                          direction: directions[i],
                          label: i % labelEvery == 0 ? labelBuilder(times[i]) : null,
                          highlighted: highlightIndex == i,
                        ),
                      ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _ArrowCell extends StatelessWidget {
  final double? direction;
  final String? label;
  final bool highlighted;

  const _ArrowCell({required this.direction, required this.label, required this.highlighted});

  @override
  Widget build(BuildContext context) {
    final color = highlighted ? Colors.red : Colors.black87;
    return Column(
      mainAxisAlignment: MainAxisAlignment.start,
      children: [
        SizedBox(
          height: 32,
          child: direction == null
              ? null
              : Transform.rotate(
                  angle: (direction! + 180) * math.pi / 180,
                  child: Icon(Icons.navigation, size: 18, color: color),
                ),
        ),
        if (label != null)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              label!,
              maxLines: 1,
              softWrap: false,
              overflow: TextOverflow.visible,
              style: const TextStyle(fontSize: 10),
            ),
          ),
      ],
    );
  }
}
