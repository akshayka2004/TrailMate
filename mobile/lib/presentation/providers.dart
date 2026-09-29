import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';

import '../data/api_client.dart';
import '../data/campus_repository.dart';
import '../data/sync_cache.dart';

/// Light/dark toggle — defaults to dark, matching the app's original design.
final themeModeProvider = StateProvider<ThemeMode>((ref) => ThemeMode.dark);

final apiClientProvider = Provider<ApiClient>((ref) => ApiClient.create());

/// Set once at startup after Hive opens the box.
final syncCacheProvider = Provider<SyncCache>(
  (ref) => throw UnimplementedError('SyncCache must be overridden at startup'),
);

final authApiProvider = Provider<AuthApi>(
  (ref) => AuthApi(ref.watch(apiClientProvider)),
);

/// The logged-in user's role (admin/staff/student), used purely for UI
/// gating (e.g. hiding walk-mode from students) — the backend is the real
/// authority and re-checks role on every write regardless.
final currentRoleProvider = FutureProvider<String?>(
  (ref) => ref.watch(apiClientProvider).getRole(),
);

final adminApiProvider = Provider<AdminApi>(
  (ref) => AdminApi(ref.watch(apiClientProvider), ref.watch(campusRepositoryProvider)),
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
