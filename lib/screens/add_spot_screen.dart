import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:latlong2/latlong.dart';

import '../models/spot.dart';
import '../services/geocoding_api.dart';
import '../services/spots_repository.dart';

class AddSpotScreen extends StatefulWidget {
  const AddSpotScreen({super.key});

  @override
  State<AddSpotScreen> createState() => _AddSpotScreenState();
}

class _AddSpotScreenState extends State<AddSpotScreen> with SingleTickerProviderStateMixin {
  final _repository = SpotsRepository();
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
      setState(() => _results = results);
    } catch (_) {
      setState(() => _searchError = 'No se pudo buscar. Comprueba tu conexión.');
    } finally {
      setState(() => _searching = false);
    }
  }

  Future<void> _saveSpot(String name, double latitude, double longitude) async {
    await _repository.addSpot(Spot(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      name: name,
      latitude: latitude,
      longitude: longitude,
    ));
    if (mounted) Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Añadir cala, playa o zona'),
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
                    labelText: 'Nombre de la playa o cala',
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
                onTap: () => _saveSpot(result.label, result.latitude, result.longitude),
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
                userAgentPackageName: 'com.example.sea_wether_app',
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
                    : () => _saveSpot(
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
