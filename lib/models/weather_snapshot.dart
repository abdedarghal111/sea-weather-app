/// Nivel de una valoración, de mejor a peor. El índice se usa para comparar
/// "cuál es peor" entre varias comprobaciones (ver [WeatherSnapshot._worstOf]).
enum RatingLevel { veryGood, good, fair, bad, veryBad }

extension RatingLevelLabel on RatingLevel {
  String get label => switch (this) {
        RatingLevel.veryGood => 'Muy bueno',
        RatingLevel.good => 'Bueno',
        RatingLevel.fair => 'Regular',
        RatingLevel.bad => 'Malo',
        RatingLevel.veryBad => 'Muy malo',
      };
}

extension RainTitle on RatingLevel {
  String get rainTitle => switch (this) {
        RatingLevel.veryGood => 'Sin lluvia',
        RatingLevel.good => 'Casi sin lluvia',
        RatingLevel.fair => 'Puede llover',
        RatingLevel.bad => 'Va a llover',
        RatingLevel.veryBad => 'Lluvia segura',
      };
}

extension WaterClarityTitle on RatingLevel {
  String get waterClarityTitle => switch (this) {
        RatingLevel.veryGood => 'Agua cristalina',
        RatingLevel.good => 'Agua clara',
        RatingLevel.fair => 'Agua algo opaca',
        RatingLevel.bad => 'Agua opaca',
        RatingLevel.veryBad => 'Agua muy opaca',
      };
}

extension ShoreDisturbanceTitle on RatingLevel {
  String get shoreDisturbanceTitle => switch (this) {
        RatingLevel.veryGood => 'Playa muy tranquila',
        RatingLevel.good => 'Playa tranquila',
        RatingLevel.fair => 'Playa algo removida',
        RatingLevel.bad => 'Playa removida',
        RatingLevel.veryBad => 'Playa muy removida',
      };

  String get shoreDisturbanceShortLabel => switch (this) {
        RatingLevel.veryGood => 'Tranquila',
        RatingLevel.good => 'Tranquila',
        RatingLevel.fair => 'Algo removida',
        RatingLevel.bad => 'Removida',
        RatingLevel.veryBad => 'Muy removida',
      };
}

const rainSeriesTitle = 'Lluvia prevista';
const waterClaritySeriesTitle = 'Agua clara u opaca';
const shoreDisturbanceSeriesTitle = 'Playa tranquila o removida';

class Rating {
  final RatingLevel level;
  final String reason;

  /// Posición continua dentro de la escala, de 0 (extremo "muy malo") a 1
  /// (extremo "muy bueno"). Sirve para colocar el marcador de [RatingGauge]
  /// de forma proporcional al valor real, no solo saltando entre 5 puntos.
  final double score;

  const Rating({required this.level, required this.reason, required this.score});
}

/// Puntúa un valor donde MENOS es mejor (ej. viento, oleaje, lluvia),
/// repartiendo la escala en 5 tramos de 0.2 según los mismos umbrales que
/// determinan el nivel cualitativo, e interpolando dentro del tramo.
///
/// Usa `<` estricto (no `<=`) para que coincida exactamente con las
/// comparaciones de los niveles cualitativos (`value < t1` => veryGood,
/// etc.): así, justo en el valor de un umbral, nivel y score cambian de
/// tramo a la vez en vez de que el score se quede "pegado" al tramo mejor.
double _lowerIsBetterScore(double value, double t1, double t2, double t3, double t4) {
  if (value < t1) return 0.9;
  if (value < t2) return 0.6 + 0.2 * (1 - (value - t1) / (t2 - t1));
  if (value < t3) return 0.4 + 0.2 * (1 - (value - t2) / (t3 - t2));
  if (value < t4) return 0.2 + 0.2 * (1 - (value - t3) / (t4 - t3));
  return 0.1;
}

