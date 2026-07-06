import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/api_client.dart';
import '../data/campus_repository.dart';
import '../data/sync_cache.dart';

final apiClientProvider = Provider<ApiClient>((ref) => ApiClient.create());

/// Set once at startup after Hive opens the box.
final syncCacheProvider = Provider<SyncCache>(
  (ref) => throw UnimplementedError('SyncCache must be overridden at startup'),
);

final authApiProvider = Provider<AuthApi>(
  (ref) => AuthApi(ref.watch(apiClientProvider)),
);

final campusRepositoryProvider = Provider<CampusRepository>(
  (ref) => CampusRepository(
    ref.watch(apiClientProvider),
    ref.watch(syncCacheProvider),
  ),
);

/// Loads the campus snapshot (online or from cache) once, exposing status.
final campusLoadProvider = FutureProvider<CampusRepository>((ref) async {
  final repo = ref.watch(campusRepositoryProvider);
  await repo.load();
  return repo;
});
