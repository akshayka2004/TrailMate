import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';

import '../data/campus_repository.dart';
import '../data/demo_data.dart';
import '../domain/models.dart';
import 'map_screen.dart';
import 'providers.dart';
import 'theme.dart';
import 'walk_mode_screen.dart' show WalkModeScreen, CampusOverviewMap;

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  String _query = '';
  final _searchController = TextEditingController();

  // On-campus check: null = not yet determined, true/false = result.
  bool? _onCampus;
  double? _distanceFromCampusM;
  bool _locationChecked = false;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _checkOnCampus(CampusRepository repo) async {
    if (_locationChecked) return;
    _locationChecked = true;
    try {
      final enabled = await Geolocator.isLocationServiceEnabled();
      if (!enabled) return;
      var perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) {
        perm = await Geolocator.requestPermission();
      }
      if (perm == LocationPermission.denied || perm == LocationPermission.deniedForever) {
        return;
      }
      final pos = await Geolocator.getCurrentPosition().timeout(const Duration(seconds: 6));
      final center = repo.campusCenter;
      final distance = repo.haversine(LatLng(pos.latitude, pos.longitude), center);
      if (!mounted) return;
      setState(() {
        _distanceFromCampusM = distance;
        _onCampus = distance <= kCampusRadiusMeters;
      });
    } catch (_) {
      // Location unavailable — silently skip the banner rather than
      // blocking the home screen over a non-essential check.
    }
  }

  @override
  Widget build(BuildContext context) {
    final load = ref.watch(campusLoadProvider);
    final roleAsync = ref.watch(currentRoleProvider);
    final canManageCampus = roleAsync.maybeWhen(
      data: (role) => role == 'admin' || role == 'staff',
      orElse: () => false,
    );

    return Scaffold(
      appBar: AppBar(
        title: const Text('TrailMate'),
        actions: [
          if (canManageCampus) ...[
            IconButton(
              tooltip: 'View all checkpoints',
              icon: const Icon(Icons.map_outlined),
              onPressed: () {
                final repo = ref.read(campusLoadProvider).value;
                if (repo == null) return;
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => CampusOverviewMap(repo: repo)),
                );
              },
            ),
            IconButton(
              tooltip: 'Admin walk mode',
              icon: const Icon(Icons.add_location_alt_outlined),
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const WalkModeScreen()),
              ),
            ),
          ],
          Builder(
            builder: (context) {
              final mode = ref.watch(themeModeProvider);
              final isDark = mode == ThemeMode.dark;
              return IconButton(
                tooltip: isDark ? 'Switch to light mode' : 'Switch to dark mode',
                icon: Icon(isDark ? Icons.light_mode_outlined : Icons.dark_mode_outlined),
                onPressed: () => ref.read(themeModeProvider.notifier).state =
                    isDark ? ThemeMode.light : ThemeMode.dark,
              );
            },
          ),
          IconButton(
            tooltip: 'Sign out',
            icon: const Icon(Icons.logout),
            onPressed: () async {
              await ref.read(authApiProvider).logout();
              if (context.mounted) Navigator.of(context).maybePop();
            },
          ),
        ],
      ),
      body: load.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => _ErrorState(
          message: 'Could not load campus data and no offline cache exists.',
          detail: '$e',
          onRetry: () => ref.invalidate(campusLoadProvider),
        ),
        data: (repo) {
          _checkOnCampus(repo);
          // Default view (no search yet) lists every building so the user
          // sees available destinations immediately after login, instead of
          // a blank "search to navigate" placeholder they have to type past.
          final hits = _query.isEmpty
              ? [
                  for (final b in repo.buildings)
                    SearchHit(title: b.name, subtitle: 'Building', lat: b.lat, lng: b.lng),
                ]
              : repo.search(_query);
          return Column(
            children: [
              if (repo.isDemoData)
                const _StatusBanner(
                  icon: Icons.info_outline,
                  text: 'Demo mode — showing sample campus data (no live connection)',
                )
              else if (repo.loadedFromCache)
                const _StatusBanner(
                  icon: Icons.cloud_off_outlined,
                  text: 'Offline — showing last synced campus data',
                ),
              if (_onCampus != null)
                _StatusBanner(
                  icon: _onCampus! ? Icons.school_outlined : Icons.explore_off_outlined,
                  text: _onCampus!
                      ? 'You appear to be on campus'
                      : 'You appear to be off campus '
                        '(~${(_distanceFromCampusM! / 1000).toStringAsFixed(1)} km away)',
                ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                child: TextField(
                  controller: _searchController,
                  autofocus: false,
                  decoration: InputDecoration(
                    prefixIcon: Icon(Icons.search, color: context.palette.textMuted),
                    hintText: 'Search buildings, rooms, departments',
                    suffixIcon: _query.isEmpty
                        ? null
                        : IconButton(
                            icon: Icon(Icons.close, color: context.palette.textMuted),
                            onPressed: () {
                              _searchController.clear();
                              setState(() => _query = '');
                            },
                          ),
                  ),
                  onChanged: (v) => setState(() => _query = v),
                ),
              ),
              Expanded(
                child: hits.isEmpty
                    ? (_query.isEmpty
                        ? _Placeholder(count: repo.checkpoints.length)
                        : const _NoResults())
                    : ListView.separated(
                        padding: const EdgeInsets.only(bottom: 8),
                        itemCount: hits.length,
                        separatorBuilder: (_, _) =>
                            const Divider(height: 1, indent: 16, endIndent: 16),
                        itemBuilder: (_, i) => _HitTile(
                          hit: hits[i],
                          onTap: () => _navigateTo(repo, hits[i]),
                        ),
                      ),
              ),
            ],
          );
        },
      ),
    );
  }

  void _navigateTo(CampusRepository repo, SearchHit hit) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => MapScreen(
          destination: LatLng(hit.lat, hit.lng),
          destinationLabel: hit.title,
        ),
      ),
    );
  }
}

