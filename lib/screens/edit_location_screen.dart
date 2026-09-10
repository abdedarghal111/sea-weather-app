// Pantalla de edición de una localidad guardada: cambiar el nombre, situarla
// en un mapa que se puede recorrer, o borrarla.

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:latlong2/latlong.dart';

import '../models/location.dart';
import '../widgets/map_layers.dart';

enum EditLocationAction { rename, delete }

class EditLocationScreen extends StatefulWidget {
  const EditLocationScreen({super.key, required this.location});

  final Location location;

  @override
  State<EditLocationScreen> createState() => _EditLocationScreenState();
}

class _EditLocationScreenState extends State<EditLocationScreen> {
  late final _nameController = TextEditingController(text: widget.location.name);
  late final LatLng _point = LatLng(widget.location.latitude, widget.location.longitude);
  final _mapController = MapController();

  @override
  void dispose() {
    _nameController.dispose();
    _mapController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final name = _nameController.text.trim();
    return Scaffold(
      appBar: AppBar(
        title: const Text('Editar localidad'),
        actions: [
          IconButton(
            onPressed: () => Navigator.of(context).pop((EditLocationAction.delete, '')),
            tooltip: 'Borrar la localidad',
            icon: const FaIcon(FontAwesomeIcons.trash),
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: TextField(
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: 'Nombre',
                border: OutlineInputBorder(),
              ),
              textInputAction: TextInputAction.done,
              onChanged: (_) => setState(() {}),
            ),
          ),
          Expanded(
            child: Stack(
              children: [
                FlutterMap(
                  mapController: _mapController,
                  options: MapOptions(initialCenter: _point, initialZoom: 13),
                  children: [
                    osmTileLayer(),
                    MarkerLayer(markers: [locationPinMarker(_point)]),
                  ],
                ),
                // Tras recorrer el mapa hace falta una vuelta al punto: si no,
                // recuperarlo a mano es incómodo.
                Positioned(
                  right: 12,
                  bottom: 12,
                  child: FloatingActionButton.small(
                    onPressed: () => _mapController.move(_point, 13),
                    tooltip: 'Volver a la localidad',
                    child: const FaIcon(FontAwesomeIcons.crosshairs),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                Expanded(child: Text(widget.location.coordinatesLabel)),
                const SizedBox(width: 8),
                FilledButton(
                  onPressed: name.isEmpty
                      ? null
                      : () => Navigator.of(context).pop((EditLocationAction.rename, name)),
                  child: const Text('Guardar'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
