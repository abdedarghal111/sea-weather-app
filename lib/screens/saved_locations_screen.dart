// Pantalla inicial: localidades guardadas con su resumen de valoraciones.

import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

import '../models/location.dart';
import '../models/location_forecast.dart';
import '../models/weather_snapshot.dart';
import '../services/api_error.dart';
import '../services/forecast_cache.dart';
import '../services/locations_repository.dart';
import '../widgets/update_banner.dart';
import 'add_location_screen.dart';
import 'location_detail_screen.dart';

class SavedLocationsScreen extends StatefulWidget {
  const SavedLocationsScreen({super.key});

  @override
  State<SavedLocationsScreen> createState() => _SavedLocationsScreenState();
}

class _SavedLocationsScreenState extends State<SavedLocationsScreen> {
  final _repository = LocationsRepository();
  final _cache = ForecastCache();
  late Future<List<Location>> _locationsFuture;

  @override
  void initState() {
    super.initState();
    _locationsFuture = _repository.loadLocations();
  }

  /// Un Future por localidad, creado una sola vez: dentro del `itemBuilder`
  /// cada rebuild o cada scroll relanzaría la consulta.
  final _forecastFutures = <String, Future<LocationForecast>>{};

  Future<LocationForecast> _forecastFor(Location location) => _forecastFutures.putIfAbsent(
        location.coordinatesKey,
        () => _cache.forecastFor(location),
      );

  void _reload() {
    setState(() {
      _forecastFutures.clear();
      _locationsFuture = _repository.loadLocations();
    });
  }

  Future<void> _openAddLocation() async {
    final added = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => const AddLocationScreen()),
    );
    if (added == true) _reload();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Tus localidades')),
      floatingActionButton: FloatingActionButton(
        onPressed: _openAddLocation,
        child: const FaIcon(FontAwesomeIcons.plus),
      ),
      body: Column(
        children: [
          const UpdateBanner(),
          Expanded(
            child: FutureBuilder<List<Location>>(
              future: _locationsFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const FaIcon(FontAwesomeIcons.triangleExclamation, size: 48),
                          const SizedBox(height: 16),
                          const Text(
                            'No se pudieron cargar tus localidades guardadas.',
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 16),
                          FilledButton.icon(
                            onPressed: _reload,
                            icon: const FaIcon(FontAwesomeIcons.arrowRotateRight),
                            label: const Text('Reintentar'),
                          ),
                        ],
                      ),
                    ),
                  );
                }
                final locations = snapshot.data ?? [];
                if (locations.isEmpty) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const FaIcon(FontAwesomeIcons.umbrellaBeach, size: 64),
                          const SizedBox(height: 16),
                          const Text(
                            'Todavía no tienes ninguna localidad guardada',
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 16),
                          FilledButton.icon(
                            onPressed: _openAddLocation,
                            icon: const FaIcon(FontAwesomeIcons.plus),
                            label: const Text('Añadir tu primera localidad'),
                          ),
                        ],
                      ),
                    ),
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.all(12),
                  itemCount: locations.length,
                  itemBuilder: (context, index) {
                    final location = locations[index];
                    return Card(
                      margin: const EdgeInsets.only(bottom: 12),
                      child: ListTile(
                        contentPadding: const EdgeInsets.all(12),
                        title: Text(location.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                        subtitle: FutureBuilder<LocationForecast>(
                          future: _forecastFor(location),
                          builder: (context, snap) {
                            if (snap.hasError) {
                              final error = snap.error;
                              return Padding(
                                padding: const EdgeInsets.only(top: 8),
                                child: Text(
                                  error is ApiException
                                      ? error.message
                                      : 'No se pudo obtener el tiempo',
                                ),
                              );
                            }
                            if (!snap.hasData) {
                              return const Padding(
                                padding: EdgeInsets.only(top: 8),
                                child: Text('Cargando...'),
                              );
                            }
                            final weather = snap.data!.now;
                            final waterClarity = weather.rateWaterClarity().level;
                            final shoreDisturbance = weather.rateShoreDisturbance().level;
                            final rain = weather.rateRain().level;
                            return Padding(
                              padding: const EdgeInsets.only(top: 8),
                              child: Wrap(
                                spacing: 12,
                                runSpacing: 4,
                                children: [
                                  _ratingChip(waterClarity.waterClarityTitle, waterClarity),
                                  _ratingChip(shoreDisturbance.shoreDisturbanceShortLabel, shoreDisturbance),
                                  _ratingChip('Surf', weather.rateSurf().level),
                                  _ratingChip('Sol', weather.rateSun().level),
                                  _ratingChip(rain.rainTitle, rain),
                                ],
                              ),
                            );
                          },
                        ),
                        trailing: IconButton(
                          icon: const FaIcon(FontAwesomeIcons.trash),
                          onPressed: () async {
                            final messenger = ScaffoldMessenger.of(context);
                            try {
                              await _repository.removeLocation(location.id);
                              _reload();
                            } catch (_) {
                              messenger.showSnackBar(
                                const SnackBar(content: Text('No se pudo eliminar la localidad.')),
                              );
                            }
                          },
                        ),
                        onTap: () => Navigator.of(context).push(
                          MaterialPageRoute(builder: (_) => LocationDetailScreen(location: location)),
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _ratingChip(String label, RatingLevel level) {
    final (icon, color) = switch (level) {
      RatingLevel.veryGood => (FontAwesomeIcons.circleCheck, Colors.green),
      RatingLevel.good => (FontAwesomeIcons.circleCheck, Colors.lightGreen),
      RatingLevel.fair => (FontAwesomeIcons.triangleExclamation, Colors.amber),
      RatingLevel.bad => (FontAwesomeIcons.circleXmark, Colors.deepOrange),
      RatingLevel.veryBad => (FontAwesomeIcons.ban, Colors.red),
    };
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        FaIcon(icon, size: 14, color: color),
        const SizedBox(width: 4),
        Text(label, style: const TextStyle(fontSize: 12)),
      ],
    );
  }
}
