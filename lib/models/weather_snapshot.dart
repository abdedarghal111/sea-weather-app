// Condiciones de un instante y las valoraciones (agua clara, playa
// removida, surf, sol y lluvia) que se derivan de ellas.

/// Nivel de una valoración, de mejor a peor. El índice ordena de menos a más
/// grave (ver [WeatherSnapshot._worstOf]).
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

  /// Posición continua en la escala, de 0 ("muy malo") a 1 ("muy bueno"),
  /// para situar el marcador del termómetro de forma proporcional al valor
  /// real y no solo por el nivel en el que cae.
  final double score;

  const Rating({required this.level, required this.reason, required this.score});
}

/// Puntúa un valor donde menos es mejor (viento, oleaje, lluvia): reparte la
/// escala en cinco tramos de 0.2 e interpola dentro del tramo.
///
/// Los umbrales se comparan con `<` estricto, igual que los del nivel, para
/// que nivel y score cambien de tramo a la vez.
double _lowerIsBetterScore(double value, double t1, double t2, double t3, double t4) {
  if (value < t1) return 0.9;
  if (value < t2) return 0.6 + 0.2 * (1 - (value - t1) / (t2 - t1));
  if (value < t3) return 0.4 + 0.2 * (1 - (value - t2) / (t3 - t2));
  if (value < t4) return 0.2 + 0.2 * (1 - (value - t3) / (t4 - t3));
  return 0.1;
}

/// Igual que [_lowerIsBetterScore] pero donde más es mejor (horas de sol,
/// periodo de swell): los umbrales van decreciendo.
double _higherIsBetterScore(double value, double t1, double t2, double t3, double t4) {
  if (value >= t1) return 0.9;
  if (value >= t2) return 0.6 + 0.2 * (1 - (t1 - value) / (t1 - t2));
  if (value >= t3) return 0.4 + 0.2 * (1 - (t2 - value) / (t2 - t3));
  if (value >= t4) return 0.2 + 0.2 * (1 - (t3 - value) / (t3 - t4));
  return 0.1;
}

/// Tramo de una escala de valoración: nivel y motivo que se muestran para
/// los valores que caen dentro. En [reason], `{}` se sustituye por el valor
/// ya formateado.
///
/// [limit] es el límite superior exclusivo donde menos es mejor, y el
/// inferior inclusivo donde más es mejor. El último tramo recoge el resto,
/// con el infinito que corresponda.
class _Band {
  final double limit;
  final RatingLevel level;
  final String reason;

  const _Band(this.limit, this.level, this.reason);

  Rating _rating(String formatted, double score) => Rating(
        level: level,
        reason: reason.replaceFirst('{}', formatted),
        score: score,
      );
}

/// Valora [value] sobre una escala de cinco tramos donde menos es mejor,
/// ordenados del mejor al peor. Los mismos límites alimentan el nivel y el
/// score, así que no pueden desalinearse.
Rating _rateLowerIsBetter(double value, String formatted, List<_Band> bands) {
  final score = _lowerIsBetterScore(
      value, bands[0].limit, bands[1].limit, bands[2].limit, bands[3].limit);
  return bands.firstWhere((band) => value < band.limit)._rating(formatted, score);
}

/// Igual que [_rateLowerIsBetter] pero donde más es mejor: los límites son
/// inferiores, inclusivos y van decreciendo.
Rating _rateHigherIsBetter(double value, String formatted, List<_Band> bands) {
  final score = _higherIsBetterScore(
      value, bands[0].limit, bands[1].limit, bands[2].limit, bands[3].limit);
  return bands.firstWhere((band) => value >= band.limit)._rating(formatted, score);
}

/// Tramo de la escala de tamaño de ola para surf, la única no monótona: la
/// calidad sube hasta 1.5 m y baja a partir de ahí, así que cada tramo lleva
/// su propio recorrido de score en vez de deducirlo del nivel.
class _SurfBand {
  /// Límite superior del tramo, inclusivo si [inclusive]. El tramo empieza
  /// donde acabó el anterior (el primero, en 0 m).
  final double limit;
  final bool inclusive;
  final RatingLevel level;
  final String reason;

