// lib/ui/pages/register_page.dart
// Screen 03 — Register

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:pinput/pinput.dart';
import '../../bloc/auth/auth_bloc.dart';
import '../../core/theme/app_theme.dart';

class RegisterPage extends StatefulWidget {
  const RegisterPage({super.key});

  @override
  State<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  String _pin = '';
  bool _obscurePassword = true;
  bool _obscureConfirm = true;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  void _onRegister() {
    if (!_formKey.currentState!.validate()) return;
    if (_pin.length < 4) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('PIN wajib 4-6 digit angka'),
          backgroundColor: AppTheme.warning,
        ),
      );
      return;
    }
    context.read<AuthBloc>().add(AuthRegisterRequested(
          email: _emailController.text.trim(),
          password: _passwordController.text,
          pin: _pin,
        ));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Daftar Akun'),
      ),
      body: BlocListener<AuthBloc, AuthState>(
        listener: (context, state) {
          if (state is AuthError) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(state.message),
                backgroundColor: AppTheme.danger,
              ),
            );
          } else if (state is AuthAuthenticated) {
            Navigator.of(context).popUntil((route) => route.isFirst);
          }
        },
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Email
                TextFormField(
                  controller: _emailController,
                  keyboardType: TextInputType.emailAddress,
                  decoration: const InputDecoration(
                    labelText: 'Email',
                    prefixIcon: Icon(Icons.email_outlined),
                    helperText: 'Email akan jadi username akun',
                  ),
                  validator: (v) {
                    if (v == null || v.isEmpty) return 'Email wajib diisi';
                    if (!v.contains('@')) return 'Format email tidak valid';
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                // Password
                TextFormField(
                  controller: _passwordController,
                  obscureText: _obscurePassword,
                  decoration: InputDecoration(
                    labelText: 'Password (min 8 karakter)',
                    prefixIcon: const Icon(Icons.lock_outline),
                    suffixIcon: IconButton(
                      icon: Icon(
                        _obscurePassword
                            ? Icons.visibility_outlined
                            : Icons.visibility_off_outlined,
                      ),
                      onPressed: () {
                        setState(() => _obscurePassword = !_obscurePassword);
                      },
                    ),
                  ),
                  validator: (v) {
                    if (v == null || v.isEmpty) return 'Password wajib diisi';
                    if (v.length < 8) return 'Minimal 8 karakter';
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                // Confirm Password
                TextFormField(
                  controller: _confirmPasswordController,
                  obscureText: _obscureConfirm,
                  decoration: InputDecoration(
                    labelText: 'Konfirmasi Password',
                    prefixIcon: const Icon(Icons.lock_outline),
                    suffixIcon: IconButton(
                      icon: Icon(
                        _obscureConfirm
                            ? Icons.visibility_outlined
                            : Icons.visibility_off_outlined,
                      ),
                      onPressed: () {
                        setState(() => _obscureConfirm = !_obscureConfirm);
                      },
                    ),
                  ),
                  validator: (v) {
                    if (v != _passwordController.text) {
                      return 'Password tidak cocok';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 24),
                // PIN Section
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppTheme.surfaceCard,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppTheme.border),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: const [
                          Icon(Icons.pin, color: AppTheme.accentCyan, size: 20),
                          SizedBox(width: 8),
                          Text(
                            'Setup PIN (4-6 digit)',
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              color: AppTheme.textPrimary,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        'PIN untuk membuka aplikasi',
                        style: TextStyle(
                          color: AppTheme.textSecondary,
                          fontSize: 13,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Center(
                        child: Pinput(
                          length: 6,
                          obscureText: true,
                          onChanged: (v) {
                            setState(() => _pin = v);
                          },
                          defaultPinTheme: PinTheme(
                            width: 48,
                            height: 48,
                            decoration: BoxDecoration(
                              color: AppTheme.surfaceElevated,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: AppTheme.border),
                            ),
                            textStyle: const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: AppTheme.textPrimary,
                            ),
                          ),
                          focusedPinTheme: PinTheme(
                            width: 48,
                            height: 48,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: AppTheme.primary,
                                width: 2,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                // Register Button
                BlocBuilder<AuthBloc, AuthState>(
                  builder: (context, state) {
                    return ElevatedButton(
                      onPressed: state is AuthLoading ? null : _onRegister,
                      child: state is AuthLoading
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Text('DAFTAR SEKARANG'),
                    );
                  },
                ),
                const SizedBox(height: 16),
                // Login link
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text(
                      'Sudah punya akun? ',
                      style: TextStyle(color: AppTheme.textSecondary),
                    ),
                    GestureDetector(
                      onTap: () => Navigator.of(context).pop(),
                      child: const Text(
                        'Login',
                        style: TextStyle(
                          color: AppTheme.primary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
