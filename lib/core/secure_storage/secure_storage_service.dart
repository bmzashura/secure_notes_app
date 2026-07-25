// lib/core/secure_storage/secure_storage_service.dart
// Wrapper untuk flutter_secure_storage
// Menyimpan: access_token, refresh_token, user_id, pin_salt

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../constants/app_constants.dart';

class SecureStorageService {
  final FlutterSecureStorage _storage;
  FlutterSecureStorage get storage => _storage;

  SecureStorageService({FlutterSecureStorage? storage})
      : _storage = storage ??
            const FlutterSecureStorage(
              aOptions: AndroidOptions(
                encryptedSharedPreferences: true,
              ),
              iOptions: IOSOptions(
                accessibility: KeychainAccessibility.first_unlock_this_device,
              ),
            );

  // ─── Token Management ──────────────────────────────────────────────────────

  Future<void> saveAccessToken(String token) async {
    await _storage.write(key: AppConstants.accessTokenKey, value: token);
  }

  Future<void> saveTokens({
    required String accessToken,
    required String refreshToken,
    required String userId,
  }) async {
    await Future.wait([
      _storage.write(key: AppConstants.accessTokenKey, value: accessToken),
      _storage.write(key: AppConstants.refreshTokenKey, value: refreshToken),
      _storage.write(key: AppConstants.userIdKey, value: userId),
    ]);
  }

  Future<String?> getAccessToken() async {
    return _storage.read(key: AppConstants.accessTokenKey);
  }

  Future<String?> getRefreshToken() async {
    return _storage.read(key: AppConstants.refreshTokenKey);
  }

  Future<String?> getUserId() async {
    return _storage.read(key: AppConstants.userIdKey);
  }

  Future<void> clearTokens() async {
    await Future.wait([
      _storage.delete(key: AppConstants.accessTokenKey),
      _storage.delete(key: AppConstants.refreshTokenKey),
      _storage.delete(key: AppConstants.userIdKey),
    ]);
  }

  // ─── PIN / Crypto Key Storage ──────────────────────────────────────────────

  /// Simpan PIN salt (untuk biometric unlock)
  Future<void> savePinSalt(String salt) async {
    await _storage.write(key: 'pin_salt', value: salt);
  }

  Future<String?> getPinSalt() async {
    return _storage.read(key: 'pin_salt');
  }

  /// Simpan encrypted master key (untuk biometric unlock)
  Future<void> saveEncryptedMasterKey(String encryptedKey) async {
    await _storage.write(key: 'encrypted_master_key', value: encryptedKey);
  }

  Future<String?> getEncryptedMasterKey() async {
    return _storage.read(key: 'encrypted_master_key');
  }

  /// Simpan master PIN (untuk enkripsi semua notes)
  Future<void> saveMasterPin(String pin) async {
    await _storage.write(key: 'master_pin', value: pin);
  }

  Future<String?> getMasterPin() async {
    return _storage.read(key: 'master_pin');
  }

  Future<void> clearMasterPin() async {
    await _storage.delete(key: 'master_pin');
  }

  // ─── Clear All ────────────────────────────────────────────────────────────

  Future<void> clearAll() async {
    await _storage.deleteAll();
  }
}
