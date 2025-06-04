import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:firebase_auth/firebase_auth.dart' as firebase;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:result_dart/result_dart.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../../core/database/database_provider.dart';
import '../../../../core/logging/app_logger.dart';
import '../../data/services/firebase_auth_service.dart';
import '../../domain/entities/user.dart';
import '../../domain/repositories/auth_repository.dart';

part 'auth_providers.g.dart';

/// Provider for Firebase Auth instance
@riverpod
firebase.FirebaseAuth firebaseAuth(Ref ref) {
  return firebase.FirebaseAuth.instance;
}

/// Provider for Google Sign-In instance
@riverpod
GoogleSignIn googleSignIn(Ref ref) {
  return GoogleSignIn(scopes: ['email', 'profile']);
}

/// Provider for Connectivity instance
@riverpod
Connectivity connectivity(Ref ref) {
  return Connectivity();
}

/// Provider for AuthRepository implementation
@riverpod
AuthRepository authRepository(Ref ref) {
  return FirebaseAuthService(
    firebaseAuth: ref.watch(firebaseAuthProvider),
    googleSignIn: ref.watch(googleSignInProvider),
    database: ref.watch(appDatabaseProvider),
    connectivity: ref.watch(connectivityProvider),
  );
}

/// Auth state notifier for managing authentication state
@riverpod
class AuthNotifier extends _$AuthNotifier {
  @override
  Stream<User?> build() {
    final authRepo = ref.watch(authRepositoryProvider);
    return authRepo.authStateChanges();
  }

  /// Sign in with Google
  Future<Result<User>> signInWithGoogle() async {
    final logger = ref.read(appLoggerProvider);
    final authRepo = ref.read(authRepositoryProvider);

    logger.i('🔐 Starting Google Sign-In...');

    final result = await authRepo.signInWithGoogle();

    return result.fold(
      (user) {
        logger.i('✅ Sign-in successful: ${user.displayName}');
        return Success(user);
      },
      (error) {
        logger.e('❌ Sign-in failed: $error');
        return Failure(error);
      },
    );
  }

  /// Check sign-out risk
  Future<Result<SignOutRisk>> checkSignOutRisk() async {
    final authRepo = ref.read(authRepositoryProvider);
    return authRepo.checkSignOutRisk();
  }

  /// Sign out with data clearing
  Future<Result<void>> signOut() async {
    final logger = ref.read(appLoggerProvider);
    final authRepo = ref.read(authRepositoryProvider);

    logger.w('🚪 Starting sign-out process...');

    final result = await authRepo.signOut();

    return result.fold(
      (_) {
        logger.i('✅ Sign-out successful - all data cleared');
        return Success('Signed out and data cleared');
      },
      (error) {
        logger.e('❌ Sign-out failed: $error');
        return Failure(error);
      },
    );
  }

  /// Get current user synchronously
  User? getCurrentUser() {
    final authRepo = ref.read(authRepositoryProvider);
    return authRepo.getCurrentUser();
  }

  /// Whether user is authenticated
  bool get isAuthenticated {
    final authRepo = ref.read(authRepositoryProvider);
    return authRepo.isAuthenticated;
  }
}

/// Convenience provider for current user
@riverpod
User? currentUser(Ref ref) {
  final authState = ref.watch(authNotifierProvider);
  return authState.whenOrNull(data: (user) => user);
}

/// Convenience provider for authentication status
@riverpod
bool isAuthenticated(Ref ref) {
  final user = ref.watch(currentUserProvider);
  return user != null;
}