/// Igual que [_lowerIsBetterScore] pero para valores donde MÁS es mejor (ej.
/// horas de sol, periodo de swell). t1 > t2 > t3 > t4.
double _higherIsBetterScore(double value, double t1, double t2, double t3, double t4) {
  if (value >= t1) return 0.9;
  if (value >= t2) return 0.6 + 0.2 * (1 - (t1 - value) / (t1 - t2));
  if (value >= t3) return 0.4 + 0.2 * (1 - (t2 - value) / (t2 - t3));
  if (value >= t4) return 0.2 + 0.2 * (1 - (t3 - value) / (t3 - t4));
  return 0.1;
}

/// Las variables meteorológicas y marinas de un instante concreto. El mismo
/// objeto describe el "ahora", cada hora de la previsión y cada día: por eso
/// ningún campo lleva en el nombre el agregado (máximo, media) ni el periodo,
/// salvo los que de verdad miran hacia atrás en el tiempo.
class WeatherSnapshot {
  final double airTemperature;
  final double apparentTemperature;
  final double precipitationProbability;
  final double precipitationTotal;
  final double precipitationPast48h;
  final double windSpeed;
  final double windGustSpeed;
  final double averageWindSpeedPast48h;
  final double uvIndex;
  final double cloudCover;
  final double sunshineHours;
  // Código del periodo entero (para saber si va a haber tormenta en algún
  // momento) vs. código del instante (para saber si hay niebla justo ahora):
  // la niebla matinal en la costa no debe tumbar la valoración de sol de todo
  // el día.
  final int periodWeatherCode;
  final int instantWeatherCode;
  // Solo los datos marinos pueden faltar de verdad: la Marine API devuelve
  // null cuando el punto no es costero.
  final double? waveHeight;
  // Altura de ola en media cuadrática de las últimas 48 h: el resumen de la
  // energía que ha recibido la playa en esos dos días (ver [trailingRms]).
  final double? rmsWaveHeightPast48h;
  final double? windWaveHeight;
  final double? swellHeight;
  final double? swellPeriod;
  final double? seaTemperature;
  final DateTime? sunrise;
  final DateTime? sunset;
  // Grados de los que sopla el viento (convención meteorológica: 0/360 =
  // viento del norte). Solo se rellena en los puntos horarios; de ahí sale
  // la flecha de WindDirectionChart, que la voltea 180° para mostrar hacia
  // dónde se dirige el viento en vez de de dónde viene.
  final double? windFromDirection;
  // Grados de los que vienen las olas, misma convención que el viento (la
  // Marine API también reporta el origen, no el destino).
  final double? waveFromDirection;
  final DateTime fetchedAt;

  const WeatherSnapshot({
    required this.airTemperature,
    required this.apparentTemperature,
    required this.precipitationProbability,
    required this.precipitationTotal,
    required this.precipitationPast48h,
    required this.windSpeed,
    required this.windGustSpeed,
    required this.averageWindSpeedPast48h,
    required this.uvIndex,
    required this.cloudCover,
    required this.sunshineHours,
    required this.periodWeatherCode,
    required this.instantWeatherCode,
    this.waveHeight,
    this.rmsWaveHeightPast48h,
    this.windWaveHeight,
    this.swellHeight,
    this.swellPeriod,
    this.seaTemperature,
    this.sunrise,
    this.sunset,
    this.windFromDirection,
    this.waveFromDirection,
    required this.fetchedAt,
  });

  Map<String, dynamic> toJson() => {
        'airTemperature': airTemperature,
        'apparentTemperature': apparentTemperature,
        'precipitationProbability': precipitationProbability,
        'precipitationTotal': precipitationTotal,
        'precipitationPast48h': precipitationPast48h,
        'windSpeed': windSpeed,
        'windGustSpeed': windGustSpeed,
        'averageWindSpeedPast48h': averageWindSpeedPast48h,
        'uvIndex': uvIndex,
        'cloudCover': cloudCover,
        'sunshineHours': sunshineHours,
        'periodWeatherCode': periodWeatherCode,
        'instantWeatherCode': instantWeatherCode,
        'waveHeight': waveHeight,
        'rmsWaveHeightPast48h': rmsWaveHeightPast48h,
        'windWaveHeight': windWaveHeight,
        'swellHeight': swellHeight,
        'swellPeriod': swellPeriod,
        'seaTemperature': seaTemperature,
        'sunrise': sunrise?.toIso8601String(),
        'sunset': sunset?.toIso8601String(),
        'windFromDirection': windFromDirection,
        'waveFromDirection': waveFromDirection,
        'fetchedAt': fetchedAt.toIso8601String(),
      };