  /// Score en cada extremo del tramo; dentro se interpola linealmente.
  final double scoreAtStart;
  final double scoreAtLimit;

  const _SurfBand(
    this.limit,
    this.level,
    this.reason, {
    required this.scoreAtStart,
    required this.scoreAtLimit,
    this.inclusive = false,
  });

  bool contains(double value) => inclusive ? value <= limit : value < limit;

  Rating _ratingAt(double value, double start, String formatted) {
    final span = limit - start;
    final progress = span.isFinite ? ((value - start) / span).clamp(0.0, 1.0) : 0.0;
    return Rating(
      level: level,
      reason: reason.replaceFirst('{}', formatted),
      score: scoreAtStart + (scoreAtLimit - scoreAtStart) * progress,
    );
  }
}

/// Escala de tamaño de ola para surf hasta el temporal de [_hugeSwellBand].
const _swellSizeBands = [
  _SurfBand(0.3, RatingLevel.veryBad, 'Prácticamente sin olas ({} m) para surfear',
      scoreAtStart: 0.0, scoreAtLimit: 0.2),
  _SurfBand(0.5, RatingLevel.bad, 'Olas muy pequeñas ({} m) para surfear',
      scoreAtStart: 0.2, scoreAtLimit: 0.4),
  _SurfBand(0.8, RatingLevel.fair, 'Olas pequeñas ({} m), surf flojo',
      scoreAtStart: 0.4, scoreAtLimit: 0.6),
  _SurfBand(1.0, RatingLevel.good, 'Buen tamaño de ola ({} m) para surfear',
      scoreAtStart: 0.6, scoreAtLimit: 0.8, inclusive: true),
  // El tramo excelente va partido en dos: el score sube hasta 1.5 m y
  // vuelve a bajar, con el mismo nivel a ambos lados.
  _SurfBand(1.5, RatingLevel.veryGood, 'Tamaño de ola excelente ({} m) para surfear',
      scoreAtStart: 0.8, scoreAtLimit: 1.0, inclusive: true),
  _SurfBand(2.0, RatingLevel.veryGood, 'Tamaño de ola excelente ({} m) para surfear',
      scoreAtStart: 1.0, scoreAtLimit: 0.8, inclusive: true),
  _SurfBand(3.0, RatingLevel.good, 'Olas grandes ({} m), para surfistas expertos',
      scoreAtStart: 0.8, scoreAtLimit: 0.6, inclusive: true),
  _SurfBand(4.5, RatingLevel.fair, 'Olas muy grandes y descontroladas ({} m)',
      scoreAtStart: 0.6, scoreAtLimit: 0.4, inclusive: true),
  _SurfBand(6.0, RatingLevel.bad, 'Oleaje de fondo enorme ({} m), peligroso',
      scoreAtStart: 0.4, scoreAtLimit: 0.2, inclusive: true),
];

/// Por encima de 6 m no se distinguen grados: todo es impracticable.
const _hugeSwellBand = _SurfBand(
  double.infinity,
  RatingLevel.veryBad,
  'Oleaje de fondo de temporal ({} m), muy peligroso',
  scoreAtStart: 0.1,
  scoreAtLimit: 0.1,
  inclusive: true,
);

Rating _rateSwellSize(double swell) {
  final formatted = swell.toStringAsFixed(1);
  var start = 0.0;
  for (final band in _swellSizeBands) {
    if (band.contains(swell)) return band._ratingAt(swell, start, formatted);
    start = band.limit;
  }
  return _hugeSwellBand._ratingAt(swell, start, formatted);
}

