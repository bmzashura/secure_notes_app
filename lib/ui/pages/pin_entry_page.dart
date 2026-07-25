// lib/ui/pages/pin_entry_page.dart
// Screen — PIN Entry (Lockout / Biometric Unlock Screen)
// Muncul saat app di-buka setelah auto-lock (30 detik background)
// Atau saat unlock dengan PIN

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../bloc/auth/auth_bloc.dart';
import '../../core/theme/app_theme.dart';
import '../../data/repositories/repositories.dart';
import '../../app.dart';

class PinEntryPage extends StatefulWidget {
  const PinEntryPage({super.key});

  @override
  State<PinEntryPage> createState() => _PinEntryPageState();
}

class _PinEntryPageState extends State<PinEntryPage> {
  final _pinController = TextEditingController();
  final _focusNode = FocusNode();
  String _error = '';
  bool _isLoading = false;
  int _attempts = 0;
  static const int _maxAttempts = 3;

  @override
  void initState() {
    super.initState();
    // Auto-focus untuk langsung input
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _focusNode.requestFocus();
    });
  }

  @override
  void dispose() {
    _pinController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  Future<void> _verifyPin() async {
    if (_isLoading) return;

    final pin = _pinController.text;
    if (pin.length < 4) {
      setState(() => _error = 'PIN minimal 4 digit');
      return;
    }

    setState(() {
      _error = '';
      _isLoading = true;
    });

    try {
      final authRepo = getIt<AuthRepository>();
      // Verifikasi PIN ke server
      // PIN verify endpoint: POST /api/v1/auth/verify-pin
      // Body: { "pin": "xxxx" }
      // Response: { "valid": true } atau 401

      await authRepo.verifyPin(pin);

      if (mounted) {
        // PIN benar → unlock dan ke HomePage
        Navigator.of(context).pushReplacementNamed('/home');
      }
    } on AuthException catch (e) {
      _attempts++;
      if (_attempts >= _maxAttempts) {
        // Terlalu banyak percobaan → lockout
        if (mounted) {
          _showLockoutDialog();
        }
      } else {
        setState(() {
          _error = 'PIN salah. Percobaan ke-${_attempts + 1}/$_maxAttempts';
          _pinController.clear();
        });
      }
    } catch (e) {
      setState(() => _error = 'Verifikasi gagal. Coba lagi.');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showLockoutDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.surfaceElevated,
        title: const Text('🔒 Terlalu Banyak Percobaan'),
        content: Text(
          'Anda telah salah memasukkan PIN $_maxAttempts kali.\n\n'
          'Akun dikunci sementara selama ${_lockoutDuration()}.\n\n'
          ' Hubungi admin jika lupa PIN.',
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              context.read<AuthBloc>().add(AuthLogoutRequested());
              Navigator.of(context).pushNamedAndRemoveUntil(
                '/login', (route) => false,
              );
            },
            child: const Text('Logout'),
          ),
        ],
      ),
    );
  }

  String _lockoutDuration() {
    if (_attempts >= 5) return '5 menit';
    if (_attempts >= 4) return '2 menit';
    return '1 menit';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Column(
            children: [
              const Spacer(flex: 2),
              // Icon + Title
              const Icon(
                Icons.lock_outline,
                size: 64,
                color: AppTheme.primary,
              ),
              const SizedBox(height: 24),
              const Text(
                'SecureNotes',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.textPrimary,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Masukkan PIN untuk membuka',
                style: TextStyle(
                  fontSize: 14,
                  color: AppTheme.textMuted,
                ),
              ),
              const Spacer(),
              // PIN Input
              SizedBox(
                width: 200,
                child: TextField(
                  controller: _pinController,
                  focusNode: _focusNode,
                  obscureText: true,
                  textAlign: TextAlign.center,
                  keyboardType: TextInputType.number,
                  maxLength: 6,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  style: const TextStyle(
                    fontSize: 24,
                    letterSpacing: 16,
                    color: AppTheme.textPrimary,
                  ),
                  decoration: InputDecoration(
                    counterText: '',
                    hintText: '● ● ● ●',
                    hintStyle: TextStyle(
                      color: AppTheme.textMuted.withOpacity(0.3),
                      letterSpacing: 16,
                    ),
                    errorText: _error.isEmpty ? null : _error,
                    border: const UnderlineInputBorder(),
                    focusedBorder: const UnderlineInputBorder(
                      borderSide: BorderSide(color: AppTheme.primary, width: 2),
                    ),
                    errorBorder: const UnderlineInputBorder(
                      borderSide: BorderSide(color: AppTheme.danger),
                    ),
                  ),
                  onSubmitted: (_) => _verifyPin(),
                ),
              ),
              const SizedBox(height: 24),
              // Submit Button
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _verifyPin,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: _isLoading
                      ? const SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Text(
                          'BUKA',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.5,
                          ),
                        ),
                ),
              ),
              const Spacer(),
              // Biometric shortcut hint
              TextButton.icon(
                onPressed: () async {
                  // Biometric unlock — placeholder
                  // Implementasi: LocalAuthentication → verify PIN biometrics
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Biometric unlock dalam pengembangan'),
                      backgroundColor: AppTheme.warning,
                    ),
                  );
                },
                icon: const Icon(Icons.fingerprint, color: AppTheme.primary),
                label: const Text(
                  'Gunakan Fingerprint',
                  style: TextStyle(color: AppTheme.primary),
                ),
              ),
              const SizedBox(height: 8),
              // Logout option
              TextButton(
                onPressed: () {
                  context.read<AuthBloc>().add(AuthLogoutRequested());
                  Navigator.of(context).pushNamedAndRemoveUntil(
                    '/login', (route) => false,
                  );
                },
                child: const Text(
                  'Logout',
                  style: TextStyle(color: AppTheme.textMuted, fontSize: 12),
                ),
              ),
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }
}
