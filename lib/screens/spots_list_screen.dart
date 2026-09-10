import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

import '../models/beach_conditions.dart';
import '../models/spot.dart';
import '../models/spot_conditions_bundle.dart';
import '../services/conditions_cache.dart';
import '../services/spots_repository.dart';
import '../services/weather_api_error.dart';
import 'add_spot_screen.dart';
import 'spot_detail_screen.dart';

class SpotsListScreen extends StatefulWidget {
  const SpotsListScreen({super.key});

  @override
  State<SpotsListScreen> createState() => _SpotsListScreenState();
}

class _SpotsListScreenState extends State<SpotsListScreen> {
  final _repository = SpotsRepository();
  final _cache = ConditionsCache();
  late Future<List<Spot>> _spotsFuture;

  @override
  void initState() {
    super.initState();
    _spotsFuture = _repository.loadSpots();
  }

  /// Un Future por cala, creado una sola vez. Si se crearan dentro del
  /// `itemBuilder`, cada rebuild o cada scroll relanzaría la consulta.
  final _conditionFutures = <String, Future<SpotConditionsBundle>>{};

  Future<SpotConditionsBundle> _conditionsFor(Spot spot) =>
      _conditionFutures.putIfAbsent(spot.cacheKey, () => _cache.getConditions(spot));

  void _reload() {
    setState(() {
      _conditionFutures.clear();
      _spotsFuture = _repository.loadSpots();
    });
  }

  Future<void> _openAddSpot() async {
    final added = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => const AddSpotScreen()),
    );
    if (added == true) _reload();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Buscar cala, playa o zona')),
      floatingActionButton: FloatingActionButton(
        onPressed: _openAddSpot,
        child: const FaIcon(FontAwesomeIcons.plus),
      ),
      body: FutureBuilder<List<Spot>>(
        future: _spotsFuture,
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
                      'No se pudieron cargar tus calas y playas guardadas.',
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
          final spots = snapshot.data ?? [];
          if (spots.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const FaIcon(FontAwesomeIcons.umbrellaBeach, size: 64),
                    const SizedBox(height: 16),
                    const Text(
                      'Todavía no tienes ninguna cala o playa guardada',
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),
                    FilledButton.icon(
                      onPressed: _openAddSpot,
                      icon: const FaIcon(FontAwesomeIcons.plus),
                      label: const Text('Añadir tu primera cala'),
                    ),
                  ],
                ),
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(12),
            itemCount: spots.length,
            itemBuilder: (context, index) {
              final spot = spots[index];
              return Card(
                margin: const EdgeInsets.only(bottom: 12),
                child: ListTile(
                  contentPadding: const EdgeInsets.all(12),
                  title: Text(spot.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: FutureBuilder<SpotConditionsBundle>(
                    future: _conditionsFor(spot),
                    builder: (context, snap) {
                      if (snap.hasError) {
                        final error = snap.error;
                        return Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: Text(
                            error is WeatherApiException
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
                      final conditions = snap.data!.current;
                      final agua = conditions.rateWaterClarity().level;
                      final playa = conditions.ratePlayaRemovida().level;
                      final lluvia = conditions.rateRain().level;
                      return Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Wrap(
                          spacing: 12,
                          runSpacing: 4,
                          children: [
                            _indicator(agua.waterClarityTitle, agua),
                            _indicator(playa.playaRemovidaShortLabel, playa),
                            _indicator('Surf', conditions.rateSurf().level),
                            _indicator('Sol', conditions.rateSun().level),
                            _indicator(lluvia.rainTitle, lluvia),
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
                        await _repository.removeSpot(spot.id);
                        _reload();
                      } catch (_) {
                        messenger.showSnackBar(
                          const SnackBar(content: Text('No se pudo eliminar la cala.')),
                        );
                      }
                    },
                  ),
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => SpotDetailScreen(spot: spot)),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }

  Widget _indicator(String label, RatingLevel level) {
    final (icon, color) = switch (level) {
      RatingLevel.veryGood => (FontAwesomeIcons.circleCheck, Colors.green),
      RatingLevel.good => (FontAwesomeIcons.circleCheck, Colors.lightGreen),
      RatingLevel.ok => (FontAwesomeIcons.triangleExclamation, Colors.amber),
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
