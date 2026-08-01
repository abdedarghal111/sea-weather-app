import 'dart:convert';

import 'package:http/http.dart' as http;

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
    final response = await http.get(uri);
    final body = jsonDecode(response.body) as Map<String, dynamic>;
    final results = body['results'] as List<dynamic>?;
    if (results == null) return [];

    return results.map((r) {
      final map = r as Map<String, dynamic>;
      return GeocodingResult(
        name: map['name'] as String,
        admin1: map['admin1'] as String?,
        country: map['country'] as String?,
        latitude: (map['latitude'] as num).toDouble(),
        longitude: (map['longitude'] as num).toDouble(),
      );
    }).toList();
  }
}
