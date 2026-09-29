import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';

/// Shared base-map tile layer + attribution for every FlutterMap in the app.
///
/// Raw `tile.openstreetmap.org` throttles/blocks direct app traffic under
/// its usage policy (it expects browsers or cached/self-hosted setups, not
/// bulk per-app requests) — that is what was causing the map to render
/// route lines/markers but leave the base map blank. CARTO's free raster
/// tiles are meant for exactly this kind of direct app use and don't hit
/// that wall, so switching the tile source is the actual fix rather than
/// just a network retry.
const _kTileUrl =
    'https://{s}.basemaps.cartocdn.com/rastertiles/voyager/{z}/{x}/{y}{r}.png';
const _kTileSubdomains = ['a', 'b', 'c', 'd'];

TileLayer buildTileLayer({void Function()? onTileError}) {
  return TileLayer(
    urlTemplate: _kTileUrl,
    subdomains: _kTileSubdomains,
    userAgentPackageName: 'in.saintgits.trailmate',
    maxNativeZoom: 20,
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
      TextSourceAttribution('CARTO'),
    ],
  );
}
