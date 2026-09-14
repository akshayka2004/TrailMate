import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';

import '../data/campus_repository.dart';
import '../domain/models.dart';
import 'map_screen.dart';
import 'providers.dart';
import 'theme.dart';
import 'walk_mode_screen.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  String _query = '';
  final _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final load = ref.watch(campusLoadProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('TrailMate'),
        actions: [
          IconButton(
            tooltip: 'Admin walk mode',
            icon: const Icon(Icons.add_location_alt_outlined),
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const WalkModeScreen()),
            ),
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
          final hits = repo.search(_query);
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
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                child: TextField(
                  controller: _searchController,
                  autofocus: false,
                  decoration: InputDecoration(
                    prefixIcon: const Icon(Icons.search, color: Colors.white54),
                    hintText: 'Search buildings, rooms, departments',
                    suffixIcon: _query.isEmpty
                        ? null
                        : IconButton(
                            icon: const Icon(Icons.close, color: Colors.white54),
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
                child: _query.isEmpty
                    ? _Placeholder(count: repo.checkpoints.length)
                    : hits.isEmpty
                        ? const _NoResults()
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
      color: kSecondary,
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
    return ListTile(
      leading: const CircleAvatar(
        backgroundColor: kSecondary,
        child: Icon(Icons.place_outlined, color: kAccent, size: 20),
      ),
      title: Text(hit.title, style: const TextStyle(fontWeight: FontWeight.w600)),
      subtitle: Text(hit.subtitle, style: const TextStyle(color: Colors.white54)),
      trailing: const Icon(Icons.chevron_right, color: Colors.white38),
      onTap: onTap,
    );
  }
}

class _Placeholder extends StatelessWidget {
  const _Placeholder({required this.count});
  final int count;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.map_outlined, size: 48, color: kMuted),
          const SizedBox(height: 12),
          Text(
            'Search to navigate.\n$count checkpoints loaded.',
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.white54),
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
    return const Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.search_off, size: 40, color: kMuted),
          SizedBox(height: 10),
          Text('No matches found', style: TextStyle(color: Colors.white54)),
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
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.wifi_off_rounded, size: 40, color: kMuted),
            const SizedBox(height: 12),
            Text(message, textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white70)),
            const SizedBox(height: 6),
            Text(detail, textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white38, fontSize: 11)),
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
