import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';

import '../domain/models.dart';
import 'providers.dart';
import 'scanner_screen.dart';
import 'theme.dart';

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
  Checkpoint? _originCheckpoint;
  RouteResult? _route;
  String? _status;
  bool _busy = true;

  @override
  void initState() {
    super.initState();
    _computeRoute();
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
    final pos = await Geolocator.getCurrentPosition();
    return LatLng(pos.latitude, pos.longitude);
  }

  Future<void> _computeRoute() async {
    setState(() {
      _busy = true;
      _status = 'Locating you…';
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
    _originCheckpoint = originCp;

    try {
      final route = await repo.route(originCp.id, destCp.id);
      setState(() {
        _route = route;
        _busy = false;
        _status = null;
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
    if (route == null || route.steps.isEmpty) return;
    final pts = route.steps.map((s) => LatLng(s.lat, s.lng)).toList();
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
    });
    _fitRoute();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Now starting from ${cp.label}')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final route = _route;
    final polyPoints =
        route?.steps.map((s) => LatLng(s.lat, s.lng)).toList() ?? <LatLng>[];

    return Scaffold(
      appBar: AppBar(title: Text('To ${widget.destinationLabel}')),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: kAccent,
        foregroundColor: kPrimary,
        icon: const Icon(Icons.qr_code_scanner),
        label: const Text('Scan checkpoint'),
        onPressed: _scanToConfirm,
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
              TileLayer(
                urlTemplate:
                    'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'in.saintgits.trailmate',
              ),
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
                      child: const Icon(Icons.my_location, color: kAccent),
                    ),
                  if (_originCheckpoint != null && _currentPos == null)
                    Marker(
                      point: LatLng(
                          _originCheckpoint!.lat, _originCheckpoint!.lng),
                      child: const Icon(Icons.circle, color: kAccent, size: 16),
                    ),
                ],
              ),
            ],
          ),
          if (_busy)
            const Center(child: CircularProgressIndicator()),
          if (route != null)
            Positioned(
              left: 12,
              right: 12,
              bottom: 88,
              child: Card(
                color: kSecondary,
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Row(
                    children: [
                      const Icon(Icons.directions_walk, color: kAccent),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          '${route.steps.length} stops · '
                          '${route.totalDistanceMeters.round()} m · '
                          '${(route.totalTimeSeconds / 60).ceil()} min walk',
                          style: const TextStyle(color: kForeground),
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
                color: kSecondary,
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Text(_status!,
                      style: const TextStyle(color: Colors.white70)),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