  factory WeatherSnapshot.fromJson(Map<String, dynamic> json) => WeatherSnapshot(
        airTemperature: (json['airTemperature'] as num).toDouble(),
        apparentTemperature: (json['apparentTemperature'] as num).toDouble(),
        precipitationProbability: (json['precipitationProbability'] as num).toDouble(),
        precipitationTotal: (json['precipitationTotal'] as num).toDouble(),
        precipitationPast48h: (json['precipitationPast48h'] as num).toDouble(),
        windSpeed: (json['windSpeed'] as num).toDouble(),
        windGustSpeed: (json['windGustSpeed'] as num).toDouble(),
        averageWindSpeedPast48h: (json['averageWindSpeedPast48h'] as num).toDouble(),
        uvIndex: (json['uvIndex'] as num).toDouble(),
        cloudCover: (json['cloudCover'] as num).toDouble(),
        sunshineHours: (json['sunshineHours'] as num).toDouble(),
        periodWeatherCode: json['periodWeatherCode'] as int,
        instantWeatherCode: json['instantWeatherCode'] as int,
        waveHeight: (json['waveHeight'] as num?)?.toDouble(),
        rmsWaveHeightPast48h: (json['rmsWaveHeightPast48h'] as num?)?.toDouble(),
        windWaveHeight: (json['windWaveHeight'] as num?)?.toDouble(),
        swellHeight: (json['swellHeight'] as num?)?.toDouble(),
        swellPeriod: (json['swellPeriod'] as num?)?.toDouble(),
        seaTemperature: (json['seaTemperature'] as num?)?.toDouble(),
        sunrise: (json['sunrise'] as String?) != null ? DateTime.parse(json['sunrise'] as String) : null,
        sunset: (json['sunset'] as String?) != null ? DateTime.parse(json['sunset'] as String) : null,
        windFromDirection: (json['windFromDirection'] as num?)?.toDouble(),
        waveFromDirection: (json['waveFromDirection'] as num?)?.toDouble(),
        fetchedAt: DateTime.parse(json['fetchedAt'] as String),
      );

