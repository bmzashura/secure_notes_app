// lib/data/repositories/auth_repository.dart
// Repository untuk autentikasi: register, login, logout, refresh

import 'package:dio/dio.dart';
import '../../core/api/api_client.dart';
import '../../core/secure_storage/secure_storage_service.dart';
import '../models/models.dart';

class AuthRepository {
  final ApiClient _apiClient;
  final SecureStorageService _secureStorage;

  AuthRepository({
    required ApiClient apiClient,
    required SecureStorageService secureStorage,
  })  : _apiClient = apiClient,
        _secureStorage = secureStorage;

  /// Register akun baru
  Future<AuthTokens> register({
    required String email,
    required String password,
    required String pin,
  }) async {
    try {
      final response = await _apiClient.post(
        '/api/v1/auth/register',
        data: {
          'email': email,
          'password': password,
          'pin': pin,
        },
      );
      final tokens = AuthTokens.fromJson(response.data);
      await _secureStorage.saveTokens(
        accessToken: tokens.accessToken,
        refreshToken: tokens.refreshToken,
        userId: tokens.userId,
      );
      // Simpan master PIN untuk enkripsi semua notes
      await _secureStorage.saveMasterPin(pin);
      return tokens;
    } on DioException catch (e) {
      throw _mapError(e);
    }
  }

  /// Login dengan email + password
  Future<AuthTokens> login({
    required String email,
    required String password,
  }) async {
    try {
      final response = await _apiClient.post(
        '/api/v1/auth/login',
        data: {
          'email': email,
          'password': password,
        },
      );
      final tokens = AuthTokens.fromJson(response.data);
      await _secureStorage.saveTokens(
        accessToken: tokens.accessToken,
        refreshToken: tokens.refreshToken,
        userId: tokens.userId,
      );
      return tokens;
    } on DioException catch (e) {
      throw _mapError(e);
    }
  }

  /// Logout — revoke refresh token on server, then clear local tokens
  Future<void> logout() async {
    try {
      final refreshToken = await _secureStorage.getRefreshToken();
      if (refreshToken != null) {
        await _apiClient.post('/api/v1/auth/logout', data: {
          'refresh_token': refreshToken,
        });
      }
    } finally {
      // Always clear local tokens regardless of API result
      await _secureStorage.clearTokens();
    }
  }

  /// Cek apakah sudah login (only checks token existence — validity
  /// is verified by the API interceptor via 401 + refresh flow)
  Future<bool> isLoggedIn() async {
    final token = await _secureStorage.getAccessToken();
    return token != null;
  }

  /// Verifikasi PIN lokal (untuk lockout screen)
  /// PIN verify via API — return true if valid
  Future<bool> verifyPin(String pin) async {
    try {
      // PIN verify endpoint — endpoint ini akan menambah attempt count
      await _apiClient.post('/api/v1/auth/verify-pin', data: {'pin': pin});
      return true;
    } on DioException catch (e) {
      if (e.response?.statusCode == 401) {
        throw AuthException('PIN salah', code: 'INVALID_PIN');
      }
      throw _mapError(e);
    }
  }

  /// Ganti PIN
  Future<void> changePin({
    required String oldPin,
    required String newPin,
  }) async {
    try {
      await _apiClient.post('/api/v1/auth/change-pin', data: {
        'old_pin': oldPin,
        'new_pin': newPin,
      });
      // Update master PIN yang tersimpan
      await _secureStorage.saveMasterPin(newPin);
    } on DioException catch (e) {
      throw _mapError(e);
    }
  }

  /// Ambil profil user
  Future<User> getMe() async {
    try {
      final response = await _apiClient.get('/api/v1/user/me');
      return User.fromJson(response.data);
    } on DioException catch (e) {
      throw _mapError(e);
    }
  }

  /// Hapus akun
  Future<void> deleteAccount() async {
    try {
      await _apiClient.delete('/api/v1/user/account');
      await _secureStorage.clearAll();
    } on DioException catch (e) {
      throw _mapError(e);
    }
  }

  // ─── Error Mapping ─────────────────────────────────────────────────────────

  Exception _mapError(DioException e) {
    if (e.response != null) {
      final status = e.response!.statusCode;
      final detail = e.response!.data?['detail'] ?? 'Terjadi kesalahan';
      switch (status) {
        case 400:
          return AuthException(detail, code: 'BAD_REQUEST');
        case 401:
          return AuthException(detail, code: 'UNAUTHORIZED');
        case 409:
          return AuthException(detail, code: 'CONFLICT');
        default:
          return AuthException(detail, code: 'SERVER_ERROR');
      }
    }
    if (e.type == DioExceptionType.connectionTimeout ||
        e.type == DioExceptionType.receiveTimeout) {
      return AuthException('Koneksi timeout. Periksa jaringan Anda.', code: 'TIMEOUT');
    }
    return AuthException('Tidak dapat terhubung ke server.', code: 'NETWORK');
  }
}

class AuthException implements Exception {
  final String message;
  final String code;
  AuthException(this.message, {required this.code});

  @override
  String toString() => message;
}
