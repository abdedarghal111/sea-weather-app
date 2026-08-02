import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

import '../models/beach_conditions.dart';
import '../models/condition_point.dart';
import '../models/spot.dart';
import '../models/spot_conditions_bundle.dart';
import '../services/conditions_cache.dart';
import '../widgets/condition_tile.dart';
import '../widgets/rating_gauge.dart';
import '../widgets/rating_time_series_chart.dart';
import '../widgets/raw_parameter_time_series_chart.dart';

class _RawParamSpec {
  final String title;
  final String unit;
  final double? Function(BeachConditions) value;
  const _RawParamSpec(this.title, this.unit, this.value);
}

const _rawParams = [
  _RawParamSpec('Temp. máx.', '°C', _tempMax),
  _RawParamSpec('Sensación', '°C', _feelsLike),
  _RawParamSpec('Nubosidad', '%', _cloudCover),
  _RawParamSpec('Índice UV', '', _uvIndex),
  _RawParamSpec('Horas de sol', 'h', _sunshine),
  _RawParamSpec('Prob. lluvia', '%', _rainProb),
  _RawParamSpec('Lluvia', 'mm', _rainToday),
  _RawParamSpec('Lluvia 48h', 'mm', _rain48h),
  _RawParamSpec('Viento máx.', 'km/h', _windMax),
  _RawParamSpec('Rachas', 'km/h', _gusts),
  _RawParamSpec('Viento sostenido 48h', 'km/h', _windSustained48h),
  _RawParamSpec('Altura de ola', 'm', _waveHeight),
  _RawParamSpec('Oleaje de viento', 'm', _windWaveHeight),
  _RawParamSpec('Oleaje máx. 48h', 'm', _waveMax48h),
  _RawParamSpec('Temp. del agua', '°C', _seaTemp),
  _RawParamSpec('Oleaje de fondo', 'm', _swellHeight),
  _RawParamSpec('Periodo swell', 's', _swellPeriod),
];

double? _tempMax(BeachConditions c) => c.airTempMax;
double? _feelsLike(BeachConditions c) => c.feelsLike;
double? _cloudCover(BeachConditions c) => c.cloudCoverCurrent;
double? _uvIndex(BeachConditions c) => c.uvIndexMax;
double? _sunshine(BeachConditions c) => c.sunshineDurationHours;
double? _rainProb(BeachConditions c) => c.precipitationProbabilityMax;
double? _rainToday(BeachConditions c) => c.precipitationSumToday;
double? _rain48h(BeachConditions c) => c.precipitationSumRecent48h;
double? _windMax(BeachConditions c) => c.windSpeedMax;
double? _gusts(BeachConditions c) => c.windGustsMax;
double? _windSustained48h(BeachConditions c) => c.windSpeedSustained48h;
double? _waveHeight(BeachConditions c) => c.waveHeight;
double? _windWaveHeight(BeachConditions c) => c.windWaveHeight;
double? _waveMax48h(BeachConditions c) => c.waveHeightMaxRecent48h;
double? _seaTemp(BeachConditions c) => c.seaSurfaceTemperature;
double? _swellHeight(BeachConditions c) => c.swellWaveHeight;
double? _swellPeriod(BeachConditions c) => c.swellWavePeriod;

const _weekdayNames = ['lun', 'mar', 'mié', 'jue', 'vie', 'sáb', 'dom'];
const _monthNames = [
  'ene', 'feb', 'mar', 'abr', 'may', 'jun',
  'jul', 'ago', 'sep', 'oct', 'nov', 'dic',
];

String _hourLabel(DateTime time) => '${time.hour}h';

/// Rango horario mostrado en el panel "Por horas".
enum HourlyRange { morning, full }

const _morningStartHour = 8;
const _morningEndHour = 22;

String _dayLabel(DateTime time) =>
    '${_weekdayNames[time.weekday - 1]} ${time.day}';

/// Cabecera del selector de día del panel "Por horas": "Hoy", "Mañana" o
/// "lun 4 ago" para el resto.
String _hourlyDayHeaderLabel(DateTime date) {
  final today = DateTime.now();
  final difference = DateTime(date.year, date.month, date.day)
      .difference(DateTime(today.year, today.month, today.day))
      .inDays;
  if (difference == 0) return 'Hoy';
  if (difference == 1) return 'Mañana';
  return '${_weekdayNames[date.weekday - 1]} ${date.day} ${_monthNames[date.month - 1]}';
}

class SpotDetailScreen extends StatefulWidget {
  final Spot spot;

  const SpotDetailScreen({super.key, required this.spot});

  @override
  State<SpotDetailScreen> createState() => _SpotDetailScreenState();
}

class _SpotDetailScreenState extends State<SpotDetailScreen> {
  final _cache = ConditionsCache();
  Future<SpotConditionsBundle>? _future;
  int _hourlyDayOffset = 0;
  HourlyRange _hourlyRange = HourlyRange.morning;

