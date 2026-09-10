import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

import '../models/forecast_point.dart';
import '../models/location.dart';
import '../models/location_forecast.dart';
import '../models/weather_snapshot.dart';
import '../services/api_error.dart';
import '../services/forecast_cache.dart';
import '../widgets/measurement_chart.dart';
import '../widgets/measurement_tile.dart';
import '../widgets/rating_chart.dart';
import '../widgets/rating_gauge.dart';
import '../widgets/wave_direction_chart.dart';
import '../widgets/wind_direction_chart.dart';

class MeasurementSpec {
  final String title;
  final String unit;
  final double? Function(WeatherSnapshot) value;
  const MeasurementSpec(this.title, this.unit, this.value);
}

const _measurements = [
  MeasurementSpec('Temp. máx.', '°C', _airTemperature),
  MeasurementSpec('Sensación', '°C', _apparentTemperature),
  MeasurementSpec('Nubosidad', '%', _cloudCover),
  MeasurementSpec('Índice UV', '', _uvIndex),
  MeasurementSpec('Horas de sol', 'h', _sunshineHours),
  MeasurementSpec('Prob. lluvia', '%', _precipitationProbability),
  MeasurementSpec('Lluvia', 'mm', _precipitationTotal),
  MeasurementSpec('Lluvia 48h', 'mm', _precipitationPast48h),
  MeasurementSpec('Viento máx.', 'km/h', _windSpeed),
  MeasurementSpec('Rachas', 'km/h', _windGustSpeed),
  MeasurementSpec('Viento sostenido 48h', 'km/h', _averageWindSpeedPast48h),
  MeasurementSpec('Altura de ola', 'm', _waveHeight),
  MeasurementSpec('Oleaje de viento', 'm', _windWaveHeight),
  MeasurementSpec('Oleaje sostenido 48h', 'm', _rmsWaveHeightPast48h),
  MeasurementSpec('Temp. del agua', '°C', _seaTemperature),
  MeasurementSpec('Oleaje de fondo', 'm', _swellHeight),
  MeasurementSpec('Periodo swell', 's', _swellPeriod),
];

double? _airTemperature(WeatherSnapshot w) => w.airTemperature;
double? _apparentTemperature(WeatherSnapshot w) => w.apparentTemperature;
double? _cloudCover(WeatherSnapshot w) => w.cloudCover;
double? _uvIndex(WeatherSnapshot w) => w.uvIndex;
double? _sunshineHours(WeatherSnapshot w) => w.sunshineHours;
double? _precipitationProbability(WeatherSnapshot w) => w.precipitationProbability;
double? _precipitationTotal(WeatherSnapshot w) => w.precipitationTotal;
double? _precipitationPast48h(WeatherSnapshot w) => w.precipitationPast48h;
double? _windSpeed(WeatherSnapshot w) => w.windSpeed;
double? _windGustSpeed(WeatherSnapshot w) => w.windGustSpeed;
double? _averageWindSpeedPast48h(WeatherSnapshot w) => w.averageWindSpeedPast48h;
double? _waveHeight(WeatherSnapshot w) => w.waveHeight;
double? _windWaveHeight(WeatherSnapshot w) => w.windWaveHeight;
double? _rmsWaveHeightPast48h(WeatherSnapshot w) => w.rmsWaveHeightPast48h;
double? _seaTemperature(WeatherSnapshot w) => w.seaTemperature;
double? _swellHeight(WeatherSnapshot w) => w.swellHeight;
double? _swellPeriod(WeatherSnapshot w) => w.swellPeriod;

const _weekdayNames = ['lun', 'mar', 'mié', 'jue', 'vie', 'sáb', 'dom'];
const _monthNames = [
  'ene', 'feb', 'mar', 'abr', 'may', 'jun',
  'jul', 'ago', 'sep', 'oct', 'nov', 'dic',
];

String _hourLabel(DateTime time) => '${time.hour}h';

String _timeLabel(DateTime time) =>
    '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';

/// Franja de horas mostrada en el panel "Por horas": solo las horas de luz o
/// el día entero.
enum HourlyWindow { daylight, fullDay }

const _daylightStartHour = 8;
const _daylightEndHour = 22;

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

class LocationDetailScreen extends StatefulWidget {
  final Location location;

  const LocationDetailScreen({super.key, required this.location});

  @override
  State<LocationDetailScreen> createState() => _LocationDetailScreenState();
}

class _LocationDetailScreenState extends State<LocationDetailScreen> {
  final _cache = ForecastCache();
  Future<LocationForecast>? _forecast;
  int _hourlyDayOffset = 0;
  HourlyWindow _hourlyWindow = HourlyWindow.daylight;

