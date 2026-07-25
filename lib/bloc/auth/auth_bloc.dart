// lib/bloc/auth/auth_bloc.dart
// BLoC untuk autentikasi: login, register, logout, PIN

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../data/repositories/repositories.dart';
import '../../data/models/models.dart';

// ─── Events ─────────────────────────────────────────────────────────────────

abstract class AuthEvent extends Equatable {
  @override
  List<Object?> get props => [];
}

class AuthCheckRequested extends AuthEvent {}

class AuthLoginRequested extends AuthEvent {
  final String email;
  final String password;
  AuthLoginRequested({required this.email, required this.password});
  @override
  List<Object?> get props => [email, password];
}

class AuthRegisterRequested extends AuthEvent {
  final String email;
  final String password;
  final String pin;
  AuthRegisterRequested({
    required this.email,
    required this.password,
    required this.pin,
  });
  @override
  List<Object?> get props => [email, password, pin];
}

class AuthLogoutRequested extends AuthEvent {}

class AuthDeleteAccountRequested extends AuthEvent {}

// ─── States ──────────────────────────────────────────────────────────────────

abstract class AuthState extends Equatable {
  @override
  List<Object?> get props => [];
}

class AuthInitial extends AuthState {}

class AuthLoading extends AuthState {}

class AuthAuthenticated extends AuthState {
  final User user;
  AuthAuthenticated(this.user);
  @override
  List<Object?> get props => [user];
}

class AuthUnauthenticated extends AuthState {}

class AuthNeedsSetup extends AuthState {}

class AuthError extends AuthState {
  final String message;
  AuthError(this.message);
  @override
  List<Object?> get props => [message];
}

// ─── BLoC ───────────────────────────────────────────────────────────────────

class AuthBloc extends Bloc<AuthEvent, AuthState> {
  final AuthRepository _authRepository;

  AuthBloc({required AuthRepository authRepository})
      : _authRepository = authRepository,
        super(AuthInitial()) {
    on<AuthCheckRequested>(_onCheckRequested);
    on<AuthLoginRequested>(_onLoginRequested);
    on<AuthRegisterRequested>(_onRegisterRequested);
    on<AuthLogoutRequested>(_onLogoutRequested);
    on<AuthDeleteAccountRequested>(_onDeleteAccountRequested);
  }

  Future<void> _onCheckRequested(
    AuthCheckRequested event,
    Emitter<AuthState> emit,
  ) async {
    emit(AuthLoading());
    try {
      final isLoggedIn = await _authRepository.isLoggedIn();
      if (isLoggedIn) {
        final user = await _authRepository.getMe();
        emit(AuthAuthenticated(user));
      } else {
        emit(AuthUnauthenticated());
      }
    } catch (e) {
      emit(AuthUnauthenticated());
    }
  }

  Future<void> _onLoginRequested(
    AuthLoginRequested event,
    Emitter<AuthState> emit,
  ) async {
    emit(AuthLoading());
    try {
      await _authRepository.login(
        email: event.email,
        password: event.password,
      );
      final user = await _authRepository.getMe();
      emit(AuthAuthenticated(user));
    } on AuthException catch (e) {
      emit(AuthError(e.message));
    } catch (e) {
      emit(AuthError('Login gagal. Silakan coba lagi.'));
    }
  }

  Future<void> _onRegisterRequested(
    AuthRegisterRequested event,
    Emitter<AuthState> emit,
  ) async {
    emit(AuthLoading());
    try {
      await _authRepository.register(
        email: event.email,
        password: event.password,
        pin: event.pin,
      );
      final user = await _authRepository.getMe();
      emit(AuthAuthenticated(user));
    } on AuthException catch (e) {
      emit(AuthError(e.message));
    } catch (e) {
      emit(AuthError('Registrasi gagal. Silakan coba lagi.'));
    }
  }

  Future<void> _onLogoutRequested(
    AuthLogoutRequested event,
    Emitter<AuthState> emit,
  ) async {
    emit(AuthLoading());
    try {
      await _authRepository.logout();
    } finally {
      emit(AuthUnauthenticated());
    }
  }

  Future<void> _onDeleteAccountRequested(
    AuthDeleteAccountRequested event,
    Emitter<AuthState> emit,
  ) async {
    emit(AuthLoading());
    try {
      await _authRepository.deleteAccount();
    } finally {
      emit(AuthUnauthenticated());
    }
  }
}