  /// 1. ¿El agua está cristalina o turbia? El viento (medio y rachas) y el
  /// oleaje de viento local remueven sedimento del fondo; la lluvia reciente
  /// también enturbia por escorrentía. Esto es una estimación, no una
  /// medición real de turbidez.
  Rating rateWaterClarity() {
    final checks = <Rating>[
      if (windSpeed < 15)
        Rating(
          level: RatingLevel.veryGood,
          reason: 'Viento en calma (${windSpeed.round()} km/h)',
          score: _lowerIsBetterScore(windSpeed, 15, 20, 30, 40),
        )
      else if (windSpeed < 20)
        Rating(
          level: RatingLevel.good,
          reason: 'Viento suave (${windSpeed.round()} km/h)',
          score: _lowerIsBetterScore(windSpeed, 15, 20, 30, 40),
        )
      else if (windSpeed < 30)
        Rating(
          level: RatingLevel.fair,
          reason: 'Viento moderado (${windSpeed.round()} km/h)',
          score: _lowerIsBetterScore(windSpeed, 15, 20, 30, 40),
        )
      else if (windSpeed < 40)
        Rating(
          level: RatingLevel.bad,
          reason: 'Viento fuerte (${windSpeed.round()} km/h) remueve el fondo',
          score: _lowerIsBetterScore(windSpeed, 15, 20, 30, 40),
        )
      else
        Rating(
          level: RatingLevel.veryBad,
          reason: 'Viento muy fuerte (${windSpeed.round()} km/h)',
          score: _lowerIsBetterScore(windSpeed, 15, 20, 30, 40),
        ),
      if (windGustSpeed >= 45)
        Rating(
          level: RatingLevel.veryBad,
          reason: 'Rachas muy fuertes remueven el fondo',
          score: _lowerIsBetterScore(windGustSpeed, 10, 20, 30, 45),
        )
      else if (windGustSpeed > 30)
        Rating(
          level: RatingLevel.bad,
          reason: 'Rachas fuertes pueden remover el fondo',
          score: _lowerIsBetterScore(windGustSpeed, 10, 20, 30, 45),
        )
      else if (windGustSpeed > 20)
        Rating(
          level: RatingLevel.fair,
          reason: 'Rachas moderadas pueden levantar sedimento',
          score: _lowerIsBetterScore(windGustSpeed, 10, 20, 30, 45),
        ),
      if (precipitationPast48h < 1)
        Rating(
          level: RatingLevel.veryGood,
          reason: 'Sin lluvia reciente',
          score: _lowerIsBetterScore(precipitationPast48h, 1, 2, 10, 20),
        )
      else if (precipitationPast48h < 2)
        Rating(
          level: RatingLevel.good,
          reason: 'Muy poca lluvia reciente',
          score: _lowerIsBetterScore(precipitationPast48h, 1, 2, 10, 20),
        )
      else if (precipitationPast48h < 10)
        Rating(
          level: RatingLevel.fair,
          reason: 'Algo de lluvia reciente, puede haber turbidez',
          score: _lowerIsBetterScore(precipitationPast48h, 1, 2, 10, 20),
        )
      else if (precipitationPast48h < 20)
        Rating(
          level: RatingLevel.bad,
          reason: 'Lluvia reciente ha podido enturbiar el agua',
          score: _lowerIsBetterScore(precipitationPast48h, 1, 2, 10, 20),
        )
      else
        Rating(
          level: RatingLevel.veryBad,
          reason: 'Lluvia reciente abundante, agua probablemente turbia',
          score: _lowerIsBetterScore(precipitationPast48h, 1, 2, 10, 20),
        ),
    ];

    final localWave = windWaveHeight ?? waveHeight;
    if (localWave == null) {
      checks.add(const Rating(
        level: RatingLevel.fair,
        reason: 'Sin datos de oleaje, no se puede asegurar la visibilidad',
        score: 0.5,
      ));
    } else if (localWave < 0.3) {
      checks.add(Rating(
        level: RatingLevel.veryGood,
        reason: 'Mar en calma (${localWave.toStringAsFixed(1)} m), alta confianza en buena visibilidad',
        score: _lowerIsBetterScore(localWave, 0.3, 0.5, 0.8, 1.2),
      ));
    } else if (localWave < 0.5) {
      checks.add(Rating(
        level: RatingLevel.good,
        reason: 'Oleaje suave (${localWave.toStringAsFixed(1)} m), visibilidad probablemente buena',
        score: _lowerIsBetterScore(localWave, 0.3, 0.5, 0.8, 1.2),
      ));
    } else if (localWave < 0.8) {
      checks.add(Rating(
        level: RatingLevel.fair,
        reason: 'Algo de oleaje (${localWave.toStringAsFixed(1)} m), visibilidad no garantizada',
        score: _lowerIsBetterScore(localWave, 0.3, 0.5, 0.8, 1.2),
      ));
    } else if (localWave < 1.2) {
      checks.add(Rating(
        level: RatingLevel.bad,
        reason: 'Oleaje remueve el fondo (${localWave.toStringAsFixed(1)} m), poca visibilidad',
        score: _lowerIsBetterScore(localWave, 0.3, 0.5, 0.8, 1.2),
      ));
    } else {
      checks.add(Rating(
        level: RatingLevel.veryBad,
        reason: 'Oleaje fuerte (${localWave.toStringAsFixed(1)} m), agua probablemente muy turbia',
        score: _lowerIsBetterScore(localWave, 0.3, 0.5, 0.8, 1.2),
      ));
    }

    return _worstOf(checks);
  }

