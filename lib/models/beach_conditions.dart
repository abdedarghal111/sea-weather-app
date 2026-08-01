/// Nivel de una valoración, de mejor a peor. El índice se usa para comparar
/// "cuál es peor" entre varias comprobaciones (ver [BeachConditions._worstOf]).
enum RatingLevel { veryGood, good, ok, bad, veryBad }

extension RatingLevelLabel on RatingLevel {
  String get label => switch (this) {
        RatingLevel.veryGood => 'Muy bueno',
        RatingLevel.good => 'Bueno',
        RatingLevel.ok => 'Regular',
        RatingLevel.bad => 'Malo',
        RatingLevel.veryBad => 'Muy malo',
      };
}

class BeachRating {
  final RatingLevel level;
  final String reason;

  /// Posición continua dentro de la escala, de 0 (extremo "muy malo") a 1
  /// (extremo "muy bueno"). Sirve para colocar el marcador de [RatingGauge]
  /// de forma proporcional al valor real, no solo saltando entre 5 puntos.
  final double score;

  const BeachRating({required this.level, required this.reason, required this.score});
}

/// Puntúa un valor donde MENOS es mejor (ej. viento, oleaje, lluvia),
/// repartiendo la escala en 5 tramos de 0.2 según los mismos umbrales que
/// determinan el nivel cualitativo, e interpolando dentro del tramo.
///
/// Usa `<` estricto (no `<=`) para que coincida exactamente con las
/// comparaciones de los niveles cualitativos (`value < t1` => veryGood,
/// etc.): así, justo en el valor de un umbral, nivel y score cambian de
/// tramo a la vez en vez de que el score se quede "pegado" al tramo mejor.
double _ascendingScore(double value, double t1, double t2, double t3, double t4) {
  if (value < t1) return 0.9;
  if (value < t2) return 0.6 + 0.2 * (1 - (value - t1) / (t2 - t1));
  if (value < t3) return 0.4 + 0.2 * (1 - (value - t2) / (t3 - t2));
  if (value < t4) return 0.2 + 0.2 * (1 - (value - t3) / (t4 - t3));
  return 0.1;
}

/// Igual que [_ascendingScore] pero para valores donde MÁS es mejor (ej.
/// horas de sol, periodo de swell). t1 > t2 > t3 > t4.
double _descendingScore(double value, double t1, double t2, double t3, double t4) {
  if (value >= t1) return 0.9;
  if (value >= t2) return 0.6 + 0.2 * (1 - (t1 - value) / (t1 - t2));
  if (value >= t3) return 0.4 + 0.2 * (1 - (t2 - value) / (t2 - t3));
  if (value >= t4) return 0.2 + 0.2 * (1 - (t3 - value) / (t3 - t4));
  return 0.1;
}

class BeachConditions {
  final double airTempMax;
  final double feelsLike;
  final double precipitationProbabilityMax;
  final double precipitationSumToday;
  final double precipitationSumRecent48h;
  final double windSpeedMax;
  final double windGustsMax;
  final double windSpeedSustained48h;
  final double uvIndexMax;
  final double cloudCoverCurrent;
  final double sunshineDurationHours;
  // Código del día (para saber si va a haber tormenta en algún momento) vs.
  // código de ahora mismo (para saber si hay niebla justo ahora): la niebla
  // matinal en la costa no debe tumbar la valoración de sol de todo el día.
  final int weatherCode;
  final int currentWeatherCode;
  // Solo los datos marinos pueden faltar de verdad: la Marine API devuelve
  // null cuando el punto no es costero.
  final double? waveHeight;
  final double? waveHeightMaxRecent48h;
  final double? windWaveHeight;
  final double? swellWaveHeight;
  final double? swellWavePeriod;
  final double? seaSurfaceTemperature;
  final DateTime fetchedAt;