  @override
  void initState() {
    super.initState();
    _forecast = _cache.forecastFor(widget.location);
  }

  Future<void> _refresh({bool force = false}) async {
    setState(() {
      _forecast = _cache.forecastFor(widget.location, forceRefresh: force);
    });
    try {
      await _forecast;
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

  /// Días completos que hay disponibles en [LocationForecast.hourly].
  int _hourlyDayCount(LocationForecast forecast) => forecast.hourly.length ~/ 24;

  /// [_hourlyDayOffset] recortado al rango de días realmente disponible.
  int _clampedHourlyOffset(LocationForecast forecast) {
    final dayCount = _hourlyDayCount(forecast);
    return _hourlyDayOffset.clamp(0, dayCount > 0 ? dayCount - 1 : 0);
  }

  List<ForecastPoint> _hourlySlice(LocationForecast forecast, int offset) {
    final day = forecast.hourly.skip(offset * 24).take(24).toList();
    if (_hourlyWindow == HourlyWindow.fullDay) return day;
    return day
        .where((p) =>
            p.time.hour >= _daylightStartHour && p.time.hour <= _daylightEndHour)
        .toList();
  }

  Widget _buildHourlyWindowSelector() {
    return Center(
      child: SegmentedButton<HourlyWindow>(
        segments: const [
          ButtonSegment(
            value: HourlyWindow.daylight,
            label: Text('Día'),
            icon: FaIcon(FontAwesomeIcons.sun, size: 14),
          ),
          ButtonSegment(
            value: HourlyWindow.fullDay,
            label: Text('24 horas'),
            icon: FaIcon(FontAwesomeIcons.clock, size: 14),
          ),
        ],
        selected: {_hourlyWindow},
        onSelectionChanged: (selection) =>
            setState(() => _hourlyWindow = selection.first),
      ),
    );
  }

  Widget _buildHourlyDaySelector(LocationForecast forecast, int offset, int dayCount) {
    final headerDate = dayCount > 0 ? forecast.hourly[offset * 24].time : DateTime.now();

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
  /// actual queda fuera de la franja de horas de luz).
  double? _nowMarkerPosition(List<ForecastPoint> points) {
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

  /// Número de tarjetas que produce [_buildSeriesItem] para una serie no
  /// vacía: 5 gráficas de valoración + 1 de dirección de viento + 1 de
  /// dirección de las olas + 1 por cada [MeasurementSpec] de [_measurements].
  int _seriesItemCount(List<ForecastPoint> points) =>
      points.isEmpty ? 1 : 7 + _measurements.length;

  /// Construye bajo demanda la tarjeta `index` de una sección de serie
  /// temporal (a partir de [points]/[times] ya calculados una única vez por
  /// pestaña). Se usa como `itemBuilder` de un `ListView.builder` en vez de
  /// construir las ~23 gráficas por adelantado: así solo se calculan (y solo
  /// se llaman los métodos rateX(), que no son gratis) las que realmente
  /// entran en pantalla o en su caché de scroll.
  Widget _buildSeriesItem(
    List<ForecastPoint> points,
    List<DateTime> times,
    String Function(DateTime) labelBuilder,
    int index, {
    double? highlightPosition,
  }) {
    if (points.isEmpty) {
      return const Text('Sin datos disponibles.');
    }

    switch (index) {
      case 0:
        return RatingChart(
          title: waterClaritySeriesTitle,
          times: times,
          scores: points.map((p) => p.weather.rateWaterClarity().score).toList(),
          labelBuilder: labelBuilder,
          highlightPosition: highlightPosition,
        );
      case 1:
        return RatingChart(
          title: shoreDisturbanceSeriesTitle,
          times: times,
          scores: points.map((p) => p.weather.rateShoreDisturbance().score).toList(),
          labelBuilder: labelBuilder,
          highlightPosition: highlightPosition,
        );
      case 2:
        return RatingChart(
          title: 'Surf',
          times: times,
          scores: points.map((p) => p.weather.rateSurf().score).toList(),
          labelBuilder: labelBuilder,
          highlightPosition: highlightPosition,
        );
      case 3:
        return RatingChart(
          title: 'Sol',
          times: times,
          scores: points.map((p) => p.weather.rateSun().score).toList(),
          labelBuilder: labelBuilder,
          highlightPosition: highlightPosition,
        );
      case 4:
        return RatingChart(
          title: rainSeriesTitle,
          times: times,
          scores: points.map((p) => p.weather.rateRain().score).toList(),
          labelBuilder: labelBuilder,
          highlightPosition: highlightPosition,
        );
      case 5:
        return WindDirectionChart(
          times: times,
          directions: points.map((p) => p.weather.windFromDirection).toList(),
          labelBuilder: labelBuilder,
          highlightPosition: highlightPosition,
        );
      case 6:
        return WaveDirectionChart(
          times: times,
          directions: points.map((p) => p.weather.waveFromDirection).toList(),
          labelBuilder: labelBuilder,
          highlightPosition: highlightPosition,
        );
      default:
        final spec = _measurements[index - 7];
        return MeasurementChart(
          title: spec.title,
          unit: spec.unit,
          times: times,
          values: points.map((p) => spec.value(p.weather)).toList(),
          labelBuilder: labelBuilder,
          highlightPosition: highlightPosition,
        );
    }
  }

  Widget _errorView(Object? error) {
    final failure = error is ApiException ? error : null;
    return ListView(
      children: [
        const SizedBox(height: 80),
        const FaIcon(FontAwesomeIcons.triangleExclamation, size: 48),
        const SizedBox(height: 12),
        Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Text(
              failure?.message ?? 'No se pudo obtener el tiempo.',
              textAlign: TextAlign.center,
            ),
          ),
        ),
        // Reintentar solo se sugiere cuando puede servir de algo: unas
        // coordenadas inválidas no se arreglan deslizando.
        if (failure == null || failure.isRetryable) ...[
          const SizedBox(height: 8),
          const Center(child: Text('Desliza para reintentar.')),
        ],
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: Text(widget.location.name),
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
        body: FutureBuilder<LocationForecast>(
          future: _forecast,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snapshot.hasError) {
              return RefreshIndicator(
                  onRefresh: () => _refresh(force: true),
                  child: _errorView(snapshot.error));
            }

            final forecast = snapshot.data!;
            final weatherNow = forecast.now;
            final hourlyDayCount = _hourlyDayCount(forecast);
            final hourlyOffset = _clampedHourlyOffset(forecast);
            final hourlyPoints = _hourlySlice(forecast, hourlyOffset);
            final hourlyTimes = hourlyPoints.map((p) => p.time).toList();
            final hourlyHighlight = _nowMarkerPosition(hourlyPoints);
            final dailyTimes = forecast.daily.map((p) => p.time).toList();

            // Las dos pestañas de serie temporal usan ListView.builder (no
            // ListView(children: [...])) para que las ~23 gráficas de cada
            // una (incluidas las llamadas a rateX(), que no son gratis) se
            // construyan solo bajo demanda según lo que entra en pantalla o
            // en la caché de scroll, en vez de construirse siempre las tres
            // pestañas enteras en cada build (p. ej. al cambiar de día u
            // horario en "Por horas").
            const hourlyHeaderCount = 4;
            return TabBarView(
              children: [
                RefreshIndicator(
                  onRefresh: () => _refresh(force: true),
                  child: _buildNowTab(weatherNow),
                ),
                RefreshIndicator(
                  onRefresh: () => _refresh(force: true),
                  child: ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount:
                        hourlyHeaderCount + _seriesItemCount(hourlyPoints),
                    itemBuilder: (context, index) {
                      switch (index) {
                        case 0:
                          return _buildHourlyDaySelector(
                              forecast, hourlyOffset, hourlyDayCount);
                        case 1:
                          return const SizedBox(height: 8);
                        case 2:
                          return _buildHourlyWindowSelector();
                        case 3:
                          return const SizedBox(height: 12);
                        default:
                          return _buildSeriesItem(
                            hourlyPoints,
                            hourlyTimes,
                            _hourLabel,
                            index - hourlyHeaderCount,
                            highlightPosition: hourlyHighlight,
                          );
                      }
                    },
                  ),
                ),
                RefreshIndicator(
                  onRefresh: () => _refresh(force: true),
                  child: ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _seriesItemCount(forecast.daily),
                    itemBuilder: (context, index) => _buildSeriesItem(
                      forecast.daily,
                      dailyTimes,
                      _dayLabel,
                      index,
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _rainGauge(Rating rating) =>
      RatingGauge(title: rating.level.rainTitle, rating: rating);

  Widget _waterClarityGauge(Rating rating) =>
      RatingGauge(title: rating.level.waterClarityTitle, rating: rating);

  Widget _shoreDisturbanceGauge(Rating rating) =>
      RatingGauge(title: rating.level.shoreDisturbanceTitle, rating: rating);

  Widget _buildNowTab(WeatherSnapshot weather) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text(_minutesAgoLabel(weather.fetchedAt),
            style: Theme.of(context).textTheme.bodySmall),
        const SizedBox(height: 12),
        _waterClarityGauge(weather.rateWaterClarity()),
        const SizedBox(height: 16),
        _shoreDisturbanceGauge(weather.rateShoreDisturbance()),
        const SizedBox(height: 16),
        RatingGauge(title: 'Surf', rating: weather.rateSurf()),
        const SizedBox(height: 16),
        RatingGauge(title: 'Sol', rating: weather.rateSun()),
        const SizedBox(height: 16),
        _rainGauge(weather.rateRain()),
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
            MeasurementTile(
              icon: FontAwesomeIcons.temperatureHalf,
              label: 'Temp. máx.',
              value: '${weather.airTemperature.round()}°C',
            ),
            MeasurementTile(
              icon: FontAwesomeIcons.temperatureThreeQuarters,
              label: 'Sensación',
              value: '${weather.apparentTemperature.round()}°C',
            ),
            MeasurementTile(
              icon: FontAwesomeIcons.cloud,
              label: 'Nubosidad',
              value: '${weather.cloudCover.round()}%',
            ),
            MeasurementTile(
              icon: FontAwesomeIcons.sun,
              label: 'Índice UV',
              value: weather.uvIndex.round().toString(),
            ),
            MeasurementTile(
              icon: FontAwesomeIcons.solarPanel,
              label: 'Horas de sol',
              value: '${weather.sunshineHours.round()} h',
            ),
            MeasurementTile(
              icon: FontAwesomeIcons.droplet,
              label: 'Prob. lluvia hoy',
              value: '${weather.precipitationProbability.round()}%',
            ),
            MeasurementTile(
              icon: FontAwesomeIcons.cloudRain,
              label: 'Lluvia hoy',
              value: '${weather.precipitationTotal.toStringAsFixed(1)} mm',
            ),
            MeasurementTile(
              icon: FontAwesomeIcons.cloudShowersHeavy,
              label: 'Lluvia 48h',
              value: '${weather.precipitationPast48h.toStringAsFixed(1)} mm',
            ),
            MeasurementTile(
              icon: FontAwesomeIcons.wind,
              label: 'Viento máx.',
              value: '${weather.windSpeed.round()} km/h',
            ),
            MeasurementTile(
              icon: FontAwesomeIcons.fan,
              label: 'Rachas',
              value: '${weather.windGustSpeed.round()} km/h',
            ),
            MeasurementTile(
              icon: FontAwesomeIcons.calendarWeek,
              label: 'Viento sostenido 48h',
              value: '${weather.averageWindSpeedPast48h.round()} km/h',
            ),
            MeasurementTile(
              icon: FontAwesomeIcons.water,
              label: 'Altura de ola',
              value: weather.waveHeight != null
                  ? '${weather.waveHeight!.toStringAsFixed(1)} m'
                  : '—',
            ),
            MeasurementTile(
              icon: FontAwesomeIcons.waterLadder,
              label: 'Oleaje de viento',
              value: weather.windWaveHeight != null
                  ? '${weather.windWaveHeight!.toStringAsFixed(1)} m'
                  : '—',
            ),
            MeasurementTile(
              icon: FontAwesomeIcons.chartLine,
              label: 'Oleaje sostenido 48h',
              value: weather.rmsWaveHeightPast48h != null
                  ? '${weather.rmsWaveHeightPast48h!.toStringAsFixed(1)} m'
                  : '—',
            ),
            MeasurementTile(
              icon: FontAwesomeIcons.personSwimming,
              label: 'Temp. del agua',
              value: weather.seaTemperature != null
                  ? '${weather.seaTemperature!.round()}°C'
                  : '—',
            ),
            MeasurementTile(
              icon: FontAwesomeIcons.waveSquare,
              label: 'Oleaje de fondo',
              value: weather.swellHeight != null
                  ? '${weather.swellHeight!.toStringAsFixed(1)} m'
                  : '—',
            ),
            MeasurementTile(
              icon: FontAwesomeIcons.stopwatch,
              label: 'Periodo swell',
              value: weather.swellPeriod != null
                  ? '${weather.swellPeriod!.round()} s'
                  : '—',
            ),
            MeasurementTile(
              icon: FontAwesomeIcons.solidSun,
              label: 'Amanecer',
              value: weather.sunrise != null ? _timeLabel(weather.sunrise!) : '—',
            ),
            MeasurementTile(
              icon: FontAwesomeIcons.solidMoon,
              label: 'Atardecer',
              value: weather.sunset != null ? _timeLabel(weather.sunset!) : '—',
            ),
          ],
        ),
      ],
    );
  }
}