  /// 2. ¿Va a haber playa removida (arena revuelta, escalones)? Viento y
  /// oleaje sostenidos durante los últimos días, no solo ahora mismo.
  Rating rateShoreDisturbance() {
    final checks = <Rating>[
      if (averageWindSpeedPast48h < 15)
        Rating(
          level: RatingLevel.veryGood,
          reason: 'Viento en calma los últimos días (${averageWindSpeedPast48h.round()} km/h)',
          score: _lowerIsBetterScore(averageWindSpeedPast48h, 15, 20, 30, 40),
        )
      else if (averageWindSpeedPast48h < 20)
        Rating(
          level: RatingLevel.good,
          reason: 'Viento suave los últimos días (${averageWindSpeedPast48h.round()} km/h)',
          score: _lowerIsBetterScore(averageWindSpeedPast48h, 15, 20, 30, 40),
        )
      else if (averageWindSpeedPast48h < 30)
        Rating(
          level: RatingLevel.fair,
          reason: 'Viento sostenido moderado (${averageWindSpeedPast48h.round()} km/h)',
          score: _lowerIsBetterScore(averageWindSpeedPast48h, 15, 20, 30, 40),
        )
      else if (averageWindSpeedPast48h < 40)
        Rating(
          level: RatingLevel.bad,
          reason: 'Viento fuerte varios días seguidos (${averageWindSpeedPast48h.round()} km/h)',
          score: _lowerIsBetterScore(averageWindSpeedPast48h, 15, 20, 30, 40),
        )
      else
        Rating(
          level: RatingLevel.veryBad,
          reason: 'Viento muy fuerte varios días seguidos (${averageWindSpeedPast48h.round()} km/h)',
          score: _lowerIsBetterScore(averageWindSpeedPast48h, 15, 20, 30, 40),
        ),
    ];

    // Umbrales más bajos que los del oleaje instantáneo porque este valor es
    // una media cuadrática de 48 h, no un pico: un mar que llega a 1.2 m de
    // media cuadrática durante dos días ha estado rompiendo mucho más fuerte
    // en sus peores horas. Son una primera estimación, pendiente de
    // contrastar con playas reales.
    final recentWave = rmsWaveHeightPast48h;
    if (recentWave == null) {
      checks.add(const Rating(
        level: RatingLevel.fair,
        reason: 'Sin datos de oleaje de días recientes',
        score: 0.5,
      ));
    } else if (recentWave < 0.3) {
      checks.add(Rating(
        level: RatingLevel.veryGood,
        reason: 'Oleaje en calma en días recientes (${recentWave.toStringAsFixed(1)} m)',
        score: _lowerIsBetterScore(recentWave, 0.3, 0.5, 0.8, 1.2),
      ));
    } else if (recentWave < 0.5) {
      checks.add(Rating(
        level: RatingLevel.good,
        reason: 'Oleaje suave en días recientes (${recentWave.toStringAsFixed(1)} m)',
        score: _lowerIsBetterScore(recentWave, 0.3, 0.5, 0.8, 1.2),
      ));
    } else if (recentWave < 0.8) {
      checks.add(Rating(
        level: RatingLevel.fair,
        reason: 'Oleaje moderado en días recientes (${recentWave.toStringAsFixed(1)} m)',
        score: _lowerIsBetterScore(recentWave, 0.3, 0.5, 0.8, 1.2),
      ));
    } else if (recentWave < 1.2) {
      checks.add(Rating(
        level: RatingLevel.bad,
        reason: 'Oleaje fuerte en días recientes (${recentWave.toStringAsFixed(1)} m), puede haber escalones',
        score: _lowerIsBetterScore(recentWave, 0.3, 0.5, 0.8, 1.2),
      ));
    } else {
      checks.add(Rating(
        level: RatingLevel.veryBad,
        reason: 'Oleaje muy fuerte en días recientes (${recentWave.toStringAsFixed(1)} m)',
        score: _lowerIsBetterScore(recentWave, 0.3, 0.5, 0.8, 1.2),
      ));
    }

    return _worstOf(checks);
  }

