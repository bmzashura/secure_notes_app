// lib/ui/pages/pin_entry_page.dart
// Screen — PIN Entry (Lockout / Biometric Unlock Screen)

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../bloc/auth/auth_bloc.dart';
import '../../core/theme/app_theme.dart';
import '../../core/secure_storage/secure_storage_service.dart';
import '../../app.dart';

class PinEntryPage extends StatefulWidget {
  const PinEntryPage({super.key});

  @override
  State<PinEntryPage> createState() => _PinEntryPageState();
}

class _PinEntryPageState extends State<PinEntryPage> {
  final _pinController = TextEditingController();
  String _error = '';
  bool _isLoading = false;
  int _attempts = 0;
  static const int _maxAttempts = 3;

  @override
  void dispose() {
    _pinController.dispose();
    super.dispose();
  }

  Future<void> _verifyPin() async {
    if (_isLoading) return;
    if (_pinController.text.length < 4) {
      setState(() => _error = 'PIN minimal 4 digit');
      return;
    }

    setState(() {
      _error = '';
      _isLoading = true;
    });

    try {
      final storedPin = await getIt<SecureStorageService>().getMasterPin();
      if (storedPin == null) {
        setState(() {
          _error = 'PIN belum di-set. Silakan register ulang.';
          _isLoading = false;
        });
        return;
      }

      if (_pinController.text == storedPin) {
        if (mounted) {
          Navigator.of(context).pushReplacementNamed('/home');
        }
      } else {
        _attempts++;
        if (_attempts >= _maxAttempts) {
          if (mounted) _showLockoutDialog();
        } else {
          setState(() {
            _error = 'PIN salah. ${_maxAttempts - _attempts} percobaan tersisa.';
            _pinController.clear();
            _isLoading = false;
          });
        }
      }
    } catch (e) {
      setState(() {
        _error = 'Verifikasi gagal.';
        _isLoading = false;
      });
    }
  }

  void _showLockoutDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.surfaceElevated,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppTheme.danger.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.lock_clock, color: AppTheme.danger, size: 48),
            ),
            const SizedBox(height: 20),
            const Text(
              'Terlalu Banyak Percobaan',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: AppTheme.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Coba lagi beberapa saat',
              style: TextStyle(color: AppTheme.textSecondary),
              textAlign: TextAlign.center,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              context.read<AuthBloc>().add(AuthLogoutRequested());
              Navigator.of(context).pushNamedAndRemoveUntil('/login', (route) => false);
            },
            child: const Text('Logout'),
          ),
        ],
      ),
    );
  }

  void _onLogout() {
    context.read<AuthBloc>().add(AuthLogoutRequested());
    Navigator.of(context).pushNamedAndRemoveUntil('/login', (route) => false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.surface,
      body: SafeArea(
        child: Column(
          children: [
            const Spacer(),

            // Lock icon
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [AppTheme.primary, AppTheme.accentCyan],
                ),
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                    color: AppTheme.primary.withValues(alpha: 0.3),
                    blurRadius: 20,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: const Icon(Icons.lock_outline, size: 40, color: Colors.white),
            ),

            const SizedBox(height: 24),

            const Text(
              'SecureNotes',
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.w700,
                color: AppTheme.textPrimary,
                letterSpacing: 1,
              ),
            ),

            const SizedBox(height: 8),

            const Text(
              'Masukkan PIN',
              style: TextStyle(
                fontSize: 14,
                color: AppTheme.textMuted,
              ),
            ),

            const SizedBox(height: 32),

            // PIN dots
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(6, (index) {
                final isFilled = index < _pinController.text.length;
                return Container(
                  margin: const EdgeInsets.symmetric(horizontal: 6),
                  width: 14,
                  height: 14,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: isFilled ? AppTheme.primary : Colors.transparent,
                    border: Border.all(
                      color: isFilled ? AppTheme.primary : AppTheme.border,
                      width: 2,
                    ),
                  ),
                );
              }),
            ),

            const SizedBox(height: 16),

            // Error message
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 200),
              child: _error.isEmpty
                  ? const SizedBox(height: 20)
                  : Container(
                      margin: const EdgeInsets.symmetric(horizontal: 32),
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      decoration: BoxDecoration(
                        color: AppTheme.danger.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        _error,
                        style: const TextStyle(
                          color: AppTheme.danger,
                          fontSize: 13,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
            ),

            const Spacer(),

            // Numpad
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 48),
              child: Column(
                children: [
                  _buildNumpadRow(['1', '2', '3']),
                  const SizedBox(height: 16),
                  _buildNumpadRow(['4', '5', '6']),
                  const SizedBox(height: 16),
                  _buildNumpadRow(['7', '8', '9']),
                  const SizedBox(height: 16),
                  _buildNumpadRow(['', '0', '⌫']),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // Submit Button
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 48),
              child: SizedBox(
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
            ),

            const SizedBox(height: 16),

            // Logout
            TextButton(
              onPressed: _onLogout,
              child: const Text(
                'Logout',
                style: TextStyle(color: AppTheme.textMuted, fontSize: 12),
              ),
            ),

            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Widget _buildNumpadRow(List<String> keys) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: keys.map((key) {
        if (key.isEmpty) {
          return const SizedBox(width: 64, height: 64);
        }
        if (key == '⌫') {
          return _buildBackspaceKey();
        }
        return _buildNumKey(key);
      }).toList(),
    );
  }

  Widget _buildNumKey(String num) {
    return GestureDetector(
      onTap: _isLoading
          ? null
          : () {
              HapticFeedback.lightImpact();
              if (_pinController.text.length < 6) {
                setState(() {
                  _pinController.text += num;
                  _error = '';
                });
              }
            },
      child: Container(
        width: 64,
        height: 64,
        decoration: BoxDecoration(
          color: AppTheme.surfaceCard,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppTheme.border),
        ),
        child: Center(
          child: Text(
            num,
            style: const TextStyle(
              fontSize: 26,
              fontWeight: FontWeight.w600,
              color: AppTheme.textPrimary,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBackspaceKey() {
    return GestureDetector(
      onTap: _isLoading
          ? null
          : () {
              HapticFeedback.lightImpact();
              if (_pinController.text.isNotEmpty) {
                setState(() {
                  _pinController.text = _pinController.text.substring(0, _pinController.text.length - 1);
                });
              }
            },
      child: const SizedBox(
        width: 64,
        height: 64,
        child: Center(
          child: Icon(Icons.backspace_outlined, color: AppTheme.textMuted, size: 24),
        ),
      ),
    );
  }
}
