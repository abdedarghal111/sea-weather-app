import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/forecast_point.dart';
import '../models/location.dart';
import '../models/location_forecast.dart';
import '../models/trailing_window.dart';
import '../models/weather_snapshot.dart';
import 'api_error.dart';

const _requestTimeout = Duration(seconds: 15);

class OpenMeteoApi {
  // Con past_days=2 y forecast_days=16 los arrays diarios traen 18 entradas
  // [anteayer, ayer, hoy, +1...+15] y los horarios 18*24 horas en el mismo
  // orden cronológico: hoy empieza en el índice pastDays*24.
  static const _pastDays = 2;
  static const _forecastDays = 16; // máximo que permite Open-Meteo

  // El modelo marino solo llega a unos 9 días: más allá devolvía arrays
  // rellenos de null, casi el doble de payload para nada.
  static const _marineForecastDays = 10;

  /// Open-Meteo limita las peticiones **simultáneas** (responde 429 "too many
  /// concurrent requests" a partir de unas cinco a la vez), aparte de la
  /// cuota por minuto. Con varias localidades en pantalla es fácil pasarse,
  /// así que las consultas se encolan.
  static final _requestGate = _RequestGate(4);

  /// Espera entre reintentos de un fallo transitorio. Un 429 por concurrencia
  /// se despeja en milisegundos.
  static const _retryDelays = [
    Duration(milliseconds: 250),
    Duration(milliseconds: 750),
  ];

  /// Pide un JSON reintentando los fallos transitorios y traduciendo el resto
  /// a [ApiException].
  static Future<Map<String, dynamic>> _fetchJson(Uri uri) async {
    for (var attempt = 0;; attempt++) {
      try {
        return await _requestGate.run(() => _getJson(uri));
      } on ApiException catch (error) {
        if (!error.isRetryable || attempt >= _retryDelays.length) rethrow;
        await Future<void>.delayed(_retryDelays[attempt]);
      }
    }
  }

  /// Una sola consulta. Una respuesta no-200 trae `{"error": true, "reason":
  /// "..."}`, así que el motivo se saca de ahí cuando existe.
  static Future<Map<String, dynamic>> _getJson(Uri uri) async {
    final http.Response response;
    try {
      response = await http.get(uri).timeout(_requestTimeout);
    } catch (error) {
      throw translateTransportError(error);
    }

    Map<String, dynamic>? body;
    try {
      final decoded = jsonDecode(response.body);
      if (decoded is Map<String, dynamic>) body = decoded;
    } catch (_) {
      // Cuerpo que no es JSON: se trata igual que un cuerpo inesperado.
    }

    if (response.statusCode != 200) {
      throw translateApiError(response.statusCode, body?['reason'] as String?);
    }
    if (body == null || body['error'] == true) {
      throw translateApiError(response.statusCode, body?['reason'] as String?);
    }
    return body;
  }

  /// Lee un array numérico de la respuesta admitiendo huecos. Una clave
  /// ausente o de otro tipo se trata como array vacío, no como error: la API
  /// devuelve 200 con la unidad "undefined" y todo null cuando la variable no
  /// aplica a ese punto.
  static List<num?> _numList(dynamic raw) {
    if (raw is! List) return const [];
    return raw.map((v) => v is num ? v : null).toList(growable: false);
  }

  static List<String?> _stringList(dynamic raw) {
    if (raw is! List) return const [];
    return raw.map((v) => v is String ? v : null).toList(growable: false);
  }

