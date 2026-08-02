import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/beach_conditions.dart';
import '../models/condition_point.dart';
import '../models/spot.dart';
import '../models/spot_conditions_bundle.dart';
import '../models/trailing_window.dart';

const _requestTimeout = Duration(seconds: 15);

class OpenMeteoApi {
  // Con past_days=2 y forecast_days=16 los arrays diarios traen 18 entradas
  // [anteayer, ayer, hoy, +1...+15] y los horarios 18*24 horas en el mismo
  // orden cronológico: hoy empieza en el índice pastDays*24.
  static const _pastDays = 2;
  static const _forecastDays = 16; // máximo que permite Open-Meteo

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
      '&timezone=auto&forecast_days=$_forecastDays&past_days=$_pastDays',
    );

    final responses = await Future.wait([
      http.get(forecastUri).timeout(_requestTimeout),
      http.get(marineUri).timeout(_requestTimeout),
    ]);

    final forecast = jsonDecode(responses[0].body) as Map<String, dynamic>;
    final marine = jsonDecode(responses[1].body) as Map<String, dynamic>;

    final current = forecast['current'] as Map<String, dynamic>;
    final daily = forecast['daily'] as Map<String, dynamic>;
    final hourly = forecast['hourly'] as Map<String, dynamic>;
    final marineCurrent = marine['current'] as Map<String, dynamic>?;
    final marineDaily = marine['daily'] as Map<String, dynamic>?;
    final marineHourly = marine['hourly'] as Map<String, dynamic>?;

    final dailyTime = (daily['time'] as List<dynamic>).cast<String>();
    final dailyTemp = (daily['temperature_2m_max'] as List<dynamic>).cast<num>();
    final dailyFeelsLike = (daily['apparent_temperature_max'] as List<dynamic>).cast<num>();
    final dailyRainProb = (daily['precipitation_probability_max'] as List<dynamic>).cast<num>();
    final dailyRainSum = (daily['precipitation_sum'] as List<dynamic>).cast<num>();
    final dailyWind = (daily['wind_speed_10m_max'] as List<dynamic>).cast<num>();
    final dailyGusts = (daily['wind_gusts_10m_max'] as List<dynamic>).cast<num>();
    final dailyUv = (daily['uv_index_max'] as List<dynamic>).cast<num>();
    final dailySunshine = (daily['sunshine_duration'] as List<dynamic>).cast<num>();
    final dailyWeatherCode = (daily['weather_code'] as List<dynamic>).cast<num>();
    final dailyCloudCover = (daily['cloud_cover_mean'] as List<dynamic>).cast<num>();
    final dailySunrise = (daily['sunrise'] as List<dynamic>).cast<String>();
    final dailySunset = (daily['sunset'] as List<dynamic>).cast<String>();
    final dailyWindDirection = (daily['wind_direction_10m_dominant'] as List<dynamic>).cast<num>();
    final dailyWaveMax = (marineDaily?['wave_height_max'] as List<dynamic>?)?.cast<num?>();

    final hourlyTime = (hourly['time'] as List<dynamic>).cast<String>();
    final hourlyTemp = (hourly['temperature_2m'] as List<dynamic>).cast<num>();
    final hourlyFeelsLike = (hourly['apparent_temperature'] as List<dynamic>).cast<num>();
    final hourlyRainProb = (hourly['precipitation_probability'] as List<dynamic>).cast<num>();
    final hourlyRainSum = (hourly['precipitation'] as List<dynamic>).cast<num>();
    final hourlyWeatherCode = (hourly['weather_code'] as List<dynamic>).cast<num>();
    final hourlyCloudCover = (hourly['cloud_cover'] as List<dynamic>).cast<num>();
    final hourlyWind = (hourly['wind_speed_10m'] as List<dynamic>).cast<num>();
    final hourlyGusts = (hourly['wind_gusts_10m'] as List<dynamic>).cast<num>();
    final hourlyWindDirection = (hourly['wind_direction_10m'] as List<dynamic>).cast<num>();
    final hourlyUv = (hourly['uv_index'] as List<dynamic>).cast<num>();
    final hourlyWave = (marineHourly?['wave_height'] as List<dynamic>?)?.cast<num?>();
    final hourlyWindWave = (marineHourly?['wind_wave_height'] as List<dynamic>?)?.cast<num?>();
    final hourlySwellHeight = (marineHourly?['swell_wave_height'] as List<dynamic>?)?.cast<num?>();
    final hourlySwellPeriod = (marineHourly?['swell_wave_period'] as List<dynamic>?)?.cast<num?>();
    final hourlySeaTemp = (marineHourly?['sea_surface_temperature'] as List<dynamic>?)?.cast<num?>();

    final todayIndex = _pastDays;

    // "Sostenido/reciente" = media (viento) o suma (lluvia) de los 2 días
    // anteriores a [dayIndex], sin incluir ese propio día (igual que el
    // cálculo "actual" de siempre, solo que ahora reutilizable por índice).
    double? recentDailyAverage(List<num> values, int dayIndex) {
      if (dayIndex <= 0) return null;
      return trailingAverage(values, dayIndex - 1, 2);
    }

    double? recentDailySum(List<num> values, int dayIndex) {
      if (dayIndex <= 0) return null;
      return trailingSum(values, dayIndex - 1, 2);
    }

    // El modelo marino solo pronostica de forma fiable unos pocos días: más
    // allá de su horizonte real, la API sigue devolviendo arrays del tamaño
    // pedido (forecast_days=16) pero rellenos de null. Todo lo que lee estos
    // arrays debe saltarse esas entradas en vez de asumir que "dentro de
    // rango" implica "con dato".
    double? recentMarineDailyAverage(int dayIndex) {
      final values = dailyWaveMax;
      if (values == null || dayIndex <= 0) return null;
      final start = (dayIndex - 2).clamp(0, dayIndex);
      final window = values.sublist(start, dayIndex).whereType<num>();
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

    final currentConditions = buildConditions(
      feelsLike: (current['apparent_temperature'] as num).toDouble(),
      cloudCoverCurrent: (current['cloud_cover'] as num).toDouble(),
      airTempMax: dailyTemp[todayIndex].toDouble(),
      precipitationProbabilityMax: dailyRainProb[todayIndex].toDouble(),
      precipitationSumToday: dailyRainSum[todayIndex].toDouble(),
      precipitationSumRecent48h: recentDailySum(dailyRainSum, todayIndex) ?? 0,
      windSpeedMax: dailyWind[todayIndex].toDouble(),
      windGustsMax: dailyGusts[todayIndex].toDouble(),
      windSpeedSustained48h: recentDailyAverage(dailyWind, todayIndex) ?? dailyWind[todayIndex].toDouble(),
      uvIndexMax: dailyUv[todayIndex].toDouble(),
      sunshineDurationHours: dailySunshine[todayIndex].toDouble() / 3600,
      weatherCode: dailyWeatherCode[todayIndex].toInt(),
      currentWeatherCode: (current['weather_code'] as num).toInt(),
      waveHeight: (marineCurrent?['wave_height'] as num?)?.toDouble(),
      windWaveHeight: (marineCurrent?['wind_wave_height'] as num?)?.toDouble(),
      swellWaveHeight: (marineCurrent?['swell_wave_height'] as num?)?.toDouble(),
      swellWavePeriod: (marineCurrent?['swell_wave_period'] as num?)?.toDouble(),
      seaSurfaceTemperature: (marineCurrent?['sea_surface_temperature'] as num?)?.toDouble(),
      waveHeightMaxRecent48h: recentMarineDailyAverage(todayIndex),
      sunrise: DateTime.parse(dailySunrise[todayIndex]),
      sunset: DateTime.parse(dailySunset[todayIndex]),
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
      hourlyPoints.add(ConditionPoint(
        time: DateTime.parse(hourlyTime[i]),
        conditions: buildConditions(
          airTempMax: hourlyTemp[i].toDouble(),
          feelsLike: hourlyFeelsLike[i].toDouble(),
          cloudCoverCurrent: hourlyCloudCover[i].toDouble(),
          precipitationProbabilityMax: hourlyRainProb[i].toDouble(),
          precipitationSumToday: trailingSum(hourlyRainSum, i, 24),
          precipitationSumRecent48h: trailingSum(hourlyRainSum, i, 48),
          windSpeedMax: hourlyWind[i].toDouble(),
          windGustsMax: hourlyGusts[i].toDouble(),
          windSpeedSustained48h: trailingAverage(hourlyWind, i, 48),
          uvIndexMax: hourlyUv[i].toDouble(),
          // sunshine_duration solo existe como agregado diario: se reutiliza
          // el valor de ese día para todas sus horas.
          sunshineDurationHours: dailySunshine[i ~/ 24].toDouble() / 3600,
          weatherCode: hourlyWeatherCode[i].toInt(),
          currentWeatherCode: hourlyWeatherCode[i].toInt(),
          waveHeight: marineAt(hourlyWave, i)?.toDouble(),
          windWaveHeight: marineAt(hourlyWindWave, i)?.toDouble(),
          swellWaveHeight: marineAt(hourlySwellHeight, i)?.toDouble(),
          swellWavePeriod: marineAt(hourlySwellPeriod, i)?.toDouble(),
          seaSurfaceTemperature: marineAt(hourlySeaTemp, i)?.toDouble(),
          waveHeightMaxRecent48h: trailingMarineMax(hourlyWave, i, 48),
          sunrise: DateTime.parse(dailySunrise[i ~/ 24]),
          sunset: DateTime.parse(dailySunset[i ~/ 24]),
          windDirection10m: hourlyWindDirection[i].toDouble(),
          fetchedAt: DateTime.parse(hourlyTime[i]),
        ),
      ));
    }

    // Próximos días: de hoy (incluido) hasta el final del array diario.
    final dailyPoints = <ConditionPoint>[];
    for (var d = todayIndex; d < dailyTime.length; d++) {
      dailyPoints.add(ConditionPoint(
        time: DateTime.parse(dailyTime[d]),
        conditions: buildConditions(
          airTempMax: dailyTemp[d].toDouble(),
          feelsLike: dailyFeelsLike[d].toDouble(),
          cloudCoverCurrent: dailyCloudCover[d].toDouble(),
          precipitationProbabilityMax: dailyRainProb[d].toDouble(),
          precipitationSumToday: dailyRainSum[d].toDouble(),
          precipitationSumRecent48h: recentDailySum(dailyRainSum, d) ?? 0,
          windSpeedMax: dailyWind[d].toDouble(),
          windGustsMax: dailyGusts[d].toDouble(),
          windSpeedSustained48h: recentDailyAverage(dailyWind, d) ?? dailyWind[d].toDouble(),
          uvIndexMax: dailyUv[d].toDouble(),
          sunshineDurationHours: dailySunshine[d].toDouble() / 3600,
          weatherCode: dailyWeatherCode[d].toInt(),
          currentWeatherCode: dailyWeatherCode[d].toInt(),
          waveHeight: marineAt(dailyWaveMax, d)?.toDouble(),
          windWaveHeight: dailyMarineMax(hourlyWindWave, d),
          swellWaveHeight: dailyMarineMax(hourlySwellHeight, d),
          swellWavePeriod: dailyMarineMax(hourlySwellPeriod, d),
          seaSurfaceTemperature: dailyMarineMean(hourlySeaTemp, d),
          waveHeightMaxRecent48h: recentMarineDailyAverage(d),
          sunrise: DateTime.parse(dailySunrise[d]),
          sunset: DateTime.parse(dailySunset[d]),
          windDirection10m: dailyWindDirection[d].toDouble(),
          fetchedAt: DateTime.parse(dailyTime[d]),
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
