// lib/core/api/api_client.dart
// Dio HTTP client dengan JWT interceptor

import 'package:dio/dio.dart';
import '../constants/app_constants.dart';
import '../secure_storage/secure_storage_service.dart';

class ApiClient {
  final Dio _dio;
  final SecureStorageService _secureStorage;

  ApiClient({required SecureStorageService secureStorage})
      : _secureStorage = secureStorage,
        _dio = Dio(_buildBaseOptions()) {
    _dio.interceptors.add(_AuthInterceptor(secureStorage));
    _dio.interceptors.add(LogInterceptor(
      requestBody: true,
      responseBody: false, // Jangan log response body — bisa ada data sensitif
      logPrint: (o) => print('[API] $o'),
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

  _AuthInterceptor(this._secureStorage);

  @override
  void onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    // Skip auth header untuk endpoints publik
    final publicPaths = [
      '/api/v1/auth/register',
      '/api/v1/auth/login',
      '/api/v1/auth/refresh',
      '/health',
      '/docs',
    ];

    final isPublic = publicPaths.any(
      (path) => options.path.endsWith(path),
    );

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
    // Jika 401 → coba refresh token
    if (err.response?.statusCode == 401) {
      final refreshed = await _tryRefreshToken();
      if (refreshed) {
        // Retry original request
        final opts = err.requestOptions;
        final token = await _secureStorage.getAccessToken();
        opts.headers['Authorization'] = 'Bearer $token';
        try {
          final response = await Dio().fetch(opts);
          return handler.resolve(response);
        } catch (e) {
          return handler.next(err);
        }
      }
    }
    handler.next(err);
  }

  Future<bool> _tryRefreshToken() async {
    try {
      final refreshToken = await _secureStorage.getRefreshToken();
      if (refreshToken == null) return false;

      final dio = Dio(BaseOptions(baseUrl: AppConstants.baseUrl));
      final response = await dio.post('/api/v1/auth/refresh', data: {
        'refresh_token': refreshToken,
      });

      if (response.statusCode == 200) {
        final newAccessToken = response.data['access_token'];
        // Simpan via SecureStorageService public method
        await _secureStorage.saveAccessToken(newAccessToken);
        return true;
      }
    } catch (_) {}
    return false;
  }
}
