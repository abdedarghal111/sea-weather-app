import 'package:flutter_test/flutter_test.dart';
import 'package:sea_weather_app/models/beach_conditions.dart';

// Mirrors the private `_ascendingScore` / `_descendingScore` helpers in
// lib/models/beach_conditions.dart so the exact numeric score can be
// predicted and asserted here (the real functions are private to that
// library file). If the production formula changes, update these too.
double _mirrorAscending(double value, double t1, double t2, double t3, double t4) {
  if (value < t1) return 0.9;
  if (value < t2) return 0.6 + 0.2 * (1 - (value - t1) / (t2 - t1));
  if (value < t3) return 0.4 + 0.2 * (1 - (value - t2) / (t3 - t2));
  if (value < t4) return 0.2 + 0.2 * (1 - (value - t3) / (t4 - t3));
  return 0.1;
}

double _mirrorDescending(double value, double t1, double t2, double t3, double t4) {
  if (value >= t1) return 0.9;
  if (value >= t2) return 0.6 + 0.2 * (1 - (t1 - value) / (t1 - t2));
  if (value >= t3) return 0.4 + 0.2 * (1 - (t2 - value) / (t2 - t3));
  if (value >= t4) return 0.2 + 0.2 * (1 - (t3 - value) / (t3 - t4));
  return 0.1;
}

