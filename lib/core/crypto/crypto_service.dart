// lib/core/crypto/crypto_service.dart
// AES-256-GCM encryption service
// Kunci di-derive dari PIN via PBKDF2-SHA256

import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';
import 'package:encrypt/encrypt.dart';
import 'package:pointycastle/export.dart';
import '../constants/app_constants.dart';

class CryptoService {
  /// Derive a 256-bit key from PIN using PBKDF2-SHA256
  Uint8List deriveKey(String pin, Uint8List salt) {
    final pbkdf2 = PBKDF2KeyDerivator(HMac(SHA256Digest(), 64));
    pbkdf2.init(Pbkdf2Parameters(
      salt,
      AppConstants.pbkdf2Iterations,
      AppConstants.aesKeyLength,
    ));
    return pbkdf2.process(Uint8List.fromList(utf8.encode(pin)));
  }

  /// Generate cryptographically secure random salt (16 bytes)
  Uint8List generateSalt() {
    final random = Random.secure();
    return Uint8List.fromList(
      List.generate(16, (_) => random.nextInt(256)),
    );
  }

  /// Generate cryptographically secure random IV (12 bytes for GCM)
  Uint8List generateIV() {
    final random = Random.secure();
    return Uint8List.fromList(
      List.generate(12, (_) => random.nextInt(256)),
    );
  }

  /// Encrypt plaintext using AES-256-GCM
  /// Returns: {ciphertext, iv}
  EncryptedData encrypt(String plaintext, Uint8List key) {
    final iv = IV.fromSecureRandom(12);
    final encrypter = Encrypter(AES(Key(key), mode: AESMode.gcm));
    final encrypted = encrypter.encrypt(plaintext, iv: iv);
    return EncryptedData(
      ciphertext: encrypted.base64,
      iv: iv.base64,
    );
  }

  /// Encrypt plaintext using AES-256-GCM with a provided IV
  /// Used when title and content must share the same IV
  EncryptedData encryptWithIV(String plaintext, Uint8List key, Uint8List iv) {
    final encrypter = Encrypter(AES(Key(key), mode: AESMode.gcm));
    final encrypted = encrypter.encrypt(plaintext, iv: IV(iv));
    return EncryptedData(
      ciphertext: encrypted.base64,
      iv: ivBase64(iv),
    );
  }

  /// Decrypt ciphertext using AES-256-GCM
  String decrypt(String ciphertextBase64, String ivBase64, Uint8List key) {
    final iv = IV.fromBase64(ivBase64);
    final encrypter = Encrypter(AES(Key(key), mode: AESMode.gcm));
    final decrypted = encrypter.decrypt64(ciphertextBase64, iv: iv);
    return decrypted;
  }

  /// Encrypt note: returns {ciphertext, iv, salt}
  EncryptedNote encryptNote(String plaintext, String pin) {
    final salt = generateSalt();
    final iv = generateIV();
    final key = deriveKey(pin, salt);

    final encrypter = Encrypter(AES(Key(key), mode: AESMode.gcm));
    final encrypted = encrypter.encrypt(plaintext, iv: IV(iv));

    return EncryptedNote(
      ciphertext: encrypted.base64,
      iv: ivBase64(iv),
      salt: saltBase64(salt),
    );
  }

  /// Decrypt note using PIN
  String decryptNote(String ciphertext, String iv, String salt, String pin) {
    final saltBytes = base64ToBytes(salt);
    final key = deriveKey(pin, saltBytes);
    return decrypt(ciphertext, iv, key);
  }

  // ─── Helpers ────────────────────────────────────────────────────────────────

  Uint8List base64ToBytes(String base64) {
    return Uint8List.fromList(base64Decode(base64));
  }

  String ivBase64(Uint8List iv) => base64Encode(iv);
  String saltBase64(Uint8List salt) => base64Encode(salt);
}

class EncryptedData {
  final String ciphertext;
  final String iv;
  EncryptedData({required this.ciphertext, required this.iv});
}

class EncryptedNote {
  final String ciphertext;
  final String iv;
  final String salt;
  EncryptedNote({
    required this.ciphertext,
    required this.iv,
    required this.salt,
  });
}
