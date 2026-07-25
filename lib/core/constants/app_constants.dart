// lib/core/constants/app_constants.dart

class AppConstants {
  AppConstants._();

  // API
  static const String baseUrl = 'http://10.0.2.2:8000'; // Android emulator localhost
  static const Duration connectTimeout = Duration(seconds: 15);
  static const Duration receiveTimeout = Duration(seconds: 15);

  // JWT
  static const String accessTokenKey = 'access_token';
  static const String refreshTokenKey = 'refresh_token';
  static const String userIdKey = 'user_id';

  // PIN / Crypto
  static const int pinMinLength = 4;
  static const int pinMaxLength = 6;
  static const int pbkdf2Iterations = 100000;
  static const int aesKeyLength = 32; // 256-bit

  // Security
  static const Duration autoLockDuration = Duration(seconds: 30);
  static const int maxPinAttempts = 3;
  static const Duration lockoutDuration1 = Duration(minutes: 1);
  static const Duration lockoutDuration2 = Duration(minutes: 2);
  static const Duration lockoutDuration3 = Duration(minutes: 5);

  // Password
  static const int passwordMinLength = 8;
  static const int passwordMaxLength = 128;
}
