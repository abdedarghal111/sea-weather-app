import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:latlong2/latlong.dart';

import '../models/location.dart';
import '../services/api_error.dart';
import '../services/geocoding_api.dart';
import '../services/locations_repository.dart';

class AddLocationScreen extends StatefulWidget {
  const AddLocationScreen({super.key});

  @override
  State<AddLocationScreen> createState() => _AddLocationScreenState();
}

class _AddLocationScreenState extends State<AddLocationScreen> with SingleTickerProviderStateMixin {
  final _repository = LocationsRepository();
  late final TabController _tabController;

  final _searchController = TextEditingController();
  List<GeocodingResult> _results = [];
  bool _searching = false;
  String? _searchError;

  LatLng? _tappedPoint;
  final _mapNameController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    _mapNameController.dispose();
    super.dispose();
  }

  Future<void> _search() async {
    setState(() {
      _searching = true;
      _searchError = null;
    });
    try {
      final results = await GeocodingApi.search(_searchController.text);
      setState(() {
        _results = results;
        // El buscador solo indexa poblaciones: playas, lagos y embalses no
        // aparecen por nombre, y sin este aviso la lista se quedaba vacía sin
        // explicar por qué.
        _searchError = results.isEmpty && _searchController.text.trim().isNotEmpty
            ? 'Sin resultados. El buscador solo encuentra pueblos y ciudades: '
                'para una playa, cala, lago o embalse, usa la pestaña Mapa.'
            : null;
      });
    } on ApiException catch (error) {
      setState(() => _searchError = error.message);
    } catch (_) {
      setState(() => _searchError = 'No se pudo buscar. Comprueba tu conexión.');
    } finally {
      setState(() => _searching = false);
    }
  }

  Future<void> _saveLocation(String name, double latitude, double longitude) async {
    final navigator = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);
    try {
      await _repository.addLocation(Location(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        name: name,
        latitude: latitude,
        longitude: longitude,
      ));
      navigator.pop(true);
    } catch (_) {
      messenger.showSnackBar(
        const SnackBar(content: Text('No se pudo guardar la localidad.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Añadir localidad'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Buscar', icon: FaIcon(FontAwesomeIcons.magnifyingGlass)),
            Tab(text: 'Mapa', icon: FaIcon(FontAwesomeIcons.map)),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildSearchTab(),
          _buildMapTab(),
        ],
      ),
    );
  }

  Widget _buildSearchTab() {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _searchController,
                  decoration: const InputDecoration(
                    labelText: 'Nombre de la localidad',
                    border: OutlineInputBorder(),
                  ),
                  onSubmitted: (_) => _search(),
                ),
              ),
              const SizedBox(width: 8),
              FilledButton(
                onPressed: _searching ? null : _search,
                child: _searching
                    ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Text('Buscar'),
              ),
            ],
          ),
        ),
        if (_searchError != null) Padding(padding: const EdgeInsets.all(12), child: Text(_searchError!)),
        Expanded(
          child: ListView.builder(
            itemCount: _results.length,
            itemBuilder: (context, index) {
              final result = _results[index];
              return ListTile(
                leading: const FaIcon(FontAwesomeIcons.locationDot),
                title: Text(result.label),
                onTap: () => _saveLocation(result.label, result.latitude, result.longitude),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildMapTab() {
    return Column(
      children: [
        Expanded(
          child: FlutterMap(
            options: MapOptions(
              initialCenter: const LatLng(38.08, -0.65),
              initialZoom: 8,
              onTap: (tapPosition, point) => setState(() => _tappedPoint = point),
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'es.abderra.sea_weather_app',
              ),
              if (_tappedPoint != null)
                MarkerLayer(markers: [
                  Marker(
                    point: _tappedPoint!,
                    child: const FaIcon(FontAwesomeIcons.mapPin, color: Colors.red, size: 36),
                  ),
                ]),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _mapNameController,
                  decoration: const InputDecoration(
                    labelText: 'Nombre para este punto',
                    border: OutlineInputBorder(),
                  ),
                  onChanged: (_) => setState(() {}),
                ),
              ),
              const SizedBox(width: 8),
              FilledButton(
                onPressed: _tappedPoint == null || _mapNameController.text.trim().isEmpty
                    ? null
                    : () => _saveLocation(
                          _mapNameController.text.trim(),
                          _tappedPoint!.latitude,
                          _tappedPoint!.longitude,
                        ),
                child: const Text('Guardar'),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
