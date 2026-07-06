import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';

import '../domain/models.dart';
import 'providers.dart';
import 'scanner_screen.dart';
import 'theme.dart';

/// Phase 7 — admin builds a campus section by walking: drop a checkpoint at
/// the current GPS location, auto-mint its QR, optionally chain an edge to the
/// previous drop, and scan-to-confirm placement. Each drop is pushed to the
/// backend in real time.
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
          _error = 'Location unavailable — enable GPS permission.';
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
      setState(() {
        _dropped.add(cp);
        _busy = false;
      });
    } catch (e) {
      setState(() {
        _busy = false;
        _error = 'Failed to drop checkpoint: $e';
      });
    }
  }

  Future<String?> _askLabel() {
    final controller = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: kSecondary,
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
    return Scaffold(
      appBar: AppBar(title: const Text('Admin walk mode')),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: kAccent,
        foregroundColor: kPrimary,
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
          SwitchListTile(
            value: _chain,
            activeThumbColor: kAccent,
            onChanged: (v) => setState(() => _chain = v),
            title: const Text('Connect to previous checkpoint'),
            subtitle: const Text('Auto-create a walking edge as you go'),
          ),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text(_error!,
                  style: const TextStyle(color: Colors.redAccent)),
            ),
          const Divider(color: kMuted, height: 1),
          Expanded(
            child: _dropped.isEmpty
                ? const Center(
                    child: Text(
                      'Walk the campus and drop checkpoints.\n'
                      'Each is saved with a QR code immediately.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.white54),
                    ),
                  )
                : ListView.builder(
                    itemCount: _dropped.length,
                    itemBuilder: (_, i) {
                      final cp = _dropped[_dropped.length - 1 - i];
                      return ListTile(
                        leading: Image.network(
                          admin.qrPngUrl(cp.id),
                          width: 44,
                          height: 44,
                          errorBuilder: (_, _, _) =>
                              const Icon(Icons.qr_code, color: kAccent),
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