/// Variables meteorológicas y marinas de un instante. El mismo objeto
/// describe el "ahora", cada hora y cada día, así que los nombres no
/// mencionan el agregado salvo cuando el campo mira hacia atrás en el tiempo.
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
  // Código del periodo entero (¿habrá tormenta en algún momento?) frente al
  // del instante (¿hay niebla ahora?): la niebla matinal no debe tumbar la
  // valoración de sol del día entero.
  final int periodWeatherCode;
  final int instantWeatherCode;
  // Los datos marinos faltan cuando el punto no es costero.
  final double? waveHeight;
  // Media cuadrática de la altura de ola de las últimas 48 h; ver
  // [trailingRms].
  final double? rmsWaveHeightPast48h;
  final double? windWaveHeight;
  final double? swellHeight;
  final double? swellPeriod;
  final double? seaTemperature;
  final DateTime? sunrise;
  final DateTime? sunset;
  // Grados de los que sopla el viento (convención meteorológica: 0/360 =
  // del norte).
  final double? windFromDirection;
  // Grados de los que vienen las olas, misma convención que el viento.
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

  /// ¿El agua está clara o turbia? Estimación a partir del viento, el oleaje
  /// local y la lluvia reciente; no es una medición de turbidez.
  Rating rateWaterClarity() {
    // Las rachas no usan tabla de tramos: la escala es parcial (por debajo
    // de 20 km/h no añaden comprobación) y sus umbrales de score no
    // coinciden con los del nivel.
    final gustScore = _lowerIsBetterScore(windGustSpeed, 10, 20, 30, 45);
    final localWave = windWaveHeight ?? waveHeight;

    final checks = <Rating>[
      _rateLowerIsBetter(windSpeed, '${windSpeed.round()}', _clarityWindBands),
      if (windGustSpeed >= 45)
        Rating(
          level: RatingLevel.veryBad,
          reason: 'Rachas muy fuertes remueven el fondo',
          score: gustScore,
        )
      else if (windGustSpeed > 30)
        Rating(
          level: RatingLevel.bad,
          reason: 'Rachas fuertes pueden remover el fondo',
          score: gustScore,
        )
      else if (windGustSpeed > 20)
        Rating(
          level: RatingLevel.fair,
          reason: 'Rachas moderadas pueden levantar sedimento',
          score: gustScore,
        ),
      _rateLowerIsBetter(precipitationPast48h, '', _clarityRecentRainBands),
      if (localWave == null)
        const Rating(
          level: RatingLevel.fair,
          reason: 'Sin datos de oleaje, no se puede asegurar la visibilidad',
          score: 0.5,
        )
      else
        _rateLowerIsBetter(localWave, localWave.toStringAsFixed(1), _clarityWaveBands),
    ];

    return _worstOf(checks);
  }

  static const _clarityWindBands = [
    _Band(15, RatingLevel.veryGood, 'Viento en calma ({} km/h)'),
    _Band(20, RatingLevel.good, 'Viento suave ({} km/h)'),
    _Band(30, RatingLevel.fair, 'Viento moderado ({} km/h)'),
    _Band(40, RatingLevel.bad, 'Viento fuerte ({} km/h) remueve el fondo'),
    _Band(double.infinity, RatingLevel.veryBad, 'Viento muy fuerte ({} km/h)'),
  ];

  static const _clarityRecentRainBands = [
    _Band(1, RatingLevel.veryGood, 'Sin lluvia reciente'),
    _Band(2, RatingLevel.good, 'Muy poca lluvia reciente'),
    _Band(10, RatingLevel.fair, 'Algo de lluvia reciente, puede haber turbidez'),
    _Band(20, RatingLevel.bad, 'Lluvia reciente ha podido enturbiar el agua'),
    _Band(double.infinity, RatingLevel.veryBad,
        'Lluvia reciente abundante, agua probablemente turbia'),
  ];

  static const _clarityWaveBands = [
    _Band(0.3, RatingLevel.veryGood,
        'Mar en calma ({} m), alta confianza en buena visibilidad'),
    _Band(0.5, RatingLevel.good, 'Oleaje suave ({} m), visibilidad probablemente buena'),
    _Band(0.8, RatingLevel.fair, 'Algo de oleaje ({} m), visibilidad no garantizada'),
    _Band(1.2, RatingLevel.bad, 'Oleaje remueve el fondo ({} m), poca visibilidad'),
    _Band(double.infinity, RatingLevel.veryBad,
        'Oleaje fuerte ({} m), agua probablemente muy turbia'),
  ];

  /// ¿Estará la playa removida (arena revuelta, escalones)? Mira el viento y
  /// el oleaje sostenidos de los últimos días, no el instante.
  Rating rateShoreDisturbance() {
    final recentWave = rmsWaveHeightPast48h;

    return _worstOf([
      _rateLowerIsBetter(averageWindSpeedPast48h, '${averageWindSpeedPast48h.round()}',
          _shoreWindBands),
      if (recentWave == null)
        const Rating(
          level: RatingLevel.fair,
          reason: 'Sin datos de oleaje de días recientes',
          score: 0.5,
        )
      else
        _rateLowerIsBetter(recentWave, recentWave.toStringAsFixed(1), _shoreWaveBands),
    ]);
  }

  static const _shoreWindBands = [
    _Band(15, RatingLevel.veryGood, 'Viento en calma los últimos días ({} km/h)'),
    _Band(20, RatingLevel.good, 'Viento suave los últimos días ({} km/h)'),
    _Band(30, RatingLevel.fair, 'Viento sostenido moderado ({} km/h)'),
    _Band(40, RatingLevel.bad, 'Viento fuerte varios días seguidos ({} km/h)'),
    _Band(double.infinity, RatingLevel.veryBad,
        'Viento muy fuerte varios días seguidos ({} km/h)'),
  ];

  // Umbrales más bajos que los del oleaje instantáneo: al ser una media
  // cuadrática de 48 h, un valor moderado implica horas mucho peores.
  static const _shoreWaveBands = [
    _Band(0.3, RatingLevel.veryGood, 'Oleaje en calma en días recientes ({} m)'),
    _Band(0.5, RatingLevel.good, 'Oleaje suave en días recientes ({} m)'),
    _Band(0.8, RatingLevel.fair, 'Oleaje moderado en días recientes ({} m)'),
    _Band(1.2, RatingLevel.bad,
        'Oleaje fuerte en días recientes ({} m), puede haber escalones'),
    _Band(double.infinity, RatingLevel.veryBad,
        'Oleaje muy fuerte en días recientes ({} m)'),
  ];

  /// ¿Se puede hacer surf? Tamaño y periodo del oleaje de fondo. Sin saber
  /// la orientación de la playa no se distingue offshore de onshore: solo se
  /// penaliza el viento fuerte.
  Rating rateSurf() {
    final swell = swellHeight;
    final period = swellPeriod;

    return _worstOf([
      if (swell == null)
        const Rating(
          level: RatingLevel.fair,
          reason: 'Sin datos de oleaje de fondo para valorar el surf',
          score: 0.5,
        )
      else
        _rateSwellSize(swell),
      // Sin dato de periodo se omite la comprobación en vez de penalizar.
      if (period != null) _rateHigherIsBetter(period, '', _surfPeriodBands),
      _rateLowerIsBetter(windSpeed, '', _surfWindBands),
    ]);
  }

  static const _surfPeriodBands = [
    _Band(12, RatingLevel.veryGood, 'Swell largo y limpio'),
    _Band(10, RatingLevel.good, 'Buen periodo de swell'),
    _Band(8, RatingLevel.fair, 'Swell de calidad media'),
    _Band(6, RatingLevel.bad, 'Oleaje corto, bastante desordenado'),
    _Band(double.negativeInfinity, RatingLevel.veryBad, 'Oleaje muy corto y desordenado'),
  ];

  // Más exigente que la escala de viento del resto: un viento que aún no
  // enturbia el agua ya desordena la ola.
  static const _surfWindBands = [
    _Band(10, RatingLevel.veryGood, 'Viento en calma, favorable para el surf'),
    _Band(15, RatingLevel.good, 'Viento flojo'),
    _Band(20, RatingLevel.fair, 'Algo de viento, puede afectar a la calidad'),
    _Band(25, RatingLevel.bad, 'Viento moderado-fuerte, probablemente desordene la ola'),
    _Band(double.infinity, RatingLevel.veryBad, 'Viento fuerte, ola muy desordenada'),
  ];

  /// ¿Hace sol? Nubosidad del instante y horas de sol reales del día.
  Rating rateSun() {
    return _worstOf([
      if (instantWeatherCode == 45 || instantWeatherCode == 48)
        const Rating(level: RatingLevel.veryBad, reason: 'Niebla ahora mismo', score: 0.05),
      _rateLowerIsBetter(cloudCover, '${cloudCover.round()}', _sunCloudBands),
      _rateHigherIsBetter(sunshineHours, '', _sunshineBands),
      if (uvIndex > 8)
        const Rating(
            level: RatingLevel.fair,
            reason: 'Índice UV muy alto, usa protección solar',
            score: 0.5),
    ]);
  }

  static const _sunCloudBands = [
    _Band(15, RatingLevel.veryGood, 'Cielo despejado, mucho sol'),
    _Band(35, RatingLevel.good, 'Cielo mayormente despejado ({}% nubes)'),
    _Band(65, RatingLevel.fair, 'Parcialmente nublado ({}% nubes)'),
    _Band(90, RatingLevel.bad, 'Muy nublado ({}% nubes), poco sol'),
    _Band(double.infinity, RatingLevel.veryBad, 'Cielo cubierto, prácticamente sin sol'),
  ];

  static const _sunshineBands = [
    _Band(10, RatingLevel.veryGood, 'Muchísimas horas de sol hoy'),
    _Band(8, RatingLevel.good, 'Muchas horas de sol hoy'),
    _Band(5, RatingLevel.fair, 'Sol intermitente hoy'),
    _Band(2, RatingLevel.bad, 'Pocas horas de sol reales hoy'),
    _Band(double.negativeInfinity, RatingLevel.veryBad, 'Casi sin horas de sol hoy'),
  ];

  /// ¿Va a llover? Probabilidad y cantidad de lluvia previstas.
  Rating rateRain() {
    // Escala parcial, como las rachas de [rateWaterClarity]: por debajo de
    // 0.5 mm no añade comprobación.
    final expectedRain = 'Se esperan ${precipitationTotal.toStringAsFixed(1)} mm de lluvia';
    final rainTotalScore = _lowerIsBetterScore(precipitationTotal, 0.1, 0.5, 3, 10);

    return _worstOf([
      if (periodWeatherCode >= 95)
        const Rating(level: RatingLevel.veryBad, reason: 'Tormenta prevista', score: 0.05),
      _rateLowerIsBetter(
          precipitationProbability, '${precipitationProbability.round()}', _rainChanceBands),
      if (precipitationTotal >= 10)
        Rating(level: RatingLevel.veryBad, reason: expectedRain, score: rainTotalScore)
      else if (precipitationTotal > 3)
        Rating(level: RatingLevel.bad, reason: expectedRain, score: rainTotalScore)
      else if (precipitationTotal > 0.5)
        Rating(level: RatingLevel.fair, reason: expectedRain, score: rainTotalScore),
    ]);
  }

  static const _rainChanceBands = [
    _Band(10, RatingLevel.veryGood, 'Sin lluvia prevista'),
    _Band(20, RatingLevel.good, 'Muy baja probabilidad de lluvia ({}%)'),
    _Band(50, RatingLevel.fair, 'Posibilidad de algún chubasco'),
    _Band(75, RatingLevel.bad, 'Alta probabilidad de lluvia'),
    _Band(double.infinity, RatingLevel.veryBad, 'Probabilidad muy alta de lluvia'),
  ];

  /// La peor comprobación; a igualdad de nivel, la de menor score.
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