class _StatusBanner extends StatelessWidget {
  const _StatusBanner({required this.icon, required this.text});
  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      color: context.palette.surface,
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 14, color: kAccent),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              text,
              textAlign: TextAlign.center,
              style: const TextStyle(color: kAccent, fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }
}

class _HitTile extends StatelessWidget {
  const _HitTile({required this.hit, required this.onTap});
  final SearchHit hit;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return ListTile(
      leading: CircleAvatar(
        backgroundColor: palette.surface,
        child: const Icon(Icons.place_outlined, color: kAccent, size: 20),
      ),
      title: Text(hit.title, style: const TextStyle(fontWeight: FontWeight.w600)),
      subtitle: Text(hit.subtitle, style: TextStyle(color: palette.textMuted)),
      trailing: Icon(Icons.chevron_right, color: palette.textFaint),
      onTap: onTap,
    );
  }
}

class _Placeholder extends StatelessWidget {
  const _Placeholder({required this.count});
  final int count;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.map_outlined, size: 48, color: palette.divider),
          const SizedBox(height: 12),
          Text(
            'Search to navigate.\n$count checkpoints loaded.',
            textAlign: TextAlign.center,
            style: TextStyle(color: palette.textMuted),
          ),
        ],
      ),
    );
  }
}

class _NoResults extends StatelessWidget {
  const _NoResults();

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.search_off, size: 40, color: palette.divider),
          const SizedBox(height: 10),
          Text('No matches found', style: TextStyle(color: palette.textMuted)),
        ],
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.message, required this.detail, required this.onRetry});
  final String message;
  final String detail;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.wifi_off_rounded, size: 40, color: palette.divider),
            const SizedBox(height: 12),
            Text(message, textAlign: TextAlign.center,
                style: TextStyle(color: palette.textSoft)),
            const SizedBox(height: 6),
            Text(detail, textAlign: TextAlign.center,
                style: TextStyle(color: palette.textFaint, fontSize: 11)),
            const SizedBox(height: 16),
            OutlinedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh, size: 18),
              label: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }
}
