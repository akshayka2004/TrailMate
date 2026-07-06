import 'dart:collection';

import 'package:dio/dio.dart';
import 'package:latlong2/latlong.dart';

import '../domain/models.dart';
import 'api_client.dart';
import 'sync_cache.dart';

/// Owns the campus dataset and routing. Online it pulls /sync/snapshot and
/// /route; offline it serves the cached snapshot and computes routes with a
/// client-side shortest-path search (Dijkstra) over the cached graph.
///
/// Offline strategy (Phase 6 decision): client-side pathfinding over the
/// cached graph — not precomputed routes — so any origin/destination pair
/// works without a round trip.
class CampusRepository {
  CampusRepository(this._api, this._cache);

  final ApiClient _api;
  final SyncCache _cache;

  List<Building> buildings = [];
  List<Room> rooms = [];
  List<Department> departments = [];
  List<Checkpoint> checkpoints = [];
  // adjacency: checkpointId -> list of (neighborId, distance, timeSec)
  final Map<int, List<(int, double, int)>> _adj = {};
  bool loadedFromCache = false;

  Future<void> load() async {
    Map<String, dynamic>? snapshot;
    try {
      final resp = await _api.dio.get('/sync/snapshot');
      snapshot = resp.data as Map<String, dynamic>;
      await _cache.save(snapshot);
      loadedFromCache = false;
    } catch (_) {
      snapshot = _cache.snapshot;
      loadedFromCache = true;
      if (snapshot == null) rethrow;
    }
    _ingest(snapshot);
  }

  /// Ingest a snapshot payload directly (used by tests and offline seeding).
  void ingestSnapshot(Map<String, dynamic> snapshot) => _ingest(snapshot);

  void _ingest(Map<String, dynamic> snapshot) {
    final graph = snapshot['graph'] as Map<String, dynamic>;
    buildings = (graph['buildings'] as List)
        .map((e) => Building.fromJson(e as Map<String, dynamic>))
        .toList();
    rooms = (graph['rooms'] as List)
        .map((e) => Room.fromJson(e as Map<String, dynamic>))
        .toList();
    departments = (graph['departments'] as List)
        .map((e) => Department.fromJson(e as Map<String, dynamic>))
        .toList();
    checkpoints = (graph['checkpoints'] as List)
        .map((e) => Checkpoint.fromJson(e as Map<String, dynamic>))
        .toList();

    _adj.clear();
    for (final cp in checkpoints) {
      _adj[cp.id] = [];
    }
    for (final e in graph['edges'] as List) {
      final m = e as Map<String, dynamic>;
      final a = m['checkpoint_a_id'] as int;
      final b = m['checkpoint_b_id'] as int;
      final dist = (m['distance_meters'] as num).toDouble();
      final t = m['walking_time_estimate_sec'] as int;
      _adj[a]?.add((b, dist, t));
      _adj[b]?.add((a, dist, t)); // undirected
    }
  }

  List<SearchHit> search(String query) {
    final q = query.trim().toLowerCase();
    if (q.isEmpty) return [];
    final buildingById = {for (final b in buildings) b.id: b};
    final hits = <SearchHit>[];

    for (final b in buildings) {
      if (b.name.toLowerCase().contains(q)) {
        hits.add(SearchHit(
          title: b.name,
          subtitle: 'Building',
          lat: b.lat,
          lng: b.lng,
        ));
      }
    }
    for (final r in rooms) {
      if (r.name.toLowerCase().contains(q)) {
        final b = buildingById[r.buildingId];
        if (b != null) {
          hits.add(SearchHit(
            title: r.name,
            subtitle: '${r.type.replaceAll('_', ' ')} · ${b.name}',
            lat: b.lat,
            lng: b.lng,
          ));
        }
      }
    }
    for (final d in departments) {
      if (d.name.toLowerCase().contains(q)) {
        final b = buildingById[d.buildingId];
        if (b != null) {
          hits.add(SearchHit(
            title: d.name,
            subtitle: 'Department · ${b.name}',
            lat: b.lat,
            lng: b.lng,
          ));
        }
      }
    }
    return hits;
  }

  Checkpoint? nearestCheckpoint(double lat, double lng) {
    if (checkpoints.isEmpty) return null;
    const distance = Distance();
    Checkpoint? best;
    double bestD = double.infinity;
    final from = LatLng(lat, lng);
    for (final cp in checkpoints) {
      final d = distance(from, LatLng(cp.lat, cp.lng));
      if (d < bestD) {
        bestD = d;
        best = cp;
      }
    }
    return best;
  }

  /// Route between two checkpoints. Tries the backend; on any failure falls
  /// back to a local Dijkstra over the cached graph.
  Future<RouteResult> route(int fromId, int toId) async {
    try {
      final resp = await _api.dio
          .get('/route', queryParameters: {'from_id': fromId, 'to_id': toId});
      return RouteResult.fromJson(resp.data as Map<String, dynamic>);
    } catch (_) {
      return routeOffline(fromId, toId);
    }
  }

