# SecureNotes

Aplikasi mobile catatan terenkripsi end-to-end dengan arsitektur zero-knowledge. Dibangun untuk UAS Keamanan Aplikasi Mobile TI222.

---

## Akun Dummy

| Field | Value |
|-------|-------|
| Email | `b@z.com` |
| Password | `12345678` |
| PIN | `654321` |

> PIN ini adalah **master PIN** — digunakan untuk enkripsi/dekripsi semua catatan.

---

## Arsitektur

### Zero-Knowledge Design

```
┌─────────────────┐         HTTPS          ┌──────────────────┐
│   Flutter App   │ ◄──────────────────► │   Backend API    │
│                 │                        │                  │
│  ┌──────────┐  │                        │  /api/v1/notes  │
│  │  Master  │  │    ciphertext only     │  ──────────────  │
│  │  PIN    │──┼──► AES-256-GCM ───────┼─► blob storage  │
│  │ (local) │  │    never sent         │                  │
│  └──────────┘  │                        └──────────────────┘
└─────────────────┘
```

Server **tidak pernah** mengetahui PIN atau kunci enkripsi. Semua enkripsi/dekripsi dilakukan secara lokal di perangkat.

### Encryption Flow

```
PIN (4-6 digit)
     │
     ▼
PBKDF2-SHA256 (100,000 iterations) ──► AES-256-GCM Key
     │
     ▼
   Salt (16 bytes) ──────────────────► Salt + IV stored in API
     │
     ▼
   AES-256-GCM Encrypt ──────────────► Ciphertext → API
```

Setiap note memiliki `salt` dan `iv` sendiri. Title dan content dienkripsi dengan key + iv yang sama agar server cukup menyimpan satu salt.

---

## API Endpoints

Base URL: `https://api.bemis.dpdns.org`

### Authentication

| Method | Endpoint | Public | Description |
|--------|----------|--------|-------------|
| `POST` | `/api/v1/auth/register` | ✅ | Register dengan email, password, PIN |
| `POST` | `/api/v1/auth/login` | ✅ | Login dengan email, password |
| `POST` | `/api/v1/auth/refresh` | ✅ | Refresh access token |
| `POST` | `/api/v1/auth/logout` | ❌ | Logout (revoke refresh token) |
| `POST` | `/api/v1/auth/change-pin` | ❌ | Ganti PIN (verifikasi PIN lama) |

### Notes

| Method | Endpoint | Auth | Description |
|--------|----------|------|-------------|
| `GET` | `/api/v1/notes` | ❌ | List semua notes (metadata only, tanpa ciphertext) |
| `GET` | `/api/v1/notes/{id}` | ❌ | Detail note lengkap dengan ciphertext |
| `POST` | `/api/v1/notes` | ❌ | Buat note baru (ciphertext + iv + salt) |
| `PUT` | `/api/v1/notes/{id}` | ❌ | Update note |
| `DELETE` | `/api/v1/notes/{id}` | ❌ | Hapus note |

### User

| Method | Endpoint | Auth | Description |
|--------|----------|------|-------------|
| `GET` | `/api/v1/user/me` | ❌ | Ambil profil user |
| `DELETE` | `/api/v1/user/account` | ❌ | Hapus akun |

### Status

| Method | Endpoint | Public | Description |
|--------|----------|--------|-------------|
| `GET` | `/health` | ✅ | Health check |
| `GET` | `/` | ✅ | Root info |

### Request/Response Schema

**Register / Login Response:**
```json
{
  "access_token": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...",
  "refresh_token": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...",
  "token_type": "bearer",
  "user_id": "uuid-string"
}
```

**Note Schema (API):**
```json
{
  "id": "uuid-string",
  "ciphertext": "base64-encrypted-content",
  "iv": "base64-iv",
  "salt": "base64-salt",
  "title_encrypted": "base64-or-null",
  "created_at": "2026-07-25T03:00:00Z",
  "updated_at": "2026-07-25T03:00:00Z"
}
```

---

## Tech Stack

| Komponen | Teknologi |
|----------|----------|
| Framework | Flutter 3.x |
| State Management | flutter_bloc (BLoC pattern) |
| HTTP Client | Dio + Auth Interceptor |
| Secure Storage | flutter_secure_storage (Android Keystore / iOS Keychain) |
| Enkripsi | AES-256-GCM via `encrypt` + PBKDF2-SHA256 via `pointycastle` |
| Dependency Injection | get_it |
| Input PIN | pinput |

---

## Struktur Proyek

```
lib/
├── main.dart                       # Entry point
├── app.dart                        # DI setup (GetIt) + BlocProvider
├── core/
│   ├── constants/
│   │   └── app_constants.dart      # Base URL, timeout, PBKDF2 config
│   ├── crypto/
│   │   └── crypto_service.dart     # AES-256-GCM encrypt/decrypt, PBKDF2 key derivation
│   ├── secure_storage/
│   │   └── secure_storage_service.dart  # Keystore wrapper: tokens + master PIN
│   └── api/
│       └── api_client.dart         # Dio client + JWT auth interceptor (mutex lock)
├── data/
│   ├── models/
│   │   └── models.dart             # User, Note (with ciphertext), AuthTokens
│   └── repositories/
│       ├── repositories.dart       # AuthRepository: register, login, logout, changePin
│       └── notes_repository.dart    # NotesRepository: CRUD + re-encrypt all
├── bloc/
│   ├── auth/
│   │   └── auth_bloc.dart          # AuthBloc: login, register, logout
│   └── notes/
│       └── notes_bloc.dart         # NotesBloc: load, create, update, delete, re-encrypt
└── ui/
    └── pages/
        ├── splash_page.dart         # Auth check on startup
        ├── login_page.dart          # Login form
        ├── register_page.dart        # Register + PIN setup
        ├── home_page.dart           # Notes list
        ├── note_editor_page.dart    # Create/edit note
        └── settings_page.dart        # Change PIN, logout
```

