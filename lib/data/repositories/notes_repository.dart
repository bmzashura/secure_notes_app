// lib/data/repositories/notes_repository.dart
// Repository untuk CRUD notes terenkripsi

import 'package:dio/dio.dart';
import '../../core/api/api_client.dart';
import '../../core/crypto/crypto_service.dart';
import '../../core/secure_storage/secure_storage_service.dart';
import '../models/models.dart';

class NotesRepository {
  final ApiClient _apiClient;
  final CryptoService _cryptoService;
  final SecureStorageService _secureStorage;

  NotesRepository({
    required ApiClient apiClient,
    required CryptoService cryptoService,
    required SecureStorageService secureStorage,
  })  : _apiClient = apiClient,
        _cryptoService = cryptoService,
        _secureStorage = secureStorage;

  /// Ambil semua notes (metadata only — tanpa ciphertext)
  Future<List<Note>> getNotes() async {
    try {
      final response = await _apiClient.get('/api/v1/notes');
      final List<dynamic> data = response.data;
      return data.map((json) => Note.fromJson(json)).toList();
    } on DioException catch (e) {
      throw _mapError(e);
    }
  }

  /// Ambil satu note lengkap dengan ciphertext
  Future<Note> getNote(String noteId) async {
    try {
      final response = await _apiClient.get('/api/v1/notes/$noteId');
      return Note.fromJson(response.data);
    } on DioException catch (e) {
      throw _mapError(e);
    }
  }

  /// Buat catatan baru — enkripsi dulu sebelum kirim
  /// Title dan content dienkripsi dengan SALT dan IV yang SAMA
  /// menggunakan master PIN dari secure storage
  Future<String> createNote({
    required String content,
    String? title,
  }) async {
    final masterPin = await _secureStorage.getMasterPin();
    if (masterPin == null) {
      throw NotesException('Master PIN tidak ditemukan. Silakan login ulang.', code: 'NO_MASTER_PIN');
    }

    try {
      final salt = _cryptoService.generateSalt();
      final key = _cryptoService.deriveKey(masterPin, salt);
      final iv = _cryptoService.generateIV();

      final encryptedContent = _cryptoService.encryptWithIV(content, key, iv);

      String? encryptedTitle;
      if (title != null && title.isNotEmpty) {
        encryptedTitle = _cryptoService.encryptWithIV(title, key, iv).ciphertext;
      }

      final response = await _apiClient.post('/api/v1/notes', data: {
        'ciphertext': encryptedContent.ciphertext,
        'iv': _cryptoService.ivBase64(iv),
        'salt': _cryptoService.saltBase64(salt),
        'title_encrypted': encryptedTitle,
      });

      return response.data['id'] as String;
    } on DioException catch (e) {
      throw _mapError(e);
    }
  }

  /// Update catatan
  Future<void> updateNote({
    required String noteId,
    required String content,
    String? title,
  }) async {
    final masterPin = await _secureStorage.getMasterPin();
    if (masterPin == null) {
      throw NotesException('Master PIN tidak ditemukan. Silakan login ulang.', code: 'NO_MASTER_PIN');
    }

    try {
      final salt = _cryptoService.generateSalt();
      final key = _cryptoService.deriveKey(masterPin, salt);
      final iv = _cryptoService.generateIV();

      final encryptedContent = _cryptoService.encryptWithIV(content, key, iv);

      String? encryptedTitle;
      if (title != null && title.isNotEmpty) {
        encryptedTitle = _cryptoService.encryptWithIV(title, key, iv).ciphertext;
      }

      await _apiClient.put('/api/v1/notes/$noteId', data: {
        'ciphertext': encryptedContent.ciphertext,
        'iv': _cryptoService.ivBase64(iv),
        'salt': _cryptoService.saltBase64(salt),
        'title_encrypted': encryptedTitle,
      });
    } on DioException catch (e) {
      throw _mapError(e);
    }
  }