const _eps = 0.01;
const _tol = 0.0001;

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
    group('wind speed branch (thresholds 15/20/30/40 km/h)', () {
      test('calm wind is very good', () {
        final r = _conditions(windSpeedMax: 5, waveHeight: 0.1).rateWaterClarity();
        expect(r.level, RatingLevel.veryGood);
        expect(r.score, closeTo(0.9, _tol));
      });

      test('just below 15 is still very good', () {
        final r = _conditions(windSpeedMax: 15 - _eps, waveHeight: 0.1).rateWaterClarity();
        expect(r.level, RatingLevel.veryGood);
      });

      test('18 km/h (mid "good" band) interpolates to the expected score', () {
        final r = _conditions(windSpeedMax: 18, waveHeight: 0.1).rateWaterClarity();
        expect(r.level, RatingLevel.good);
        expect(r.score, closeTo(_mirrorAscending(18, 15, 20, 30, 40), _tol));
      });

      test('25 km/h (mid "ok" band) interpolates to the expected score', () {
        final r = _conditions(windSpeedMax: 25, waveHeight: 0.1).rateWaterClarity();
        expect(r.level, RatingLevel.ok);
        expect(r.score, closeTo(_mirrorAscending(25, 15, 20, 30, 40), _tol));
      });

      test('35 km/h (mid "bad" band) is bad', () {
        final r = _conditions(windSpeedMax: 35, waveHeight: 0.1).rateWaterClarity();
        expect(r.level, RatingLevel.bad);
        expect(r.score, closeTo(_mirrorAscending(35, 15, 20, 30, 40), _tol));
      });

      test('very strong wind (40+) is very bad with the floor score', () {
        final r = _conditions(windSpeedMax: 45, waveHeight: 0.1).rateWaterClarity();
        expect(r.level, RatingLevel.veryBad);
        expect(r.score, closeTo(0.1, _tol));
      });

      test('an extreme hurricane-force value is still just veryBad/0.1, no lower', () {
        final r = _conditions(windSpeedMax: 150, waveHeight: 0.1).rateWaterClarity();
        expect(r.level, RatingLevel.veryBad);
        expect(r.score, closeTo(0.1, _tol));
      });

      test('exact t1 boundary (15 km/h): level and score change tiers together (no plateau leak)', () {
        final r = _conditions(windSpeedMax: 15, waveHeight: 0.1).rateWaterClarity();
        expect(r.level, RatingLevel.good);
        expect(r.score, closeTo(0.8, _tol));
      });

      test('exact t4 boundary (40 km/h): level and score both drop to the veryBad floor together', () {
        final r = _conditions(windSpeedMax: 40, waveHeight: 0.1).rateWaterClarity();
        expect(r.level, RatingLevel.veryBad);
        expect(r.score, closeTo(0.1, _tol));
      });
    });

    group('wind gusts branch (only engaged above 20 km/h)', () {
      test('gusts at or below 20 km/h do not drag the rating down', () {
        final calmGusts = _conditions(windSpeedMax: 5, windGustsMax: 20, waveHeight: 0.1).rateWaterClarity();
        final noGusts = _conditions(windSpeedMax: 5, windGustsMax: 5, waveHeight: 0.1).rateWaterClarity();
        expect(calmGusts.level, noGusts.level);
      });

      test('moderate gusts (21-30) cap the rating at ok even with calm sustained wind', () {
        final r = _conditions(windSpeedMax: 5, windGustsMax: 25, waveHeight: 0.1).rateWaterClarity();
        expect(r.level, RatingLevel.ok);
      });

      test('strong gusts (31-45) are rated bad', () {
        final r = _conditions(windSpeedMax: 5, windGustsMax: 35, waveHeight: 0.1).rateWaterClarity();
        expect(r.level, RatingLevel.bad);
      });

      test('violent gusts (>45) are rated very bad', () {
        final r = _conditions(windSpeedMax: 5, windGustsMax: 50, waveHeight: 0.1).rateWaterClarity();
        expect(r.level, RatingLevel.veryBad);
      });
    });

    group('recent rainfall 48h branch (thresholds 2/10/20 mm)', () {
      test('no rain is very good', () {
        final r = _conditions(windSpeedMax: 5, waveHeight: 0.1, precipitationSumRecent48h: 0).rateWaterClarity();
        expect(r.level, RatingLevel.veryGood);
      });

      test('moderate rain (>2mm) is ok', () {
        final r = _conditions(windSpeedMax: 5, waveHeight: 0.1, precipitationSumRecent48h: 5).rateWaterClarity();
        expect(r.level, RatingLevel.ok);
      });

      test('heavy rain (>10mm) is bad', () {
        final r = _conditions(windSpeedMax: 5, waveHeight: 0.1, precipitationSumRecent48h: 15).rateWaterClarity();
        expect(r.level, RatingLevel.bad);
      });

      test('very heavy rain (>20mm) is very bad', () {
        final r = _conditions(windSpeedMax: 5, waveHeight: 0.1, precipitationSumRecent48h: 25).rateWaterClarity();
        expect(r.level, RatingLevel.veryBad);
        expect(r.reason, contains('Lluvia'));
      });

      test('1.5mm now lands in its own "good" tier (previously mislabeled veryGood)', () {
        final r = _conditions(windSpeedMax: 5, waveHeight: 0.1, precipitationSumRecent48h: 1.5).rateWaterClarity();
        expect(r.level, RatingLevel.good);
        expect(r.score, closeTo(0.7, _tol));
      });

      test('exactly 2mm is the top of the "good" tier, not veryGood', () {
        final r = _conditions(windSpeedMax: 5, waveHeight: 0.1, precipitationSumRecent48h: 2).rateWaterClarity();
        expect(r.level, RatingLevel.ok);
        expect(r.score, closeTo(0.6, _tol));
      });

      test('genuinely dry (<1mm) gets the true veryGood plateau score', () {
        final r = _conditions(windSpeedMax: 5, waveHeight: 0.1, precipitationSumRecent48h: 0.5).rateWaterClarity();
        expect(r.level, RatingLevel.veryGood);
        expect(r.score, closeTo(0.9, _tol));
      });
    });

    group('local wave height branch (windWaveHeight ?? waveHeight, thresholds 0.3/0.5/0.8/1.2 m)', () {
      test('flat local sea is very good', () {
        final r = _conditions(windSpeedMax: 5, windWaveHeight: 0.1).rateWaterClarity();
        expect(r.level, RatingLevel.veryGood);
      });

      test('strong local wind-wave is bad even with light wind', () {
        final r = _conditions(windSpeedMax: 5, windWaveHeight: 1.0).rateWaterClarity();
        expect(r.level, RatingLevel.bad);
      });

      test('rough local wind-wave (>1.2m) is very bad', () {
        final r = _conditions(windSpeedMax: 5, windWaveHeight: 1.5).rateWaterClarity();
        expect(r.level, RatingLevel.veryBad);
      });

      test('windWaveHeight takes priority over the coarser total waveHeight when both are present', () {
        final r = _conditions(windSpeedMax: 5, windWaveHeight: 0.1, waveHeight: 3.0).rateWaterClarity();
        expect(r.level, RatingLevel.veryGood);
      });

      test('falls back to waveHeight when windWaveHeight is missing', () {
        final r = _conditions(windSpeedMax: 5, windWaveHeight: null, waveHeight: 1.0).rateWaterClarity();
        expect(r.level, RatingLevel.bad);
      });

      test('missing wave data entirely falls back to a cautious ok / 0.5 score, not a guess of good or bad', () {
        final r = _conditions(windSpeedMax: 5, windWaveHeight: null, waveHeight: null).rateWaterClarity();
        expect(r.level, RatingLevel.ok);
        expect(r.score, closeTo(0.5, _tol));
        expect(r.reason, contains('oleaje'));
      });
    });

    group('worst-of interaction across the 4 checks', () {
      test('one bad parameter drags an otherwise-perfect day down to its level', () {
        final r = _conditions(windSpeedMax: 2, windGustsMax: 2, precipitationSumRecent48h: 0, windWaveHeight: 2.0)
            .rateWaterClarity();
        expect(r.level, RatingLevel.veryBad);
      });

      test('a perfect day across all 4 checks is very good', () {
        final r = _conditions(windSpeedMax: 2, windGustsMax: 2, precipitationSumRecent48h: 0, windWaveHeight: 0.05)
            .rateWaterClarity();
        expect(r.level, RatingLevel.veryGood);
      });

      test('tie-break: among two checks at the same level, the lower (worse) score wins', () {
        // wind at 21 km/h -> ok, score ~0.58; local wave at 0.75m -> ok, score ~0.47.
        final r = _conditions(windSpeedMax: 21, windWaveHeight: 0.75, precipitationSumRecent48h: 0)
            .rateWaterClarity();
        final windOnlyScore = _mirrorAscending(21, 15, 20, 30, 40);
        final waveOnlyScore = _mirrorAscending(0.75, 0.3, 0.5, 0.8, 1.2);
        expect(r.level, RatingLevel.ok);
        expect(r.score, closeTo(waveOnlyScore < windOnlyScore ? waveOnlyScore : windOnlyScore, _tol));
      });
    });
  });

  group('ratePlayaRemovida', () {
    group('sustained wind branch (thresholds 15/20/30/40 km/h over 48h)', () {
      test('calm sustained wind is very good', () {
        final r = _conditions(windSpeedSustained48h: 5, waveHeightMaxRecent48h: 0.1).ratePlayaRemovida();
        expect(r.level, RatingLevel.veryGood);
      });

      test('mid sustained wind (25 km/h) is ok, with the expected interpolated score', () {
        final r = _conditions(windSpeedSustained48h: 25, waveHeightMaxRecent48h: 0.1).ratePlayaRemovida();
        expect(r.level, RatingLevel.ok);
        expect(r.score, closeTo(_mirrorAscending(25, 15, 20, 30, 40), _tol));
      });

      test('very strong sustained wind (>40) is very bad', () {
        final r = _conditions(windSpeedSustained48h: 45, waveHeightMaxRecent48h: 0.1).ratePlayaRemovida();
        expect(r.level, RatingLevel.veryBad);
      });
    });

    group('recent max wave height branch (thresholds 0.4/0.6/1.0/1.5 m over 48h)', () {
      test('calm recent seas are very good', () {
        final r = _conditions(windSpeedSustained48h: 5, waveHeightMaxRecent48h: 0.2).ratePlayaRemovida();
        expect(r.level, RatingLevel.veryGood);
      });

      test('a recent 1.8m max is very bad regardless of calm wind', () {
        final r = _conditions(windSpeedSustained48h: 5, waveHeightMaxRecent48h: 1.8).ratePlayaRemovida();
        expect(r.level, RatingLevel.veryBad);
      });

      test('missing recent-wave data falls back to a cautious ok / 0.5 score', () {
        final r = _conditions(windSpeedSustained48h: 5, waveHeightMaxRecent48h: null).ratePlayaRemovida();
        expect(r.level, RatingLevel.ok);
        expect(r.score, closeTo(0.5, _tol));
        expect(r.reason, contains('oleaje'));
      });

      test('exact t1 boundary (0.4m): level and score change tiers together', () {
        final r = _conditions(windSpeedSustained48h: 5, waveHeightMaxRecent48h: 0.4).ratePlayaRemovida();
        expect(r.level, RatingLevel.good);
        expect(r.score, closeTo(0.8, _tol));
      });
    });

    test('storm-battered beach: strong sustained wind + big recent surf is very bad', () {
      final r = _conditions(windSpeedSustained48h: 50, waveHeightMaxRecent48h: 2.5).ratePlayaRemovida();
      expect(r.level, RatingLevel.veryBad);
    });
  });

  group('rateSurf', () {
    group('swell height branch (custom bucketed formula, thresholds 0.3/0.5/0.8/1.0/2.0 m)', () {
      test('dead flat (0m) is very bad with score 0', () {
        final r = _conditions(swellWaveHeight: 0, swellWavePeriod: 10, windSpeedMax: 5).rateSurf();
        expect(r.level, RatingLevel.veryBad);
        expect(r.score, closeTo(0.0, _tol));
      });

      test('0.15m (mid "veryBad" band) has a proportionally low, non-zero score', () {
        final r = _conditions(swellWaveHeight: 0.15, swellWavePeriod: 10, windSpeedMax: 5).rateSurf();
        expect(r.level, RatingLevel.veryBad);
        expect(r.score, closeTo(0.1, _tol));
      });

      test('0.4m (mid "bad" band) is bad', () {
        final r = _conditions(swellWaveHeight: 0.4, swellWavePeriod: 10, windSpeedMax: 5).rateSurf();
        expect(r.level, RatingLevel.bad);
        expect(r.score, closeTo(0.3, _tol));
      });

      test('0.65m (mid "ok" band) is ok / surf flojo', () {
        final r = _conditions(swellWaveHeight: 0.65, swellWavePeriod: 10, windSpeedMax: 5).rateSurf();
        expect(r.level, RatingLevel.ok);
        expect(r.score, closeTo(0.5, _tol));
      });

      test('0.9m (mid "good" band) is good', () {
        // period omitted and wind pinned at its veryGood plateau (better
        // level than "good") so neither can out-rank the swell check here.
        final r = _conditions(swellWaveHeight: 0.9, windSpeedMax: 0).rateSurf();
        expect(r.level, RatingLevel.good);
        expect(r.score, closeTo(0.7, _tol));
      });

      test('1.5m is the sweet spot for swell size, but the combined rating caps at 0.9', () {
        // The swell-height formula alone peaks at 1.0 for a 1.5m swell, but
        // rateSurf() always also folds in a wind check whose own best
        // possible score is a flat 0.9 (see _ascendingScore's plateau). Once
        // both checks tie at veryGood, the tiebreak picks the LOWER score,
        // so the wind check's 0.9 wins over swell's 1.0. In practice a
        // perfect-size swell can never push the overall surf score above 0.9.
        final r = _conditions(swellWaveHeight: 1.5, windSpeedMax: 0).rateSurf();
        expect(r.level, RatingLevel.veryGood);
        expect(r.score, closeTo(0.9, _tol));
      });

      test('1.0m and 2.0m (both edges of the veryGood band) score equally lower than the 1.5m peak', () {
        final at1 = _conditions(swellWaveHeight: 1.0, windSpeedMax: 0).rateSurf();
        final at2 = _conditions(swellWaveHeight: 2.0, windSpeedMax: 0).rateSurf();
        expect(at1.score, closeTo(0.8, _tol));
        expect(at2.score, closeTo(0.8, _tol));
      });

      test('score rises monotonically from 1.0m to the 1.5m peak, then falls monotonically to 2.0m', () {
        final scores = [1.0, 1.1, 1.2, 1.3, 1.4, 1.5, 1.6, 1.7, 1.8, 1.9, 2.0]
            .map((h) => _conditions(swellWaveHeight: h, windSpeedMax: 0).rateSurf().score)
            .toList();
        for (var i = 1; i <= 5; i++) {
          expect(scores[i], greaterThanOrEqualTo(scores[i - 1]), reason: 'expected rise up to the 1.5m peak');
        }
        for (var i = 6; i <= 10; i++) {
          expect(scores[i], lessThanOrEqualTo(scores[i - 1]), reason: 'expected fall after the 1.5m peak');
        }
      });

      test('crossing 2.0m is now a smooth transition into "good", not a cliff', () {
        final justAtLimit = _conditions(swellWaveHeight: 2.0, windSpeedMax: 0).rateSurf();
        final justOverLimit = _conditions(swellWaveHeight: 2.01, windSpeedMax: 0).rateSurf();
        expect(justAtLimit.level, RatingLevel.veryGood);
        expect(justOverLimit.level, RatingLevel.good);
        expect(justAtLimit.score, closeTo(0.8, _tol));
        expect(justOverLimit.score, closeTo(0.798, 0.001));
      });

      test('big-but-surfable (2.5m) rates good, distinct from a huge/dangerous (10m) storm swell', () {
        final big = _conditions(swellWaveHeight: 2.5, windSpeedMax: 0).rateSurf();
        final huge = _conditions(swellWaveHeight: 10.0, windSpeedMax: 0).rateSurf();
        expect(big.level, RatingLevel.good);
        expect(big.score, closeTo(0.7, _tol));
        expect(huge.level, RatingLevel.veryBad);
        expect(huge.score, closeTo(0.1, _tol));
      });

      test('4.0m (mid "ok" band, very large/unruly) and 5.0m (mid "bad" band, dangerous) grade progressively worse', () {
        final at4 = _conditions(swellWaveHeight: 4.0, windSpeedMax: 0).rateSurf();
        final at5 = _conditions(swellWaveHeight: 5.0, windSpeedMax: 0).rateSurf();
        expect(at4.level, RatingLevel.ok);
        expect(at5.level, RatingLevel.bad);
        expect(at5.score, lessThan(at4.score));
      });

      test('score declines monotonically (no cliffs) all the way from the 1.5m peak out to a 10m storm swell', () {
        final scores = [1.5, 2.0, 2.5, 3.0, 3.5, 4.0, 4.5, 5.0, 5.5, 6.0, 6.5, 8.0, 10.0]
            .map((h) => _conditions(swellWaveHeight: h, windSpeedMax: 0).rateSurf().score)
            .toList();
        for (var i = 1; i < scores.length; i++) {
          expect(scores[i], lessThanOrEqualTo(scores[i - 1] + 1e-9), reason: 'regression at index $i');
        }
      });

      test('missing swell height data falls back to a cautious ok / 0.5 score', () {
        final r = _conditions(swellWaveHeight: null, swellWavePeriod: 10, windSpeedMax: 5).rateSurf();
        expect(r.level, RatingLevel.ok);
        expect(r.score, closeTo(0.5, _tol));
      });
    });

    group('swell period branch (thresholds 6/8/10/12 s, optional check)', () {
      test('very short period (choppy wind swell, <6s) is very bad even with great size', () {
        final r = _conditions(swellWaveHeight: 1.5, swellWavePeriod: 4, windSpeedMax: 5).rateSurf();
        expect(r.level, RatingLevel.veryBad);
      });

      test('long clean groundswell period (>=12s) is very good', () {
        final r = _conditions(swellWaveHeight: 1.5, swellWavePeriod: 14, windSpeedMax: 5).rateSurf();
        expect(r.level, RatingLevel.veryGood);
      });

      test('9s (mid "ok" band) is ok, with the expected interpolated score', () {
        final r = _conditions(swellWaveHeight: 1.5, swellWavePeriod: 9, windSpeedMax: 5).rateSurf();
        expect(r.level, RatingLevel.ok);
        expect(r.score, closeTo(_mirrorDescending(9, 12, 10, 8, 6), _tol));
      });

      test('when period data is missing, the check is simply omitted (not treated as bad)', () {
        final withoutPeriod = _conditions(swellWaveHeight: 1.5, swellWavePeriod: null, windSpeedMax: 5).rateSurf();
        expect(withoutPeriod.level, RatingLevel.veryGood);
      });
    });

    group('surf-specific wind branch (thresholds 10/15/20/25 km/h, stricter than the other checks)', () {
      test('calm wind (<10) is very good', () {
        final r = _conditions(swellWaveHeight: 1.5, swellWavePeriod: 12, windSpeedMax: 5).rateSurf();
        expect(r.level, RatingLevel.veryGood);
      });

      test('18 km/h wind rates only "ok" for surf while the same wind is "good" for water clarity', () {
        // Surf uses stricter thresholds (10/15/20/25) than water clarity's
        // (15/20/30/40), so identical wind is judged more harshly for surf.
        final surf = _conditions(swellWaveHeight: 1.5, swellWavePeriod: 12, windSpeedMax: 18).rateSurf();
        final clarity = _conditions(windSpeedMax: 18, waveHeight: 0.1).rateWaterClarity();
        expect(surf.level, RatingLevel.ok);
        expect(clarity.level, RatingLevel.good);
      });

      test('very strong wind (>25) ruins an otherwise-excellent swell', () {
        final r = _conditions(swellWaveHeight: 1.5, swellWavePeriod: 12, windSpeedMax: 30).rateSurf();
        expect(r.level, RatingLevel.veryBad);
      });
    });

    test('perfect surf day: great size, long period, calm wind is very good', () {
      final r = _conditions(swellWaveHeight: 1.5, swellWavePeriod: 14, windSpeedMax: 5).rateSurf();
      expect(r.level, RatingLevel.veryGood);
    });

    test('blown-out day: tiny wind slop with a gale is very bad', () {
      final r = _conditions(swellWaveHeight: 0.1, swellWavePeriod: 4, windSpeedMax: 40).rateSurf();
      expect(r.level, RatingLevel.veryBad);
    });
  });

  group('rateSun', () {
    group('cloud cover branch (thresholds 15/35/65/90 %)', () {
      test('clear sky is very good', () {
        final r = _conditions(cloudCoverCurrent: 5, sunshineDurationHours: 10).rateSun();
        expect(r.level, RatingLevel.veryGood);
      });

      test('50% cloud (mid "ok" band) interpolates to the expected score', () {
        final r = _conditions(cloudCoverCurrent: 50, sunshineDurationHours: 10).rateSun();
        expect(r.level, RatingLevel.ok);
        expect(r.score, closeTo(_mirrorAscending(50, 15, 35, 65, 90), _tol));
      });

      test('overcast (>=90%) is very bad', () {
        final r = _conditions(cloudCoverCurrent: 95).rateSun();
        expect(r.level, RatingLevel.veryBad);
      });
    });

    group('sunshine duration branch (thresholds 2/5/8/10 h)', () {
      test('a full sunny day (>=10h) is very good', () {
        final r = _conditions(cloudCoverCurrent: 10, sunshineDurationHours: 11).rateSun();
        expect(r.level, RatingLevel.veryGood);
      });

      test('6.5h (mid "ok" band) interpolates to the expected score', () {
        final r = _conditions(cloudCoverCurrent: 10, sunshineDurationHours: 6.5).rateSun();
        expect(r.level, RatingLevel.ok);
        expect(r.score, closeTo(_mirrorDescending(6.5, 10, 8, 5, 2), _tol));
      });

      test('almost no real sunshine (<2h) is very bad even under a clear sky', () {
        final r = _conditions(cloudCoverCurrent: 10, sunshineDurationHours: 1).rateSun();
        expect(r.level, RatingLevel.veryBad);
      });
    });

    group('fog override (hard veryBad regardless of cloud/sun readings)', () {
      test('fog code 45 overrides an otherwise-perfect sunny forecast', () {
        final r = _conditions(cloudCoverCurrent: 5, sunshineDurationHours: 12, currentWeatherCode: 45).rateSun();
        expect(r.level, RatingLevel.veryBad);
        expect(r.score, closeTo(0.05, _tol));
        expect(r.reason, contains('Niebla'));
      });

      test('fog code 48 also overrides', () {
        final r = _conditions(cloudCoverCurrent: 5, sunshineDurationHours: 12, currentWeatherCode: 48).rateSun();
        expect(r.level, RatingLevel.veryBad);
      });

      test('a non-fog code does not trigger the override', () {
        final r = _conditions(cloudCoverCurrent: 5, sunshineDurationHours: 12, currentWeatherCode: 3).rateSun();
        expect(r.level, RatingLevel.veryGood);
      });
    });

    group('UV cap (adds an "ok" ceiling, but never rescues a worse rating)', () {
      test('UV > 8 caps an otherwise-perfect day at ok', () {
        final r = _conditions(cloudCoverCurrent: 5, sunshineDurationHours: 12, uvIndexMax: 9).rateSun();
        expect(r.level, RatingLevel.ok);
        expect(r.reason, contains('UV'));
      });

      test('UV exactly at 8 does not trigger the cap (uses strict >)', () {
        final r = _conditions(cloudCoverCurrent: 5, sunshineDurationHours: 12, uvIndexMax: 8).rateSun();
        expect(r.level, RatingLevel.veryGood);
      });

      test('a high UV index does not rescue an already-overcast day back up to ok', () {
        final r = _conditions(cloudCoverCurrent: 95, uvIndexMax: 11).rateSun();
        expect(r.level, RatingLevel.veryBad);
      });
    });
  });

  group('rateRain', () {
    group('rain probability branch (thresholds 10/20/50/75 %)', () {
      test('near-zero probability is very good', () {
        final r = _conditions(precipitationProbabilityMax: 2).rateRain();
        expect(r.level, RatingLevel.veryGood);
      });

      test('35% (mid "ok" band) interpolates to the expected score', () {
        final r = _conditions(precipitationProbabilityMax: 35).rateRain();
        expect(r.level, RatingLevel.ok);
        expect(r.score, closeTo(_mirrorAscending(35, 10, 20, 50, 75), _tol));
      });

      test('90% probability is very bad', () {
        final r = _conditions(precipitationProbabilityMax: 90).rateRain();
        expect(r.level, RatingLevel.veryBad);
      });
    });

    group('expected rain amount today branch (thresholds 0.5/3/10 mm, no check added if <= 0.5mm)', () {
      test('a light drizzle amount (<=0.5mm) does not add a check, so probability alone decides', () {
        final trace = _conditions(precipitationProbabilityMax: 5, precipitationSumToday: 0.3).rateRain();
        final none = _conditions(precipitationProbabilityMax: 5, precipitationSumToday: 0).rateRain();
        expect(trace.level, none.level);
        expect(trace.score, closeTo(none.score, _tol));
      });

      test('6mm expected (mid "bad" band) drags an otherwise-fine forecast down to bad', () {
        final r = _conditions(precipitationProbabilityMax: 5, precipitationSumToday: 6).rateRain();
        expect(r.level, RatingLevel.bad);
      });

      test('15mm expected is very bad even with low probability', () {
        final r = _conditions(precipitationProbabilityMax: 5, precipitationSumToday: 15).rateRain();
        expect(r.level, RatingLevel.veryBad);
      });
    });

    group('storm override (hard veryBad regardless of probability/amount)', () {
      test('thunderstorm code (95) overrides a low-probability, dry forecast', () {
        final r = _conditions(precipitationProbabilityMax: 5, precipitationSumToday: 0, weatherCode: 95).rateRain();
        expect(r.level, RatingLevel.veryBad);
        expect(r.score, closeTo(0.05, _tol));
        expect(r.reason, contains('Tormenta'));
      });

      test('thunderstorm with hail codes (96, 99) also override', () {
        expect(_conditions(weatherCode: 96).rateRain().level, RatingLevel.veryBad);
        expect(_conditions(weatherCode: 99).rateRain().level, RatingLevel.veryBad);
      });

      test('code 94 (just below the storm threshold) does not trigger the override', () {
        final r = _conditions(precipitationProbabilityMax: 5, precipitationSumToday: 0, weatherCode: 94).rateRain();
        expect(r.level, RatingLevel.veryGood);
      });
    });

    test('dry, sunny forecast is very good', () {
      final r = _conditions(precipitationProbabilityMax: 3, precipitationSumToday: 0).rateRain();
      expect(r.level, RatingLevel.veryGood);
    });
  });

  group('cross-parameter realism scenarios (integration across all 5 ratings at once)', () {
    test('an ideal calm sunny beach day scores well across all 5 parameters', () {
      final conditions = _conditions(
        windSpeedMax: 5,
        windGustsMax: 8,
        windSpeedSustained48h: 5,
        precipitationSumRecent48h: 0,
        precipitationProbabilityMax: 2,
        precipitationSumToday: 0,
        cloudCoverCurrent: 5,
        sunshineDurationHours: 11,
        uvIndexMax: 6,
        weatherCode: 1,
        currentWeatherCode: 1,
        waveHeight: 0.1,
        windWaveHeight: 0.1,
        waveHeightMaxRecent48h: 0.1,
        swellWaveHeight: 1.3,
        swellWavePeriod: 12,
      );
      expect(conditions.rateWaterClarity().level, RatingLevel.veryGood);
      expect(conditions.ratePlayaRemovida().level, RatingLevel.veryGood);
      expect(conditions.rateSurf().level, RatingLevel.veryGood);
      expect(conditions.rateSun().level, RatingLevel.veryGood);
      expect(conditions.rateRain().level, RatingLevel.veryGood);
    });

    test('a stormy, gale-force day scores badly across all 5 parameters', () {
      final conditions = _conditions(
        windSpeedMax: 55,
        windGustsMax: 70,
        windSpeedSustained48h: 55,
        precipitationSumRecent48h: 30,
        precipitationProbabilityMax: 95,
        precipitationSumToday: 20,
        cloudCoverCurrent: 100,
        sunshineDurationHours: 0,
        uvIndexMax: 1,
        weatherCode: 96,
        currentWeatherCode: 65,
        waveHeight: 3.0,
        windWaveHeight: 2.5,
        waveHeightMaxRecent48h: 3.0,
        swellWaveHeight: 0.1,
        swellWavePeriod: 4,
      );
      expect(conditions.rateWaterClarity().level, RatingLevel.veryBad);
      expect(conditions.ratePlayaRemovida().level, RatingLevel.veryBad);
      expect(conditions.rateSurf().level, RatingLevel.veryBad);
      expect(conditions.rateSun().level, RatingLevel.veryBad);
      expect(conditions.rateRain().level, RatingLevel.veryBad);
    });
  });

  group('global score sanity: range and monotonicity across sampled inputs', () {
    List<double> sample(num Function(double) build, List<double> xs) => xs.map((x) => build(x).toDouble()).toList();

    test('rateWaterClarity score always stays within [0, 1] across a wide wind sweep', () {
      for (var w = -5.0; w <= 200; w += 5) {
        final score = _conditions(windSpeedMax: w < 0 ? 0 : w, waveHeight: 0.1).rateWaterClarity().score;
        expect(score, inInclusiveRange(0.0, 1.0), reason: 'wind=$w');
      }
    });

    test('rateWaterClarity score is non-increasing as wind speed worsens (0 to 100 km/h)', () {
      final scores =
          sample((w) => _conditions(windSpeedMax: w, waveHeight: 0.1).rateWaterClarity().score, [
        for (var w = 0.0; w <= 100; w += 1) w,
      ]);
      for (var i = 1; i < scores.length; i++) {
        expect(scores[i], lessThanOrEqualTo(scores[i - 1] + 1e-9), reason: 'regression at index $i');
      }
    });

    test('rateSun score is non-increasing as cloud cover worsens (0 to 100%)', () {
      final scores = sample(
        (c) => _conditions(cloudCoverCurrent: c, sunshineDurationHours: 10).rateSun().score,
        [for (var c = 0.0; c <= 100; c += 1) c],
      );
      for (var i = 1; i < scores.length; i++) {
        expect(scores[i], lessThanOrEqualTo(scores[i - 1] + 1e-9), reason: 'regression at index $i');
      }
    });

    test('rateRain score is non-increasing as rain probability worsens (0 to 100%)', () {
      final scores = sample(
        (p) => _conditions(precipitationProbabilityMax: p).rateRain().score,
        [for (var p = 0.0; p <= 100; p += 1) p],
      );
      for (var i = 1; i < scores.length; i++) {
        expect(scores[i], lessThanOrEqualTo(scores[i - 1] + 1e-9), reason: 'regression at index $i');
      }
    });

    test('ratePlayaRemovida score is non-increasing as recent max wave height worsens (0 to 5m)', () {
      final scores = sample(
        (h) => _conditions(waveHeightMaxRecent48h: h).ratePlayaRemovida().score,
        [for (var h = 0.0; h <= 5; h += 0.1) h],
      );
      for (var i = 1; i < scores.length; i++) {
        expect(scores[i], lessThanOrEqualTo(scores[i - 1] + 1e-9), reason: 'regression at index $i');
      }
    });

    test('all 5 rating methods always report a score within [0, 1] and a non-empty reason', () {
      final samples = [
        _conditions(),
        _conditions(windSpeedMax: 0, windGustsMax: 0, cloudCoverCurrent: 0, sunshineDurationHours: 0),
        _conditions(windSpeedMax: 200, windGustsMax: 200, cloudCoverCurrent: 100, sunshineDurationHours: 24),
        _conditions(swellWaveHeight: null, swellWavePeriod: null, waveHeight: null, windWaveHeight: null),
        _conditions(weatherCode: 99, currentWeatherCode: 45, precipitationProbabilityMax: 100),
      ];
      for (final c in samples) {
        for (final rating in [c.rateWaterClarity(), c.ratePlayaRemovida(), c.rateSurf(), c.rateSun(), c.rateRain()]) {
          expect(rating.score, inInclusiveRange(0.0, 1.0));
          expect(rating.reason, isNotEmpty);
        }
      }
    });
  });
}
