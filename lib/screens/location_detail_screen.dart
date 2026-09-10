// Pantalla de detalle de una localidad: pestañas de ahora, por horas y
// próximos días.

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

/// Una medida del tiempo o del mar con lo necesario para mostrarla en sus
/// dos formas: tarjeta en "Ahora" y gráfica en las series temporales. Así la
/// lista de medidas y su orden se declaran una sola vez.
class MeasurementSpec {
  /// Título de la gráfica, y también etiqueta de la tarjeta salvo que
  /// [tileLabel] diga otra cosa.
  final String title;
  final String unit;
  final FaIconData icon;
  final String? tileLabel;

  /// Devuelve null cuando la medida no aplica al punto, como los datos
  /// marinos de una localidad de interior.
  final double? Function(WeatherSnapshot) value;

  const MeasurementSpec(this.title, this.unit, this.icon, this.value, {this.tileLabel});

  String get label => tileLabel ?? title;

  /// El valor para la tarjeta de "Ahora", o "—" si no hay dato. Milímetros
  /// y metros llevan un decimal, porque redondear 0.4 mm a "0 mm" pierde el
  /// dato; el resto se redondea.
  String formatted(WeatherSnapshot weather) {
    final measured = value(weather);
    if (measured == null) return '—';
    final text = unit == 'mm' || unit == 'm'
        ? measured.toStringAsFixed(1)
        : measured.round().toString();
    if (unit.isEmpty) return text;
    return unit == '°C' || unit == '%' ? '$text$unit' : '$text $unit';
  }
}

/// Medidas que se muestran, en el orden en que aparecen. No es `const`
/// porque los extractores son funciones anónimas.
final _measurements = <MeasurementSpec>[
  MeasurementSpec('Temp. máx.', '°C', FontAwesomeIcons.temperatureHalf,
      (w) => w.airTemperature),
  MeasurementSpec('Sensación', '°C', FontAwesomeIcons.temperatureThreeQuarters,
      (w) => w.apparentTemperature),
  MeasurementSpec('Nubosidad', '%', FontAwesomeIcons.cloud, (w) => w.cloudCover),
  MeasurementSpec('Índice UV', '', FontAwesomeIcons.sun, (w) => w.uvIndex),
  MeasurementSpec('Horas de sol', 'h', FontAwesomeIcons.solarPanel, (w) => w.sunshineHours),
  MeasurementSpec('Prob. lluvia', '%', FontAwesomeIcons.droplet,
      (w) => w.precipitationProbability,
      tileLabel: 'Prob. lluvia hoy'),
  MeasurementSpec('Lluvia', 'mm', FontAwesomeIcons.cloudRain, (w) => w.precipitationTotal,
      tileLabel: 'Lluvia hoy'),
  MeasurementSpec('Lluvia 48h', 'mm', FontAwesomeIcons.cloudShowersHeavy,
      (w) => w.precipitationPast48h),
  MeasurementSpec('Viento máx.', 'km/h', FontAwesomeIcons.wind, (w) => w.windSpeed),
  MeasurementSpec('Rachas', 'km/h', FontAwesomeIcons.fan, (w) => w.windGustSpeed),
  MeasurementSpec('Viento sostenido 48h', 'km/h', FontAwesomeIcons.calendarWeek,
      (w) => w.averageWindSpeedPast48h),
  MeasurementSpec('Altura de ola', 'm', FontAwesomeIcons.water, (w) => w.waveHeight),
  MeasurementSpec('Oleaje de viento', 'm', FontAwesomeIcons.waterLadder,
      (w) => w.windWaveHeight),
  MeasurementSpec('Oleaje sostenido 48h', 'm', FontAwesomeIcons.chartLine,
      (w) => w.rmsWaveHeightPast48h),
  MeasurementSpec('Temp. del agua', '°C', FontAwesomeIcons.personSwimming,
      (w) => w.seaTemperature),
  MeasurementSpec('Oleaje de fondo', 'm', FontAwesomeIcons.waveSquare, (w) => w.swellHeight),
  MeasurementSpec('Periodo swell', 's', FontAwesomeIcons.stopwatch, (w) => w.swellPeriod),
];

const _weekdayNames = ['lun', 'mar', 'mié', 'jue', 'vie', 'sáb', 'dom'];
const _monthNames = [
  'ene', 'feb', 'mar', 'abr', 'may', 'jun',
  'jul', 'ago', 'sep', 'oct', 'nov', 'dic',
];

String _hourLabel(DateTime time) => '${time.hour}h';

String _timeLabel(DateTime time) =>
    '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';

/// Franja horaria mostrada en la pestaña "Por horas": solo las horas de luz
/// o el día entero.
enum HourlyWindow { daylight, fullDay }

const _daylightStartHour = 8;
const _daylightEndHour = 22;

String _dayLabel(DateTime time) =>
    '${_weekdayNames[time.weekday - 1]} ${time.day}';