  @override
  void initState() {
    super.initState();
    _future = _cache.getConditions(widget.spot);
  }

  Future<void> _refresh({bool force = false}) async {
    setState(() {
      _future = _cache.getConditions(widget.spot, forceRefresh: force);
    });
    try {
      await _future;
    } catch (_) {
      // El FutureBuilder ya muestra el estado de error; aquí solo evitamos
      // que quede como excepción asíncrona sin capturar.
    }
  }

  String _minutesAgoLabel(DateTime fetchedAt) {
    final minutes = DateTime.now().difference(fetchedAt).inMinutes;
    if (minutes < 1) return 'actualizado justo ahora';
    return 'actualizado hace $minutes min';
  }

  /// Días completos que hay disponibles en [SpotConditionsBundle.hourly].
  int _hourlyDayCount(SpotConditionsBundle bundle) => bundle.hourly.length ~/ 24;

  /// [_hourlyDayOffset] recortado al rango de días realmente disponible.
  int _clampedHourlyOffset(SpotConditionsBundle bundle) {
    final dayCount = _hourlyDayCount(bundle);
    return _hourlyDayOffset.clamp(0, dayCount > 0 ? dayCount - 1 : 0);
  }

  List<ConditionPoint> _hourlySlice(SpotConditionsBundle bundle, int offset) {
    final day = bundle.hourly.skip(offset * 24).take(24).toList();
    if (_hourlyRange == HourlyRange.full) return day;
    return day
        .where((p) =>
            p.time.hour >= _morningStartHour && p.time.hour <= _morningEndHour)
        .toList();
  }

  Widget _buildHourlyRangeSelector() {
    return Center(
      child: SegmentedButton<HourlyRange>(
        segments: const [
          ButtonSegment(
            value: HourlyRange.morning,
            label: Text('Mañana'),
            icon: FaIcon(FontAwesomeIcons.sun, size: 14),
          ),
          ButtonSegment(
            value: HourlyRange.full,
            label: Text('24 horas'),
            icon: FaIcon(FontAwesomeIcons.clock, size: 14),
          ),
        ],
        selected: {_hourlyRange},
        onSelectionChanged: (selection) =>
            setState(() => _hourlyRange = selection.first),
      ),
    );
  }