  /// 3. ¿Se puede hacer surf? Tamaño y periodo del oleaje de fondo (swell);
  /// sin conocer la orientación de la playa no se evalúa offshore/onshore,
  /// solo se penaliza el viento fuerte en general.
  Rating rateSurf() {
    final checks = <Rating>[];

    final swell = swellHeight;
    if (swell == null) {
      checks.add(const Rating(
        level: RatingLevel.fair,
        reason: 'Sin datos de oleaje de fondo para valorar el surf',
        score: 0.5,
      ));
    } else if (swell < 0.3) {
      checks.add(Rating(
        level: RatingLevel.veryBad,
        reason: 'Prácticamente sin olas (${swell.toStringAsFixed(1)} m) para surfear',
        score: 0.2 * (swell / 0.3).clamp(0.0, 1.0),
      ));
    } else if (swell < 0.5) {
      checks.add(Rating(
        level: RatingLevel.bad,
        reason: 'Olas muy pequeñas (${swell.toStringAsFixed(1)} m) para surfear',
        score: 0.2 + 0.2 * ((swell - 0.3) / (0.5 - 0.3)),
      ));
    } else if (swell < 0.8) {
      checks.add(Rating(
        level: RatingLevel.fair,
        reason: 'Olas pequeñas (${swell.toStringAsFixed(1)} m), surf flojo',
        score: 0.4 + 0.2 * ((swell - 0.5) / (0.8 - 0.5)),
      ));
    } else if (swell <= 1.0) {
      checks.add(Rating(
        level: RatingLevel.good,
        reason: 'Buen tamaño de ola (${swell.toStringAsFixed(1)} m) para surfear',
        score: 0.6 + 0.2 * ((swell - 0.8) / (1.0 - 0.8)),
      ));
    } else if (swell <= 2.0) {
      checks.add(Rating(
        level: RatingLevel.veryGood,
        reason: 'Tamaño de ola excelente (${swell.toStringAsFixed(1)} m) para surfear',
        score: 0.8 + 0.2 * (1 - ((swell - 1.0) / (2.0 - 1.0) - 0.5).abs() * 2).clamp(0.0, 1.0),
      ));
    } else if (swell <= 3.0) {
      checks.add(Rating(
        level: RatingLevel.good,
        reason: 'Olas grandes (${swell.toStringAsFixed(1)} m), para surfistas expertos',
        score: 0.6 + 0.2 * (1 - (swell - 2.0) / (3.0 - 2.0)),
      ));
    } else if (swell <= 4.5) {
      checks.add(Rating(
        level: RatingLevel.fair,
        reason: 'Olas muy grandes y descontroladas (${swell.toStringAsFixed(1)} m)',
        score: 0.4 + 0.2 * (1 - (swell - 3.0) / (4.5 - 3.0)),
      ));
    } else if (swell <= 6.0) {
      checks.add(Rating(
        level: RatingLevel.bad,
        reason: 'Oleaje de fondo enorme (${swell.toStringAsFixed(1)} m), peligroso',
        score: 0.2 + 0.2 * (1 - (swell - 4.5) / (6.0 - 4.5)),
      ));
    } else {
      checks.add(Rating(
        level: RatingLevel.veryBad,
        reason: 'Oleaje de fondo de temporal (${swell.toStringAsFixed(1)} m), muy peligroso',
        score: 0.1,
      ));
    }

    final period = swellPeriod;
    if (period != null) {
      if (period < 6) {
        checks.add(Rating(
          level: RatingLevel.veryBad,
          reason: 'Oleaje muy corto y desordenado',
          score: _higherIsBetterScore(period, 12, 10, 8, 6),
        ));
      } else if (period < 8) {
        checks.add(Rating(
          level: RatingLevel.bad,
          reason: 'Oleaje corto, bastante desordenado',
          score: _higherIsBetterScore(period, 12, 10, 8, 6),
        ));
      } else if (period < 10) {
        checks.add(Rating(
          level: RatingLevel.fair,
          reason: 'Swell de calidad media',
          score: _higherIsBetterScore(period, 12, 10, 8, 6),
        ));
      } else if (period < 12) {
        checks.add(Rating(
          level: RatingLevel.good,
          reason: 'Buen periodo de swell',
          score: _higherIsBetterScore(period, 12, 10, 8, 6),
        ));
      } else {
        checks.add(Rating(
          level: RatingLevel.veryGood,
          reason: 'Swell largo y limpio',
          score: _higherIsBetterScore(period, 12, 10, 8, 6),
        ));
      }
    }

    if (windSpeed < 10) {
      checks.add(Rating(
        level: RatingLevel.veryGood,
        reason: 'Viento en calma, favorable para el surf',
        score: _lowerIsBetterScore(windSpeed, 10, 15, 20, 25),
      ));
    } else if (windSpeed < 15) {
      checks.add(Rating(
        level: RatingLevel.good,
        reason: 'Viento flojo',
        score: _lowerIsBetterScore(windSpeed, 10, 15, 20, 25),
      ));
    } else if (windSpeed < 20) {
      checks.add(Rating(
        level: RatingLevel.fair,
        reason: 'Algo de viento, puede afectar a la calidad',
        score: _lowerIsBetterScore(windSpeed, 10, 15, 20, 25),
      ));
    } else if (windSpeed < 25) {
      checks.add(Rating(
        level: RatingLevel.bad,
        reason: 'Viento moderado-fuerte, probablemente desordene la ola',
        score: _lowerIsBetterScore(windSpeed, 10, 15, 20, 25),
      ));
    } else {
      checks.add(Rating(
        level: RatingLevel.veryBad,
        reason: 'Viento fuerte, ola muy desordenada',
        score: _lowerIsBetterScore(windSpeed, 10, 15, 20, 25),
      ));
    }

    return _worstOf(checks);
  }

