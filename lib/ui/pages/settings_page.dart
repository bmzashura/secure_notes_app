// lib/ui/pages/settings_page.dart
// Screen 08 — Security Settings

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:local_auth/local_auth.dart';
import '../../bloc/auth/auth_bloc.dart';
import '../../core/theme/app_theme.dart';
import '../../core/secure_storage/secure_storage_service.dart';
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
          // Account Section
          _SectionHeader(title: 'AKUN'),
          _SettingsTile(
            icon: Icons.email_outlined,
            title: 'user@email.com',
            subtitle: 'Akun didaftarkan',
            onTap: null,
          ),
          const SizedBox(height: 8),
          _SettingsTile(
            icon: Icons.lock_outline,
            title: 'Ganti Password',
            trailing: const Icon(
              Icons.chevron_right,
              color: AppTheme.textMuted,
            ),
            onTap: () => _showChangePasswordDialog(),
          ),
          const SizedBox(height: 24),
          // Security Section
          _SectionHeader(title: 'KEAMANAN CATATAN'),
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
                activeColor: AppTheme.primary,
              ),
              onTap: null,
            ),
          const SizedBox(height: 8),
          // Auto-lock
          _SettingsTile(
            icon: Icons.timer_outlined,
            title: 'Auto-Lock',
            trailing: DropdownButton<String>(
              value: '30 detik',
              underline: const SizedBox(),
              dropdownColor: AppTheme.surfaceElevated,
              items: const [
                DropdownMenuItem(value: '15 detik', child: Text('15 detik')),
                DropdownMenuItem(value: '30 detik', child: Text('30 detik')),
                DropdownMenuItem(value: '1 menit', child: Text('1 menit')),
                DropdownMenuItem(value: '5 menit', child: Text('5 menit')),
              ],
              onChanged: (_) {},
            ),
            onTap: null,
          ),
          const SizedBox(height: 24),
          // Data Section
          _SectionHeader(title: 'DATA'),
          _SettingsTile(
            icon: Icons.delete_forever,
            title: 'Hapus Semua Data',
            titleColor: AppTheme.danger,
            onTap: () => _showDeleteAccountDialog(),
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
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.surfaceElevated,
        title: const Text('Ganti PIN'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: oldPinController,
              obscureText: true,
              keyboardType: TextInputType.number,
              maxLength: 6,
              decoration: const InputDecoration(labelText: 'PIN Lama'),
            ),
            TextField(
              controller: newPinController,
              obscureText: true,
              keyboardType: TextInputType.number,
              maxLength: 6,
              decoration: const InputDecoration(labelText: 'PIN Baru'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Batal'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('PIN berhasil diubah'),
                  backgroundColor: AppTheme.success,
                ),
              );
            },
            child: const Text('Simpan'),
          ),
        ],
      ),
    );
  }

  void _showChangePasswordDialog() {
    final oldPwController = TextEditingController();
    final newPwController = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.surfaceElevated,
        title: const Text('Ganti Password'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: oldPwController,
              obscureText: true,
              decoration: const InputDecoration(labelText: 'Password Lama'),
            ),
            TextField(
              controller: newPwController,
              obscureText: true,
              decoration: const InputDecoration(labelText: 'Password Baru'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Batal'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Password berhasil diubah'),
                  backgroundColor: AppTheme.success,
                ),
              );
            },
            child: const Text('Simpan'),
          ),
        ],
      ),
    );
  }

  void _showDeleteAccountDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.surfaceElevated,
        title: const Row(
          children: [
            Icon(Icons.warning, color: AppTheme.danger),
            SizedBox(width: 8),
            Text('Hapus Akun?'),
          ],
        ),
        content: const Text(
          'Semua catatan dan data akan dihapus permanen. '
          'Operasi ini TIDAK DAPAT dibatalkan.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Batal'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.danger,
            ),
            onPressed: () {
              Navigator.of(ctx).pop();
              context.read<AuthBloc>().add(AuthDeleteAccountRequested());
              Navigator.of(context).pushAndRemoveUntil(
                MaterialPageRoute(builder: (_) => const LoginPage()),
                (route) => false,
              );
            },
            child: const Text('Hapus Permanen'),
          ),
        ],
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
  final String? subtitle;
  final Widget? trailing;
  final VoidCallback? onTap;
  final Color? titleColor;

  const _SettingsTile({
    required this.icon,
    required this.title,
    this.subtitle,
    this.trailing,
    this.onTap,
    this.titleColor,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      child: ListTile(
        leading: Icon(icon, color: titleColor ?? AppTheme.primary),
        title: Text(
          title,
          style: TextStyle(
            color: titleColor ?? AppTheme.textPrimary,
            fontWeight: FontWeight.w500,
          ),
        ),
        subtitle: subtitle != null
            ? Text(
                subtitle!,
                style: const TextStyle(
                  color: AppTheme.textMuted,
                  fontSize: 12,
                ),
              )
            : null,
        trailing: trailing,
        onTap: onTap,
      ),
    );
  }
}
