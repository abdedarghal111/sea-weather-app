// Buscador de localidades por nombre contra la Geocoding API de Open-Meteo.

import 'dart:convert';

import 'package:http/http.dart' as http;

import 'api_error.dart';

class GeocodingResult {
  final String name;
  final String? admin1;
  final String? country;
  final double latitude;
  final double longitude;

  const GeocodingResult({
    required this.name,
    this.admin1,
    this.country,
    required this.latitude,
    required this.longitude,
  });

  String get label => [name, admin1, country].where((p) => p != null && p.isNotEmpty).join(', ');
}

class GeocodingApi {
  static Future<List<GeocodingResult>> search(String query) async {
    if (query.trim().isEmpty) return [];

    final uri = Uri.parse(
      'https://geocoding-api.open-meteo.com/v1/search'
      '?name=${Uri.encodeQueryComponent(query.trim())}&count=5&language=es&format=json',
    );
    final http.Response response;
    try {
      response = await http.get(uri).timeout(const Duration(seconds: 15));
    } catch (error) {
      throw translateTransportError(error);
    }

    Map<String, dynamic>? body;
    try {
      final decoded = jsonDecode(response.body);
      if (decoded is Map<String, dynamic>) body = decoded;
    } catch (_) {
      // Cuerpo no JSON: se trata como respuesta inesperada más abajo.
    }

    if (response.statusCode != 200 || body == null || body['error'] == true) {
      throw translateApiError(response.statusCode, body?['reason'] as String?);
    }

    // Sin coincidencias, la API omite "results" en vez de devolver lista
    // vacía.
    final results = body['results'] as List<dynamic>?;
    if (results == null) return [];

    // Una entrada sin nombre o sin coordenadas se descarta en vez de romper
    // la búsqueda entera.
    return results
        .whereType<Map<String, dynamic>>()
        .map((map) {
          final name = map['name'];
          final latitude = map['latitude'];
          final longitude = map['longitude'];
          if (name is! String || latitude is! num || longitude is! num) return null;
          return GeocodingResult(
            name: name,
            admin1: map['admin1'] as String?,
            country: map['country'] as String?,
            latitude: latitude.toDouble(),
            longitude: longitude.toDouble(),
          );
        })
        .whereType<GeocodingResult>()
        .toList();
  }
}
