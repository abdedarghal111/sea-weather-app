import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

import '../models/beach_conditions.dart';

/// Barra estilo termómetro con 5 tramos fijos (de peor a mejor, izquierda a
/// derecha) que sirven de escala y leyenda. No es una barra de progreso: no
/// se rellena; en su lugar, un marcador se coloca de forma continua sobre la
/// escala según [BeachRating.score], reflejando el valor real y no solo la
/// categoría discreta en la que cae.
class RatingGauge extends StatelessWidget {
  final String title;
  final BeachRating rating;

  const RatingGauge({super.key, required this.title, required this.rating});

  static const _segmentColors = [
    Colors.red,
    Colors.deepOrange,
    Colors.amber,
    Colors.lightGreen,
    Colors.green,
  ];

  static const _segmentLabels = ['Muy malo', 'Malo', 'Regular', 'Bueno', 'Muy bueno'];

  Color get _levelColor => switch (rating.level) {
        RatingLevel.veryBad => Colors.red,
        RatingLevel.bad => Colors.deepOrange,
        RatingLevel.ok => Colors.amber.shade800,
        RatingLevel.good => Colors.lightGreen.shade800,
        RatingLevel.veryGood => Colors.green,
      };

  FaIconData get _levelIcon => switch (rating.level) {
        RatingLevel.veryBad => FontAwesomeIcons.ban,
        RatingLevel.bad => FontAwesomeIcons.circleXmark,
        RatingLevel.ok => FontAwesomeIcons.triangleExclamation,
        RatingLevel.good => FontAwesomeIcons.circleCheck,
        RatingLevel.veryGood => FontAwesomeIcons.circleCheck,
      };

  @override
  Widget build(BuildContext context) {
    final activeIndex = 4 - rating.level.index;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: _levelColor.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _levelColor.withValues(alpha: 0.4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              FaIcon(_levelIcon, size: 20, color: _levelColor),
              const SizedBox(width: 8),
              Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
            ],
          ),
          const SizedBox(height: 6),
          Text(rating.reason, style: Theme.of(context).textTheme.bodyMedium),
          const SizedBox(height: 14),
          LayoutBuilder(
            builder: (context, constraints) {
              const markerSize = 16.0;
              final trackWidth = constraints.maxWidth;
              final markerLeft = (trackWidth * rating.score - markerSize / 2)
                  .clamp(0.0, trackWidth - markerSize);

              return Stack(
                clipBehavior: Clip.none,
                children: [
                  Positioned(
                    left: markerLeft,
                    top: -18,
                    child: FaIcon(FontAwesomeIcons.caretDown, size: markerSize, color: _levelColor),
                  ),
                  Row(
                    children: List.generate(
                      _segmentColors.length,
                      (i) => Expanded(
                        child: Container(
                          height: 10,
                          margin: const EdgeInsets.symmetric(horizontal: 1),
                          decoration: BoxDecoration(
                            color: _segmentColors[i],
                            borderRadius: BorderRadius.horizontal(
                              left: i == 0 ? const Radius.circular(6) : Radius.zero,
                              right: i == _segmentColors.length - 1 ? const Radius.circular(6) : Radius.zero,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
          const SizedBox(height: 4),
          Row(
            children: List.generate(
              _segmentLabels.length,
              (i) => Expanded(
                child: Text(
                  _segmentLabels[i],
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: i == activeIndex ? FontWeight.bold : FontWeight.normal,
                    color: i == activeIndex ? _segmentColors[i] : Colors.grey,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
