import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../data/campus_repository.dart';
import '../domain/models.dart';
import 'map_tiles.dart';
import 'providers.dart';
import 'scanner_screen.dart';
import 'theme.dart';

/// Phase 7 — admin builds a campus section by walking: drop a checkpoint at
/// the current GPS location, auto-mint its QR, optionally chain an edge to the
/// previous drop, and scan-to-confirm placement. Each drop is pushed to the
/// backend in real time — or, when the backend is unreachable, saved locally
/// so the flow stays fully demoable (see AdminApi's fallback in
/// campus_repository.dart).
class WalkModeScreen extends ConsumerStatefulWidget {
  const WalkModeScreen({super.key});

  @override
  ConsumerState<WalkModeScreen> createState() => _WalkModeScreenState();
}

class _WalkModeScreenState extends ConsumerState<WalkModeScreen> {
  final _dropped = <Checkpoint>[];
  bool _busy = false;
  bool _chain = true;
  String? _error;

  Future<LatLng?> _position() async {
    try {
      var perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) {
        perm = await Geolocator.requestPermission();
      }
      if (perm == LocationPermission.denied ||
          perm == LocationPermission.deniedForever) {
        return null;
      }
      final pos = await Geolocator.getCurrentPosition()
          .timeout(const Duration(seconds: 8));
      return LatLng(pos.latitude, pos.longitude);
    } catch (_) {
      return null;
    }
  }

  Future<void> _drop() async {
    final label = await _askLabel();
    if (label == null || label.trim().isEmpty) return;

    setState(() {
      _busy = true;
      _error = null;
    });
    final admin = ref.read(adminApiProvider);
    final repo = ref.read(campusRepositoryProvider);
    try {
      final pos = await _position();
      if (pos == null) {
        setState(() {
          _busy = false;
          _error = 'Location unavailable — enable GPS permission and try again.';
        });
        return;
      }
      final cp = await admin.createCheckpoint(label.trim(), pos.latitude, pos.longitude);
      await admin.generateQr(cp.id);

      if (_chain && _dropped.isNotEmpty) {
        final prev = _dropped.last;
        final dist = repo.haversine(
          LatLng(prev.lat, prev.lng),
          LatLng(cp.lat, cp.lng),
        );
        await admin.connectEdge(prev.id, cp.id, dist);
      }

      // AdminApi's live-backend success path doesn't touch the in-memory
      // repo (only the offline/demo fallback does) — without this, the
      // freshly-created checkpoint wouldn't show up anywhere (overview map,
      // student search) until the app restarted. Refetch so it's live
      // immediately, and invalidate campusLoadProvider so HomeScreen (which
      // watches that provider, not this repo instance directly) rebuilds.
      if (!repo.isDemoData) await repo.load();
      ref.invalidate(campusLoadProvider);

      setState(() {
        _dropped.add(cp);
        _busy = false;
      });
    } catch (_) {
      // Network/server failures against a *reachable* backend land here
      // (bad request, auth, 5xx) — unreachable-backend cases are already
      // handled transparently by AdminApi's demo fallback above.
      setState(() {
        _busy = false;
        _error = 'Could not save the checkpoint. Check your connection and try again.';
      });
    }
  }

  Future<String?> _askLabel() {
    final controller = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Checkpoint label'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(hintText: 'e.g. Library Entrance'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, controller.text),
            child: const Text('Drop'),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmByScan(Checkpoint cp) async {
    final payload = await Navigator.of(context).push<String>(
      MaterialPageRoute(builder: (_) => const ScannerScreen()),
    );
    if (payload == null || !mounted) return;
    final repo = ref.read(campusRepositoryProvider);
    // Repo cache may not have the just-created checkpoint; match by id string.
    final ok = repo.checkpointByPayload(payload)?.id == cp.id ||
        payload.trim() == 'TRAILMATE:CP:${cp.id}';
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(ok
            ? 'Confirmed placement of ${cp.label}'
            : 'Scanned a different checkpoint'),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final admin = ref.read(adminApiProvider);
    final isDemoData = ref.read(campusRepositoryProvider).isDemoData;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Admin walk mode'),
        actions: [
          IconButton(
            tooltip: 'View all checkpoints',
            icon: const Icon(Icons.map_outlined),
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => CampusOverviewMap(
                  repo: ref.read(campusRepositoryProvider),
                ),
              ),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        icon: _busy
            ? const SizedBox(
                height: 18,
                width: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : const Icon(Icons.add_location_alt),
        label: const Text('Drop checkpoint here'),
        onPressed: _busy ? null : _drop,
      ),
      body: Column(
        children: [
          if (isDemoData)
            Container(
              width: double.infinity,
              color: context.palette.surface,
              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.info_outline, size: 14, color: kAccent),
                  SizedBox(width: 6),
                  Flexible(
                    child: Text(
                      'Demo mode — checkpoints are saved on this device only, '
                      'not synced to a server',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: kAccent, fontSize: 12),
                    ),
                  ),
                ],
              ),
            ),
          SwitchListTile(
            value: _chain,
            activeThumbColor: kAccent,
            onChanged: (v) => setState(() => _chain = v),
            title: const Text('Connect to previous checkpoint'),
            subtitle: const Text('Auto-create a walking edge as you go'),
          ),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: Row(
                children: [
                  const Icon(Icons.error_outline, color: kDestructive, size: 18),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(_error!, style: const TextStyle(color: kDestructive)),
                  ),
                ],
              ),
            ),
          Divider(color: context.palette.divider, height: 1),
          Expanded(
            child: _dropped.isEmpty
                ? Center(
                    child: Text(
                      'Walk the campus and drop checkpoints.\n'
                      'Each is saved with a QR code immediately.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: context.palette.textMuted),
                    ),
                  )
                : ListView.builder(
                    itemCount: _dropped.length,
                    itemBuilder: (_, i) {
                      final cp = _dropped[_dropped.length - 1 - i];
                      return ListTile(
                        leading: SizedBox(
                          width: 44,
                          height: 44,
                          child: isDemoData
                              // No live backend to render/store a QR image —
                              // render it client-side from the payload so it
                              // still works standalone.
                              ? QrImageView(
                                  data: 'TRAILMATE:CP:${cp.id}',
                                  backgroundColor: Colors.white,
                                  padding: const EdgeInsets.all(4),
                                )
                              : Image.network(
                                  admin.qrPngUrl(cp.id),
                                  errorBuilder: (_, _, _) =>
                                      const Icon(Icons.qr_code, color: kAccent),
                                ),
                        ),
                        title: Text(cp.label),
                        subtitle: Text(
                          '${cp.lat.toStringAsFixed(5)}, ${cp.lng.toStringAsFixed(5)}',
                        ),
                        trailing: IconButton(
                          icon: const Icon(Icons.qr_code_scanner,
                              color: kAccent),
                          tooltip: 'Scan to confirm',
                          onPressed: () => _confirmByScan(cp),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

/// Overview map for admins/staff — shows every checkpoint and edge recorded
/// so far ("till now"), not just the ones dropped in the current walk-mode
/// session. Read-only: use "Drop checkpoint here" to add new ones.
///
/// Labels are shown on tap rather than always-on: with 15+ checkpoints only
/// tens of metres apart, permanently drawn text labels overlap into an
/// unreadable smear. Tapping a marker reveals just that one name instead.
class CampusOverviewMap extends StatefulWidget {
  const CampusOverviewMap({super.key, required this.repo});

  final CampusRepository repo;

  @override
  State<CampusOverviewMap> createState() => _CampusOverviewMapState();
}

class _CampusOverviewMapState extends State<CampusOverviewMap> {
  Checkpoint? _selected;

  @override
  Widget build(BuildContext context) {
    final checkpoints = widget.repo.checkpoints;
    final center = checkpoints.isEmpty
        ? widget.repo.campusCenter
        : LatLng(
            checkpoints.map((c) => c.lat).reduce((a, b) => a + b) / checkpoints.length,
            checkpoints.map((c) => c.lng).reduce((a, b) => a + b) / checkpoints.length,
          );

    return Scaffold(
      appBar: AppBar(title: Text('All checkpoints (${checkpoints.length})')),
      body: checkpoints.isEmpty
          ? Center(
              child: Text('No checkpoints recorded yet.',
                  style: TextStyle(color: context.palette.textMuted)),
            )
          : Stack(
              children: [
                FlutterMap(
                  options: MapOptions(
                    initialCenter: center,
                    initialZoom: 16.5,
                    onTap: (_, _) => setState(() => _selected = null),
                  ),
                  children: [
                    buildTileLayer(),
                    MarkerLayer(
                      markers: [
                        for (final cp in checkpoints)
                          Marker(
                            point: LatLng(cp.lat, cp.lng),
                            width: 32,
                            height: 32,
                            child: GestureDetector(
                              onTap: () => setState(() => _selected = cp),
                              child: Icon(Icons.location_on,
                                  color: _selected?.id == cp.id ? Colors.redAccent : kAccent,
                                  size: 28),
                            ),
                          ),
                      ],
                    ),
                    buildMapAttribution(),
                  ],
                ),
                if (_selected != null)
                  Positioned(
                    left: 12,
                    right: 12,
                    bottom: 16,
                    child: Card(
                      child: ListTile(
                        leading: const Icon(Icons.location_on, color: kAccent),
                        title: Text(_selected!.label),
                        subtitle: Text(
                          '${_selected!.lat.toStringAsFixed(5)}, ${_selected!.lng.toStringAsFixed(5)}',
                        ),
                        trailing: IconButton(
                          icon: const Icon(Icons.close),
                          onPressed: () => setState(() => _selected = null),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
    );
  }
}
