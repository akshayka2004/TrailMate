import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';

/// Shared base-map tile layer + attribution for every FlutterMap in the app.
///
/// CARTO's free `basemaps.cartocdn.com` raster tiles require an API key as
/// of their current usage policy (unauthenticated requests return a 200 OK
/// PNG that just says "API KEY REQUIRED" baked into the image — that's what
/// made the map look "broken"). Pass the key at build time, same pattern as
/// API_BASE_URL, so it never lives in source:
///   flutter run --dart-define=CARTO_API_KEY=your_key
/// Get a free key (5M requests/month non-commercial) at carto.com/basemaps.
const String _kCartoApiKey = String.fromEnvironment('CARTO_API_KEY');

/// Falls back to raw OpenStreetMap tiles (no key needed, verified working)
/// if no CARTO key was supplied at build time.
const _kCartoUrl = 'https://basemaps.cartocdn.com/rastertiles/voyager/{z}/{x}/{y}.png?key=$_kCartoApiKey';
const _kOsmUrl = 'https://tile.openstreetmap.org/{z}/{x}/{y}.png';

TileLayer buildTileLayer({void Function()? onTileError}) {
  final usingCarto = _kCartoApiKey.isNotEmpty;
  return TileLayer(
    urlTemplate: usingCarto ? _kCartoUrl : _kOsmUrl,
    userAgentPackageName: 'in.saintgits.trailmate',
    maxNativeZoom: 19,
    errorTileCallback: onTileError == null ? null : (tile, error, stack) => onTileError(),
  );
}

/// OSM's tile usage policy requires visible attribution — this also gives
/// the user a legible marker of "this is a live map" vs. a broken blank one.
Widget buildMapAttribution() {
  return RichAttributionWidget(
    alignment: AttributionAlignment.bottomLeft,
    attributions: [
      TextSourceAttribution('OpenStreetMap contributors'),
      if (_kCartoApiKey.isNotEmpty) TextSourceAttribution('CARTO'),
    ],
  );
}