  const BeachConditions({
    required this.airTempMax,
    required this.feelsLike,
    required this.precipitationProbabilityMax,
    required this.precipitationSumToday,
    required this.precipitationSumRecent48h,
    required this.windSpeedMax,
    required this.windGustsMax,
    required this.windSpeedSustained48h,
    required this.uvIndexMax,
    required this.cloudCoverCurrent,
    required this.sunshineDurationHours,
    required this.weatherCode,
    required this.currentWeatherCode,
    this.waveHeight,
    this.waveHeightMaxRecent48h,
    this.windWaveHeight,
    this.swellWaveHeight,
    this.swellWavePeriod,
    this.seaSurfaceTemperature,
    required this.fetchedAt,
  });

  Map<String, dynamic> toJson() => {
        'airTempMax': airTempMax,
        'feelsLike': feelsLike,
        'precipitationProbabilityMax': precipitationProbabilityMax,
        'precipitationSumToday': precipitationSumToday,
        'precipitationSumRecent48h': precipitationSumRecent48h,
        'windSpeedMax': windSpeedMax,
        'windGustsMax': windGustsMax,
        'windSpeedSustained48h': windSpeedSustained48h,
        'uvIndexMax': uvIndexMax,
        'cloudCoverCurrent': cloudCoverCurrent,
        'sunshineDurationHours': sunshineDurationHours,
        'weatherCode': weatherCode,
        'currentWeatherCode': currentWeatherCode,
        'waveHeight': waveHeight,
        'waveHeightMaxRecent48h': waveHeightMaxRecent48h,
        'windWaveHeight': windWaveHeight,
        'swellWaveHeight': swellWaveHeight,
        'swellWavePeriod': swellWavePeriod,
        'seaSurfaceTemperature': seaSurfaceTemperature,
        'fetchedAt': fetchedAt.toIso8601String(),
      };

  factory BeachConditions.fromJson(Map<String, dynamic> json) => BeachConditions(
        airTempMax: (json['airTempMax'] as num).toDouble(),
        feelsLike: (json['feelsLike'] as num).toDouble(),
        precipitationProbabilityMax: (json['precipitationProbabilityMax'] as num).toDouble(),
        precipitationSumToday: (json['precipitationSumToday'] as num).toDouble(),
        precipitationSumRecent48h: (json['precipitationSumRecent48h'] as num).toDouble(),
        windSpeedMax: (json['windSpeedMax'] as num).toDouble(),
        windGustsMax: (json['windGustsMax'] as num).toDouble(),
        windSpeedSustained48h: (json['windSpeedSustained48h'] as num).toDouble(),
        uvIndexMax: (json['uvIndexMax'] as num).toDouble(),
        cloudCoverCurrent: (json['cloudCoverCurrent'] as num).toDouble(),
        sunshineDurationHours: (json['sunshineDurationHours'] as num).toDouble(),
        weatherCode: json['weatherCode'] as int,
        currentWeatherCode: json['currentWeatherCode'] as int,
        waveHeight: (json['waveHeight'] as num?)?.toDouble(),
        waveHeightMaxRecent48h: (json['waveHeightMaxRecent48h'] as num?)?.toDouble(),
        windWaveHeight: (json['windWaveHeight'] as num?)?.toDouble(),
        swellWaveHeight: (json['swellWaveHeight'] as num?)?.toDouble(),
        swellWavePeriod: (json['swellWavePeriod'] as num?)?.toDouble(),
        seaSurfaceTemperature: (json['seaSurfaceTemperature'] as num?)?.toDouble(),
        fetchedAt: DateTime.parse(json['fetchedAt'] as String),
      );

