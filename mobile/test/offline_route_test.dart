import 'package:flutter_test/flutter_test.dart';
import 'package:trailmate/data/api_client.dart';
import 'package:trailmate/data/campus_repository.dart';
import 'package:trailmate/data/sync_cache.dart';

/// Offline Dijkstra tests over a synthetic snapshot — no backend, no Hive box.
class _FakeCache implements SyncCache {
  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

CampusRepository _repo() =>
    CampusRepository(ApiClient.create(), _FakeCache());

Map<String, dynamic> _snapshot() => {
      'version': 1,
      'graph': {
        'buildings': [
          {'id': 1, 'name': 'CS Block', 'description': null, 'lat': 9.5, 'lng': 76.5},
        ],
        'departments': [],
        'rooms': [
          {'id': 1, 'name': 'CS-101', 'type': 'classroom', 'floor': 1, 'building_id': 1},
        ],
        'checkpoints': [
          {'id': 1, 'label': 'A', 'lat': 9.5000, 'lng': 76.5000, 'building_id': null},
          {'id': 2, 'label': 'B', 'lat': 9.5010, 'lng': 76.5000, 'building_id': null},
          {'id': 3, 'label': 'C', 'lat': 9.5020, 'lng': 76.5000, 'building_id': 1},
          {'id': 4, 'label': 'Island', 'lat': 9.6, 'lng': 76.6, 'building_id': null},
        ],
        'edges': [
          {'checkpoint_a_id': 1, 'checkpoint_b_id': 2, 'distance_meters': 100.0, 'walking_time_estimate_sec': 71, 'is_indoor': false},
          {'checkpoint_a_id': 2, 'checkpoint_b_id': 3, 'distance_meters': 50.0, 'walking_time_estimate_sec': 36, 'is_indoor': false},
          {'checkpoint_a_id': 1, 'checkpoint_b_id': 3, 'distance_meters': 500.0, 'walking_time_estimate_sec': 357, 'is_indoor': false},
        ],
      },
    };

void main() {
  test('offline route picks the cheaper chain over the costly direct edge', () {
    final repo = _repo()..ingestSnapshot(_snapshot());
    final route = repo.routeOffline(1, 3);
    expect(route.steps.map((s) => s.checkpointId).toList(), [1, 2, 3]);
    expect(route.totalDistanceMeters, 150.0);
    expect(route.totalTimeSeconds, 107);
  });

  test('same start and end is zero length', () {
    final repo = _repo()..ingestSnapshot(_snapshot());
    final route = repo.routeOffline(2, 2);
    expect(route.steps.length, 1);
    expect(route.totalDistanceMeters, 0);
  });

  test('disconnected destination throws', () {
    final repo = _repo()..ingestSnapshot(_snapshot());
    expect(() => repo.routeOffline(1, 4), throwsStateError);
  });

  test('search matches buildings and rooms', () {
    final repo = _repo()..ingestSnapshot(_snapshot());
    expect(repo.search('cs').length, greaterThanOrEqualTo(2)); // CS Block + CS-101
    expect(repo.search('nope'), isEmpty);
  });

  test('QR payload resolves to a checkpoint', () {
    final repo = _repo()..ingestSnapshot(_snapshot());
    expect(repo.checkpointByPayload('TRAILMATE:CP:3')?.label, 'C');
    expect(repo.checkpointByPayload('garbage'), isNull);
  });
}
