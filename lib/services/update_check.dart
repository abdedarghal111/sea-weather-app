import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/app_version.dart';

/// Resultado de mirar si hay una versión nueva publicada.
sealed class UpdateCheck {
  const UpdateCheck();
}

/// La versión instalada es la última publicada (o más nueva, si es un build
/// local por delante de la release).
class UpdateUpToDate extends UpdateCheck {
  const UpdateUpToDate();
}

class UpdateAvailable extends UpdateCheck {
  /// Versión publicada, ya sin la `v` del tag.
  final AppVersion version;

  /// Página de la release en GitHub, con los ficheros de cada plataforma.
  final String releaseUrl;

  const UpdateAvailable(this.version, this.releaseUrl);
}

/// No se pudo saber: sin red, GitHub caído, límite de peticiones alcanzado o
/// respuesta inesperada. No se distingue el motivo porque al usuario no le
/// cambia nada: la app funciona igual, solo no sabemos si hay versión nueva.
class UpdateCheckFailed extends UpdateCheck {
  const UpdateCheckFailed();
}

/// Consulta la última release publicada y la compara con la versión
/// instalada.
///
/// La API pública de GitHub limita a 60 peticiones por hora y por IP sin
/// token, así que el resultado se cachea con el mismo TTL que las condiciones
/// del tiempo: abrir la lista de calas varias veces seguidas no gasta cuota.
class UpdateChecker {
  static const ttl = Duration(minutes: 15);

  static const _repository = 'abdedarghal111/sea-weather-app';
  static const _storageKey = 'latest_release_cache';
  static const _requestTimeout = Duration(seconds: 10);

  static final _endpoint = Uri.https(
    'api.github.com',
    '/repos/$_repository/releases/latest',
  );

  /// Consulta en curso, compartida entre pantallas: sin esto, dos
  /// reconstrucciones seguidas gastan dos peticiones de la cuota.
  static Future<_LatestRelease?>? _inFlight;

  /// Con [forceRefresh] se ignora la caché (pull-to-refresh).
  Future<UpdateCheck> check({bool forceRefresh = false}) async {
    final current = await _currentVersion();
    if (current == null) return const UpdateCheckFailed();

    final latest = await _latestRelease(forceRefresh: forceRefresh);
    if (latest == null) return const UpdateCheckFailed();

    final published = AppVersion.tryParse(latest.tagName);
    if (published == null) return const UpdateCheckFailed();

    return published > current
        ? UpdateAvailable(published, latest.releaseUrl)
        : const UpdateUpToDate();
  }

  Future<AppVersion?> _currentVersion() async {
    try {
      final info = await PackageInfo.fromPlatform();
      return AppVersion.tryParse(info.version);
    } catch (_) {
      // En algún entorno sin plataforma nativa detrás (tests, web sin build
      // completo) esto puede fallar: se trata como comprobación fallida.
      return null;
    }
  }

  Future<_LatestRelease?> _latestRelease({required bool forceRefresh}) async {
    if (!forceRefresh) {
      final cached = await _readStored();
      if (cached != null && DateTime.now().difference(cached.fetchedAt) < ttl) {
        return cached;
      }
    }

    final pending = _inFlight;
    if (pending != null) return pending;

    final request = _fetchAndStore();
    _inFlight = request;
    try {
      return await request;
    } finally {
      _inFlight = null;
    }
  }

  Future<_LatestRelease?> _fetchAndStore() async {
    try {
      final response = await http.get(_endpoint,
          headers: const {'Accept': 'application/vnd.github+json'}).timeout(_requestTimeout);
      if (response.statusCode != 200) return null;

      final decoded = jsonDecode(response.body);
      if (decoded is! Map<String, dynamic>) return null;

      final tagName = decoded['tag_name'];
      final releaseUrl = decoded['html_url'];
      if (tagName is! String || releaseUrl is! String) return null;

      final release = _LatestRelease(tagName, releaseUrl, DateTime.now());
      await _store(release);
      return release;
    } catch (_) {
      // Sin red, timeout, JSON roto o SharedPreferences no disponible: es
      // información secundaria, así que no se propaga como error.
      return null;
    }
  }

  Future<_LatestRelease?> _readStored() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_storageKey);
      if (raw == null) return null;
      return _LatestRelease.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    } catch (_) {
      // Caché de un esquema antiguo o corrupta: como si no existiera.
      return null;
    }
  }

  Future<void> _store(_LatestRelease release) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_storageKey, jsonEncode(release.toJson()));
  }
}

/// La última release publicada, tal y como se guarda en caché.
class _LatestRelease {
  final String tagName;
  final String releaseUrl;
  final DateTime fetchedAt;

  const _LatestRelease(this.tagName, this.releaseUrl, this.fetchedAt);

  factory _LatestRelease.fromJson(Map<String, dynamic> json) => _LatestRelease(
        json['tagName'] as String,
        json['releaseUrl'] as String,
        DateTime.parse(json['fetchedAt'] as String),
      );

  Map<String, dynamic> toJson() => {
        'tagName': tagName,
        'releaseUrl': releaseUrl,
        'fetchedAt': fetchedAt.toIso8601String(),
      };
}