  /// Hapus catatan
  Future<void> deleteNote(String noteId) async {
    try {
      await _apiClient.delete('/api/v1/notes/$noteId');
    } on DioException catch (e) {
      throw _mapError(e);
    }
  }

  /// Helper: enkripsi note dengan PIN spesifik (untuk re-encryption saat ganti PIN)
  Future<void> _encryptAndUpdateNote({
    required String noteId,
    required String content,
    required String pin,
    String? title,
  }) async {
    final salt = _cryptoService.generateSalt();
    final key = _cryptoService.deriveKey(pin, salt);
    final iv = _cryptoService.generateIV();

    final encryptedContent = _cryptoService.encryptWithIV(content, key, iv);

    String? encryptedTitle;
    if (title != null && title.isNotEmpty) {
      encryptedTitle = _cryptoService.encryptWithIV(title, key, iv).ciphertext;
    }

    await _apiClient.put('/api/v1/notes/$noteId', data: {
      'ciphertext': encryptedContent.ciphertext,
      'iv': _cryptoService.ivBase64(iv),
      'salt': _cryptoService.saltBase64(salt),
      'title_encrypted': encryptedTitle,
    });
  }

  /// Dekripsi note content (local only — PIN dari user)
  String decryptContent(Note note, String pin) {
    final ciphertext = note.ciphertext;
    if (ciphertext == null) {
      throw NotesException('Ciphertext tidak tersedia.', code: 'DECRYPT_ERROR');
    }
    return _cryptoService.decryptNote(ciphertext, note.iv, note.salt, pin);
  }

  /// Re-encrypt semua notes dengan PIN baru
  /// Verifikasi old PIN dulu dengan decrypt satu note
  /// Lalu re-encrypt semua notes dengan PIN baru
  Future<void> reEncryptAllNotes({
    required String oldPin,
    required String newPin,
  }) async {
    final allNotes = await getNotes();
    if (allNotes.isEmpty) return;

    // Verifikasi old PIN dengan decrypt note pertama
    final firstNote = await getNote(allNotes.first.id);
    decryptContent(firstNote, oldPin);
    if (firstNote.titleEncrypted != null) {
      decryptContent(
        firstNote.copyWith(ciphertext: firstNote.titleEncrypted),
        oldPin,
      );
    }

    // Re-encrypt semua notes dengan PIN baru
    for (final noteSummary in allNotes) {
      final note = await getNote(noteSummary.id);
      final content = decryptContent(note, oldPin);

      String? title;
      if (note.titleEncrypted != null) {
        title = decryptContent(
          note.copyWith(ciphertext: note.titleEncrypted),
          oldPin,
        );
      }

      await _encryptAndUpdateNote(
        noteId: note.id,
        content: content,
        pin: newPin,
        title: title,
      );
    }
  }

  // ─── Error Mapping ─────────────────────────────────────────────────────────

  Exception _mapError(DioException e) {
    if (e.response != null) {
      final status = e.response!.statusCode;
      final detail = e.response!.data?['detail'] ?? 'Terjadi kesalahan';
      switch (status) {
        case 401:
          return NotesException('Sesi habis. Silakan login ulang.', code: 'UNAUTHORIZED');
        case 403:
          return NotesException('Tidak memiliki akses.', code: 'FORBIDDEN');
        case 404:
          return NotesException('Catatan tidak ditemukan.', code: 'NOT_FOUND');
        default:
          return NotesException(detail, code: 'SERVER_ERROR');
      }
    }
    if (e.type == DioExceptionType.connectionTimeout ||
        e.type == DioExceptionType.receiveTimeout) {
      return NotesException('Koneksi timeout.', code: 'TIMEOUT');
    }
    return NotesException('Tidak dapat terhubung ke server.', code: 'NETWORK');
  }
}

class NotesException implements Exception {
  final String message;
  final String code;
  NotesException(this.message, {required this.code});

  @override
  String toString() => message;
}
