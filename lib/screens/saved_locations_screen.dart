// Pantalla inicial: localidades guardadas con su resumen de valoraciones,
// más un modo edición para reordenarlas, renombrarlas o borrarlas.

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
import 'edit_location_screen.dart';
import 'location_detail_screen.dart';

class SavedLocationsScreen extends StatefulWidget {
  const SavedLocationsScreen({super.key});

  @override
  State<SavedLocationsScreen> createState() => _SavedLocationsScreenState();
}

class _SavedLocationsScreenState extends State<SavedLocationsScreen> {
  final _repository = LocationsRepository();
  final _cache = ForecastCache();

  List<Location> _locations = [];
  bool _loading = true;
  bool _loadFailed = false;
  bool _editing = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  /// Un Future por localidad, creado una sola vez: dentro del `itemBuilder`
  /// cada rebuild o cada scroll relanzaría la consulta.
  final _forecastFutures = <String, Future<LocationForecast>>{};

  Future<LocationForecast> _forecastFor(Location location) => _forecastFutures.putIfAbsent(
        location.coordinatesKey,
        () => _cache.forecastFor(location),
      );

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _loadFailed = false;
      _forecastFutures.clear();
    });
    try {
      final locations = await _repository.loadLocations();
      if (!mounted) return;
      setState(() {
        _locations = locations;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loadFailed = true;
        _loading = false;
      });
    }
  }

  Future<void> _openAddLocation() async {
    final added = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => const AddLocationScreen()),
    );
    if (added == true) _load();
  }

  // `onReorderItem` ya entrega el índice destino descontando la localidad que
  // se está moviendo.
  Future<void> _reorder(int oldIndex, int newIndex) async {
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _locations.insert(newIndex, _locations.removeAt(oldIndex)));
    try {
      await _repository.saveOrder(_locations);
    } catch (_) {
      messenger.showSnackBar(
        const SnackBar(content: Text('No se pudo guardar el nuevo orden.')),
      );
    }
  }

  Future<void> _openEditScreen(Location location) async {
    final result = await Navigator.of(context).push<(EditLocationAction, String)>(
      MaterialPageRoute(builder: (_) => EditLocationScreen(location: location)),
    );
    if (result == null || !mounted) return;

    final (action, name) = result;
    if (action == EditLocationAction.delete) {
      await _deleteLocation(location);
    } else {
      await _renameLocation(location, name);
    }
  }

  Future<void> _renameLocation(Location location, String name) async {
    if (name.isEmpty || name == location.name) return;
    final messenger = ScaffoldMessenger.of(context);
    try {
      await _repository.renameLocation(location.id, name);
      setState(() {
        final index = _locations.indexWhere((l) => l.id == location.id);
        if (index != -1) _locations[index] = _locations[index].copyWith(name: name);
      });
    } catch (_) {
      messenger.showSnackBar(
        const SnackBar(content: Text('No se pudo cambiar el nombre.')),
      );
    }
  }

  Future<void> _deleteLocation(Location location) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      await _repository.removeLocation(location.id);
      setState(() {
        _locations.removeWhere((l) => l.id == location.id);
        if (_locations.isEmpty) _editing = false;
      });
    } catch (_) {
      messenger.showSnackBar(
        const SnackBar(content: Text('No se pudo eliminar la localidad.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Tus localidades'),
        actions: [
          if (_locations.isNotEmpty)
            IconButton(
              onPressed: () => setState(() => _editing = !_editing),
              tooltip: _editing ? 'Terminar de editar' : 'Editar la lista',
              icon: FaIcon(_editing ? FontAwesomeIcons.check : FontAwesomeIcons.penToSquare),
            ),
        ],
      ),
      floatingActionButton: _editing
          ? null
          : FloatingActionButton(
              onPressed: _openAddLocation,
              child: const FaIcon(FontAwesomeIcons.plus),
            ),
      body: Column(
        children: [
          const UpdateBanner(),
          Expanded(child: _buildList()),
        ],
      ),
    );
  }

  Widget _buildList() {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_loadFailed) {
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
                onPressed: _load,
                icon: const FaIcon(FontAwesomeIcons.arrowRotateRight),
                label: const Text('Reintentar'),
              ),
            ],
          ),
        ),
      );
    }
    if (_locations.isEmpty) {
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

    if (_editing) {
      return ReorderableListView.builder(
        padding: const EdgeInsets.all(12),
        itemCount: _locations.length,
        onReorderItem: _reorder,
        itemBuilder: (context, index) {
          final location = _locations[index];
          return Card(
            key: ValueKey(location.id),
            margin: const EdgeInsets.only(bottom: 12),
            child: ListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              leading: ReorderableDragStartListener(
                index: index,
                child: const FaIcon(FontAwesomeIcons.gripLines),
              ),
              title: Text(location.name, style: const TextStyle(fontWeight: FontWeight.bold)),
              subtitle: Text(location.coordinatesLabel),
              trailing: const FaIcon(FontAwesomeIcons.penToSquare),
              onTap: () => _openEditScreen(location),
            ),
          );
        },
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: _locations.length,
      itemBuilder: (context, index) {
        final location = _locations[index];
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
                      error is ApiException ? error.message : 'No se pudo obtener el tiempo',
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
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => LocationDetailScreen(location: location)),
            ),
          ),
        );
      },
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