  /// 4. ¿Hace mucho sol? Nubosidad actual + horas reales de sol hoy.
  Rating rateSun() {
    final checks = <Rating>[
      if (instantWeatherCode == 45 || instantWeatherCode == 48)
        const Rating(level: RatingLevel.veryBad, reason: 'Niebla ahora mismo', score: 0.05),
      if (cloudCover < 15)
        Rating(
          level: RatingLevel.veryGood,
          reason: 'Cielo despejado, mucho sol',
          score: _lowerIsBetterScore(cloudCover, 15, 35, 65, 90),
        )
      else if (cloudCover < 35)
        Rating(
          level: RatingLevel.good,
          reason: 'Cielo mayormente despejado (${cloudCover.round()}% nubes)',
          score: _lowerIsBetterScore(cloudCover, 15, 35, 65, 90),
        )
      else if (cloudCover < 65)
        Rating(
          level: RatingLevel.fair,
          reason: 'Parcialmente nublado (${cloudCover.round()}% nubes)',
          score: _lowerIsBetterScore(cloudCover, 15, 35, 65, 90),
        )
      else if (cloudCover < 90)
        Rating(
          level: RatingLevel.bad,
          reason: 'Muy nublado (${cloudCover.round()}% nubes), poco sol',
          score: _lowerIsBetterScore(cloudCover, 15, 35, 65, 90),
        )
      else
        Rating(
          level: RatingLevel.veryBad,
          reason: 'Cielo cubierto, prácticamente sin sol',
          score: _lowerIsBetterScore(cloudCover, 15, 35, 65, 90),
        ),
      if (sunshineHours >= 10)
        Rating(
          level: RatingLevel.veryGood,
          reason: 'Muchísimas horas de sol hoy',
          score: _higherIsBetterScore(sunshineHours, 10, 8, 5, 2),
        )
      else if (sunshineHours >= 8)
        Rating(
          level: RatingLevel.good,
          reason: 'Muchas horas de sol hoy',
          score: _higherIsBetterScore(sunshineHours, 10, 8, 5, 2),
        )
      else if (sunshineHours >= 5)
        Rating(
          level: RatingLevel.fair,
          reason: 'Sol intermitente hoy',
          score: _higherIsBetterScore(sunshineHours, 10, 8, 5, 2),
        )
      else if (sunshineHours >= 2)
        Rating(
          level: RatingLevel.bad,
          reason: 'Pocas horas de sol reales hoy',
          score: _higherIsBetterScore(sunshineHours, 10, 8, 5, 2),
        )
      else
        Rating(
          level: RatingLevel.veryBad,
          reason: 'Casi sin horas de sol hoy',
          score: _higherIsBetterScore(sunshineHours, 10, 8, 5, 2),
        ),
      if (uvIndex > 8)
        const Rating(level: RatingLevel.fair, reason: 'Índice UV muy alto, usa protección solar', score: 0.5),
    ];

    return _worstOf(checks);
  }

