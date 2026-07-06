import 'dart:convert';

import 'package:hive/hive.dart';

/// Offline cache of the full campus snapshot (Phase 6 client half).
///
/// The snapshot JSON from GET /sync/snapshot is stored verbatim in a Hive
/// box, so search and route fallback can run against cached data when the
/// device is offline. Client-side A* over the cached graph is the documented
/// offline strategy; this class owns persistence for it.
class SyncCache {
  static const _boxName = 'trailmate_sync';
  static const _snapshotKey = 'snapshot';
  static const _versionKey = 'version';

  final Box _box;

  SyncCache._(this._box);

  static Future<SyncCache> open() async {
    final box = await Hive.openBox(_boxName);
    return SyncCache._(box);
  }

  int get version => (_box.get(_versionKey) as int?) ?? -1;

  Map<String, dynamic>? get snapshot {
    final raw = _box.get(_snapshotKey) as String?;
    if (raw == null) return null;
    return jsonDecode(raw) as Map<String, dynamic>;
  }

  Future<void> save(Map<String, dynamic> snapshot) async {
    await _box.put(_snapshotKey, jsonEncode(snapshot));
    await _box.put(_versionKey, snapshot['version'] as int? ?? 0);
  }

  bool get hasData => _box.containsKey(_snapshotKey);
}