  /// 1. ¿El agua está cristalina o turbia? El viento (medio y rachas) y el
  /// oleaje de viento local remueven sedimento del fondo; la lluvia reciente
  /// también enturbia por escorrentía. Esto es una estimación, no una
  /// medición real de turbidez.
  BeachRating rateWaterClarity() {
    final checks = <BeachRating>[
      if (windSpeedMax < 15)
        BeachRating(
          level: RatingLevel.veryGood,
          reason: 'Viento en calma (${windSpeedMax.round()} km/h)',
          score: _ascendingScore(windSpeedMax, 15, 20, 30, 40),
        )
      else if (windSpeedMax < 20)
        BeachRating(
          level: RatingLevel.good,
          reason: 'Viento suave (${windSpeedMax.round()} km/h)',
          score: _ascendingScore(windSpeedMax, 15, 20, 30, 40),
        )
      else if (windSpeedMax < 30)
        BeachRating(
          level: RatingLevel.ok,
          reason: 'Viento moderado (${windSpeedMax.round()} km/h)',
          score: _ascendingScore(windSpeedMax, 15, 20, 30, 40),
        )
      else if (windSpeedMax < 40)
        BeachRating(
          level: RatingLevel.bad,
          reason: 'Viento fuerte (${windSpeedMax.round()} km/h) remueve el fondo',
          score: _ascendingScore(windSpeedMax, 15, 20, 30, 40),
        )
      else
        BeachRating(
          level: RatingLevel.veryBad,
          reason: 'Viento muy fuerte (${windSpeedMax.round()} km/h)',
          score: _ascendingScore(windSpeedMax, 15, 20, 30, 40),
        ),
      if (windGustsMax >= 45)
        BeachRating(
          level: RatingLevel.veryBad,
          reason: 'Rachas muy fuertes remueven el fondo',
          score: _ascendingScore(windGustsMax, 10, 20, 30, 45),
        )
      else if (windGustsMax > 30)
        BeachRating(
          level: RatingLevel.bad,
          reason: 'Rachas fuertes pueden remover el fondo',
          score: _ascendingScore(windGustsMax, 10, 20, 30, 45),
        )
      else if (windGustsMax > 20)
        BeachRating(
          level: RatingLevel.ok,
          reason: 'Rachas moderadas pueden levantar sedimento',
          score: _ascendingScore(windGustsMax, 10, 20, 30, 45),
        ),
      if (precipitationSumRecent48h < 1)
        BeachRating(
          level: RatingLevel.veryGood,
          reason: 'Sin lluvia reciente',
          score: _ascendingScore(precipitationSumRecent48h, 1, 2, 10, 20),
        )
      else if (precipitationSumRecent48h < 2)
        BeachRating(
          level: RatingLevel.good,
          reason: 'Muy poca lluvia reciente',
          score: _ascendingScore(precipitationSumRecent48h, 1, 2, 10, 20),
        )
      else if (precipitationSumRecent48h < 10)
        BeachRating(
          level: RatingLevel.ok,
          reason: 'Algo de lluvia reciente, puede haber turbidez',
          score: _ascendingScore(precipitationSumRecent48h, 1, 2, 10, 20),
        )
      else if (precipitationSumRecent48h < 20)
        BeachRating(
          level: RatingLevel.bad,
          reason: 'Lluvia reciente ha podido enturbiar el agua',
          score: _ascendingScore(precipitationSumRecent48h, 1, 2, 10, 20),
        )
      else
        BeachRating(
          level: RatingLevel.veryBad,
          reason: 'Lluvia reciente abundante, agua probablemente turbia',
          score: _ascendingScore(precipitationSumRecent48h, 1, 2, 10, 20),
        ),
    ];

    final localWave = windWaveHeight ?? waveHeight;
    if (localWave == null) {
      checks.add(const BeachRating(
        level: RatingLevel.ok,
        reason: 'Sin datos de oleaje, no se puede asegurar la visibilidad',
        score: 0.5,
      ));
    } else if (localWave < 0.3) {
      checks.add(BeachRating(
        level: RatingLevel.veryGood,
        reason: 'Mar en calma (${localWave.toStringAsFixed(1)} m), alta confianza en buena visibilidad',
        score: _ascendingScore(localWave, 0.3, 0.5, 0.8, 1.2),
      ));
    } else if (localWave < 0.5) {
      checks.add(BeachRating(
        level: RatingLevel.good,
        reason: 'Oleaje suave (${localWave.toStringAsFixed(1)} m), visibilidad probablemente buena',
        score: _ascendingScore(localWave, 0.3, 0.5, 0.8, 1.2),
      ));
    } else if (localWave < 0.8) {
      checks.add(BeachRating(
        level: RatingLevel.ok,
        reason: 'Algo de oleaje (${localWave.toStringAsFixed(1)} m), visibilidad no garantizada',
        score: _ascendingScore(localWave, 0.3, 0.5, 0.8, 1.2),
      ));
    } else if (localWave < 1.2) {
      checks.add(BeachRating(
        level: RatingLevel.bad,
        reason: 'Oleaje remueve el fondo (${localWave.toStringAsFixed(1)} m), poca visibilidad',
        score: _ascendingScore(localWave, 0.3, 0.5, 0.8, 1.2),
      ));
    } else {
      checks.add(BeachRating(
        level: RatingLevel.veryBad,
        reason: 'Oleaje fuerte (${localWave.toStringAsFixed(1)} m), agua probablemente muy turbia',
        score: _ascendingScore(localWave, 0.3, 0.5, 0.8, 1.2),
      ));
    }

    return _worstOf(checks);
  }

