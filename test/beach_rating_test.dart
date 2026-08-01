import 'package:flutter_test/flutter_test.dart';
import 'package:sea_wether_app/models/beach_conditions.dart';

BeachConditions _conditions({
  double airTempMax = 25,
  double precipitationProbabilityMax = 0,
  double precipitationSumToday = 0,
  double precipitationSumRecent48h = 0,
  double windSpeedMax = 10,
  double windGustsMax = 15,
  double windSpeedSustained48h = 10,
  double uvIndexMax = 5,
  double cloudCoverCurrent = 10,
  double sunshineDurationHours = 10,
  int weatherCode = 1,
  int currentWeatherCode = 1,
  double? waveHeight,
  double? waveHeightMaxRecent48h,
  double? windWaveHeight,
  double? swellWaveHeight,
  double? swellWavePeriod,
}) {
  return BeachConditions(
    airTempMax: airTempMax,
    feelsLike: airTempMax,
    precipitationProbabilityMax: precipitationProbabilityMax,
    precipitationSumToday: precipitationSumToday,
    precipitationSumRecent48h: precipitationSumRecent48h,
    windSpeedMax: windSpeedMax,
    windGustsMax: windGustsMax,
    windSpeedSustained48h: windSpeedSustained48h,
    uvIndexMax: uvIndexMax,
    cloudCoverCurrent: cloudCoverCurrent,
    sunshineDurationHours: sunshineDurationHours,
    weatherCode: weatherCode,
    currentWeatherCode: currentWeatherCode,
    waveHeight: waveHeight,
    waveHeightMaxRecent48h: waveHeightMaxRecent48h,
    windWaveHeight: windWaveHeight,
    swellWaveHeight: swellWaveHeight,
    swellWavePeriod: swellWavePeriod,
    fetchedAt: DateTime(2026, 7, 31),
  );
}

void main() {
  group('rateWaterClarity', () {
    test('calm wind and sea with no rain is very good', () {
      final rating = _conditions(windSpeedMax: 10, waveHeight: 0.2).rateWaterClarity();

      expect(rating.level, RatingLevel.veryGood);
    });

    test('borderline wind/wave lands in the middle, not very good', () {
      final rating = _conditions(windSpeedMax: 18, waveHeight: 0.6).rateWaterClarity();

      expect(rating.level, RatingLevel.ok);
    });

    test('very strong wind is rated very bad', () {
      final rating = _conditions(windSpeedMax: 45, waveHeight: 0.2).rateWaterClarity();

      expect(rating.level, RatingLevel.veryBad);
    });

    test('strong local wind-wave is rated bad even with light wind', () {
      final rating = _conditions(windSpeedMax: 10, windWaveHeight: 1.0).rateWaterClarity();

      expect(rating.level, RatingLevel.bad);
    });

    test('very heavy recent rain is rated very bad', () {
      final rating = _conditions(waveHeight: 0.1, precipitationSumRecent48h: 25).rateWaterClarity();

      expect(rating.level, RatingLevel.veryBad);
      expect(rating.reason, contains('Lluvia'));
    });

    test('score is continuous within a level, not just a fixed 5-step jump', () {
      // Dos vientos distintos, ambos "ok", deben dar scores distintos: el
      // marcador se mueve dentro del tramo según el valor real, no solo
      // salta entre 5 posiciones fijas.
      final calmerOk = _conditions(windSpeedMax: 21, waveHeight: 0.1).rateWaterClarity();
      final windierOk = _conditions(windSpeedMax: 29, waveHeight: 0.1).rateWaterClarity();

      expect(calmerOk.level, RatingLevel.ok);
      expect(windierOk.level, RatingLevel.ok);
      expect(calmerOk.score, greaterThan(windierOk.score));
    });
  });

  group('ratePlayaRemovida', () {
    test('calm sustained wind and low recent waves is very good', () {
      final rating = _conditions(windSpeedSustained48h: 10, waveHeightMaxRecent48h: 0.3).ratePlayaRemovida();

      expect(rating.level, RatingLevel.veryGood);
    });

    test('very strong sustained wind is rated very bad', () {
      final rating = _conditions(windSpeedSustained48h: 45, waveHeightMaxRecent48h: 0.3).ratePlayaRemovida();

      expect(rating.level, RatingLevel.veryBad);
    });

    test('very high recent wave max is rated very bad', () {
      final rating = _conditions(windSpeedSustained48h: 10, waveHeightMaxRecent48h: 1.8).ratePlayaRemovida();

      expect(rating.level, RatingLevel.veryBad);
    });
  });

  group('rateSurf', () {
    test('excellent size and long period swell with calm wind is very good', () {
      final rating = _conditions(swellWaveHeight: 1.5, swellWavePeriod: 13, windSpeedMax: 5).rateSurf();

      expect(rating.level, RatingLevel.veryGood);
    });

    test('flat swell is rated very bad', () {
      final rating = _conditions(swellWaveHeight: 0.2, swellWavePeriod: 13, windSpeedMax: 5).rateSurf();

      expect(rating.level, RatingLevel.veryBad);
    });

    test('very short period wind swell is rated very bad despite good size', () {
      final rating = _conditions(swellWaveHeight: 1.0, swellWavePeriod: 5, windSpeedMax: 5).rateSurf();

      expect(rating.level, RatingLevel.veryBad);
    });

    test('very strong wind is rated very bad even with a good swell', () {
      final rating = _conditions(swellWaveHeight: 1.0, swellWavePeriod: 13, windSpeedMax: 30).rateSurf();

      expect(rating.level, RatingLevel.veryBad);
    });

    test('missing swell data falls back to a cautious ok rating', () {
      final rating = _conditions(windSpeedMax: 10).rateSurf();

      expect(rating.level, RatingLevel.ok);
    });
  });

  group('rateSun', () {
    test('clear sky with lots of sunshine is very good', () {
      final rating = _conditions(cloudCoverCurrent: 5, sunshineDurationHours: 12, uvIndexMax: 5).rateSun();

      expect(rating.level, RatingLevel.veryGood);
    });

    test('overcast sky is rated very bad', () {
      final rating = _conditions(cloudCoverCurrent: 95).rateSun();

      expect(rating.level, RatingLevel.veryBad);
    });

    test('fog weather code is rated very bad', () {
      final rating = _conditions(cloudCoverCurrent: 5, sunshineDurationHours: 12, currentWeatherCode: 45).rateSun();

      expect(rating.level, RatingLevel.veryBad);
      expect(rating.reason, contains('Niebla'));
    });

    test('very high UV caps rating at ok', () {
      final rating = _conditions(cloudCoverCurrent: 5, sunshineDurationHours: 12, uvIndexMax: 9).rateSun();

      expect(rating.level, RatingLevel.ok);
      expect(rating.reason, contains('UV'));
    });
  });

  group('rateRain', () {
    test('very low probability and no rain is very good', () {
      final rating = _conditions(precipitationProbabilityMax: 5, precipitationSumToday: 0).rateRain();

      expect(rating.level, RatingLevel.veryGood);
    });

    test('very high probability is rated very bad', () {
      expect(_conditions(precipitationProbabilityMax: 90).rateRain().level, RatingLevel.veryBad);
    });

    test('storm weather code is rated very bad regardless of probability', () {
      final rating = _conditions(precipitationProbabilityMax: 5, weatherCode: 95).rateRain();

      expect(rating.level, RatingLevel.veryBad);
      expect(rating.reason, contains('Tormenta'));
    });
  });
}
