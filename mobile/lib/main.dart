import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
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
      theme: buildTheme(),
      home: const _AuthGate(),
    );
  }
}

class _AuthGate extends ConsumerWidget {
  const _AuthGate();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
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
