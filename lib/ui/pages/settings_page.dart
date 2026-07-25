// lib/ui/pages/settings_page.dart
// Screen 08 — Security Settings

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:local_auth/local_auth.dart';
import '../../bloc/auth/auth_bloc.dart';
import '../../bloc/notes/notes_bloc.dart';
import '../../core/theme/app_theme.dart';
import '../../data/repositories/repositories.dart';
import '../../app.dart';
import 'login_page.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  final LocalAuthentication _localAuth = LocalAuthentication();
  bool _biometricAvailable = false;
  bool _biometricEnabled = false;

  @override
  void initState() {
    super.initState();
    _checkBiometric();
  }

  Future<void> _checkBiometric() async {
    try {
      final canAuth = await _localAuth.canCheckBiometrics;
      final isDeviceSupported = await _localAuth.isDeviceSupported();
      setState(() {
        _biometricAvailable = canAuth && isDeviceSupported;
      });
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Keamanan'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Security Section
          const _SectionHeader(title: 'KEAMANAN CATATAN'),
          _SettingsTile(
            icon: Icons.pin_outlined,
            title: 'Ganti PIN',
            trailing: const Icon(
              Icons.chevron_right,
              color: AppTheme.textMuted,
            ),
            onTap: () => _showChangePinDialog(),
          ),
          const SizedBox(height: 8),
          // Biometric
          if (_biometricAvailable)
            _SettingsTile(
              icon: Icons.fingerprint,
              title: 'Fingerprint',
              trailing: Switch(
                value: _biometricEnabled,
                onChanged: (v) => setState(() => _biometricEnabled = v),
                activeThumbColor: AppTheme.primary,
              ),
              onTap: null,
            ),
          const SizedBox(height: 32),
          // Logout
          OutlinedButton.icon(
            onPressed: () {
              context.read<AuthBloc>().add(AuthLogoutRequested());
              Navigator.of(context).pushAndRemoveUntil(
                MaterialPageRoute(builder: (_) => const LoginPage()),
                (route) => false,
              );
            },
            icon: const Icon(Icons.logout),
            label: const Text('LOGOUT'),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppTheme.danger,
              side: const BorderSide(color: AppTheme.danger),
            ),
          ),
        ],
      ),
    );
  }

  void _showChangePinDialog() {
    final oldPinController = TextEditingController();
    final newPinController = TextEditingController();
    final confirmPinController = TextEditingController();
    bool isLoading = false;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          backgroundColor: AppTheme.surfaceElevated,
          title: const Text('Ganti PIN'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: oldPinController,
                  obscureText: true,
                  keyboardType: TextInputType.number,
                  maxLength: 6,
                  enabled: !isLoading,
                  decoration: const InputDecoration(labelText: 'PIN Lama'),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: newPinController,
                  obscureText: true,
                  keyboardType: TextInputType.number,
                  maxLength: 6,
                  enabled: !isLoading,
                  decoration: const InputDecoration(labelText: 'PIN Baru (4-6 digit)'),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: confirmPinController,
                  obscureText: true,
                  keyboardType: TextInputType.number,
                  maxLength: 6,
                  enabled: !isLoading,
                  decoration: const InputDecoration(labelText: 'Konfirmasi PIN Baru'),
                ),
                if (isLoading) ...[
                  const SizedBox(height: 16),
                  const LinearProgressIndicator(),
                  const SizedBox(height: 8),
                  const Text(
                    'Mengubah PIN, jangan menutup app...',
                    style: TextStyle(color: AppTheme.textMuted, fontSize: 12),
                  ),
                ],
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: isLoading
                  ? null
                  : () => Navigator.of(ctx).pop(),
              child: const Text('Batal'),
            ),
            ElevatedButton(
              onPressed: isLoading
                  ? null
                  : () async {
                      final oldPin = oldPinController.text;
                      final newPin = newPinController.text;
                      final confirmPin = confirmPinController.text;

                      if (oldPin.length < 4) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('PIN lama minimal 4 digit'),
                            backgroundColor: AppTheme.warning,
                          ),
                        );
                        return;
                      }
                      if (newPin.length < 4) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('PIN baru minimal 4 digit'),
                            backgroundColor: AppTheme.warning,
                          ),
                        );
                        return;
                      }
                      if (newPin != confirmPin) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('PIN baru tidak cocok'),
                            backgroundColor: AppTheme.warning,
                          ),
                        );
                        return;
                      }

                      setDialogState(() => isLoading = true);

                      try {
                        // 1. Call API to change PIN on server
                        await getIt<AuthRepository>().changePin(
                          oldPin: oldPin,
                          newPin: newPin,
                        );

                        // 2. Re-encrypt all notes with new PIN via BLoC
                        final notesBloc = getIt<NotesBloc>();

                        // Listen for terminal states BEFORE adding event
                        final completer = Completer<NotesState>();
                        late final StreamSubscription sub;
                        sub = notesBloc.stream.listen((state) {
                          if (state is NotesLoaded || state is NotesError) {
                            completer.complete(state);
                            sub.cancel();
                          }
                        });

                        // Add event to trigger re-encryption
                        notesBloc.add(ReEncryptAllNotesRequested(
                          oldPin: oldPin,
                          newPin: newPin,
                        ));

                        // Wait for terminal state
                        final state = await completer.future;

                        if (state is NotesError) {
                          if (ctx.mounted) {
                            ScaffoldMessenger.of(ctx).showSnackBar(
                              SnackBar(
                                content: Text(state.message),
                                backgroundColor: AppTheme.danger,
                              ),
                            );
                          }
                          return;
                        }

                        if (ctx.mounted) {
                          Navigator.of(ctx).pop();
                          ScaffoldMessenger.of(ctx).showSnackBar(
                            const SnackBar(
                              content: Text('PIN berhasil diubah'),
                              backgroundColor: AppTheme.success,
                            ),
                          );
                        }
                      } catch (e) {
                        if (ctx.mounted) {
                          ScaffoldMessenger.of(ctx).showSnackBar(
                            SnackBar(
                              content: Text('Gagal mengubah PIN: $e'),
                              backgroundColor: AppTheme.danger,
                            ),
                          );
                        }
                      } finally {
                        if (ctx.mounted) {
                          setDialogState(() => isLoading = false);
                        }
                      }
                    },
              child: const Text('Simpan'),
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  const _SectionHeader({required this.title});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: AppTheme.textMuted,
          letterSpacing: 0.08,
        ),
      ),
    );
  }
}

class _SettingsTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final Widget? trailing;
  final VoidCallback? onTap;

  const _SettingsTile({
    required this.icon,
    required this.title,
    this.trailing,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      child: ListTile(
        leading: Icon(icon, color: AppTheme.primary),
        title: Text(
          title,
          style: const TextStyle(
            color: AppTheme.textPrimary,
            fontWeight: FontWeight.w500,
          ),
        ),
        trailing: trailing,
        onTap: onTap,
      ),
    );
  }
}
