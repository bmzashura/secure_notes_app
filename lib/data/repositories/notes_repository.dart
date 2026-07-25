// lib/data/repositories/notes_repository.dart
// Repository untuk CRUD notes terenkripsi

import 'package:dio/dio.dart';
import '../../core/api/api_client.dart';
import '../../core/crypto/crypto_service.dart';
import '../models/models.dart';

class NotesRepository {
  final ApiClient _apiClient;
  final CryptoService _cryptoService;

  NotesRepository({
    required ApiClient apiClient,
    required CryptoService cryptoService,
  })  : _apiClient = apiClient,
        _cryptoService = cryptoService;

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
  Future<String> createNote({
    required String content,
    required String pin,
    String? title,
  }) async {
    try {
      // Encrypt content
      final encryptedContent = _cryptoService.encryptNote(content, pin);
      String? encryptedTitle;
      if (title != null && title.isNotEmpty) {
        final encTitle = _cryptoService.encryptNote(title, pin);
        encryptedTitle = encTitle.ciphertext;
      }

      final response = await _apiClient.post('/api/v1/notes', data: {
        'ciphertext': encryptedContent.ciphertext,
        'iv': encryptedContent.iv,
        'salt': encryptedContent.salt,
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
    required String pin,
    String? title,
  }) async {
    try {
      final encryptedContent = _cryptoService.encryptNote(content, pin);
      String? encryptedTitle;
      if (title != null && title.isNotEmpty) {
        final encTitle = _cryptoService.encryptNote(title, pin);
        encryptedTitle = encTitle.ciphertext;
      }

      await _apiClient.put('/api/v1/notes/$noteId', data: {
        'ciphertext': encryptedContent.ciphertext,
        'iv': encryptedContent.iv,
        'salt': encryptedContent.salt,
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

  /// Dekripsi note content (local only — PIN dari user)
  String decryptContent(Note note, String pin) {
    return _cryptoService.decryptNote(
      note.ciphertext,
      note.iv,
      note.salt,
      pin,
    );
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
