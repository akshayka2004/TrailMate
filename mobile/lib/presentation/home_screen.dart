import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';

import '../data/campus_repository.dart';
import '../domain/models.dart';
import 'map_screen.dart';
import 'providers.dart';
import 'theme.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final load = ref.watch(campusLoadProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('TrailMate'),
        actions: [
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
        error: (e, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text(
              'Could not load campus data and no offline cache exists.\n\n$e',
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white70),
            ),
          ),
        ),
        data: (repo) {
          final hits = repo.search(_query);
          return Column(
            children: [
              if (repo.loadedFromCache)
                Container(
                  width: double.infinity,
                  color: kSecondary,
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: const Text(
                    'Offline — showing cached campus data',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: kAccent, fontSize: 12),
                  ),
                ),
              Padding(
                padding: const EdgeInsets.all(16),
                child: TextField(
                  autofocus: false,
                  decoration: const InputDecoration(
                    prefixIcon: Icon(Icons.search),
                    hintText: 'Search buildings, rooms, departments',
                  ),
                  onChanged: (v) => setState(() => _query = v),
                ),
              ),
              Expanded(
                child: _query.isEmpty
                    ? _Placeholder(count: repo.checkpoints.length)
                    : ListView.separated(
                        itemCount: hits.length,
                        separatorBuilder: (_, _) =>
                            const Divider(height: 1, color: kMuted),
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

class _HitTile extends StatelessWidget {
  const _HitTile({required this.hit, required this.onTap});
  final SearchHit hit;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: const Icon(Icons.place_outlined, color: kAccent),
      title: Text(hit.title),
      subtitle: Text(hit.subtitle),
      trailing: const Icon(Icons.directions, color: kAccent),
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
