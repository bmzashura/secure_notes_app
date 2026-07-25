// lib/app.dart
// App widget dengan Dependency Injection + BLoC providers

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:get_it/get_it.dart';
import 'core/theme/app_theme.dart';
import 'core/api/api_client.dart';
import 'core/secure_storage/secure_storage_service.dart';
import 'core/crypto/crypto_service.dart';
import 'data/repositories/repositories.dart';
import 'data/repositories/notes_repository.dart';
import 'bloc/auth/auth_bloc.dart';
import 'bloc/notes/notes_bloc.dart';
import 'ui/pages/splash_page.dart';
import 'ui/pages/home_page.dart';
import 'ui/pages/login_page.dart';
import 'ui/pages/register_page.dart';
import 'ui/pages/pin_entry_page.dart';

final getIt = GetIt.instance;

void setupDependencies() {
  getIt.registerLazySingleton(() => SecureStorageService());
  getIt.registerLazySingleton(() => CryptoService());
  getIt.registerLazySingleton(
    () => ApiClient(secureStorage: getIt<SecureStorageService>()),
  );

  getIt.registerLazySingleton(
    () => AuthRepository(
      apiClient: getIt<ApiClient>(),
      secureStorage: getIt<SecureStorageService>(),
    ),
  );
  getIt.registerLazySingleton(
    () => NotesRepository(
      apiClient: getIt<ApiClient>(),
      cryptoService: getIt<CryptoService>(),
      secureStorage: getIt<SecureStorageService>(),
    ),
  );

  getIt.registerFactory(
    () => AuthBloc(authRepository: getIt<AuthRepository>()),
  );
  getIt.registerFactory(
    () => NotesBloc(notesRepository: getIt<NotesRepository>()),
  );
}

// Auto-lock: 10 seconds in background
const _autoLockDuration = Duration(seconds: 10);

class SecureNotesApp extends StatefulWidget {
  const SecureNotesApp({super.key});

  @override
  State<SecureNotesApp> createState() => _SecureNotesAppState();
}

class _SecureNotesAppState extends State<SecureNotesApp> with WidgetsBindingObserver {
  DateTime? _lastPausedTime;
  bool _isAuthenticated = false;
  final _navigatorKey = GlobalKey<NavigatorState>();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused) {
      _lastPausedTime = DateTime.now();
    } else if (state == AppLifecycleState.resumed) {
      _checkAutoLock();
    }
  }

  void _checkAutoLock() {
    if (_lastPausedTime == null) return;
    if (!_isAuthenticated) return;

    final elapsed = DateTime.now().difference(_lastPausedTime!);
    if (elapsed >= _autoLockDuration) {
      _isAuthenticated = false;
      _lastPausedTime = null;
      _navigatorKey.currentState?.pushNamedAndRemoveUntil(
        '/pin-entry',
        (route) => false,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider<AuthBloc>(
          create: (_) => getIt<AuthBloc>()..add(AuthCheckRequested()),
        ),
        BlocProvider<NotesBloc>(
          create: (_) => getIt<NotesBloc>(),
        ),
      ],
      child: BlocListener<AuthBloc, AuthState>(
        listener: (context, state) {
          _isAuthenticated = state is AuthAuthenticated;
        },
        child: MaterialApp(
          navigatorKey: _navigatorKey,
          title: 'SecureNotes',
          debugShowCheckedModeBanner: false,
          theme: AppTheme.darkTheme,
          home: const SplashPage(),
          routes: {
            '/pin-entry': (_) => const PinEntryPage(),
            '/home': (_) => const HomePage(),
            '/login': (_) => const LoginPage(),
            '/register': (_) => const RegisterPage(),
          },
        ),
      ),
    );
  }
}
