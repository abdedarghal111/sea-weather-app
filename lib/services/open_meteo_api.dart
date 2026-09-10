// Consulta a Open-Meteo (previsión y datos marinos) y conversión de sus
// respuestas en la previsión que usa la app.

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
  // Los arrays llegan en orden cronológico empezando por el primer día
  // pasado: hoy es el índice _pastDays en los diarios y _pastDays*24 en los
  // horarios.
  static const _pastDays = 2;
  static const _forecastDays = 16; // máximo que permite Open-Meteo

  // El modelo marino solo llega a unos 9 días; más allá devuelve null.
  static const _marineForecastDays = 10;

  /// Open-Meteo limita las peticiones simultáneas (429 a partir de unas
  /// cinco), así que las consultas se encolan.
  static final _requestGate = _RequestGate(4);

  /// Espera entre reintentos: un 429 por concurrencia se despeja en
  /// milisegundos.
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

  /// Una sola consulta. Las respuestas de error traen `{"error": true,
  /// "reason": "..."}`, y de ahí sale el motivo cuando existe.
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
      // Cuerpo no JSON: se trata como respuesta inesperada más abajo.
    }

    if (response.statusCode != 200) {
      throw translateApiError(response.statusCode, body?['reason'] as String?);
    }
    if (body == null || body['error'] == true) {
      throw translateApiError(response.statusCode, body?['reason'] as String?);
    }
    return body;
  }

  /// Lee un array numérico admitiendo huecos. Una clave ausente o de otro
  /// tipo da un array vacío, no un error: la API responde 200 con todo null
  /// cuando la variable no aplica al punto.
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

    // La consulta marina va en paralelo y su fallo no tumba la previsión:
    // un punto de interior queda sin oleaje, no sin tiempo.
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

    // Todo se lee como anulable: la API devuelve null en las últimas horas
    // y el último día cuando el punto tiene desfase negativo respecto a UTC,
    // y `cast<num>()` es perezoso (no falla al castear, sino al leer).
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

    // "Reciente" = los 2 días anteriores a [dayIndex], sin incluirlo.
    double? recentDailyAverage(List<num?> values, int dayIndex) {
      if (dayIndex <= 0) return null;
      return trailingAverage(values, dayIndex - 1, 2);
    }

    double? recentDailySum(List<num?> values, int dayIndex) {
      if (dayIndex <= 0) return null;
      return trailingSum(values, dayIndex - 1, 2);
    }

    // El oleaje reciente sale del array horario marino con la misma ventana
    // de 48 h en las tres vistas, para que no se contradigan entre sí.
    int lastHourOfDay(int dayIndex) => dayIndex * 24 + 23;

    // La API marina solo trae wave_height_max como agregado diario: el
    // resto se deriva agrupando su array horario por día.
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

    // Lectura por índice tolerante a arrays más cortos de lo pedido o
    // inexistentes, como los marinos de un punto de interior.
    num? numberAt(List<num?>? values, int i) =>
        (values != null && i < values.length) ? values[i] : null;
    String? stringAt(List<String?> values, int i) => i < values.length ? values[i] : null;
    DateTime? parseTime(String? raw) => raw == null ? null : DateTime.tryParse(raw);

    // Sin los datos de hoy la pantalla no puede pintar nada: la respuesta
    // se rechaza indicando qué campo faltaba.
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

    // Índice horario correspondiente a "ahora". Los tiempos vienen en la
    // zona horaria del punto y se comparan con la del dispositivo: en un
    // punto lejano el resumen de oleaje reciente se desplaza unas horas.
    int nowHourIndex() {
      final now = DateTime.now();
      for (var i = hourlyTime.length - 1; i >= 0; i--) {
        final time = parseTime(stringAt(hourlyTime, i));
        if (time != null && !time.isAfter(now)) return i;
      }
      return todayIndex * 24;
    }

    final nowSnapshot = WeatherSnapshot(
      // Si falta un valor de `current` se cae al agregado de hoy.
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
      rmsWaveHeightPast48h: trailingRms(hourlyWave, nowHourIndex(), 48),
      waveFromDirection: (marineCurrent?['wave_direction'] as num?)?.toDouble(),
      sunrise: parseTime(stringAt(dailySunrise, todayIndex)),
      sunset: parseTime(stringAt(dailySunset, todayIndex)),
      fetchedAt: DateTime.now(),
    );

    // Serie horaria: desde hoy a las 0:00 hasta el final del array.
    final todayHourStart = todayIndex * 24;
    final hourlyPoints = <ForecastPoint>[];
    for (var i = todayHourStart; i < hourlyTime.length; i++) {
      // Una hora incompleta se omite: mejor un hueco en la gráfica que un
      // fallo.
      final time = parseTime(stringAt(hourlyTime, i));
      final temp = numberAt(hourlyTemp, i);
      final apparentTemp = numberAt(hourlyApparentTemp, i);
      final cloudCover = numberAt(hourlyCloudCover, i);
      final rainProbability = numberAt(hourlyRainProbability, i);
      final wind = numberAt(hourlyWind, i);
      final gusts = numberAt(hourlyGusts, i);
      final uv = numberAt(hourlyUv, i);
      final code = numberAt(hourlyWeatherCode, i);
      // sunshine_duration solo existe por día: se reutiliza el valor del día
      // en todas sus horas.
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
        weather: WeatherSnapshot(
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
          waveHeight: numberAt(hourlyWave, i)?.toDouble(),
          windWaveHeight: numberAt(hourlyWindWave, i)?.toDouble(),
          swellHeight: numberAt(hourlySwellHeight, i)?.toDouble(),
          swellPeriod: numberAt(hourlySwellPeriod, i)?.toDouble(),
          seaTemperature: numberAt(hourlySeaTemp, i)?.toDouble(),
          rmsWaveHeightPast48h: trailingRms(hourlyWave, i, 48),
          sunrise: parseTime(stringAt(dailySunrise, i ~/ 24)),
          sunset: parseTime(stringAt(dailySunset, i ~/ 24)),
          windFromDirection: numberAt(hourlyWindDirection, i)?.toDouble(),
          waveFromDirection: numberAt(hourlyWaveDirection, i)?.toDouble(),
          fetchedAt: time,
        ),
      ));
    }

    // Serie diaria: desde hoy hasta el final del array.
    final dailyPoints = <ForecastPoint>[];
    for (var d = todayIndex; d < dailyTime.length; d++) {
      // Mismo criterio que en el bucle horario: un día incompleto se omite.
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
        weather: WeatherSnapshot(
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
          waveHeight: numberAt(dailyWaveMax, d)?.toDouble(),
          windWaveHeight: marineDailyMax(hourlyWindWave, d),
          swellHeight: marineDailyMax(hourlySwellHeight, d),
          swellPeriod: marineDailyMax(hourlySwellPeriod, d),
          seaTemperature: marineDailyMean(hourlySeaTemp, d),
          rmsWaveHeightPast48h: trailingRms(hourlyWave, lastHourOfDay(d), 48),
          sunrise: parseTime(stringAt(dailySunrise, d)),
          sunset: parseTime(stringAt(dailySunset, d)),
          windFromDirection: numberAt(dailyWindDirection, d)?.toDouble(),
          waveFromDirection: numberAt(dailyWaveDirection, d)?.toDouble(),
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

/// Deja correr como mucho [maxConcurrent] operaciones a la vez y encola el
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
