import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/beach_conditions.dart';
import '../models/spot.dart';

class OpenMeteoApi {
  static Future<BeachConditions> fetchConditions(Spot spot) async {
    final forecastUri = Uri.parse(
      'https://api.open-meteo.com/v1/forecast'
      '?latitude=${spot.latitude}&longitude=${spot.longitude}'
      '&current=temperature_2m,apparent_temperature,cloud_cover,weather_code'
      '&daily=temperature_2m_max,precipitation_probability_max,precipitation_sum,'
      'wind_speed_10m_max,wind_gusts_10m_max,uv_index_max,sunshine_duration,weather_code'
      '&timezone=auto&forecast_days=1&past_days=2',
    );
    final marineUri = Uri.parse(
      'https://marine-api.open-meteo.com/v1/marine'
      '?latitude=${spot.latitude}&longitude=${spot.longitude}'
      '&current=wave_height,wind_wave_height,swell_wave_height,swell_wave_period,sea_surface_temperature'
      '&daily=wave_height_max'
      '&timezone=auto&forecast_days=1&past_days=2',
    );

    final responses = await Future.wait([
      http.get(forecastUri),
      http.get(marineUri),
    ]);

    final forecast = jsonDecode(responses[0].body) as Map<String, dynamic>;
    final marine = jsonDecode(responses[1].body) as Map<String, dynamic>;

    final current = forecast['current'] as Map<String, dynamic>;
    final daily = forecast['daily'] as Map<String, dynamic>;
    final marineCurrent = marine['current'] as Map<String, dynamic>?;
    final marineDaily = marine['daily'] as Map<String, dynamic>?;

    final dailyTemp = (daily['temperature_2m_max'] as List<dynamic>).cast<num>();
    final dailyRainProb = (daily['precipitation_probability_max'] as List<dynamic>).cast<num>();
    final dailyRainSum = (daily['precipitation_sum'] as List<dynamic>).cast<num>();
    final dailyWind = (daily['wind_speed_10m_max'] as List<dynamic>).cast<num>();
    final dailyGusts = (daily['wind_gusts_10m_max'] as List<dynamic>).cast<num>();
    final dailyUv = (daily['uv_index_max'] as List<dynamic>).cast<num>();
    final dailySunshine = (daily['sunshine_duration'] as List<dynamic>).cast<num>();
    final dailyWeatherCode = (daily['weather_code'] as List<dynamic>).cast<num>();

    // Con past_days=2 y forecast_days=1 los arrays diarios traen
    // [anteayer, ayer, hoy]: el último valor es hoy; los dos primeros son
    // los días recientes usados para las señales "sostenidas" (lluvia,
    // viento, oleaje de los últimos días).
    final todayIndex = dailyTemp.length - 1;
    double averageOfPastDays(List<num> values) =>
        values.take(todayIndex).fold<double>(0, (sum, v) => sum + v.toDouble()) / todayIndex;
    double sumOfPastDays(List<num> values) =>
        values.take(todayIndex).fold<double>(0, (sum, v) => sum + v.toDouble());

    double? recentMarineDailyAverage(String key) {
      final values = (marineDaily?[key] as List<dynamic>?)?.cast<num>();
      if (values == null || values.isEmpty) return null;
      final pastCount = values.length - 1;
      if (pastCount <= 0) return null;
      return values.take(pastCount).fold<double>(0, (sum, v) => sum + v.toDouble()) / pastCount;
    }

    return BeachConditions(
      feelsLike: (current['apparent_temperature'] as num).toDouble(),
      cloudCoverCurrent: (current['cloud_cover'] as num).toDouble(),
      airTempMax: dailyTemp[todayIndex].toDouble(),
      precipitationProbabilityMax: dailyRainProb[todayIndex].toDouble(),
      precipitationSumToday: dailyRainSum[todayIndex].toDouble(),
      precipitationSumRecent48h: sumOfPastDays(dailyRainSum),
      windSpeedMax: dailyWind[todayIndex].toDouble(),
      windGustsMax: dailyGusts[todayIndex].toDouble(),
      windSpeedSustained48h: averageOfPastDays(dailyWind),
      uvIndexMax: dailyUv[todayIndex].toDouble(),
      sunshineDurationHours: dailySunshine[todayIndex].toDouble() / 3600,
      weatherCode: dailyWeatherCode[todayIndex].toInt(),
      currentWeatherCode: (current['weather_code'] as num).toInt(),
      waveHeight: (marineCurrent?['wave_height'] as num?)?.toDouble(),
      windWaveHeight: (marineCurrent?['wind_wave_height'] as num?)?.toDouble(),
      swellWaveHeight: (marineCurrent?['swell_wave_height'] as num?)?.toDouble(),
      swellWavePeriod: (marineCurrent?['swell_wave_period'] as num?)?.toDouble(),
      seaSurfaceTemperature: (marineCurrent?['sea_surface_temperature'] as num?)?.toDouble(),
      waveHeightMaxRecent48h: recentMarineDailyAverage('wave_height_max'),
      fetchedAt: DateTime.now(),
    );
  }
}
