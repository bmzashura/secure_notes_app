# SecureNotes

Aplikasi mobile catatan terenkripsi end-to-end dengan arsitektur zero-knowledge. Dibangun untuk UAS Keamanan Aplikasi Mobile TI222.

## Arsitektur

- **Zero-Knowledge**: Server hanya menyimpan ciphertext. Kunci dekripsi tidak pernah meninggalkan perangkat.
- **Enkripsi**: AES-256-GCM dengan kunci dari PBKDF2-SHA256 (PIN user)
- **Secure Storage**: Android Keystore / iOS Keychain via flutter_secure_storage

## Tech Stack

| Komponen | Teknologi |
|----------|----------|
| Framework | Flutter 3.x |
| State Management | flutter_bloc |
| HTTP Client | Dio |
| Secure Storage | flutter_secure_storage |
| Enkripsi | encrypt + pointycastle |
| Biometric | local_auth |
| PIN Input | pinput |

## Setup

### Prasyarat
- Flutter SDK 3.x
- Android SDK / Xcode (untuk iOS)
- Backend API running di `http://10.0.2.2:8000` (Android emulator)

### Instalasi

```bash
# Clone repo
git clone https://github.com/bmzashura/secure_notes_app.git
cd secure_notes_app

# Install dependencies
flutter pub get

# Run (development)
flutter run

# Build APK debug
flutter build apk --debug
```

### Environment

Untuk development, API endpoint sudah di-set ke Android emulator localhost (`10.0.2.2:8000`). Untuk production, ubah di `lib/core/constants/app_constants.dart`:

```dart
static const String baseUrl = 'https://your-production-api.com';
```

## Kontrol Keamanan

| Kode | Kontrol | Implementasi |
|------|---------|-------------|
| S1 | Autentikasi + session | JWT + PIN bcrypt |
| S2 | Secure storage | Android Keystore / iOS Keychain |
| S3 | Enkripsi data sensitif | AES-256-GCM |
| S4 | Secure API | HTTPS + JWT |
| S5 | Authorization | User hanya akses data sendiri |
| S6 | Permission minimization | INTERNET + Biometric only |
| S7 | Secure logging | Tidak ada kredensial di log |
| S8 | Hardening | allowBackup=false, cleartext=false |

## Struktur Proyek

```
lib/
├── main.dart                   # Entry point
├── app.dart                    # DI setup + App widget
├── core/
│   ├── constants/              # App constants
│   ├── crypto/                 # AES-256-GCM encryption
│   ├── secure_storage/         # Keystore/Keychain wrapper
│   ├── api/                   # Dio client + JWT interceptor
│   └── theme/                 # Dark theme
├── data/
│   ├── models/                # User, Note, AuthTokens
│   └── repositories/          # Auth + Notes repositories
├── bloc/
│   ├── auth/                  # AuthBloc
│   └── notes/                 # NotesBloc
└── ui/
    ├── pages/                # All screens
    └── widgets/              # Reusable widgets
```

## API Required

Backend API harus running di port 8000. Lihat [secure_notes_API](https://github.com/bmzashura/secure_notes_API).

## Screens

1. Splash
2. Login
3. Register + PIN Setup
4. Home / Notes List
5. Note Editor
6. Security Settings
7. Info / About

## Kontributor

- **Bemis Huntala** — 1002240018 — Institut Teknologi Tangerang Selatan
- Mata Kuliah: Keamanan Aplikasi Mobile (TI222)
