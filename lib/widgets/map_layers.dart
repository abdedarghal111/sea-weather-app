// Piezas compartidas por los mapas de la app: teselas y pin de un punto.

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:latlong2/latlong.dart';

// La política de uso de las teselas de OpenStreetMap exige identificar la app.
TileLayer osmTileLayer() => TileLayer(
      urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
      userAgentPackageName: 'es.abderra.sea_weather_app',
    );

// El icono es un pin: se dibuja encima del punto para que la punta caiga justo
// donde está la localidad, no centrada sobre ella. El glifo es más estrecho
// que el hueco del marcador, así que sin el Center la punta se iría a la
// izquierda.
Marker locationPinMarker(LatLng point) => Marker(
      point: point,
      width: 36,
      height: 36,
      alignment: Alignment.topCenter,
      child: const Center(
        child: FaIcon(FontAwesomeIcons.locationDot, color: Colors.red, size: 36),
      ),
    );
