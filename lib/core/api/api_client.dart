// lib/core/api/api_client.dart
// Dio HTTP client dengan JWT interceptor

import 'dart:async';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import '../constants/app_constants.dart';
import '../secure_storage/secure_storage_service.dart';

class ApiClient {
  final Dio _dio;

  ApiClient({required SecureStorageService secureStorage})
      : _dio = Dio(_buildBaseOptions()) {
    _dio.interceptors.add(_AuthInterceptor(secureStorage, _dio));
    _dio.interceptors.add(LogInterceptor(
      requestBody: true,
      responseBody: false,
      logPrint: (o) => debugPrint('[API] $o'),
    ));
  }

  static BaseOptions _buildBaseOptions() {
    return BaseOptions(
      baseUrl: AppConstants.baseUrl,
      connectTimeout: AppConstants.connectTimeout,
      receiveTimeout: AppConstants.receiveTimeout,
      headers: {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      },
    );
  }

  // ─── HTTP Methods ─────────────────────────────────────────────────────────

  Future<Response<T>> get<T>(
    String path, {
    Map<String, dynamic>? queryParameters,
  }) {
    return _dio.get<T>(path, queryParameters: queryParameters);
  }

  Future<Response<T>> post<T>(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
  }) {
    return _dio.post<T>(path, data: data, queryParameters: queryParameters);
  }

  Future<Response<T>> put<T>(
    String path, {
    dynamic data,
  }) {
    return _dio.put<T>(path, data: data);
  }

  Future<Response<T>> delete<T>(String path) {
    return _dio.delete<T>(path);
  }
}

// ─── Auth Interceptor ────────────────────────────────────────────────────────

class _AuthInterceptor extends Interceptor {
  final SecureStorageService _secureStorage;
  final Dio _dio;

  // Mutex to prevent concurrent token refresh attempts
  bool _isRefreshing = false;
  final List<Completer<bool>> _pendingRequests = [];

  _AuthInterceptor(this._secureStorage, this._dio);

  @override
  void onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    // Skip auth header untuk endpoints publik — use exact match
    const publicPaths = {
      '/api/v1/auth/register',
      '/api/v1/auth/login',
      '/api/v1/auth/refresh',
      '/health',
      '/docs',
    };

    final isPublic = publicPaths.contains(options.path);

    if (!isPublic) {
      final token = await _secureStorage.getAccessToken();
      if (token != null) {
        options.headers['Authorization'] = 'Bearer $token';
      }
    }

    handler.next(options);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) async {
    if (err.response?.statusCode == 401) {
      final refreshed = await _tryRefreshToken();
      if (refreshed) {
        // Retry original request using the same Dio instance (preserves interceptors)
        final opts = err.requestOptions;
        final token = await _secureStorage.getAccessToken();
        opts.headers['Authorization'] = 'Bearer $token';
        try {
          final response = await _dio.fetch(opts);
          return handler.resolve(response);
        } catch (e) {
          return handler.next(err);
        }
      }
      // Refresh failed — notify queued requests
      _notifyRefreshFailed();
    }
    handler.next(err);
  }

  Future<bool> _tryRefreshToken() async {
    if (_isRefreshing) {
      // Wait for the ongoing refresh to complete
      final completer = Completer<bool>();
      _pendingRequests.add(completer);
      return completer.future;
    }

    _isRefreshing = true;
    try {
      final refreshToken = await _secureStorage.getRefreshToken();
      if (refreshToken == null) return false;

      final response = await _dio.post('/api/v1/auth/refresh', data: {
        'refresh_token': refreshToken,
      });

      if (response.statusCode == 200) {
        final newAccessToken = response.data['access_token'];
        await _secureStorage.saveAccessToken(newAccessToken);
        _resolvePendingRequests();
        return true;
      }
    } catch (e) {
      // Refresh failed — clear tokens so app re-auths
      await _secureStorage.clearTokens();
    } finally {
      _isRefreshing = false;
    }
    return false;
  }

  void _resolvePendingRequests() {
    for (final completer in _pendingRequests) {
      completer.complete(true);
    }
    _pendingRequests.clear();
  }

  void _notifyRefreshFailed() {
    for (final completer in _pendingRequests) {
      completer.complete(false);
    }
    _pendingRequests.clear();
  }
}
