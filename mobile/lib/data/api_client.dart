import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// API base URL. Override at build time:
///   flutter run --dart-define=API_BASE_URL=http://10.0.2.2:8000
/// (10.0.2.2 is the host loopback from the Android emulator.)
const String kApiBaseUrl =
    String.fromEnvironment('API_BASE_URL', defaultValue: 'http://localhost:8000');

/// Reads the `role` claim out of a JWT access token without verifying its
/// signature — the backend is the actual authority on role, this is purely
/// so the UI can show/hide admin-only actions (e.g. walk-mode) without an
/// extra round trip. Never trust this for anything security-sensitive.
String? decodeRoleFromJwt(String token) {
  try {
    final parts = token.split('.');
    if (parts.length != 3) return null;
    final payload = utf8.decode(base64Url.decode(base64Url.normalize(parts[1])));
    final map = jsonDecode(payload) as Map<String, dynamic>;
    return map['role'] as String?;
  } catch (_) {
    return null;
  }
}

class ApiClient {
  ApiClient._(this.dio, this._storage);

  final Dio dio;
  final FlutterSecureStorage _storage;

  static const _accessKey = 'access_token';
  static const _refreshKey = 'refresh_token';
  static const _roleKey = 'role';

  factory ApiClient.create() {
    const storage = FlutterSecureStorage();
    final dio = Dio(BaseOptions(
      baseUrl: kApiBaseUrl,
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 10),
    ));
    final client = ApiClient._(dio, storage);
    dio.interceptors.add(InterceptorsWrapper(
      onRequest: (options, handler) async {
        final token = await storage.read(key: _accessKey);
        if (token != null) {
          options.headers['Authorization'] = 'Bearer $token';
        }
        handler.next(options);
      },
      onError: (e, handler) async {
        // On 401, try one refresh then replay the original request.
        if (e.response?.statusCode == 401 &&
            e.requestOptions.extra['retried'] != true) {
          final refreshed = await client._tryRefresh();
          if (refreshed) {
            final opts = e.requestOptions;
            opts.extra['retried'] = true;
            final token = await storage.read(key: _accessKey);
            opts.headers['Authorization'] = 'Bearer $token';
            try {
              final clone = await dio.fetch(opts);
              return handler.resolve(clone);
            } catch (err) {
              return handler.next(err as DioException);
            }
          }
        }
        handler.next(e);
      },
    ));
    return client;
  }

  Future<bool> _tryRefresh() async {
    final refresh = await _storage.read(key: _refreshKey);
    if (refresh == null) return false;
    try {
      final resp = await Dio(BaseOptions(baseUrl: kApiBaseUrl)).post(
        '/auth/refresh',
        data: {'refresh_token': refresh},
      );
      final access = resp.data['access_token'] as String;
      await saveTokens(access, resp.data['refresh_token'] as String);
      final role = decodeRoleFromJwt(access);
      if (role != null) await saveRole(role);
      return true;
    } catch (_) {
      await clearTokens();
      return false;
    }
  }

  Future<void> saveTokens(String access, String refresh) async {
    await _storage.write(key: _accessKey, value: access);
    await _storage.write(key: _refreshKey, value: refresh);
  }

  Future<void> saveRole(String role) async {
    await _storage.write(key: _roleKey, value: role);
  }

  Future<String?> getRole() => _storage.read(key: _roleKey);

  Future<void> clearTokens() async {
    await _storage.delete(key: _accessKey);
    await _storage.delete(key: _refreshKey);
    await _storage.delete(key: _roleKey);
  }

  Future<bool> hasToken() async =>
      (await _storage.read(key: _accessKey)) != null;
}
