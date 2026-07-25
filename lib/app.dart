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

final getIt = GetIt.instance;

void setupDependencies() {
  // Core services
  getIt.registerLazySingleton(() => SecureStorageService());
  getIt.registerLazySingleton(() => CryptoService());
  getIt.registerLazySingleton(
    () => ApiClient(secureStorage: getIt<SecureStorageService>()),
  );

  // Repositories
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

  // BLoCs
  getIt.registerFactory(
    () => AuthBloc(authRepository: getIt<AuthRepository>()),
  );
  getIt.registerFactory(
    () => NotesBloc(notesRepository: getIt<NotesRepository>()),
  );
}

class SecureNotesApp extends StatelessWidget {
  const SecureNotesApp({super.key});

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
      child: MaterialApp(
        title: 'SecureNotes',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.darkTheme,
        home: const SplashPage(),
      ),
    );
  }
}