/// Cabecera del selector de día: "Hoy", "Mañana" o "lun 4 ago".
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
      // El FutureBuilder ya pinta el error; esto solo evita que quede como
      // excepción asíncrona sin capturar.
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

  /// Posición fraccionaria del instante actual dentro de [points], o `null`
  /// si "ahora" cae fuera del rango mostrado.
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

  /// Tarjetas de una pestaña de serie temporal, en orden: las cinco
  /// gráficas de valoración, las dos de dirección y una por cada medida de
  /// [_measurements].
  ///
  /// Devuelve constructores, no widgets: así el `ListView.builder` solo
  /// construye las gráficas visibles, que recorren todos los puntos y
  /// llaman a los métodos `rateX()`.
  List<Widget Function()> _seriesCards(
    List<ForecastPoint> points,
    List<DateTime> times,
    String Function(DateTime) labelBuilder, {
    double? highlightPosition,
  }) {
    if (points.isEmpty) return [() => const Text('Sin datos disponibles.')];

    Widget ratingChart(String title, double Function(WeatherSnapshot) score) => RatingChart(
          title: title,
          times: times,
          scores: points.map((p) => score(p.weather)).toList(),
          labelBuilder: labelBuilder,
          highlightPosition: highlightPosition,
        );

    return [
      () => ratingChart(waterClaritySeriesTitle, (w) => w.rateWaterClarity().score),
      () => ratingChart(shoreDisturbanceSeriesTitle, (w) => w.rateShoreDisturbance().score),
      () => ratingChart('Surf', (w) => w.rateSurf().score),
      () => ratingChart('Sol', (w) => w.rateSun().score),
      () => ratingChart(rainSeriesTitle, (w) => w.rateRain().score),
      () => WindDirectionChart(
            times: times,
            directions: points.map((p) => p.weather.windFromDirection).toList(),
            labelBuilder: labelBuilder,
            highlightPosition: highlightPosition,
          ),
      () => WaveDirectionChart(
            times: times,
            directions: points.map((p) => p.weather.waveFromDirection).toList(),
            labelBuilder: labelBuilder,
            highlightPosition: highlightPosition,
          ),
      for (final spec in _measurements)
        () => MeasurementChart(
              title: spec.title,
              unit: spec.unit,
              times: times,
              values: points.map((p) => spec.value(p.weather)).toList(),
              labelBuilder: labelBuilder,
              highlightPosition: highlightPosition,
            ),
    ];
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
        // Reintentar solo se sugiere cuando puede funcionar.
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
            final hourlyOffset = _clampedHourlyOffset(forecast);
            final hourlyPoints = _hourlySlice(forecast, hourlyOffset);

            // Los selectores son dos tarjetas más de la lista, para que
            // scrolleen con las gráficas.
            final hourlyCards = <Widget Function()>[
              () => _buildHourlyDaySelector(
                  forecast, hourlyOffset, _hourlyDayCount(forecast)),
              () => const SizedBox(height: 8),
              () => _buildHourlyWindowSelector(),
              () => const SizedBox(height: 12),
              ..._seriesCards(
                hourlyPoints,
                hourlyPoints.map((p) => p.time).toList(),
                _hourLabel,
                highlightPosition: _nowMarkerPosition(hourlyPoints),
              ),
            ];
            final dailyCards = _seriesCards(
              forecast.daily,
              forecast.daily.map((p) => p.time).toList(),
              _dayLabel,
            );

            return TabBarView(
              children: [
                RefreshIndicator(
                  onRefresh: () => _refresh(force: true),
                  child: _buildNowTab(forecast.now),
                ),
                for (final cards in [hourlyCards, dailyCards])
                  RefreshIndicator(
                    onRefresh: () => _refresh(force: true),
                    child: ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: cards.length,
                      itemBuilder: (context, index) => cards[index](),
                    ),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildNowTab(WeatherSnapshot weather) {
    // Estas tres titulan su termómetro con el propio nivel ("Agua
    // cristalina", "Playa removida"...), no con el nombre de la medida.
    final waterClarity = weather.rateWaterClarity();
    final shoreDisturbance = weather.rateShoreDisturbance();
    final rain = weather.rateRain();

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text(_minutesAgoLabel(weather.fetchedAt),
            style: Theme.of(context).textTheme.bodySmall),
        const SizedBox(height: 12),
        RatingGauge(title: waterClarity.level.waterClarityTitle, rating: waterClarity),
        const SizedBox(height: 16),
        RatingGauge(
            title: shoreDisturbance.level.shoreDisturbanceTitle, rating: shoreDisturbance),
        const SizedBox(height: 16),
        RatingGauge(title: 'Surf', rating: weather.rateSurf()),
        const SizedBox(height: 16),
        RatingGauge(title: 'Sol', rating: weather.rateSun()),
        const SizedBox(height: 16),
        RatingGauge(title: rain.level.rainTitle, rating: rain),
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
            for (final spec in _measurements)
              MeasurementTile(
                icon: spec.icon,
                label: spec.label,
                value: spec.formatted(weather),
              ),
            // Amanecer y atardecer son horas, no series que se puedan
            // graficar, así que van fuera de [_measurements].
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