  /// 2. ¿Va a haber playa removida (arena revuelta, escalones)? Viento y
  /// oleaje sostenidos durante los últimos días, no solo ahora mismo.
  BeachRating ratePlayaRemovida() {
    final checks = <BeachRating>[
      if (windSpeedSustained48h < 15)
        BeachRating(
          level: RatingLevel.veryGood,
          reason: 'Viento en calma los últimos días (${windSpeedSustained48h.round()} km/h)',
          score: _ascendingScore(windSpeedSustained48h, 15, 20, 30, 40),
        )
      else if (windSpeedSustained48h < 20)
        BeachRating(
          level: RatingLevel.good,
          reason: 'Viento suave los últimos días (${windSpeedSustained48h.round()} km/h)',
          score: _ascendingScore(windSpeedSustained48h, 15, 20, 30, 40),
        )
      else if (windSpeedSustained48h < 30)
        BeachRating(
          level: RatingLevel.ok,
          reason: 'Viento sostenido moderado (${windSpeedSustained48h.round()} km/h)',
          score: _ascendingScore(windSpeedSustained48h, 15, 20, 30, 40),
        )
      else if (windSpeedSustained48h < 40)
        BeachRating(
          level: RatingLevel.bad,
          reason: 'Viento fuerte varios días seguidos (${windSpeedSustained48h.round()} km/h)',
          score: _ascendingScore(windSpeedSustained48h, 15, 20, 30, 40),
        )
      else
        BeachRating(
          level: RatingLevel.veryBad,
          reason: 'Viento muy fuerte varios días seguidos (${windSpeedSustained48h.round()} km/h)',
          score: _ascendingScore(windSpeedSustained48h, 15, 20, 30, 40),
        ),
    ];

    final recentWave = waveHeightMaxRecent48h;
    if (recentWave == null) {
      checks.add(const BeachRating(
        level: RatingLevel.ok,
        reason: 'Sin datos de oleaje de días recientes',
        score: 0.5,
      ));
    } else if (recentWave < 0.4) {
      checks.add(BeachRating(
        level: RatingLevel.veryGood,
        reason: 'Oleaje en calma en días recientes (${recentWave.toStringAsFixed(1)} m)',
        score: _ascendingScore(recentWave, 0.4, 0.6, 1.0, 1.5),
      ));
    } else if (recentWave < 0.6) {
      checks.add(BeachRating(
        level: RatingLevel.good,
        reason: 'Oleaje suave en días recientes (${recentWave.toStringAsFixed(1)} m)',
        score: _ascendingScore(recentWave, 0.4, 0.6, 1.0, 1.5),
      ));
    } else if (recentWave < 1.0) {
      checks.add(BeachRating(
        level: RatingLevel.ok,
        reason: 'Oleaje moderado en días recientes (${recentWave.toStringAsFixed(1)} m)',
        score: _ascendingScore(recentWave, 0.4, 0.6, 1.0, 1.5),
      ));
    } else if (recentWave < 1.5) {
      checks.add(BeachRating(
        level: RatingLevel.bad,
        reason: 'Oleaje fuerte en días recientes (${recentWave.toStringAsFixed(1)} m), puede haber escalones',
        score: _ascendingScore(recentWave, 0.4, 0.6, 1.0, 1.5),
      ));
    } else {
      checks.add(BeachRating(
        level: RatingLevel.veryBad,
        reason: 'Oleaje muy fuerte en días recientes (${recentWave.toStringAsFixed(1)} m)',
        score: _ascendingScore(recentWave, 0.4, 0.6, 1.0, 1.5),
      ));
    }

    return _worstOf(checks);
  }

