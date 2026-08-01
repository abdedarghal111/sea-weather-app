import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

import '../models/beach_conditions.dart';
import '../models/spot.dart';
import '../services/conditions_cache.dart';
import '../widgets/condition_tile.dart';
import '../widgets/rating_gauge.dart';

class SpotDetailScreen extends StatefulWidget {
  final Spot spot;

  const SpotDetailScreen({super.key, required this.spot});

  @override
  State<SpotDetailScreen> createState() => _SpotDetailScreenState();
}

class _SpotDetailScreenState extends State<SpotDetailScreen> {
  final _cache = ConditionsCache();
  Future<BeachConditions>? _future;

  @override
  void initState() {
    super.initState();
    _future = _cache.getConditions(widget.spot);
  }

  Future<void> _refresh({bool force = false}) async {
    setState(() {
      _future = _cache.getConditions(widget.spot, forceRefresh: force);
    });
    await _future;
  }

  String _minutesAgoLabel(DateTime fetchedAt) {
    final minutes = DateTime.now().difference(fetchedAt).inMinutes;
    if (minutes < 1) return 'actualizado justo ahora';
    return 'actualizado hace $minutes min';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.spot.name)),
      body: RefreshIndicator(
        onRefresh: () => _refresh(force: true),
        child: FutureBuilder<BeachConditions>(
          future: _future,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snapshot.hasError) {
              return ListView(
                children: [
                  const SizedBox(height: 80),
                  const FaIcon(FontAwesomeIcons.triangleExclamation, size: 48),
                  const SizedBox(height: 12),
                  const Center(child: Text('No se pudo obtener el tiempo. Desliza para reintentar.')),
                ],
              );
            }

            final conditions = snapshot.data!;

            return ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Text(_minutesAgoLabel(conditions.fetchedAt), style: Theme.of(context).textTheme.bodySmall),
                const SizedBox(height: 12),
                RatingGauge(title: 'Agua cristalina', rating: conditions.rateWaterClarity()),
                const SizedBox(height: 16),
                RatingGauge(title: 'Playa removida', rating: conditions.ratePlayaRemovida()),
                const SizedBox(height: 16),
                RatingGauge(title: 'Surf', rating: conditions.rateSurf()),
                const SizedBox(height: 16),
                RatingGauge(title: 'Sol', rating: conditions.rateSun()),
                const SizedBox(height: 16),
                RatingGauge(title: 'Lluvia', rating: conditions.rateRain()),
                const SizedBox(height: 16),
                Text('Todos los datos', style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 8),
                GridView(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                    maxCrossAxisExtent: 140,
                    mainAxisSpacing: 8,
                    crossAxisSpacing: 8,
                    childAspectRatio: 0.9,
                  ),
                  children: [
                    ConditionTile(
                      icon: FontAwesomeIcons.temperatureHalf,
                      label: 'Temp. máx.',
                      value: '${conditions.airTempMax.round()}°C',
                    ),
                    ConditionTile(
                      icon: FontAwesomeIcons.temperatureThreeQuarters,
                      label: 'Sensación',
                      value: '${conditions.feelsLike.round()}°C',
                    ),
                    ConditionTile(
                      icon: FontAwesomeIcons.cloud,
                      label: 'Nubosidad',
                      value: '${conditions.cloudCoverCurrent.round()}%',
                    ),
                    ConditionTile(
                      icon: FontAwesomeIcons.sun,
                      label: 'Índice UV',
                      value: conditions.uvIndexMax.round().toString(),
                    ),
                    ConditionTile(
                      icon: FontAwesomeIcons.solarPanel,
                      label: 'Horas de sol',
                      value: '${conditions.sunshineDurationHours.round()} h',
                    ),
                    ConditionTile(
                      icon: FontAwesomeIcons.droplet,
                      label: 'Prob. lluvia hoy',
                      value: '${conditions.precipitationProbabilityMax.round()}%',
                    ),
                    ConditionTile(
                      icon: FontAwesomeIcons.cloudRain,
                      label: 'Lluvia hoy',
                      value: '${conditions.precipitationSumToday.toStringAsFixed(1)} mm',
                    ),
                    ConditionTile(
                      icon: FontAwesomeIcons.cloudShowersHeavy,
                      label: 'Lluvia 48h',
                      value: '${conditions.precipitationSumRecent48h.toStringAsFixed(1)} mm',
                    ),
                    ConditionTile(
                      icon: FontAwesomeIcons.wind,
                      label: 'Viento máx.',
                      value: '${conditions.windSpeedMax.round()} km/h',
                    ),
                    ConditionTile(
                      icon: FontAwesomeIcons.fan,
                      label: 'Rachas',
                      value: '${conditions.windGustsMax.round()} km/h',
                    ),
                    ConditionTile(
                      icon: FontAwesomeIcons.calendarWeek,
                      label: 'Viento sostenido 48h',
                      value: '${conditions.windSpeedSustained48h.round()} km/h',
                    ),
                    ConditionTile(
                      icon: FontAwesomeIcons.water,
                      label: 'Altura de ola',
                      value: conditions.waveHeight != null ? '${conditions.waveHeight!.toStringAsFixed(1)} m' : '—',
                    ),
                    ConditionTile(
                      icon: FontAwesomeIcons.waterLadder,
                      label: 'Oleaje de viento',
                      value:
                          conditions.windWaveHeight != null ? '${conditions.windWaveHeight!.toStringAsFixed(1)} m' : '—',
                    ),
                    ConditionTile(
                      icon: FontAwesomeIcons.chartLine,
                      label: 'Oleaje máx. 48h',
                      value: conditions.waveHeightMaxRecent48h != null
                          ? '${conditions.waveHeightMaxRecent48h!.toStringAsFixed(1)} m'
                          : '—',
                    ),
                    ConditionTile(
                      icon: FontAwesomeIcons.personSwimming,
                      label: 'Temp. del agua',
                      value: conditions.seaSurfaceTemperature != null
                          ? '${conditions.seaSurfaceTemperature!.round()}°C'
                          : '—',
                    ),
                    ConditionTile(
                      icon: FontAwesomeIcons.waveSquare,
                      label: 'Oleaje de fondo',
                      value:
                          conditions.swellWaveHeight != null ? '${conditions.swellWaveHeight!.toStringAsFixed(1)} m' : '—',
                    ),
                    ConditionTile(
                      icon: FontAwesomeIcons.stopwatch,
                      label: 'Periodo swell',
                      value: conditions.swellWavePeriod != null ? '${conditions.swellWavePeriod!.round()} s' : '—',
                    ),
                  ],
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}