  /// 5. ¿Va a llover? Probabilidad y cantidad de lluvia prevista para hoy.
  Rating rateRain() {
    final checks = <Rating>[
      if (periodWeatherCode >= 95)
        const Rating(level: RatingLevel.veryBad, reason: 'Tormenta prevista', score: 0.05),
      if (precipitationProbability < 10)
        Rating(
          level: RatingLevel.veryGood,
          reason: 'Sin lluvia prevista',
          score: _lowerIsBetterScore(precipitationProbability, 10, 20, 50, 75),
        )
      else if (precipitationProbability < 20)
        Rating(
          level: RatingLevel.good,
          reason: 'Muy baja probabilidad de lluvia (${precipitationProbability.round()}%)',
          score: _lowerIsBetterScore(precipitationProbability, 10, 20, 50, 75),
        )
      else if (precipitationProbability < 50)
        Rating(
          level: RatingLevel.fair,
          reason: 'Posibilidad de algún chubasco',
          score: _lowerIsBetterScore(precipitationProbability, 10, 20, 50, 75),
        )
      else if (precipitationProbability < 75)
        Rating(
          level: RatingLevel.bad,
          reason: 'Alta probabilidad de lluvia',
          score: _lowerIsBetterScore(precipitationProbability, 10, 20, 50, 75),
        )
      else
        Rating(
          level: RatingLevel.veryBad,
          reason: 'Probabilidad muy alta de lluvia',
          score: _lowerIsBetterScore(precipitationProbability, 10, 20, 50, 75),
        ),
      if (precipitationTotal >= 10)
        Rating(
          level: RatingLevel.veryBad,
          reason: 'Se esperan ${precipitationTotal.toStringAsFixed(1)} mm de lluvia',
          score: _lowerIsBetterScore(precipitationTotal, 0.1, 0.5, 3, 10),
        )
      else if (precipitationTotal > 3)
        Rating(
          level: RatingLevel.bad,
          reason: 'Se esperan ${precipitationTotal.toStringAsFixed(1)} mm de lluvia',
          score: _lowerIsBetterScore(precipitationTotal, 0.1, 0.5, 3, 10),
        )
      else if (precipitationTotal > 0.5)
        Rating(
          level: RatingLevel.fair,
          reason: 'Se esperan ${precipitationTotal.toStringAsFixed(1)} mm de lluvia',
          score: _lowerIsBetterScore(precipitationTotal, 0.1, 0.5, 3, 10),
        ),
    ];

    return _worstOf(checks);
  }

  Rating _worstOf(List<Rating> checks) {
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
