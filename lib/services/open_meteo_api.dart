import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/beach_conditions.dart';
import '../models/condition_point.dart';
import '../models/spot.dart';
import '../models/spot_conditions_bundle.dart';
import '../models/trailing_window.dart';
import 'weather_api_error.dart';

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
  /// cuota por minuto. Con varias calas en pantalla es fácil pasarse, así que
  /// las consultas se encolan.
  static final _gate = _RequestGate(4);

  /// Espera entre reintentos de un fallo transitorio. Un 429 por concurrencia
  /// se despeja en milisegundos.
  static const _retryDelays = [
    Duration(milliseconds: 250),
    Duration(milliseconds: 750),
  ];

  /// Pide un JSON reintentando los fallos transitorios y traduciendo el resto
  /// a [WeatherApiException].
  static Future<Map<String, dynamic>> _fetchJson(Uri uri) async {
    for (var attempt = 0;; attempt++) {
      try {
        return await _gate.run(() => _getJson(uri));
      } on WeatherApiException catch (error) {
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

  static Future<BeachConditions> fetchConditions(Spot spot) async {
    final bundle = await fetchConditionsBundle(spot);
    return bundle.current;
  }

  static Future<SpotConditionsBundle> fetchConditionsBundle(Spot spot) async {
    final forecastUri = Uri.parse(
      'https://api.open-meteo.com/v1/forecast'
      '?latitude=${spot.latitude}&longitude=${spot.longitude}'
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
      '?latitude=${spot.latitude}&longitude=${spot.longitude}'
      '&current=wave_height,wind_wave_height,swell_wave_height,swell_wave_period,sea_surface_temperature'
      '&hourly=wave_height,wind_wave_height,swell_wave_height,swell_wave_period,sea_surface_temperature'
      '&daily=wave_height_max'
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
      throw const WeatherApiException(
        WeatherErrorKind.malformedResponse,
        'La previsión de esta zona ha llegado incompleta.',
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
    final dailyFeelsLike = _numList(daily['apparent_temperature_max']);
    final dailyRainProb = _numList(daily['precipitation_probability_max']);
    final dailyRainSum = _numList(daily['precipitation_sum']);
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

    final hourlyTime = _stringList(hourly['time']);
    final hourlyTemp = _numList(hourly['temperature_2m']);
    final hourlyFeelsLike = _numList(hourly['apparent_temperature']);
    final hourlyRainProb = _numList(hourly['precipitation_probability']);
    final hourlyRainSum = _numList(hourly['precipitation']);
    final hourlyWeatherCode = _numList(hourly['weather_code']);
    final hourlyCloudCover = _numList(hourly['cloud_cover']);
    final hourlyWind = _numList(hourly['wind_speed_10m']);
    final hourlyGusts = _numList(hourly['wind_gusts_10m']);
    final hourlyWindDirection = _numList(hourly['wind_direction_10m']);
    final hourlyUv = _numList(hourly['uv_index']);
    final hourlyWave = marineHourly == null ? null : _numList(marineHourly['wave_height']);
    final hourlyWindWave = marineHourly == null ? null : _numList(marineHourly['wind_wave_height']);
    final hourlySwellHeight = marineHourly == null ? null : _numList(marineHourly['swell_wave_height']);
    final hourlySwellPeriod = marineHourly == null ? null : _numList(marineHourly['swell_wave_period']);
    final hourlySeaTemp = marineHourly == null ? null : _numList(marineHourly['sea_surface_temperature']);

    final todayIndex = _pastDays;

    // "Sostenido/reciente" = media (viento) o suma (lluvia) de los 2 días
    // anteriores a [dayIndex], sin incluir ese propio día (igual que el
    // cálculo "actual" de siempre, solo que ahora reutilizable por índice).
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
    double? dailyMarineMax(List<num?>? hourlyValues, int dayIndex) {
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

    double? dailyMarineMean(List<num?>? hourlyValues, int dayIndex) {
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

    // Igual que [trailingMax] de trailing_window.dart pero saltándose los
    // huecos null del array marino (ver comentario de arriba) en vez de
    // asumir datos completos.
    double? trailingMarineMax(List<num?>? values, int index, int windowSize) {
      if (values == null || index >= values.length || values[index] == null) return null;
      final start = (index - windowSize + 1).clamp(0, index);
      num? max;
      for (var i = start; i <= index; i++) {
        final v = values[i];
        if (v == null) continue;
        if (max == null || v > max) max = v;
      }
      return max?.toDouble();
    }

    BeachConditions buildConditions({
      required double airTempMax,
      required double feelsLike,
      required double cloudCoverCurrent,
      required double precipitationProbabilityMax,
      required double precipitationSumToday,
      required double precipitationSumRecent48h,
      required double windSpeedMax,
      required double windGustsMax,
      required double windSpeedSustained48h,
      required double uvIndexMax,
      required double sunshineDurationHours,
      required int weatherCode,
      required int currentWeatherCode,
      double? waveHeight,
      double? waveHeightMaxRecent48h,
      double? windWaveHeight,
      double? swellWaveHeight,
      double? swellWavePeriod,
      double? seaSurfaceTemperature,
      DateTime? sunrise,
      DateTime? sunset,
      double? windDirection10m,
      required DateTime fetchedAt,
    }) =>
        BeachConditions(
          airTempMax: airTempMax,
          feelsLike: feelsLike,
          cloudCoverCurrent: cloudCoverCurrent,
          precipitationProbabilityMax: precipitationProbabilityMax,
          precipitationSumToday: precipitationSumToday,
          precipitationSumRecent48h: precipitationSumRecent48h,
          windSpeedMax: windSpeedMax,
          windGustsMax: windGustsMax,
          windSpeedSustained48h: windSpeedSustained48h,
          uvIndexMax: uvIndexMax,
          sunshineDurationHours: sunshineDurationHours,
          weatherCode: weatherCode,
          currentWeatherCode: currentWeatherCode,
          waveHeight: waveHeight,
          waveHeightMaxRecent48h: waveHeightMaxRecent48h,
          windWaveHeight: windWaveHeight,
          swellWaveHeight: swellWaveHeight,
          swellWavePeriod: swellWavePeriod,
          seaSurfaceTemperature: seaSurfaceTemperature,
          sunrise: sunrise,
          sunset: sunset,
          windDirection10m: windDirection10m,
          fetchedAt: fetchedAt,
        );

    // Lectura por índice tolerante a arrays más cortos de lo pedido.
    num? dayNum(List<num?> values, int i) => i < values.length ? values[i] : null;
    String? dayStr(List<String?> values, int i) => i < values.length ? values[i] : null;
    DateTime? parseTime(String? raw) => raw == null ? null : DateTime.tryParse(raw);

    // La tarjeta "ahora" es lo mínimo que la pantalla necesita: si el día de
    // hoy llega incompleto, la respuesta no sirve y se dice por qué.
    double todayValue(List<num?> values, String field) {
      final value = dayNum(values, todayIndex);
      if (value == null) {
        throw WeatherApiException(
          WeatherErrorKind.malformedResponse,
          'La previsión de hoy de esta zona ha llegado incompleta.',
          reason: '$field sin dato en el día $todayIndex',
        );
      }
      return value.toDouble();
    }

    final currentConditions = buildConditions(
      // Los valores de `current` pueden faltar: se cae al agregado de hoy.
      feelsLike: (current['apparent_temperature'] as num?)?.toDouble() ??
          todayValue(dailyFeelsLike, 'apparent_temperature_max'),
      cloudCoverCurrent: (current['cloud_cover'] as num?)?.toDouble() ??
          todayValue(dailyCloudCover, 'cloud_cover_mean'),
      airTempMax: todayValue(dailyTemp, 'temperature_2m_max'),
      precipitationProbabilityMax: todayValue(dailyRainProb, 'precipitation_probability_max'),
      precipitationSumToday: todayValue(dailyRainSum, 'precipitation_sum'),
      precipitationSumRecent48h: recentDailySum(dailyRainSum, todayIndex) ?? 0,
      windSpeedMax: todayValue(dailyWind, 'wind_speed_10m_max'),
      windGustsMax: todayValue(dailyGusts, 'wind_gusts_10m_max'),
      windSpeedSustained48h: recentDailyAverage(dailyWind, todayIndex) ??
          todayValue(dailyWind, 'wind_speed_10m_max'),
      uvIndexMax: todayValue(dailyUv, 'uv_index_max'),
      sunshineDurationHours: todayValue(dailySunshine, 'sunshine_duration') / 3600,
      weatherCode: todayValue(dailyWeatherCode, 'weather_code').toInt(),
      currentWeatherCode: (current['weather_code'] as num?)?.toInt() ??
          todayValue(dailyWeatherCode, 'weather_code').toInt(),
      waveHeight: (marineCurrent?['wave_height'] as num?)?.toDouble(),
      windWaveHeight: (marineCurrent?['wind_wave_height'] as num?)?.toDouble(),
      swellWaveHeight: (marineCurrent?['swell_wave_height'] as num?)?.toDouble(),
      swellWavePeriod: (marineCurrent?['swell_wave_period'] as num?)?.toDouble(),
      seaSurfaceTemperature: (marineCurrent?['sea_surface_temperature'] as num?)?.toDouble(),
      waveHeightMaxRecent48h: recentMarineDailyAverage(todayIndex),
      sunrise: parseTime(dayStr(dailySunrise, todayIndex)),
      sunset: parseTime(dayStr(dailySunset, todayIndex)),
      fetchedAt: DateTime.now(),
    );

    // Acceso seguro a un array marino horario/diario en la posición [i]:
    // fuera de rango o dentro del hueco null de después del horizonte real
    // del modelo (ver comentario más arriba) devuelven null por igual.
    num? marineAt(List<num?>? values, int i) => (values != null && i < values.length) ? values[i] : null;

    // Por horas: de hoy 0:00 hasta el final del array (últimos días de forecast).
    final todayHourStart = todayIndex * 24;
    final hourlyPoints = <ConditionPoint>[];
    for (var i = todayHourStart; i < hourlyTime.length; i++) {
      // Una hora sin todos sus datos se omite: es lo que devuelve la API en
      // las últimas horas del rango cuando el punto tiene desfase horario
      // negativo respecto a UTC. Mejor un hueco en la gráfica que un fallo.
      final time = parseTime(dayStr(hourlyTime, i));
      final temp = dayNum(hourlyTemp, i);
      final feelsLike = dayNum(hourlyFeelsLike, i);
      final cloudCover = dayNum(hourlyCloudCover, i);
      final rainProb = dayNum(hourlyRainProb, i);
      final wind = dayNum(hourlyWind, i);
      final gusts = dayNum(hourlyGusts, i);
      final uv = dayNum(hourlyUv, i);
      final code = dayNum(hourlyWeatherCode, i);
      // sunshine_duration solo existe como agregado diario: se reutiliza el
      // valor de ese día para todas sus horas.
      final sunshine = dayNum(dailySunshine, i ~/ 24);
      if (time == null ||
          temp == null ||
          feelsLike == null ||
          cloudCover == null ||
          rainProb == null ||
          wind == null ||
          gusts == null ||
          uv == null ||
          code == null ||
          sunshine == null) {
        continue;
      }

      hourlyPoints.add(ConditionPoint(
        time: time,
        conditions: buildConditions(
          airTempMax: temp.toDouble(),
          feelsLike: feelsLike.toDouble(),
          cloudCoverCurrent: cloudCover.toDouble(),
          precipitationProbabilityMax: rainProb.toDouble(),
          precipitationSumToday: trailingSum(hourlyRainSum, i, 24),
          precipitationSumRecent48h: trailingSum(hourlyRainSum, i, 48),
          windSpeedMax: wind.toDouble(),
          windGustsMax: gusts.toDouble(),
          windSpeedSustained48h: trailingAverage(hourlyWind, i, 48) ?? wind.toDouble(),
          uvIndexMax: uv.toDouble(),
          sunshineDurationHours: sunshine.toDouble() / 3600,
          weatherCode: code.toInt(),
          currentWeatherCode: code.toInt(),
          waveHeight: marineAt(hourlyWave, i)?.toDouble(),
          windWaveHeight: marineAt(hourlyWindWave, i)?.toDouble(),
          swellWaveHeight: marineAt(hourlySwellHeight, i)?.toDouble(),
          swellWavePeriod: marineAt(hourlySwellPeriod, i)?.toDouble(),
          seaSurfaceTemperature: marineAt(hourlySeaTemp, i)?.toDouble(),
          waveHeightMaxRecent48h: trailingMarineMax(hourlyWave, i, 48),
          sunrise: parseTime(dayStr(dailySunrise, i ~/ 24)),
          sunset: parseTime(dayStr(dailySunset, i ~/ 24)),
          windDirection10m: dayNum(hourlyWindDirection, i)?.toDouble(),
          fetchedAt: time,
        ),
      ));
    }

    // Próximos días: de hoy (incluido) hasta el final del array diario.
    final dailyPoints = <ConditionPoint>[];
    for (var d = todayIndex; d < dailyTime.length; d++) {
      // Mismo criterio que en el bucle horario: el último día del rango llega
      // sin agregados cuando el desfase horario es negativo.
      final time = parseTime(dayStr(dailyTime, d));
      final temp = dayNum(dailyTemp, d);
      final feelsLike = dayNum(dailyFeelsLike, d);
      final cloudCover = dayNum(dailyCloudCover, d);
      final rainProb = dayNum(dailyRainProb, d);
      final rainSum = dayNum(dailyRainSum, d);
      final wind = dayNum(dailyWind, d);
      final gusts = dayNum(dailyGusts, d);
      final uv = dayNum(dailyUv, d);
      final sunshine = dayNum(dailySunshine, d);
      final code = dayNum(dailyWeatherCode, d);
      if (time == null ||
          temp == null ||
          feelsLike == null ||
          cloudCover == null ||
          rainProb == null ||
          rainSum == null ||
          wind == null ||
          gusts == null ||
          uv == null ||
          sunshine == null ||
          code == null) {
        continue;
      }

      dailyPoints.add(ConditionPoint(
        time: time,
        conditions: buildConditions(
          airTempMax: temp.toDouble(),
          feelsLike: feelsLike.toDouble(),
          cloudCoverCurrent: cloudCover.toDouble(),
          precipitationProbabilityMax: rainProb.toDouble(),
          precipitationSumToday: rainSum.toDouble(),
          precipitationSumRecent48h: recentDailySum(dailyRainSum, d) ?? 0,
          windSpeedMax: wind.toDouble(),
          windGustsMax: gusts.toDouble(),
          windSpeedSustained48h: recentDailyAverage(dailyWind, d) ?? wind.toDouble(),
          uvIndexMax: uv.toDouble(),
          sunshineDurationHours: sunshine.toDouble() / 3600,
          weatherCode: code.toInt(),
          currentWeatherCode: code.toInt(),
          waveHeight: marineAt(dailyWaveMax, d)?.toDouble(),
          windWaveHeight: dailyMarineMax(hourlyWindWave, d),
          swellWaveHeight: dailyMarineMax(hourlySwellHeight, d),
          swellWavePeriod: dailyMarineMax(hourlySwellPeriod, d),
          seaSurfaceTemperature: dailyMarineMean(hourlySeaTemp, d),
          waveHeightMaxRecent48h: recentMarineDailyAverage(d),
          sunrise: parseTime(dayStr(dailySunrise, d)),
          sunset: parseTime(dayStr(dailySunset, d)),
          windDirection10m: dayNum(dailyWindDirection, d)?.toDouble(),
          fetchedAt: time,
        ),
      ));
    }

    return SpotConditionsBundle(
      current: currentConditions,
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