  /// Client-side shortest path over the cached graph (Dijkstra). Used as the
  /// offline fallback and directly unit-tested.
  RouteResult routeOffline(int fromId, int toId) {
    final cpById = {for (final c in checkpoints) c.id: c};
    if (!cpById.containsKey(fromId) || !cpById.containsKey(toId)) {
      throw StateError('Unknown checkpoint');
    }
    if (fromId == toId) {
      final c = cpById[fromId]!;
      return RouteResult(
        steps: [RouteStep(checkpointId: c.id, label: c.label, lat: c.lat, lng: c.lng)],
        totalDistanceMeters: 0,
        totalTimeSeconds: 0,
      );
    }

    final dist = <int, double>{for (final c in checkpoints) c.id: double.infinity};
    final prev = <int, int>{};
    final timeTo = <int, int>{for (final c in checkpoints) c.id: 0};
    dist[fromId] = 0;

    // Simple priority queue via SplayTreeSet keyed on (distance, id).
    final pq = SplayTreeSet<(double, int)>((a, b) {
      final c = a.$1.compareTo(b.$1);
      return c != 0 ? c : a.$2.compareTo(b.$2);
    });
    pq.add((0, fromId));

    while (pq.isNotEmpty) {
      final current = pq.first;
      pq.remove(current);
      final u = current.$2;
      if (u == toId) break;
      if (current.$1 > dist[u]!) continue;
      for (final (v, w, t) in _adj[u] ?? const <(int, double, int)>[]) {
        final nd = dist[u]! + w;
        if (nd < dist[v]!) {
          pq.remove((dist[v]!, v));
          dist[v] = nd;
          timeTo[v] = timeTo[u]! + t;
          prev[v] = u;
          pq.add((nd, v));
        }
      }
    }

    if (dist[toId] == double.infinity) {
      throw StateError('No route');
    }

    final path = <int>[];
    int? cur = toId;
    while (cur != null) {
      path.insert(0, cur);
      cur = prev[cur];
    }
    final steps = path.map((id) {
      final c = cpById[id]!;
      return RouteStep(checkpointId: c.id, label: c.label, lat: c.lat, lng: c.lng);
    }).toList();

    return RouteResult(
      steps: steps,
      totalDistanceMeters: (dist[toId]! * 100).roundToDouble() / 100,
      totalTimeSeconds: timeTo[toId]!,
    );
  }

  Checkpoint? checkpointByPayload(String payload) {
    // QR payload format from the backend: "TRAILMATE:CP:<id>".
    final match = RegExp(r'^TRAILMATE:CP:(\d+)$').firstMatch(payload.trim());
    if (match == null) return null;
    final id = int.parse(match.group(1)!);
    for (final c in checkpoints) {
      if (c.id == id) return c;
    }
    return null;
  }

  double haversine(LatLng a, LatLng b) => const Distance()(a, b);

  /// Mean of all checkpoint coordinates — used to center the map initially.
  LatLng get campusCenter {
    if (checkpoints.isEmpty) return const LatLng(9.5132, 76.5423);
    final lat = checkpoints.map((c) => c.lat).reduce((a, b) => a + b) /
        checkpoints.length;
    final lng = checkpoints.map((c) => c.lng).reduce((a, b) => a + b) /
        checkpoints.length;
    return LatLng(lat, lng);
  }
}

/// Auth calls kept separate from the campus data concern.
class AuthApi {
  AuthApi(this._api);
  final ApiClient _api;

  Future<void> login(String email, String password) async {
    final resp = await _api.dio.post(
      '/auth/login',
      data: {'username': email, 'password': password},
      options: Options(contentType: Headers.formUrlEncodedContentType),
    );
    await _api.saveTokens(
      resp.data['access_token'] as String,
      resp.data['refresh_token'] as String,
    );
  }

  Future<void> logout() => _api.clearTokens();
  Future<bool> isLoggedIn() => _api.hasToken();
}

/// Admin walk-mode calls: drop a checkpoint at the current GPS location,
/// mint its QR, and connect it to the previous drop (Phase 7).
class AdminApi {
  AdminApi(this._api);
  final ApiClient _api;

  Future<Checkpoint> createCheckpoint(
    String label,
    double lat,
    double lng, {
    int? buildingId,
  }) async {
    final resp = await _api.dio.post('/checkpoints', data: {
      'label': label,
      'lat': lat,
      'lng': lng,
      'building_id': buildingId,
    });
    return Checkpoint.fromJson(resp.data as Map<String, dynamic>);
  }

  Future<void> generateQr(int checkpointId) =>
      _api.dio.post('/checkpoints/$checkpointId/qr');

  String qrPngUrl(int checkpointId) =>
      '$kApiBaseUrl/checkpoints/$checkpointId/qr.png';

  Future<void> connectEdge(
    int aId,
    int bId,
    double distanceMeters, {
    bool indoor = false,
  }) async {
    await _api.dio.post('/edges', data: {
      'checkpoint_a_id': aId,
      'checkpoint_b_id': bId,
      'distance_meters': (distanceMeters * 10).roundToDouble() / 10,
      'walking_time_estimate_sec': (distanceMeters / 1.4).ceil().clamp(1, 1 << 30),
      'is_indoor': indoor,
    });
  }
}