  /// 3. ¿Se puede hacer surf? Tamaño y periodo del oleaje de fondo (swell);
  /// sin conocer la orientación de la playa no se evalúa offshore/onshore,
  /// solo se penaliza el viento fuerte en general.
  BeachRating rateSurf() {
    final checks = <BeachRating>[];

    final swell = swellWaveHeight;
    if (swell == null) {
      checks.add(const BeachRating(
        level: RatingLevel.ok,
        reason: 'Sin datos de oleaje de fondo para valorar el surf',
        score: 0.5,
      ));
    } else if (swell < 0.3) {
      checks.add(BeachRating(
        level: RatingLevel.veryBad,
        reason: 'Prácticamente sin olas (${swell.toStringAsFixed(1)} m) para surfear',
        score: 0.2 * (swell / 0.3).clamp(0.0, 1.0),
      ));
    } else if (swell < 0.5) {
      checks.add(BeachRating(
        level: RatingLevel.bad,
        reason: 'Olas muy pequeñas (${swell.toStringAsFixed(1)} m) para surfear',
        score: 0.2 + 0.2 * ((swell - 0.3) / (0.5 - 0.3)),
      ));
    } else if (swell < 0.8) {
      checks.add(BeachRating(
        level: RatingLevel.ok,
        reason: 'Olas pequeñas (${swell.toStringAsFixed(1)} m), surf flojo',
        score: 0.4 + 0.2 * ((swell - 0.5) / (0.8 - 0.5)),
      ));
    } else if (swell <= 1.0) {
      checks.add(BeachRating(
        level: RatingLevel.good,
        reason: 'Buen tamaño de ola (${swell.toStringAsFixed(1)} m) para surfear',
        score: 0.6 + 0.2 * ((swell - 0.8) / (1.0 - 0.8)),
      ));
    } else if (swell <= 2.0) {
      checks.add(BeachRating(
        level: RatingLevel.veryGood,
        reason: 'Tamaño de ola excelente (${swell.toStringAsFixed(1)} m) para surfear',
        score: 0.8 + 0.2 * (1 - ((swell - 1.0) / (2.0 - 1.0) - 0.5).abs() * 2).clamp(0.0, 1.0),
      ));
    } else {
      checks.add(BeachRating(
        level: RatingLevel.ok,
        reason: 'Olas grandes y algo descontroladas (${swell.toStringAsFixed(1)} m)',
        score: 0.5,
      ));
    }

    final period = swellWavePeriod;
    if (period != null) {
      if (period < 6) {
        checks.add(BeachRating(
          level: RatingLevel.veryBad,
          reason: 'Oleaje muy corto y desordenado',
          score: _descendingScore(period, 12, 10, 8, 6),
        ));
      } else if (period < 8) {
        checks.add(BeachRating(
          level: RatingLevel.bad,
          reason: 'Oleaje corto, bastante desordenado',
          score: _descendingScore(period, 12, 10, 8, 6),
        ));
      } else if (period < 10) {
        checks.add(BeachRating(
          level: RatingLevel.ok,
          reason: 'Swell de calidad media',
          score: _descendingScore(period, 12, 10, 8, 6),
        ));
      } else if (period < 12) {
        checks.add(BeachRating(
          level: RatingLevel.good,
          reason: 'Buen periodo de swell',
          score: _descendingScore(period, 12, 10, 8, 6),
        ));
      } else {
        checks.add(BeachRating(
          level: RatingLevel.veryGood,
          reason: 'Swell largo y limpio',
          score: _descendingScore(period, 12, 10, 8, 6),
        ));
      }
    }

    if (windSpeedMax < 10) {
      checks.add(BeachRating(
        level: RatingLevel.veryGood,
        reason: 'Viento en calma, favorable para el surf',
        score: _ascendingScore(windSpeedMax, 10, 15, 20, 25),
      ));
    } else if (windSpeedMax < 15) {
      checks.add(BeachRating(
        level: RatingLevel.good,
        reason: 'Viento flojo',
        score: _ascendingScore(windSpeedMax, 10, 15, 20, 25),
      ));
    } else if (windSpeedMax < 20) {
      checks.add(BeachRating(
        level: RatingLevel.ok,
        reason: 'Algo de viento, puede afectar a la calidad',
        score: _ascendingScore(windSpeedMax, 10, 15, 20, 25),
      ));
    } else if (windSpeedMax < 25) {
      checks.add(BeachRating(
        level: RatingLevel.bad,
        reason: 'Viento moderado-fuerte, probablemente desordene la ola',
        score: _ascendingScore(windSpeedMax, 10, 15, 20, 25),
      ));
    } else {
      checks.add(BeachRating(
        level: RatingLevel.veryBad,
        reason: 'Viento fuerte, ola muy desordenada',
        score: _ascendingScore(windSpeedMax, 10, 15, 20, 25),
      ));
    }

    return _worstOf(checks);
  }

