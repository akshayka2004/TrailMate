import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';

import '../domain/models.dart';
import 'map_tiles.dart';
import 'providers.dart';
import 'scanner_screen.dart';
import 'theme.dart';

/// Tile load failures within this window before we tell the user the
/// connection looks slow — a single dropped tile is normal, a burst is not.
const int _kTileErrorThreshold = 4;
const Duration _kTileErrorWindow = Duration(seconds: 8);

class MapScreen extends ConsumerStatefulWidget {
  const MapScreen({
    super.key,
    required this.destination,
    required this.destinationLabel,
  });

  final LatLng destination;
  final String destinationLabel;

  @override
  ConsumerState<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends ConsumerState<MapScreen> {
  final _mapController = MapController();
  LatLng? _currentPos;
  double? _heading;
  Checkpoint? _originCheckpoint;
  RouteResult? _route;
  String? _status;
  String? _originFallbackNotice;
  bool _busy = true;
  StreamSubscription<Position>? _posSub;

  bool _slowConnection = false;
  final List<DateTime> _tileErrors = [];

  @override
  void initState() {
    super.initState();
    _computeRoute();
    _startHeadingUpdates();
  }

  @override
  void dispose() {
    _posSub?.cancel();
    super.dispose();
  }

  Future<void> _startHeadingUpdates() async {
    try {
      final enabled = await Geolocator.isLocationServiceEnabled();
      if (!enabled) return;
      var perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) {
        perm = await Geolocator.requestPermission();
      }
      if (perm == LocationPermission.denied ||
          perm == LocationPermission.deniedForever) {
        return;
      }
      _posSub = Geolocator.getPositionStream(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.best,
          distanceFilter: 2,
        ),
      ).listen((pos) {
        if (!mounted) return;
        setState(() {
          _currentPos = LatLng(pos.latitude, pos.longitude);
          // headingAccuracy < 0 means the device could not derive a heading
          // (e.g. stationary) — keep showing the last known direction.
          if (pos.headingAccuracy >= 0) _heading = pos.heading;
        });
      });
    } catch (_) {
      // Live heading is a nice-to-have; the static origin marker still works.
    }
  }

  void _onTileError() {
    final now = DateTime.now();
    _tileErrors.add(now);
    _tileErrors.removeWhere((t) => now.difference(t) > _kTileErrorWindow);
    if (_tileErrors.length >= _kTileErrorThreshold && !_slowConnection) {
      setState(() => _slowConnection = true);
    }
  }

  Future<LatLng?> _tryGetPosition() async {
    // Guard the WHOLE sequence with one timeout. On web the permission prompt
    // (requestPermission) can await user input indefinitely, so no single
    // inner timeout is enough — cap the entire acquisition and fall back to
    // the campus-center checkpoint if it does not resolve quickly.
    try {
      return await _acquirePosition().timeout(const Duration(seconds: 6));
    } catch (_) {
      return null;
    }
  }

  Future<LatLng?> _acquirePosition() async {
    final enabled = await Geolocator.isLocationServiceEnabled();
    if (!enabled) return null;
    var perm = await Geolocator.checkPermission();
    if (perm == LocationPermission.denied) {
      perm = await Geolocator.requestPermission();
    }
    if (perm == LocationPermission.denied ||
        perm == LocationPermission.deniedForever) {
      return null;
    }
    // Explicit high accuracy — the platform default can otherwise return a
    // coarse/stale fix, which was throwing the computed origin checkpoint
    // off by enough to look like "starting from some other point".
    final pos = await Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(accuracy: LocationAccuracy.best),
    );
    return LatLng(pos.latitude, pos.longitude);
  }

  /// A GPS fix further than this from the nearest known checkpoint means the
  /// user isn't actually near the campus graph — starting the route there
  /// anyway would silently pick whichever checkpoint happens to be closest,
  /// which reads as "the route starts from a random/wrong place".
  static const double _kMaxOriginSnapMeters = 500;

  Future<void> _computeRoute() async {
    setState(() {
      _busy = true;
      _status = 'Locating you…';
      _originFallbackNotice = null;
    });
    final repo = ref.read(campusRepositoryProvider);

    // Origin: live GPS if available, else the checkpoint nearest campus center.
    final pos = await _tryGetPosition();
    final origin = pos ?? repo.campusCenter;
    _currentPos = pos;

    final originCp = repo.nearestCheckpoint(origin.latitude, origin.longitude);
    final destCp =
        repo.nearestCheckpoint(widget.destination.latitude, widget.destination.longitude);
    if (originCp == null || destCp == null) {
      setState(() {
        _busy = false;
        _status = 'No checkpoints near you or the destination.';
      });
      return;
    }

    final snapDistance = repo.haversine(origin, LatLng(originCp.lat, originCp.lng));
    String? fallbackNotice;
    if (pos == null) {
      fallbackNotice = 'Could not get your GPS location — route starts from campus center instead.';
    } else if (snapDistance > _kMaxOriginSnapMeters) {
      fallbackNotice =
          'You\'re ${(snapDistance / 1000).toStringAsFixed(1)} km from the nearest checkpoint '
          '(${originCp.label}) — route may not reflect your real position.';
    }
    _originCheckpoint = originCp;

    try {
      final route = await repo.route(originCp.id, destCp.id);
      setState(() {
        _route = route;
        _busy = false;
        _status = null;
        _originFallbackNotice = fallbackNotice;
      });
      _fitRoute();
    } catch (e) {
      setState(() {
        _busy = false;
        _status = 'No route found: $e';
      });
    }
  }

  void _fitRoute() {
    final route = _route;
    if (route == null || route.polyline.isEmpty) return;
    final pts = route.polyline.map((p) => LatLng(p.$1, p.$2)).toList();
    // A single-step route (already at the destination checkpoint — e.g.
    // standing right next to it) gives fromPoints a zero-area bounds, which
    // flutter_map's bounds-fit zoom math turns into an infinite/NaN zoom and
    // crashes. Just center on the one point instead of fitting a box.
    if (pts.length < 2) {
      _mapController.move(pts.first, 18);
      return;
    }
    final bounds = LatLngBounds.fromPoints(pts);
    _mapController.fitCamera(
      CameraFit.bounds(bounds: bounds, padding: const EdgeInsets.all(48)),
    );
  }

  Future<void> _scanToConfirm() async {
    final repo = ref.read(campusRepositoryProvider);
    final payload = await Navigator.of(context).push<String>(
      MaterialPageRoute(builder: (_) => const ScannerScreen()),
    );
    if (payload == null) return;
    final cp = repo.checkpointByPayload(payload);
    if (!mounted) return;
    if (cp == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Unrecognized QR code')),
      );
      return;
    }
    // Re-anchor origin to the scanned checkpoint and recompute.
    final destCp = repo.nearestCheckpoint(
        widget.destination.latitude, widget.destination.longitude);
    if (destCp == null) return;
    setState(() => _busy = true);
    final route = await repo.route(cp.id, destCp.id);
    setState(() {
      _originCheckpoint = cp;
      _route = route;
      _busy = false;
      _currentPos = LatLng(cp.lat, cp.lng);
      // Scanning a physical checkpoint's QR is ground truth — any earlier
      // "route may be inaccurate" warning from a GPS-based guess no longer
      // applies.
      _originFallbackNotice = null;
    });
    _fitRoute();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Now starting from ${cp.label}')),
      );
    }
  }

  Future<void> _recenterToPreciseLocation() async {
    try {
      final enabled = await Geolocator.isLocationServiceEnabled();
      if (!enabled) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Turn on device location to recenter.')),
          );
        }
        return;
      }
      var perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) {
        perm = await Geolocator.requestPermission();
      }
      if (perm == LocationPermission.denied || perm == LocationPermission.deniedForever) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Location permission denied.')),
          );
        }
        return;
      }
      // bestForNavigation forces a fresh high-precision fix rather than
      // reusing whatever the stream last cached — this button's whole job
      // is "get me the most precise position right now".
      final pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(accuracy: LocationAccuracy.bestForNavigation),
      ).timeout(const Duration(seconds: 10));
      final here = LatLng(pos.latitude, pos.longitude);
      if (!mounted) return;
      setState(() => _currentPos = here);
      _mapController.move(here, 18);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not get a precise location fix.')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final route = _route;
    // route.polyline includes each edge's real-path waypoints (when an
    // admin has drawn them) instead of jumping straight between checkpoints.
    final polyPoints = route?.polyline.map((p) => LatLng(p.$1, p.$2)).toList() ?? <LatLng>[];

    return Scaffold(
      appBar: AppBar(title: Text('To ${widget.destinationLabel}')),
      floatingActionButton: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          FloatingActionButton(
            heroTag: 'recenterPrecise',
            tooltip: 'Recenter to precise location',
            onPressed: _recenterToPreciseLocation,
            child: const Icon(Icons.my_location),
          ),
          const SizedBox(height: 12),
          FloatingActionButton.extended(
            heroTag: 'scanCheckpoint',
            icon: const Icon(Icons.qr_code_scanner),
            label: const Text('Scan checkpoint'),
            onPressed: _scanToConfirm,
          ),
        ],
      ),
      body: Stack(
        children: [
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: widget.destination,
              initialZoom: 17,
            ),
            children: [
              buildTileLayer(onTileError: _onTileError),
              if (polyPoints.length > 1)
                PolylineLayer(
                  polylines: [
                    Polyline(
                      points: polyPoints,
                      strokeWidth: 5,
                      color: kAccent,
                    ),
                  ],
                ),
              MarkerLayer(
                markers: [
                  Marker(
                    point: widget.destination,
                    child: const Icon(Icons.flag, color: Colors.redAccent),
                  ),
                  if (_currentPos != null)
                    Marker(
                      point: _currentPos!,
                      child: _heading != null
                          ? Transform.rotate(
                              angle: _heading! * math.pi / 180,
                              child: const Icon(Icons.navigation,
                                  color: kAccent, size: 30),
                            )
                          : const Icon(Icons.my_location, color: kAccent),
                    ),
                  if (_originCheckpoint != null && _currentPos == null)
                    Marker(
                      point: LatLng(
                          _originCheckpoint!.lat, _originCheckpoint!.lng),
                      child: const Icon(Icons.circle, color: kAccent, size: 16),
                    ),
                ],
              ),
              buildMapAttribution(),
            ],
          ),
          if (_busy)
            const Center(child: CircularProgressIndicator()),
          if (_originFallbackNotice != null)
            Positioned(
              top: 12,
              left: 12,
              right: 12,
              child: Card(
                color: Colors.orange.shade900,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  child: Row(
                    children: [
                      const Icon(Icons.warning_amber_outlined, color: Colors.white),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(_originFallbackNotice!,
                            style: const TextStyle(color: Colors.white)),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          if (_slowConnection)
            Positioned(
              top: 12,
              left: 12,
              right: 12,
              child: Card(
                color: Colors.orange.shade900,
                child: const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  child: Row(
                    children: [
                      Icon(Icons.signal_wifi_bad_outlined, color: Colors.white),
                      SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Slow connection — map tiles are taking a while to load.',
                          style: TextStyle(color: Colors.white),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          if (route != null)
            Positioned(
              left: 12,
              right: 12,
              bottom: 88,
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Row(
                    children: [
                      const Icon(Icons.directions_walk, color: kAccent),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          route.steps.length < 2
                              ? 'You\'re already at this destination.'
                              : '${route.steps.length} stops · '
                                  '${route.totalDistanceMeters.round()} m · '
                                  '${(route.totalTimeSeconds / 60).ceil()} min walk',
                          style: TextStyle(color: context.palette.textPrimary),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          if (_status != null && !_busy)
            Positioned(
              left: 12,
              right: 12,
              bottom: 88,
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Text(_status!,
                      style: TextStyle(color: context.palette.textSoft)),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
