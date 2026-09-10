// Comprobación de si hay una versión más nueva publicada en GitHub.

import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/app_version.dart';

/// Resultado de mirar si hay una versión nueva publicada.
sealed class UpdateStatus {
  const UpdateStatus();
}

/// La versión instalada es la última publicada, o una más nueva todavía sin
/// publicar.
class UpToDate extends UpdateStatus {
  const UpToDate();
}

class UpdateAvailable extends UpdateStatus {
  /// Versión publicada, ya sin la `v` del tag.
  final AppVersion version;

  /// Página de la release en GitHub, con las descargas de cada plataforma.
  final String releaseUrl;

  const UpdateAvailable(this.version, this.releaseUrl);
}

/// No se pudo comprobar: sin red, GitHub caído, cuota agotada o respuesta
/// inesperada. El motivo no se distingue porque no cambia nada para el
/// usuario.
class UpdateCheckFailed extends UpdateStatus {
  const UpdateCheckFailed();
}

/// Compara la última release publicada con la versión instalada.
///
/// La API pública de GitHub limita a 60 peticiones por hora e IP, así que el
/// resultado se cachea durante [ttl].
class UpdateChecker {
  static const ttl = Duration(minutes: 15);

  static const _repository = 'abdedarghal111/sea-weather-app';
  static const _storageKey = 'latest_release_cache';
  static const _requestTimeout = Duration(seconds: 10);

  static final _endpoint = Uri.https(
    'api.github.com',
    '/repos/$_repository/releases/latest',
  );

  /// Consulta en curso, compartida entre pantallas: sin esto, dos rebuilds
  /// seguidos gastan dos peticiones de la cuota.
  static Future<_LatestRelease?>? _inFlight;

  /// Con [forceRefresh] se ignora la caché (pull-to-refresh).
  Future<UpdateStatus> check({bool forceRefresh = false}) async {
    final current = await _currentVersion();
    if (current == null) return const UpdateCheckFailed();

    final latest = await _latestRelease(forceRefresh: forceRefresh);
    if (latest == null) return const UpdateCheckFailed();

    final published = AppVersion.tryParse(latest.tagName);
    if (published == null) return const UpdateCheckFailed();

    return published > current
        ? UpdateAvailable(published, latest.releaseUrl)
        : const UpToDate();
  }

  Future<AppVersion?> _currentVersion() async {
    try {
      final info = await PackageInfo.fromPlatform();
      return AppVersion.tryParse(info.version);
    } catch (_) {
      // Sin plataforma nativa detrás (tests, web sin build completo) esto
      // falla: cuenta como comprobación fallida.
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
      // Sin red, timeout, JSON roto o almacenamiento no disponible: es
      // información secundaria y no se propaga como error.
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
      // Caché corrupta o de un esquema antiguo: como si no existiera.
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
