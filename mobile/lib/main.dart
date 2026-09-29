import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:hive_flutter/hive_flutter.dart';

import 'data/sync_cache.dart';
import 'presentation/home_screen.dart';
import 'presentation/login_screen.dart';
import 'presentation/providers.dart';
import 'presentation/theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Hive.initFlutter();
  final cache = await SyncCache.open();

  runApp(
    ProviderScope(
      overrides: [syncCacheProvider.overrideWithValue(cache)],
      child: const TrailMateApp(),
    ),
  );
}

class TrailMateApp extends ConsumerWidget {
  const TrailMateApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return MaterialApp(
      title: 'TrailMate',
      debugShowCheckedModeBanner: false,
      theme: buildTheme(Brightness.light),
      darkTheme: buildTheme(Brightness.dark),
      themeMode: ref.watch(themeModeProvider),
      home: const _AuthGate(),
    );
  }
}

class _AuthGate extends ConsumerStatefulWidget {
  const _AuthGate();

  @override
  ConsumerState<_AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends ConsumerState<_AuthGate> {
  @override
  void initState() {
    super.initState();
    // Ask for location up front, on app launch, rather than waiting until
    // the home/map screens first need a GPS fix — so the OS permission
    // dialog (with the Android 12+ precise/approximate choice) shows once,
    // early, instead of surprising the user mid-navigation later.
    _requestLocationUpFront();
  }

  Future<void> _requestLocationUpFront() async {
    try {
      if (!await Geolocator.isLocationServiceEnabled()) return;
      final perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) {
        await Geolocator.requestPermission();
      }
    } catch (_) {
      // Non-fatal — home/map screens re-check and degrade gracefully.
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<bool>(
      future: ref.read(authApiProvider).isLoggedIn(),
      builder: (context, snap) {
        if (!snap.hasData) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        return snap.data! ? const HomeScreen() : const LoginScreen();
      },
    );
  }
}
