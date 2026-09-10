import 'dart:async';

/// Motivo por el que una consulta a Open-Meteo (previsión o buscador de
/// localidades) no ha dado datos. Cada valor se muestra al usuario con un
/// mensaje distinto: sin esto, un rechazo de la API y una falta de cobertura
/// acaban en el mismo "no se pudo obtener el tiempo".
enum ApiErrorKind {
  network,
  timeout,
  rateLimited,
  badRequest,
  serverError,
  malformedResponse,
}

class ApiException implements Exception {
  final ApiErrorKind kind;

  /// Texto listo para pintar en pantalla.
  final String message;

  /// Datos crudos de la respuesta, solo para depurar.
  final int? statusCode;
  final String? reason;

  const ApiException(
    this.kind,
    this.message, {
    this.statusCode,
    this.reason,
  });

  /// Si volver a intentarlo tiene alguna posibilidad de funcionar. Una
  /// coordenada inválida no la tiene; un 5xx, un corte de red o un límite de
  /// peticiones simultáneas, sí.
  bool get isRetryable =>
      kind == ApiErrorKind.network ||
      kind == ApiErrorKind.timeout ||
      kind == ApiErrorKind.serverError ||
      kind == ApiErrorKind.rateLimited;

  @override
  String toString() => 'ApiException(${kind.name}, status: $statusCode, reason: $reason)';
}

/// Traducción de los `reason` que devuelve Open-Meteo en sus respuestas de
/// error. Se comparan como subcadenas en minúsculas porque el texto de la API
/// incluye el valor recibido ("Given: 999.0") y a veces lo reporta mal, así
/// que no sirve como clave exacta.
const _reasonTranslations = <(String, ApiErrorKind, String)>[
  (
    'latitude must be in range',
    ApiErrorKind.badRequest,
    'Las coordenadas de esta localidad no son válidas.',
  ),
  (
    'longitude must be in range',
    ApiErrorKind.badRequest,
    'Las coordenadas de esta localidad no son válidas.',
  ),
  (
    'forecast days is invalid',
    ApiErrorKind.badRequest,
    'El rango de días solicitado no es válido.',
  ),
  (
    'past days is invalid',
    ApiErrorKind.badRequest,
    'El rango de días solicitado no es válido.',
  ),
  (
    'timezone',
    ApiErrorKind.badRequest,
    'No se pudo determinar la zona horaria de este punto.',
  ),
  (
    'minutely api request limit',
    ApiErrorKind.rateLimited,
    'Demasiadas consultas seguidas. Espera un minuto y reintenta.',
  ),
  (
    'hourly api request limit',
    ApiErrorKind.rateLimited,
    'Se ha alcanzado el límite de consultas de esta hora.',
  ),
  (
    'daily api request limit',
    ApiErrorKind.rateLimited,
    'Se ha alcanzado el límite de consultas de hoy.',
  ),
  (
    'api request limit',
    ApiErrorKind.rateLimited,
    'Se ha alcanzado el límite de consultas del servicio.',
  ),
  (
    'cannot initialize',
    ApiErrorKind.badRequest,
    'La consulta al servicio del tiempo no es válida.',
  ),
  (
    'is invalid',
    ApiErrorKind.badRequest,
    'La consulta al servicio del tiempo no es válida.',
  ),
];

/// Mensaje por defecto según el código HTTP, para cuando el `reason` no
/// coincide con nada conocido o no viene.
(ApiErrorKind, String) _fromStatusCode(int statusCode) {
  if (statusCode == 429) {
    return (
      ApiErrorKind.rateLimited,
      'Demasiadas consultas seguidas. Espera un momento y reintenta.',
    );
  }
  if (statusCode >= 500) {
    return (
      ApiErrorKind.serverError,
      'El servicio del tiempo no responde ahora mismo.',
    );
  }
  if (statusCode >= 400) {
    return (
      ApiErrorKind.badRequest,
      'El servicio del tiempo ha rechazado la consulta de esta localidad.',
    );
  }
  return (
    ApiErrorKind.malformedResponse,
    'El servicio del tiempo ha respondido de forma inesperada.',
  );
}

/// Construye la excepción de una respuesta no satisfactoria: primero busca el
/// `reason` en la tabla y, si no está, cae al mensaje del código HTTP.
ApiException translateApiError(int statusCode, String? reason) {
  if (reason != null) {
    final needle = reason.toLowerCase();
    for (final (pattern, kind, message) in _reasonTranslations) {
      if (needle.contains(pattern)) {
        return ApiException(kind, message, statusCode: statusCode, reason: reason);
      }
    }
  }
  final (kind, message) = _fromStatusCode(statusCode);
  return ApiException(kind, message, statusCode: statusCode, reason: reason);
}

/// Mensaje para cualquier fallo antes de tener respuesta: DNS, socket caído,
/// TLS, timeout.
ApiException translateTransportError(Object error) {
  if (error is TimeoutException) {
    return const ApiException(
      ApiErrorKind.timeout,
      'El servicio del tiempo ha tardado demasiado en responder.',
    );
  }
  return const ApiException(
    ApiErrorKind.network,
    'Sin conexión con el servicio del tiempo.',
  );
}