  /// 4. ¿Hace mucho sol? Nubosidad actual + horas reales de sol hoy.
  BeachRating rateSun() {
    final checks = <BeachRating>[
      if (currentWeatherCode == 45 || currentWeatherCode == 48)
        const BeachRating(level: RatingLevel.veryBad, reason: 'Niebla ahora mismo', score: 0.05),
      if (cloudCoverCurrent < 15)
        BeachRating(
          level: RatingLevel.veryGood,
          reason: 'Cielo despejado, mucho sol',
          score: _ascendingScore(cloudCoverCurrent, 15, 35, 65, 90),
        )
      else if (cloudCoverCurrent < 35)
        BeachRating(
          level: RatingLevel.good,
          reason: 'Cielo mayormente despejado (${cloudCoverCurrent.round()}% nubes)',
          score: _ascendingScore(cloudCoverCurrent, 15, 35, 65, 90),
        )
      else if (cloudCoverCurrent < 65)
        BeachRating(
          level: RatingLevel.ok,
          reason: 'Parcialmente nublado (${cloudCoverCurrent.round()}% nubes)',
          score: _ascendingScore(cloudCoverCurrent, 15, 35, 65, 90),
        )
      else if (cloudCoverCurrent < 90)
        BeachRating(
          level: RatingLevel.bad,
          reason: 'Muy nublado (${cloudCoverCurrent.round()}% nubes), poco sol',
          score: _ascendingScore(cloudCoverCurrent, 15, 35, 65, 90),
        )
      else
        BeachRating(
          level: RatingLevel.veryBad,
          reason: 'Cielo cubierto, prácticamente sin sol',
          score: _ascendingScore(cloudCoverCurrent, 15, 35, 65, 90),
        ),
      if (sunshineDurationHours >= 10)
        BeachRating(
          level: RatingLevel.veryGood,
          reason: 'Muchísimas horas de sol hoy',
          score: _descendingScore(sunshineDurationHours, 10, 8, 5, 2),
        )
      else if (sunshineDurationHours >= 8)
        BeachRating(
          level: RatingLevel.good,
          reason: 'Muchas horas de sol hoy',
          score: _descendingScore(sunshineDurationHours, 10, 8, 5, 2),
        )
      else if (sunshineDurationHours >= 5)
        BeachRating(
          level: RatingLevel.ok,
          reason: 'Sol intermitente hoy',
          score: _descendingScore(sunshineDurationHours, 10, 8, 5, 2),
        )
      else if (sunshineDurationHours >= 2)
        BeachRating(
          level: RatingLevel.bad,
          reason: 'Pocas horas de sol reales hoy',
          score: _descendingScore(sunshineDurationHours, 10, 8, 5, 2),
        )
      else
        BeachRating(
          level: RatingLevel.veryBad,
          reason: 'Casi sin horas de sol hoy',
          score: _descendingScore(sunshineDurationHours, 10, 8, 5, 2),
        ),
      if (uvIndexMax > 8)
        const BeachRating(level: RatingLevel.ok, reason: 'Índice UV muy alto, usa protección solar', score: 0.5),
    ];

    return _worstOf(checks);
  }