  Widget _buildHourlyDaySelector(SpotConditionsBundle bundle, int offset, int dayCount) {
    final headerDate = dayCount > 0 ? bundle.hourly[offset * 24].time : DateTime.now();

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        IconButton(
          icon: const FaIcon(FontAwesomeIcons.chevronLeft, size: 16),
          onPressed:
              offset > 0 ? () => setState(() => _hourlyDayOffset = offset - 1) : null,
        ),
        SizedBox(
          width: 120,
          child: Text(
            _hourlyDayHeaderLabel(headerDate),
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.titleMedium,
          ),
        ),
        IconButton(
          icon: const FaIcon(FontAwesomeIcons.chevronRight, size: 16),
          onPressed: offset < dayCount - 1
              ? () => setState(() => _hourlyDayOffset = offset + 1)
              : null,
        ),
      ],
    );
  }

  /// Posición fraccionaria (p. ej. 2.5 = a mitad de camino entre el punto 2
  /// y el 3) del instante actual dentro de [points], o `null` si "ahora"
  /// cae fuera del rango mostrado (se está viendo otro día, o la hora
  /// actual queda fuera del filtro "Mañana").
  double? _nowPosition(List<ConditionPoint> points) {
    if (points.isEmpty) return null;
    final now = DateTime.now();
    if (now.isBefore(points.first.time) || now.isAfter(points.last.time)) {
      return null;
    }
    for (var i = 0; i < points.length - 1; i++) {
      final t0 = points[i].time;
      final t1 = points[i + 1].time;
      if (!now.isBefore(t0) && now.isBefore(t1)) {
        final fraction =
            now.difference(t0).inSeconds / t1.difference(t0).inSeconds;
        return i + fraction;
      }
    }
    return (points.length - 1).toDouble();
  }

  List<Widget> _buildSeriesSection(
    List<ConditionPoint> points,
    String Function(DateTime) labelBuilder, {
    double? highlightX,
  }) {
    if (points.isEmpty) {
      return [const Text('Sin datos disponibles.')];
    }

    final times = points.map((p) => p.time).toList();

    return [
      RatingTimeSeriesChart(
        title: 'Agua cristalina',
        times: times,
        scores:
            points.map((p) => p.conditions.rateWaterClarity().score).toList(),
        labelBuilder: labelBuilder,
        highlightX: highlightX,
      ),
      RatingTimeSeriesChart(
        title: 'Playa removida',
        times: times,
        scores:
            points.map((p) => p.conditions.ratePlayaRemovida().score).toList(),
        labelBuilder: labelBuilder,
        highlightX: highlightX,
      ),
      RatingTimeSeriesChart(
        title: 'Surf',
        times: times,
        scores: points.map((p) => p.conditions.rateSurf().score).toList(),
        labelBuilder: labelBuilder,
        highlightX: highlightX,
      ),
      RatingTimeSeriesChart(
        title: 'Sol',
        times: times,
        scores: points.map((p) => p.conditions.rateSun().score).toList(),
        labelBuilder: labelBuilder,
        highlightX: highlightX,
      ),
      RatingTimeSeriesChart(
        title: 'Lluvia',
        times: times,
        scores: points.map((p) => p.conditions.rateRain().score).toList(),
        labelBuilder: labelBuilder,
        highlightX: highlightX,
      ),
      for (final spec in _rawParams)
        RawParameterTimeSeriesChart(
          title: spec.title,
          unit: spec.unit,
          times: times,
          values: points.map((p) => spec.value(p.conditions)).toList(),
          labelBuilder: labelBuilder,
          highlightX: highlightX,
        ),
    ];
  }

  Widget _errorView() => ListView(
        children: [
          const SizedBox(height: 80),
          const FaIcon(FontAwesomeIcons.triangleExclamation, size: 48),
          const SizedBox(height: 12),
          const Center(
              child: Text(
                  'No se pudo obtener el tiempo. Desliza para reintentar.')),
        ],
      );

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: Text(widget.spot.name),
          bottom: const TabBar(
            tabs: [
              Tab(icon: FaIcon(FontAwesomeIcons.solidClock), text: 'Ahora'),
              Tab(icon: FaIcon(FontAwesomeIcons.chartLine), text: 'Por horas'),
              Tab(
                  icon: FaIcon(FontAwesomeIcons.calendarDays),
                  text: 'Próximos días'),
            ],
          ),
        ),
        body: FutureBuilder<SpotConditionsBundle>(
          future: _future,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snapshot.hasError) {
              return RefreshIndicator(
                  onRefresh: () => _refresh(force: true), child: _errorView());
            }

            final bundle = snapshot.data!;
            final conditions = bundle.current;
            final hourlyDayCount = _hourlyDayCount(bundle);
            final hourlyOffset = _clampedHourlyOffset(bundle);
            final hourlyPoints = _hourlySlice(bundle, hourlyOffset);

            return TabBarView(
              children: [
                RefreshIndicator(
                  onRefresh: () => _refresh(force: true),
                  child: _buildNowTab(conditions),
                ),
                RefreshIndicator(
                  onRefresh: () => _refresh(force: true),
                  child: ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      _buildHourlyDaySelector(
                          bundle, hourlyOffset, hourlyDayCount),
                      const SizedBox(height: 8),
                      _buildHourlyRangeSelector(),
                      const SizedBox(height: 12),
                      ..._buildSeriesSection(
                        hourlyPoints,
                        _hourLabel,
                        highlightX: _nowPosition(hourlyPoints),
                      ),
                    ],
                  ),
                ),
                RefreshIndicator(
                  onRefresh: () => _refresh(force: true),
                  child: ListView(
                    padding: const EdgeInsets.all(16),
                    children: _buildSeriesSection(bundle.daily, _dayLabel),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildNowTab(BeachConditions conditions) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text(_minutesAgoLabel(conditions.fetchedAt),
            style: Theme.of(context).textTheme.bodySmall),
        const SizedBox(height: 12),
        RatingGauge(
            title: 'Agua cristalina', rating: conditions.rateWaterClarity()),
        const SizedBox(height: 16),
        RatingGauge(
            title: 'Playa removida', rating: conditions.ratePlayaRemovida()),
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
              value:
                  '${conditions.precipitationSumToday.toStringAsFixed(1)} mm',
            ),
            ConditionTile(
              icon: FontAwesomeIcons.cloudShowersHeavy,
              label: 'Lluvia 48h',
              value:
                  '${conditions.precipitationSumRecent48h.toStringAsFixed(1)} mm',
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
              value: conditions.waveHeight != null
                  ? '${conditions.waveHeight!.toStringAsFixed(1)} m'
                  : '—',
            ),
            ConditionTile(
              icon: FontAwesomeIcons.waterLadder,
              label: 'Oleaje de viento',
              value: conditions.windWaveHeight != null
                  ? '${conditions.windWaveHeight!.toStringAsFixed(1)} m'
                  : '—',
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
              value: conditions.swellWaveHeight != null
                  ? '${conditions.swellWaveHeight!.toStringAsFixed(1)} m'
                  : '—',
            ),
            ConditionTile(
              icon: FontAwesomeIcons.stopwatch,
              label: 'Periodo swell',
              value: conditions.swellWavePeriod != null
                  ? '${conditions.swellWavePeriod!.round()} s'
                  : '—',
            ),
          ],
        ),
      ],
    );
  }
}