---

## Alur Kode Penting

### 1. Master PIN Storage (`secure_storage_service.dart`)

```dart
// Simpan master PIN saat register
await _secureStorage.saveMasterPin(pin);

// Ambil master PIN untuk enkripsi/dekripsi
final masterPin = await _secureStorage.getMasterPin();
```

Master PIN disimpan di **Android Keystore / iOS Keychain** — tidak pernah dikirim ke server (kecuali saat register/change-pin untuk verifikasi).

### 2. Enkripsi Note (`notes_repository.dart`)

```dart
// Buat note baru — gunakan master PIN untuk derive key
Future<String> createNote({required String content, String? title}) async {
  final masterPin = await _secureStorage.getMasterPin();

  // Generate salt + derive key dari PIN
  final salt = _cryptoService.generateSalt();
  final key = _cryptoService.deriveKey(masterPin, salt);
  final iv = _cryptoService.generateIV();

  // Encrypt content + title dengan key + iv yang SAMA
  final encryptedContent = _cryptoService.encryptWithIV(content, key, iv);
  String? encryptedTitle;
  if (title != null) {
    encryptedTitle = _cryptoService.encryptWithIV(title, key, iv).ciphertext;
  }

  // Kirim ke API
  await _apiClient.post('/api/v1/notes', data: {
    'ciphertext': encryptedContent.ciphertext,
    'iv': ivBase64(iv),
    'salt': saltBase64(salt),
    'title_encrypted': encryptedTitle,
  });
}
```

**Kenapa salt/iv yang sama?** Karena API cuma simpan satu salt + satu iv. Saat dekripsi, kita perlu salt + iv yang sama untuk derive key yang sama.

### 3. Auth Interceptor dengan Mutex (`api_client.dart`)

```dart
class _AuthInterceptor extends Interceptor {
  bool _isRefreshing = false;
  final List<Completer<bool>> _pendingRequests = [];

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) async {
    if (err.response?.statusCode == 401) {
      final refreshed = await _tryRefreshToken();
      if (refreshed) {
        // Retry request
        final response = await _dio.fetch(err.requestOptions);
        return handler.resolve(response);
      }
    }
    handler.next(err);
  }

  Future<bool> _tryRefreshToken() async {
    if (_isRefreshing) {
      // Tunggu refresh yang sedang berjalan
      final completer = Completer<bool>();
      _pendingRequests.add(completer);
      return completer.future;
    }

    _isRefreshing = true;
    try {
      // ... refresh logic ...
      _resolvePendingRequests(); // Resolve semua request yang menunggu
      return true;
    } finally {
      _isRefreshing = false;
    }
  }
}
```

**Masalah yang solved:** Tanpa mutex, kalau 2 request bersamaan kena 401, keduanya akan trigger refresh token bersamaan — race condition.

### 4. Change PIN + Re-Encryption (`notes_repository.dart`)

```dart
// Ganti PIN = re-encrypt semua note dengan PIN baru
Future<void> reEncryptAllNotes({
  required String oldPin,
  required String newPin,
}) async {
  // 1. Verifikasi PIN lama (decrypt note pertama)
  final firstNote = await getNote(allNotes.first.id);
  decryptContent(firstNote, oldPin); // Throw kalau salah

  // 2. Decrypt semua dengan PIN lama → encrypt dengan PIN baru
  for (final noteSummary in allNotes) {
    final note = await getNote(noteSummary.id);
    final content = decryptContent(note, oldPin);
    final title = note.titleEncrypted != null
        ? decryptContent(note.copyWith(ciphertext: note.titleEncrypted), oldPin)
        : null;

    // Update note dengan PIN baru
    await _encryptAndUpdateNote(noteId: note.id, content: content, pin: newPin, title: title);
  }
}
```

### 5. Save dengan Konfirmasi PIN (`note_editor_page.dart`)

```dart
void _showSavePinDialog() {
  // Dialog minta PIN...
  onPressed: () async {
    final masterPin = await getIt<SecureStorageService>().getMasterPin();
    if (pinCtrl.text != masterPin) {
      // PIN salah
      return;
    }
    // PIN benar → save
    _saveNote();
  },
}
```

---

## Setup Development

### Prasyarat
- Flutter SDK 3.x
- Android SDK / Xcode (untuk iOS)
- Backend API running

### Instalasi

```bash
# Clone repo
git clone https://github.com/bmzashura/secure_notes_app.git
cd secure_notes_app

# Install dependencies
flutter pub get

# Build debug APK
flutter build apk --debug

# Run (pastikan emulator atau device terhubung)
flutter run
```

### Environment

API endpoint di-set di `lib/core/constants/app_constants.dart`:

```dart
static const String baseUrl = 'https://api.bemis.dpdns.org';
```

---

## Kontrol Keamanan

| Kode | Kontrol | Implementasi |
|------|---------|-------------|
| S1 | Autentikasi + session | JWT access/refresh token + PIN |
| S2 | Secure storage | Android Keystore / iOS Keychain |
| S3 | Enkripsi data sensitif | AES-256-GCM |
| S4 | Secure API | HTTPS + JWT Bearer |
| S5 | Authorization | User hanya akses data sendiri |
| S6 | Permission minimization | INTERNET + Biometric only |
| S7 | Secure logging | Tidak ada kredensial di log |
| S8 | Hardening | allowBackup=false, cleartext=false |

---

## Kontributor

- **Bemis Huntala** — 1002240018 — Institut Teknologi Tangerang Selatan
- Mata Kuliah: Keamanan Aplikasi Mobile (TI222)
