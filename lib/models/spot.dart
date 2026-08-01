class Spot {
  final String id;
  final String name;
  final double latitude;
  final double longitude;

  const Spot({
    required this.id,
    required this.name,
    required this.latitude,
    required this.longitude,
  });

  String get cacheKey => '${latitude}_$longitude';

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'latitude': latitude,
        'longitude': longitude,
      };

  factory Spot.fromJson(Map<String, dynamic> json) => Spot(
        id: json['id'] as String,
        name: json['name'] as String,
        latitude: (json['latitude'] as num).toDouble(),
        longitude: (json['longitude'] as num).toDouble(),
      );
}