  static Future<LocationForecast> fetchForecast(Location location) async {
    final forecastUri = Uri.parse(
      'https://api.open-meteo.com/v1/forecast'
      '?latitude=${location.latitude}&longitude=${location.longitude}'
      '&current=temperature_2m,apparent_temperature,cloud_cover,weather_code'
      '&hourly=temperature_2m,apparent_temperature,precipitation_probability,precipitation,'
      'weather_code,cloud_cover,wind_speed_10m,wind_gusts_10m,uv_index,wind_direction_10m'
      '&daily=temperature_2m_max,apparent_temperature_max,precipitation_probability_max,precipitation_sum,'
      'wind_speed_10m_max,wind_gusts_10m_max,uv_index_max,sunshine_duration,weather_code,cloud_cover_mean,'
      'sunrise,sunset,wind_direction_10m_dominant'
      '&timezone=auto&forecast_days=$_forecastDays&past_days=$_pastDays',
    );
    final marineUri = Uri.parse(
      'https://marine-api.open-meteo.com/v1/marine'
      '?latitude=${location.latitude}&longitude=${location.longitude}'
      '&current=wave_height,wave_direction,wind_wave_height,swell_wave_height,'
      'swell_wave_period,sea_surface_temperature'
      '&hourly=wave_height,wave_direction,wind_wave_height,swell_wave_height,'
      'swell_wave_period,sea_surface_temperature'
      '&daily=wave_height_max,wave_direction_dominant'
      '&timezone=auto&forecast_days=$_marineForecastDays&past_days=$_pastDays',
    );

    // La marina se pide en paralelo pero su fallo no puede tumbar la
    // previsión: una zona de interior o un rechazo puntual del servicio
    // marino dejan la app sin oleaje, no sin tiempo.
    final results = await Future.wait([
      _fetchJson(forecastUri),
      _fetchJson(marineUri).then<Map<String, dynamic>?>((json) => json).catchError((_) => null),
    ]);

    final forecast = results[0]!;
    final marine = results[1];

    final current = forecast['current'] as Map<String, dynamic>?;
    final daily = forecast['daily'] as Map<String, dynamic>?;
    final hourly = forecast['hourly'] as Map<String, dynamic>?;
    if (current == null || daily == null || hourly == null) {
      throw const ApiException(
        ApiErrorKind.malformedResponse,
        'La previsión de esta localidad ha llegado incompleta.',
      );
    }
    final marineCurrent = marine?['current'] as Map<String, dynamic>?;
    final marineDaily = marine?['daily'] as Map<String, dynamic>?;
    final marineHourly = marine?['hourly'] as Map<String, dynamic>?;

    // Todo lo que viene de la API se lee como anulable. La Forecast API
    // devuelve null en las últimas horas y en el último día cuando la zona
    // horaria del punto tiene desfase negativo respecto a UTC, y `cast<num>()`
    // en Dart es perezoso: no falla al castear, falla al leer.
    final dailyTime = _stringList(daily['time']);
    final dailyTemp = _numList(daily['temperature_2m_max']);
    final dailyApparentTemp = _numList(daily['apparent_temperature_max']);
    final dailyRainProbability = _numList(daily['precipitation_probability_max']);
    final dailyRainTotal = _numList(daily['precipitation_sum']);
    final dailyWind = _numList(daily['wind_speed_10m_max']);
    final dailyGusts = _numList(daily['wind_gusts_10m_max']);
    final dailyUv = _numList(daily['uv_index_max']);
    final dailySunshine = _numList(daily['sunshine_duration']);
    final dailyWeatherCode = _numList(daily['weather_code']);
    final dailyCloudCover = _numList(daily['cloud_cover_mean']);
    final dailySunrise = _stringList(daily['sunrise']);
    final dailySunset = _stringList(daily['sunset']);
    final dailyWindDirection = _numList(daily['wind_direction_10m_dominant']);
    final dailyWaveMax = marineDaily == null ? null : _numList(marineDaily['wave_height_max']);
    final dailyWaveDirection =
        marineDaily == null ? null : _numList(marineDaily['wave_direction_dominant']);

    final hourlyTime = _stringList(hourly['time']);
    final hourlyTemp = _numList(hourly['temperature_2m']);
    final hourlyApparentTemp = _numList(hourly['apparent_temperature']);
    final hourlyRainProbability = _numList(hourly['precipitation_probability']);
    final hourlyRainTotal = _numList(hourly['precipitation']);
    final hourlyWeatherCode = _numList(hourly['weather_code']);
    final hourlyCloudCover = _numList(hourly['cloud_cover']);
    final hourlyWind = _numList(hourly['wind_speed_10m']);
    final hourlyGusts = _numList(hourly['wind_gusts_10m']);
    final hourlyWindDirection = _numList(hourly['wind_direction_10m']);
    final hourlyUv = _numList(hourly['uv_index']);
    final hourlyWave = marineHourly == null ? null : _numList(marineHourly['wave_height']);
    final hourlyWaveDirection =
        marineHourly == null ? null : _numList(marineHourly['wave_direction']);
    final hourlyWindWave = marineHourly == null ? null : _numList(marineHourly['wind_wave_height']);
    final hourlySwellHeight = marineHourly == null ? null : _numList(marineHourly['swell_wave_height']);
    final hourlySwellPeriod = marineHourly == null ? null : _numList(marineHourly['swell_wave_period']);
    final hourlySeaTemp = marineHourly == null ? null : _numList(marineHourly['sea_surface_temperature']);

    final todayIndex = _pastDays;

    // "Sostenido/reciente" = media (viento) o suma (lluvia) de los 2 días
    // anteriores a [dayIndex], sin incluir ese propio día.
    double? recentDailyAverage(List<num?> values, int dayIndex) {
      if (dayIndex <= 0) return null;
      return trailingAverage(values, dayIndex - 1, 2);
    }

    double? recentDailySum(List<num?> values, int dayIndex) {
      if (dayIndex <= 0) return null;
      return trailingSum(values, dayIndex - 1, 2);
    }

    // Los arrays marinos son MÁS CORTOS que los meteorológicos: el modelo de
    // olas solo llega a unos días, así que se le piden menos. Todo lo que los
    // recorra tiene que recortar al tamaño real y saltarse los huecos null,
    // en vez de asumir que un índice válido en el array diario lo es aquí.
    double? recentMarineDailyAverage(int dayIndex) {
      final values = dailyWaveMax;
      if (values == null || dayIndex <= 0) return null;
      final end = dayIndex.clamp(0, values.length);
      final start = (end - 2).clamp(0, end);
      final window = values.sublist(start, end).whereType<num>();
      if (window.isEmpty) return null;
      return window.map((v) => v.toDouble()).reduce((a, b) => a + b) / window.length;
    }

    // La API marina no ofrece agregados diarios nativos para oleaje de
    // fondo/viento/temperatura del agua (solo wave_height_max): se derivan
    // agrupando el array horario marino por día de calendario.
    double? marineDailyMax(List<num?>? hourlyValues, int dayIndex) {
      if (hourlyValues == null) return null;
      final start = dayIndex * 24;
      final end = (start + 24).clamp(0, hourlyValues.length);
      num? max;
      for (var i = start; i < end; i++) {
        final v = hourlyValues[i];
        if (v == null) continue;
        if (max == null || v > max) max = v;
      }
      return max?.toDouble();
    }

    double? marineDailyMean(List<num?>? hourlyValues, int dayIndex) {
      if (hourlyValues == null) return null;
      final start = dayIndex * 24;
      final end = (start + 24).clamp(0, hourlyValues.length);
      var sum = 0.0;
      var count = 0;
      for (var i = start; i < end; i++) {
        final v = hourlyValues[i];
        if (v == null) continue;
        sum += v.toDouble();
        count++;
      }
      if (count == 0) return null;
      return sum / count;
    }

    WeatherSnapshot buildSnapshot({
      required double airTemperature,
      required double apparentTemperature,
      required double cloudCover,
      required double precipitationProbability,
      required double precipitationTotal,
      required double precipitationPast48h,
      required double windSpeed,
      required double windGustSpeed,
      required double averageWindSpeedPast48h,
      required double uvIndex,
      required double sunshineHours,
      required int periodWeatherCode,
      required int instantWeatherCode,
      double? waveHeight,
      double? waveHeightPast48h,
      double? windWaveHeight,
      double? swellHeight,
      double? swellPeriod,
      double? seaTemperature,
      DateTime? sunrise,
      DateTime? sunset,
      double? windFromDirection,
      double? waveFromDirection,
      required DateTime fetchedAt,
    }) =>
        WeatherSnapshot(
          airTemperature: airTemperature,
          apparentTemperature: apparentTemperature,
          cloudCover: cloudCover,
          precipitationProbability: precipitationProbability,
          precipitationTotal: precipitationTotal,
          precipitationPast48h: precipitationPast48h,
          windSpeed: windSpeed,
          windGustSpeed: windGustSpeed,
          averageWindSpeedPast48h: averageWindSpeedPast48h,
          uvIndex: uvIndex,
          sunshineHours: sunshineHours,
          periodWeatherCode: periodWeatherCode,
          instantWeatherCode: instantWeatherCode,
          waveHeight: waveHeight,
          waveHeightPast48h: waveHeightPast48h,
          windWaveHeight: windWaveHeight,
          swellHeight: swellHeight,
          swellPeriod: swellPeriod,
          seaTemperature: seaTemperature,
          sunrise: sunrise,
          sunset: sunset,
          windFromDirection: windFromDirection,
          waveFromDirection: waveFromDirection,
          fetchedAt: fetchedAt,
        );

    // Lectura por índice tolerante a arrays más cortos de lo pedido.
    num? numberAt(List<num?> values, int i) => i < values.length ? values[i] : null;
    String? stringAt(List<String?> values, int i) => i < values.length ? values[i] : null;
    DateTime? parseTime(String? raw) => raw == null ? null : DateTime.tryParse(raw);

    // La tarjeta "ahora" es lo mínimo que la pantalla necesita: si el día de
    // hoy llega incompleto, la respuesta no sirve y se dice por qué.
    double requireTodayValue(List<num?> values, String field) {
      final value = numberAt(values, todayIndex);
      if (value == null) {
        throw ApiException(
          ApiErrorKind.malformedResponse,
          'La previsión de hoy de esta localidad ha llegado incompleta.',
          reason: '$field sin dato en el día $todayIndex',
        );
      }
      return value.toDouble();
    }

    final nowSnapshot = buildSnapshot(
      // Los valores de `current` pueden faltar: se cae al agregado de hoy.
      apparentTemperature: (current['apparent_temperature'] as num?)?.toDouble() ??
          requireTodayValue(dailyApparentTemp, 'apparent_temperature_max'),
      cloudCover: (current['cloud_cover'] as num?)?.toDouble() ??
          requireTodayValue(dailyCloudCover, 'cloud_cover_mean'),
      airTemperature: requireTodayValue(dailyTemp, 'temperature_2m_max'),
      precipitationProbability: requireTodayValue(dailyRainProbability, 'precipitation_probability_max'),
      precipitationTotal: requireTodayValue(dailyRainTotal, 'precipitation_sum'),
      precipitationPast48h: recentDailySum(dailyRainTotal, todayIndex) ?? 0,
      windSpeed: requireTodayValue(dailyWind, 'wind_speed_10m_max'),
      windGustSpeed: requireTodayValue(dailyGusts, 'wind_gusts_10m_max'),
      averageWindSpeedPast48h: recentDailyAverage(dailyWind, todayIndex) ??
          requireTodayValue(dailyWind, 'wind_speed_10m_max'),
      uvIndex: requireTodayValue(dailyUv, 'uv_index_max'),
      sunshineHours: requireTodayValue(dailySunshine, 'sunshine_duration') / 3600,
      periodWeatherCode: requireTodayValue(dailyWeatherCode, 'weather_code').toInt(),
      instantWeatherCode: (current['weather_code'] as num?)?.toInt() ??
          requireTodayValue(dailyWeatherCode, 'weather_code').toInt(),
      waveHeight: (marineCurrent?['wave_height'] as num?)?.toDouble(),
      windWaveHeight: (marineCurrent?['wind_wave_height'] as num?)?.toDouble(),
      swellHeight: (marineCurrent?['swell_wave_height'] as num?)?.toDouble(),
      swellPeriod: (marineCurrent?['swell_wave_period'] as num?)?.toDouble(),
      seaTemperature: (marineCurrent?['sea_surface_temperature'] as num?)?.toDouble(),
      waveHeightPast48h: recentMarineDailyAverage(todayIndex),
      waveFromDirection: (marineCurrent?['wave_direction'] as num?)?.toDouble(),
      sunrise: parseTime(stringAt(dailySunrise, todayIndex)),
      sunset: parseTime(stringAt(dailySunset, todayIndex)),
      fetchedAt: DateTime.now(),
    );

    // Acceso seguro a un array marino horario/diario en la posición [i]:
    // fuera de rango o dentro del hueco null de después del horizonte real
    // del modelo (ver comentario más arriba) devuelven null por igual.
    num? marineValueAt(List<num?>? values, int i) =>
        (values != null && i < values.length) ? values[i] : null;

    // Por horas: de hoy 0:00 hasta el final del array (últimos días de forecast).
    final todayHourStart = todayIndex * 24;
    final hourlyPoints = <ForecastPoint>[];
    for (var i = todayHourStart; i < hourlyTime.length; i++) {
      // Una hora sin todos sus datos se omite: es lo que devuelve la API en
      // las últimas horas del rango cuando el punto tiene desfase horario
      // negativo respecto a UTC. Mejor un hueco en la gráfica que un fallo.
      final time = parseTime(stringAt(hourlyTime, i));
      final temp = numberAt(hourlyTemp, i);
      final apparentTemp = numberAt(hourlyApparentTemp, i);
      final cloudCover = numberAt(hourlyCloudCover, i);
      final rainProbability = numberAt(hourlyRainProbability, i);
      final wind = numberAt(hourlyWind, i);
      final gusts = numberAt(hourlyGusts, i);
      final uv = numberAt(hourlyUv, i);
      final code = numberAt(hourlyWeatherCode, i);
      // sunshine_duration solo existe como agregado diario: se reutiliza el
      // valor de ese día para todas sus horas.
      final sunshine = numberAt(dailySunshine, i ~/ 24);
      if (time == null ||
          temp == null ||
          apparentTemp == null ||
          cloudCover == null ||
          rainProbability == null ||
          wind == null ||
          gusts == null ||
          uv == null ||
          code == null ||
          sunshine == null) {
        continue;
      }

      hourlyPoints.add(ForecastPoint(
        time: time,
        weather: buildSnapshot(
          airTemperature: temp.toDouble(),
          apparentTemperature: apparentTemp.toDouble(),
          cloudCover: cloudCover.toDouble(),
          precipitationProbability: rainProbability.toDouble(),
          precipitationTotal: trailingSum(hourlyRainTotal, i, 24),
          precipitationPast48h: trailingSum(hourlyRainTotal, i, 48),
          windSpeed: wind.toDouble(),
          windGustSpeed: gusts.toDouble(),
          averageWindSpeedPast48h: trailingAverage(hourlyWind, i, 48) ?? wind.toDouble(),
          uvIndex: uv.toDouble(),
          sunshineHours: sunshine.toDouble() / 3600,
          periodWeatherCode: code.toInt(),
          instantWeatherCode: code.toInt(),
          waveHeight: marineValueAt(hourlyWave, i)?.toDouble(),
          windWaveHeight: marineValueAt(hourlyWindWave, i)?.toDouble(),
          swellHeight: marineValueAt(hourlySwellHeight, i)?.toDouble(),
          swellPeriod: marineValueAt(hourlySwellPeriod, i)?.toDouble(),
          seaTemperature: marineValueAt(hourlySeaTemp, i)?.toDouble(),
          waveHeightPast48h: trailingMaxIfPresent(hourlyWave, i, 48),
          sunrise: parseTime(stringAt(dailySunrise, i ~/ 24)),
          sunset: parseTime(stringAt(dailySunset, i ~/ 24)),
          windFromDirection: numberAt(hourlyWindDirection, i)?.toDouble(),
          waveFromDirection: marineValueAt(hourlyWaveDirection, i)?.toDouble(),
          fetchedAt: time,
        ),
      ));
    }

    // Próximos días: de hoy (incluido) hasta el final del array diario.
    final dailyPoints = <ForecastPoint>[];
    for (var d = todayIndex; d < dailyTime.length; d++) {
      // Mismo criterio que en el bucle horario: el último día del rango llega
      // sin agregados cuando el desfase horario es negativo.
      final time = parseTime(stringAt(dailyTime, d));
      final temp = numberAt(dailyTemp, d);
      final apparentTemp = numberAt(dailyApparentTemp, d);
      final cloudCover = numberAt(dailyCloudCover, d);
      final rainProbability = numberAt(dailyRainProbability, d);
      final rainTotal = numberAt(dailyRainTotal, d);
      final wind = numberAt(dailyWind, d);
      final gusts = numberAt(dailyGusts, d);
      final uv = numberAt(dailyUv, d);
      final sunshine = numberAt(dailySunshine, d);
      final code = numberAt(dailyWeatherCode, d);
      if (time == null ||
          temp == null ||
          apparentTemp == null ||
          cloudCover == null ||
          rainProbability == null ||
          rainTotal == null ||
          wind == null ||
          gusts == null ||
          uv == null ||
          sunshine == null ||
          code == null) {
        continue;
      }

      dailyPoints.add(ForecastPoint(
        time: time,
        weather: buildSnapshot(
          airTemperature: temp.toDouble(),
          apparentTemperature: apparentTemp.toDouble(),
          cloudCover: cloudCover.toDouble(),
          precipitationProbability: rainProbability.toDouble(),
          precipitationTotal: rainTotal.toDouble(),
          precipitationPast48h: recentDailySum(dailyRainTotal, d) ?? 0,
          windSpeed: wind.toDouble(),
          windGustSpeed: gusts.toDouble(),
          averageWindSpeedPast48h: recentDailyAverage(dailyWind, d) ?? wind.toDouble(),
          uvIndex: uv.toDouble(),
          sunshineHours: sunshine.toDouble() / 3600,
          periodWeatherCode: code.toInt(),
          instantWeatherCode: code.toInt(),
          waveHeight: marineValueAt(dailyWaveMax, d)?.toDouble(),
          windWaveHeight: marineDailyMax(hourlyWindWave, d),
          swellHeight: marineDailyMax(hourlySwellHeight, d),
          swellPeriod: marineDailyMax(hourlySwellPeriod, d),
          seaTemperature: marineDailyMean(hourlySeaTemp, d),
          waveHeightPast48h: recentMarineDailyAverage(d),
          sunrise: parseTime(stringAt(dailySunrise, d)),
          sunset: parseTime(stringAt(dailySunset, d)),
          windFromDirection: numberAt(dailyWindDirection, d)?.toDouble(),
          waveFromDirection: marineValueAt(dailyWaveDirection, d)?.toDouble(),
          fetchedAt: time,
        ),
      ));
    }

    return LocationForecast(
      now: nowSnapshot,
      hourly: hourlyPoints,
      daily: dailyPoints,
    );
  }
}

/// Deja pasar como mucho [maxConcurrent] operaciones a la vez y encola el
/// resto en orden de llegada.
class _RequestGate {
  _RequestGate(this.maxConcurrent);

  final int maxConcurrent;
  final _waiting = <Completer<void>>[];
  int _running = 0;

  Future<T> run<T>(Future<T> Function() action) async {
    if (_running >= maxConcurrent) {
      final turn = Completer<void>();
      _waiting.add(turn);
      await turn.future;
    }
    _running++;
    try {
      return await action();
    } finally {
      _running--;
      if (_waiting.isNotEmpty) _waiting.removeAt(0).complete();
    }
  }
}
