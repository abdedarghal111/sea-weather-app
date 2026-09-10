import 'dart:async';

/// Motivo por el que una consulta del tiempo no ha dado datos. Cada valor se
/// muestra al usuario con un mensaje distinto: sin esto, un rechazo de la API
/// y una falta de cobertura acaban en el mismo "no se pudo obtener el tiempo".
enum WeatherErrorKind {
  network,
  timeout,
  rateLimited,
  badRequest,
  serverError,
  malformedResponse,
}

class WeatherApiException implements Exception {
  final WeatherErrorKind kind;

  /// Texto listo para pintar en pantalla.
  final String message;

  /// Datos crudos de la respuesta, solo para depurar.
  final int? statusCode;
  final String? reason;

  const WeatherApiException(
    this.kind,
    this.message, {
    this.statusCode,
    this.reason,
  });

  /// Si volver a intentarlo tiene alguna posibilidad de funcionar. Una
  /// coordenada inválida no la tiene; un 5xx, un corte de red o un límite de
  /// peticiones simultáneas, sí.
  bool get isRetryable =>
      kind == WeatherErrorKind.network ||
      kind == WeatherErrorKind.timeout ||
      kind == WeatherErrorKind.serverError ||
      kind == WeatherErrorKind.rateLimited;

  @override
  String toString() => 'WeatherApiException(${kind.name}, status: $statusCode, reason: $reason)';
}

/// Traducción de los `reason` que devuelve Open-Meteo en sus respuestas de
/// error. Se comparan como subcadenas en minúsculas porque el texto de la API
/// incluye el valor recibido ("Given: 999.0") y a veces lo reporta mal, así
/// que no sirve como clave exacta.
const _reasonTranslations = <(String, WeatherErrorKind, String)>[
  (
    'latitude must be in range',
    WeatherErrorKind.badRequest,
    'Las coordenadas de esta zona no son válidas.',
  ),
  (
    'longitude must be in range',
    WeatherErrorKind.badRequest,
    'Las coordenadas de esta zona no son válidas.',
  ),
  (
    'forecast days is invalid',
    WeatherErrorKind.badRequest,
    'El rango de días solicitado no es válido.',
  ),
  (
    'past days is invalid',
    WeatherErrorKind.badRequest,
    'El rango de días solicitado no es válido.',
  ),
  (
    'timezone',
    WeatherErrorKind.badRequest,
    'No se pudo determinar la zona horaria de este punto.',
  ),
  (
    'minutely api request limit',
    WeatherErrorKind.rateLimited,
    'Demasiadas consultas seguidas. Espera un minuto y reintenta.',
  ),
  (
    'hourly api request limit',
    WeatherErrorKind.rateLimited,
    'Se ha alcanzado el límite de consultas de esta hora.',
  ),
  (
    'daily api request limit',
    WeatherErrorKind.rateLimited,
    'Se ha alcanzado el límite de consultas de hoy.',
  ),
  (
    'api request limit',
    WeatherErrorKind.rateLimited,
    'Se ha alcanzado el límite de consultas del servicio.',
  ),
  (
    'cannot initialize',
    WeatherErrorKind.badRequest,
    'La consulta al servicio del tiempo no es válida.',
  ),
  (
    'is invalid',
    WeatherErrorKind.badRequest,
    'La consulta al servicio del tiempo no es válida.',
  ),
];

/// Mensaje por defecto según el código HTTP, para cuando el `reason` no
/// coincide con nada conocido o no viene.
(WeatherErrorKind, String) _fromStatusCode(int statusCode) {
  if (statusCode == 429) {
    return (
      WeatherErrorKind.rateLimited,
      'Demasiadas consultas seguidas. Espera un momento y reintenta.',
    );
  }
  if (statusCode >= 500) {
    return (
      WeatherErrorKind.serverError,
      'El servicio del tiempo no responde ahora mismo.',
    );
  }
  if (statusCode >= 400) {
    return (
      WeatherErrorKind.badRequest,
      'El servicio del tiempo ha rechazado la consulta de esta zona.',
    );
  }
  return (
    WeatherErrorKind.malformedResponse,
    'El servicio del tiempo ha respondido de forma inesperada.',
  );
}

/// Construye la excepción de una respuesta no satisfactoria: primero busca el
/// `reason` en la tabla y, si no está, cae al mensaje del código HTTP.
WeatherApiException translateApiError(int statusCode, String? reason) {
  if (reason != null) {
    final needle = reason.toLowerCase();
    for (final (pattern, kind, message) in _reasonTranslations) {
      if (needle.contains(pattern)) {
        return WeatherApiException(kind, message, statusCode: statusCode, reason: reason);
      }
    }
  }
  final (kind, message) = _fromStatusCode(statusCode);
  return WeatherApiException(kind, message, statusCode: statusCode, reason: reason);
}

/// Mensaje para cualquier fallo antes de tener respuesta: DNS, socket caído,
/// TLS, timeout.
WeatherApiException translateTransportError(Object error) {
  if (error is TimeoutException) {
    return const WeatherApiException(
      WeatherErrorKind.timeout,
      'El servicio del tiempo ha tardado demasiado en responder.',
    );
  }
  return const WeatherApiException(
    WeatherErrorKind.network,
    'Sin conexión con el servicio del tiempo.',
  );
}