  /// 5. ¿Va a llover? Probabilidad y cantidad de lluvia prevista para hoy.
  BeachRating rateRain() {
    final checks = <BeachRating>[
      if (weatherCode >= 95) const BeachRating(level: RatingLevel.veryBad, reason: 'Tormenta prevista', score: 0.05),
      if (precipitationProbabilityMax < 10)
        BeachRating(
          level: RatingLevel.veryGood,
          reason: 'Sin lluvia prevista',
          score: _ascendingScore(precipitationProbabilityMax, 10, 20, 50, 75),
        )
      else if (precipitationProbabilityMax < 20)
        BeachRating(
          level: RatingLevel.good,
          reason: 'Muy baja probabilidad de lluvia (${precipitationProbabilityMax.round()}%)',
          score: _ascendingScore(precipitationProbabilityMax, 10, 20, 50, 75),
        )
      else if (precipitationProbabilityMax < 50)
        BeachRating(
          level: RatingLevel.ok,
          reason: 'Posibilidad de algún chubasco',
          score: _ascendingScore(precipitationProbabilityMax, 10, 20, 50, 75),
        )
      else if (precipitationProbabilityMax < 75)
        BeachRating(
          level: RatingLevel.bad,
          reason: 'Alta probabilidad de lluvia',
          score: _ascendingScore(precipitationProbabilityMax, 10, 20, 50, 75),
        )
      else
        BeachRating(
          level: RatingLevel.veryBad,
          reason: 'Probabilidad muy alta de lluvia',
          score: _ascendingScore(precipitationProbabilityMax, 10, 20, 50, 75),
        ),
      if (precipitationSumToday >= 10)
        BeachRating(
          level: RatingLevel.veryBad,
          reason: 'Se esperan ${precipitationSumToday.toStringAsFixed(1)} mm de lluvia',
          score: _ascendingScore(precipitationSumToday, 0.1, 0.5, 3, 10),
        )
      else if (precipitationSumToday > 3)
        BeachRating(
          level: RatingLevel.bad,
          reason: 'Se esperan ${precipitationSumToday.toStringAsFixed(1)} mm de lluvia',
          score: _ascendingScore(precipitationSumToday, 0.1, 0.5, 3, 10),
        )
      else if (precipitationSumToday > 0.5)
        BeachRating(
          level: RatingLevel.ok,
          reason: 'Se esperan ${precipitationSumToday.toStringAsFixed(1)} mm de lluvia',
          score: _ascendingScore(precipitationSumToday, 0.1, 0.5, 3, 10),
        ),
    ];

    return _worstOf(checks);
  }

  BeachRating _worstOf(List<BeachRating> checks) {
    var worst = checks.first;
    for (final check in checks.skip(1)) {
      final isWorseLevel = check.level.index > worst.level.index;
      final isTiedButLowerScore = check.level.index == worst.level.index && check.score < worst.score;
      if (isWorseLevel || isTiedButLowerScore) {
        worst = check;
      }
    }
    return worst;
  }
}
